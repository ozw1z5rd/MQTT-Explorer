import Foundation

/// Factory for creating tree nodes from MQTT messages.
/// Mirroring the TS TreeNodeFactory.
public enum TreeNodeFactory {
    private static var messageCounter = 0
    private static let lock = NSLock()

    /// Builds a chain of edges + intermediate nodes under the given tree root
    /// for the specified topic segments, then attaches the leaf node.
    public static func insertNodeAtPosition<ViewModel: Destroyable>(
        edgeNames: [String],
        node: TreeNode<ViewModel>,
        into tree: TreeNode<ViewModel>
    ) {
        var currentNode: TreeNode<ViewModel> = tree
        var lastEdge: Edge<ViewModel>?
        for name in edgeNames {
            let edge = Edge<ViewModel>(name: name)
            currentNode.addEdge(edge)
            let nextNode = TreeNode<ViewModel>(sourceEdge: edge)
            edge.target = nextNode
            currentNode = nextNode
            lastEdge = edge
        }
        node.sourceEdge = lastEdge
        lastEdge?.target = node
    }

    /// Creates an independent temporary tree from an MQTT message.
    /// The returned tree is a standalone Tree root that can be merged
    /// into the persistent tree via updateWithNode().
    public static func fromMessage<ViewModel: Destroyable>(
        topic: String,
        payload: Base64Message?,
        qos: QoSType = .atMostOnce,
        retain: Bool = false,
        messageId: Int? = nil,
        receiveDate: Date = Date()
    ) -> Tree<ViewModel> {
        lock.lock()
        let msgNumber = messageCounter
        messageCounter += 1
        lock.unlock()

        let node = TreeNode<ViewModel>()
        let edges = topic.split(separator: "/").map(String.init)

        let msg = Message(
            topic: topic,
            payload: payload,
            qos: qos,
            retain: retain,
            messageId: messageId,
            messageNumber: msgNumber,
            received: receiveDate
        )
        node.setMessage(msg)
        let tree = Tree<ViewModel>()
        insertNodeAtPosition(edgeNames: edges, node: node, into: tree)
        return tree
    }
}
