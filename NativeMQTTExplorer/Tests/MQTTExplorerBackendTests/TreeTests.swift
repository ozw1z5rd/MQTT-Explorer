import XCTest
@testable import MQTTExplorerBackend

final class TreeTests: XCTestCase {
    func testTreeBatchedUpdates() {
        let tree = Tree<MockViewModel>()
        tree.startUpdates()

        // Feed messages
        tree.receiveMessage(topic: "a/b", payload: Base64Message.from(string: "1"), qos: .atMostOnce, retain: false)
        tree.receiveMessage(topic: "a/c", payload: Base64Message.from(string: "2"), qos: .atMostOnce, retain: false)

        // Allow timer to fire
        let expectation = self.expectation(description: "didUpdate")
        tree.didUpdate.subscribe {
            expectation.fulfill()
        }

        // Force immediate apply
        tree.applyUnmergedChanges()

        wait(for: [expectation], timeout: 2)

        let nodeB = tree.findNode(path: "a/b")
        XCTAssertNotNil(nodeB)
        XCTAssertEqual(nodeB?.message?.payload?.toUnicodeString(), "1")

        let nodeC = tree.findNode(path: "a/c")
        XCTAssertNotNil(nodeC)
    }

    func testTreePauseResume() {
        let tree = Tree<MockViewModel>()
        tree.startUpdates()

        tree.receiveMessage(topic: "x", payload: Base64Message.from(string: "before"), qos: .atMostOnce, retain: false)
        tree.pause()
        tree.receiveMessage(topic: "y", payload: Base64Message.from(string: "after"), qos: .atMostOnce, retain: false)

        // Apply manually — should process everything in the buffer regardless of pause
        tree.applyUnmergedChanges()

        XCTAssertNotNil(tree.findNode(path: "x"))
    }

    func testTreeDestroy() {
        let tree = Tree<MockViewModel>()
        tree.startUpdates()
        tree.receiveMessage(topic: "test", payload: Base64Message.from(string: "val"), qos: .atMostOnce, retain: false)
        tree.applyUnmergedChanges()
        tree.destroy()

        XCTAssertEqual(tree.edgeArray.count, 0)
    }
}

private final class MockViewModel: Destroyable, @unchecked Sendable {
    func destroy() {}
}
