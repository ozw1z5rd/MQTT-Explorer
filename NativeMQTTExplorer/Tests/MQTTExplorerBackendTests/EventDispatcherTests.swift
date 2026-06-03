import XCTest
@testable import MQTTExplorerBackend

final class EventDispatcherTests: XCTestCase {
    func testDispatchToSubscribers() {
        let dispatcher = EventDispatcher<String>()
        let expectation = self.expectation(description: "dispatch")

        dispatcher.subscribe { msg in
            XCTAssertEqual(msg, "hello")
            expectation.fulfill()
        }

        dispatcher.dispatch("hello")
        wait(for: [expectation], timeout: 1)
    }

    func testUnsubscribe() {
        let dispatcher = EventDispatcher<Int>()
        var callCount = 0

        let id = dispatcher.subscribe { _ in
            callCount += 1
        }
        dispatcher.dispatch(1)
        dispatcher.unsubscribe(id: id)
        dispatcher.dispatch(2)

        XCTAssertEqual(callCount, 1)
    }

    func testRemoveAllListeners() {
        let dispatcher = EventDispatcher<Void>()
        var count = 0

        dispatcher.subscribe { count += 1 }
        dispatcher.subscribe { count += 1 }
        dispatcher.removeAllListeners()
        dispatcher.dispatch(())
        XCTAssertEqual(count, 0)
    }
}
