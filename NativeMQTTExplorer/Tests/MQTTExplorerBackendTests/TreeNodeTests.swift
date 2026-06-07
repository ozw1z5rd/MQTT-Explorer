import XCTest
@testable import MQTTExplorerBackend

final class TreeNodeTests: XCTestCase {
    func testFirstNodeShouldRetrieveFirstNode() {
        let leaf = makeTreeNode(topic: "foo/bar")
        XCTAssertNotNil(leaf.firstNode().edges["foo"])
    }

    func testUpdateWithNodeShouldUpdateValue() {
        let leaf = makeTreeNode(topic: "foo/bar", message: "3")
        XCTAssertEqual(leaf.message?.payload?.toUnicodeString(), "3")

        let updateLeaf = makeTreeNode(topic: "foo/bar", message: "5")
        let root = leaf.firstNode()
        root.updateWithNode(updateLeaf.firstNode())

        XCTAssertNil(root.sourceEdge)
        XCTAssertEqual(leaf.message?.payload?.toUnicodeString(), "5")
    }

    func testUpdateWithNodeShouldUpdateIntermediateNodes() {
        let leaf = makeTreeNode(topic: "foo/bar/baz", message: "3")
        XCTAssertEqual(leaf.message?.payload?.toUnicodeString(), "3")

        let updateLeaf = makeTreeNode(topic: "foo/bar", message: "5")
        leaf.firstNode().updateWithNode(updateLeaf.firstNode())

        let barNode = leaf.firstNode().findNode(path: "foo/bar")
        XCTAssertNotNil(barNode)
        XCTAssertEqual(barNode?.sourceEdge?.name, "bar")
        XCTAssertEqual(barNode?.message?.payload?.toUnicodeString(), "5")

        XCTAssertEqual(leaf.sourceEdge?.name, "baz")
        XCTAssertEqual(leaf.message?.payload?.toUnicodeString(), "3")
    }

    func testUpdateWithNodeShouldAddNodesToTree() {
        let leaf1 = makeTreeNode(topic: "foo/bar", message: "foo")
        let leaf2 = makeTreeNode(topic: "foo/bar/baz", message: "bar")
        leaf1.firstNode().updateWithNode(leaf2.firstNode())

        let found = leaf1.firstNode().findNode(path: "foo/bar/baz")
        XCTAssertNotNil(found, "merge seems to have failed")
    }

    func testPath() {
        let leaf = makeTreeNode(topic: "foo/bar/baz")
        XCTAssertEqual(leaf.path(), "foo/bar/baz")

        let barNode = leaf.firstNode().findNode(path: "foo/bar")
        XCTAssertEqual(barNode?.path(), "foo/bar")
    }

    func testBranch() {
        let leaf = makeTreeNode(topic: "a/b/c")
        let branch = leaf.branch()
        XCTAssertEqual(branch.count, 4) // root + a + b + c
    }

    func testChildTopicCount() {
        let root = makeTreeNode(topic: "a", message: "1").firstNode()
        _ = makeTreeNode(topic: "b", message: "2").firstNode()
        root.updateWithNode(makeTreeNode(topic: "b", message: "2").firstNode())
        // Root should have 2 children with messages
        XCTAssertGreaterThanOrEqual(root.childTopicCount(), 2)
    }

    func testLeafMessageCount() {
        _ = makeTreeNode(topic: "x/y", message: "1")
        _ = makeTreeNode(topic: "x/z", message: "2")
        let root = makeTreeNode(topic: "x/w", message: "3").firstNode()
        root.updateWithNode(makeTreeNode(topic: "x/y", message: "1").firstNode())
        root.updateWithNode(makeTreeNode(topic: "x/z", message: "2").firstNode())

        let xNode = root.findNode(path: "x")
        XCTAssertNotNil(xNode)
        XCTAssertEqual(xNode?.leafMessageCount(), 3)
    }

    func testDestroy() {
        let leaf = makeTreeNode(topic: "test/leaf", message: "val")
        leaf.firstNode().destroy()
        // After destroy, edges should be empty
        XCTAssertEqual(leaf.firstNode().edgeArray.count, 0)
    }

    func testFindNode() {
        _ = makeTreeNode(topic: "home/livingroom/temperature", message: "22")
        let root = makeTreeNode(topic: "home/livingroom/humidity", message: "60").firstNode()
        root.updateWithNode(makeTreeNode(topic: "home/livingroom/temperature", message: "22").firstNode())

        let tempNode = root.findNode(path: "home/livingroom/temperature")
        XCTAssertNotNil(tempNode)
        XCTAssertEqual(tempNode?.message?.payload?.toUnicodeString(), "22")
    }

    func testOnMergeDispatched() {
        let expectation = self.expectation(description: "onMerge called")
        let node = TreeNode<MockViewModel>()
        node.onMerge.subscribe {
            expectation.fulfill()
        }
        let other = makeTreeNode(topic: "test", message: "val")
        node.updateWithNode(other.firstNode())
        wait(for: [expectation], timeout: 2)
    }

    func testOnMessageDispatched() {
        let expectation = self.expectation(description: "onMessage called")
        let node = TreeNode<MockViewModel>()
        node.onMessage.subscribe { msg in
            XCTAssertEqual(msg.payload?.toUnicodeString(), "hi")
            expectation.fulfill()
        }
        let other = makeTreeNode(topic: "test", message: "hi")
        node.updateWithNode(other.firstNode())
        wait(for: [expectation], timeout: 2)
    }
}

// MARK: - Helpers

private final class MockViewModel: Destroyable, @unchecked Sendable {
    func destroy() {}
}

private var retainedTrees: [AnyObject] = []

private func makeTreeNode(topic: String, message: String? = nil) -> TreeNode<MockViewModel> {
    let payload = message.map { Base64Message.from(string: $0) }
    let tree: Tree<MockViewModel> = TreeNodeFactory.fromMessage(topic: topic, payload: payload)
    retainedTrees.append(tree)
    return tree.findNode(path: topic) ?? tree
}
