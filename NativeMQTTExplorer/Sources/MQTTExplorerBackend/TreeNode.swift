import Foundation

/// A node in the MQTT topic tree. Mirroring the TS TreeNode<ViewModel>.
/// Each node represents a segment in an MQTT topic path and may contain
/// a message payload, edges to child nodes, and message history.
public class TreeNode<ViewModel: Destroyable>: Destroyable, @unchecked Sendable {
    public weak var sourceEdge: Edge<ViewModel>?
    public var message: Message?
    public var messageHistory: RingBuffer<Message> = RingBuffer<Message>(capacity: 20_000, maxItems: 100)
    public var viewModel: ViewModel?
    public var edges: [String: Edge<ViewModel>] = [:]
    public var edgeArray: [Edge<ViewModel>] = []
    public var collapsed: Bool = false
    public var messages: Int = 0
    public var lastUpdate: TimeInterval = Date().timeIntervalSince1970
    public let onMerge = EventDispatcher<Void>()
    public let onEdgesChange = EventDispatcher<Void>()
    public let onMessage = EventDispatcher<Message>()
    public let onDestroy = EventDispatcher<TreeNode<ViewModel>>()
    public var isTree: Bool = false
    public var type: TopicDataType = .json

    /// Only meaningful on Tree instances (the root).
    public var treeHash: String = UUID().uuidString

    // Caches
    private var cachedPath: String?
    private var cachedChildTopics: [TreeNode<ViewModel>]?
    private var cachedLeafMessageCount: Int?
    private var cachedChildTopicCount: Int?

    public init(sourceEdge: Edge<ViewModel>? = nil, message: Message? = nil) {
        if let edge = sourceEdge {
            self.sourceEdge = edge
            edge.target = self
        }
        if let msg = message {
            setMessage(msg)
        }

        onMerge.subscribe { [weak self] in
            self?.invalidateCaches()
            self?.lastUpdate = Date().timeIntervalSince1970
        }
        onEdgesChange.subscribe { [weak self] in
            self?.invalidateCaches()
            self?.lastUpdate = Date().timeIntervalSince1970
        }
        onMessage.subscribe { [weak self] _ in
            self?.lastUpdate = Date().timeIntervalSince1970
        }
    }

    private func invalidateCaches() {
        cachedChildTopics = nil
        cachedChildTopicCount = nil
        cachedLeafMessageCount = nil
    }

    // MARK: - Tree navigation

    private func previous() -> TreeNode<ViewModel>? {
        sourceEdge?.source
    }

    public var isLeaf: Bool {
        edgeArray.isEmpty
    }

    private var isTopicEmptyLeaf: Bool {
        !hasMessage && isLeaf
    }

    public var hasMessage: Bool {
        guard let m = message, let p = m.payload else { return false }
        return p.length > 0
    }

    public func findChild(path segments: [String]) -> TreeNode<ViewModel>? {
        if segments.isEmpty { return self }
        guard let edge = edges[segments[0]] else { return nil }
        return edge.target?.findChild(path: Array(segments.dropFirst()))
    }

    public func findNode(path: String) -> TreeNode<ViewModel>? {
        findChild(path: path.split(separator: "/").map(String.init))
    }

    public func firstNode() -> TreeNode<ViewModel> {
        if let edge = sourceEdge, let src = edge.source {
            return src.firstNode()
        }
        return self
    }

    public func path() -> String {
        if let cached = cachedPath { return cached }
        let p = branch()
            .compactMap { $0.sourceEdge?.name }
            .joined(separator: "/")
        cachedPath = p
        return p
    }

    public func branch() -> [TreeNode<ViewModel>] {
        if let prev = previous() {
            return prev.branch() + [self]
        }
        return [self]
    }

    // MARK: - Edge management

    public func addEdge(_ edge: Edge<ViewModel>, emitUpdate: Bool = false) {
        edges[edge.name] = edge
        edgeArray.append(edge)
        edge.source = self
        edge.target?.removeFromTreeIfEmpty()
        if emitUpdate {
            onEdgesChange.dispatch(())
        }
    }

    public func removeEdge(_ edge: Edge<ViewModel>) {
        edges.removeValue(forKey: edge.name)
        edgeArray = Array(edges.values)
        removeFromTreeIfEmpty()
        onMerge.dispatch(())
    }

    private func removeFromParent() {
        guard let prev = previous(), let edge = sourceEdge else { return }
        lastUpdate = Date().timeIntervalSince1970
        prev.removeEdge(edge)
        if !isTree {
            destroy()
        }
    }

    public func removeFromTreeIfEmpty() {
        if isTopicEmptyLeaf {
            removeFromParent()
        }
    }

    // MARK: - Message

    public func setMessage(_ msg: Message) {
        messageHistory.add(msg)
        message = msg
        messages += 1
    }

    // MARK: - Merge

    private func mergeEdges(from node: TreeNode<ViewModel>) {
        var edgesDidUpdate = false
        for (key, incomingEdge) in node.edges {
            if let existing = edges[key] {
                Logger.shared.debug(category: "Tree", "Merging existing edge \(key) at \(self.path())")
                existing.target?.updateWithNode(incomingEdge.target!)
            } else {
                Logger.shared.debug(category: "Tree", "Adding new edge \(key) at \(self.path())")
                addEdge(incomingEdge, emitUpdate: false)
                edgesDidUpdate = true
            }
        }
        if edgesDidUpdate {
            onEdgesChange.dispatch(())
        }
    }

    public func updateWithNode(_ node: TreeNode<ViewModel>) {
        if let msg = node.message {
            Logger.shared.debug(category: "Tree", "setMessage at \(self.path()) payload=\(msg.payload?.toUnicodeString().prefix(40) ?? "<nil>")")
            setMessage(msg)
            onMessage.dispatch(msg)
        }
        removeFromTreeIfEmpty()
        mergeEdges(from: node)
        onMerge.dispatch(())
    }

    // MARK: - Counts

    public func leafMessageCount() -> Int {
        if let cached = cachedLeafMessageCount { return cached }
        let sum = edgeArray.reduce(0) { $0 + $1.target!.leafMessageCount() }
        cachedLeafMessageCount = sum + messages
        return cachedLeafMessageCount!
    }

    public func childTopicCount() -> Int {
        if let cached = cachedChildTopicCount { return cached }
        let sum = edgeArray.reduce(0) { $0 + $1.target!.childTopicCount() }
        cachedChildTopicCount = sum + (hasMessage ? 1 : 0)
        return cachedChildTopicCount!
    }

    public func edgeCount() -> Int {
        edgeArray.count
    }

    public func childTopics() -> [TreeNode<ViewModel>] {
        if let cached = cachedChildTopics { return cached }
        let initial: [TreeNode<ViewModel>] = (message != nil && message?.payload != nil) ? [self] : []
        let result = edgeArray.reduce(initial) { $0 + $1.target!.childTopics() }
        cachedChildTopics = result
        return result
    }

    // MARK: - Destroyable

    open func destroy() {
        onDestroy.dispatch(self)
        onDestroy.removeAllListeners()

        for edge in edgeArray {
            edge.target?.destroy()
        }
        viewModel?.destroy()
        viewModel = nil
        edgeArray = []
        edges = [:]
        cachedChildTopics = []
        sourceEdge = nil
        onMerge.removeAllListeners()
        onEdgesChange.removeAllListeners()
        onMessage.removeAllListeners()
        messageHistory = RingBuffer<Message>(capacity: 1, maxItems: 1)
        message = nil
    }

    public func unconnectedClone() -> TreeNode<ViewModel> {
        let node = TreeNode<ViewModel>()
        node.message = message
        node.messageHistory = messageHistory.clone()
        node.messages = messages
        node.lastUpdate = lastUpdate
        return node
    }

    public func hashValue() -> String {
        "N\(sourceEdge?.hash() ?? "")"
    }
}

// MARK: - HashableProtocol conformance
extension TreeNode: HashableProtocol {
    public func hash() -> String {
        hashValue()
    }
}
