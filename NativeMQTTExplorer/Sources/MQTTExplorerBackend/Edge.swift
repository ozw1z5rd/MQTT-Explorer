import Foundation
import CryptoKit

/// An edge in the topic tree. Mirroring the TS Edge<ViewModel>.
/// target is strong (parent owns child through the edge),
/// source is weak (child→parent is a back-reference to avoid cycles).
public final class Edge<ViewModel: Destroyable>: HashableProtocol, Identifiable {
    public var id: String { name }

    public let name: String

    public var target: TreeNode<ViewModel>?
    public weak var source: TreeNode<ViewModel>?

    /// Children of this edge's target node, for use with OutlineGroup.
    public var children: [Edge<ViewModel>]? {
        guard let node = target, !node.edgeArray.isEmpty else { return nil }
        return node.edgeArray
    }

    private var cachedHash: String?

    public init(name: String) {
        self.name = name
    }

    public func edges() -> [Edge<ViewModel>] {
        target?.edgeArray ?? []
    }

    public func hash() -> String {
        if let cached = cachedHash {
            return cached
        }

        var previousHash = ""
        if let src = source, let srcEdge = src.sourceEdge {
            previousHash = srcEdge.hash()
        } else if let src = source, src.isTree {
            previousHash = src.treeHash
        }

        let input = previousHash + name
        let digest = Insecure.SHA1.hash(data: Data(input.utf8))
        let sha = digest.map { String(format: "%02x", $0) }.joined()
        cachedHash = "H\(sha)"
        return cachedHash!
    }

    public func firstEdge() -> Edge<ViewModel> {
        if let src = source, let srcEdge = src.sourceEdge {
            return srcEdge.firstEdge()
        }
        return self
    }
}
