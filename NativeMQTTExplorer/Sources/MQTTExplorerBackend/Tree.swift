import Foundation

/// The root of a topic tree that batches incoming messages and applies
/// them periodically via a timer. Mirroring the TS Tree<ViewModel>.
public final class Tree<ViewModel: Destroyable>: TreeNode<ViewModel>, @unchecked Sendable {
    public var connectionId: String?
    public var nodeFilter: ((TreeNode<ViewModel>) -> Bool)?

    private var unmergedMessages = ChangeBuffer()
    private var paused: Bool = false
    private var applyChangesHasCompleted: Bool = true
    private var updateTimer: DispatchSourceTimer?
    private let updateQueue = DispatchQueue.main

    public init() {
        super.init()
        isTree = true
        treeHash = UUID().uuidString
    }

    // MARK: - Batch update loop

    private func handleNewData(topic: String, payload: Base64Message?, qos: QoSType, retain: Bool, messageId: Int? = nil) {
        unmergedMessages.push(topic: topic, payload: payload, qos: qos, retain: retain, messageId: messageId)
    }

    private func runUpdates() {
        let timer = DispatchSource.makeTimerSource(queue: updateQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(300))
        timer.setEventHandler { [weak self] in
            guard let self, !self.paused, self.applyChangesHasCompleted else { return }
            self.applyChangesHasCompleted = false
            self.applyUnmergedChanges()
        }
        timer.resume()
        updateTimer = timer
    }

    // MARK: - Public API

    /// Call this for each incoming MQTT message on this connection.
    public func receiveMessage(topic: String, payload: Base64Message?, qos: QoSType, retain: Bool, messageId: Int? = nil) {
        Logger.shared.debug(category: "Tree", "Buffered message: \(topic) qos=\(qos.rawValue) retain=\(retain) size=\(payload?.length ?? 0)B")
        handleNewData(topic: topic, payload: payload, qos: qos, retain: retain, messageId: messageId)
    }

    /// Start the periodic update timer. Call after constructing.
    public func startUpdates() {
        runUpdates()
    }

    public func pause() {
        paused = true
    }

    public func resume() {
        paused = false
    }

    public func stopUpdating() {
        updateTimer?.cancel()
        updateTimer = nil
    }

    public func applyUnmergedChanges() {
        let batch = unmergedMessages.popAll()
        if !batch.isEmpty {
            Logger.shared.info(category: "Tree", "Applying \(batch.count) unmerged changes to tree")
        }
        for item in batch {
            let subTree: Tree<ViewModel> = TreeNodeFactory.fromMessage(
                topic: item.message.topic,
                payload: item.message.payload,
                qos: item.message.qos,
                retain: item.message.retain,
                messageId: item.message.messageId,
                receiveDate: item.received
            )

            if let filter = nodeFilter, !filter(subTree) {
                continue
            }
            updateWithNode(subTree)
        }
        didUpdate.dispatch(())
        Logger.shared.debug(category: "Tree", "applyUnmergedChanges complete. Root edges: [\(edgeArray.map(\.name).joined(separator: ", "))]. \(childTopicCount()) topics, \(leafMessageCount()) leaf msgs")
        applyChangesHasCompleted = true
    }

    public func unmergedChangeCount() -> Int {
        unmergedMessages.length
    }

    public var didUpdate = EventDispatcher<Void>()

    // MARK: - Overrides

    override public func destroy() {
        stopUpdating()
        didUpdate.removeAllListeners()
        super.destroy()
    }
}
