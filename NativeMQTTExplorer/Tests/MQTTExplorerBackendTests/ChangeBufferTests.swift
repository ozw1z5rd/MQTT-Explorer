import XCTest
@testable import MQTTExplorerBackend

final class ChangeBufferTests: XCTestCase {
    func testPushAndPop() {
        let buf = ChangeBuffer(maxSize: 10_000)
        XCTAssertFalse(buf.isFull)

        buf.push(topic: "test", payload: Base64Message.from(string: "hello"), qos: .atMostOnce, retain: false)
        XCTAssertEqual(buf.length, 1)

        let popped = buf.popAll()
        XCTAssertEqual(popped.count, 1)
        XCTAssertEqual(popped[0].message.topic, "test")
        XCTAssertEqual(buf.length, 0)
    }

    func testFillRatio() {
        let buf = ChangeBuffer(maxSize: 100)
        XCTAssertEqual(buf.fillRatio, 0, accuracy: 0.001)
    }

    func testFullBuffer() {
        let buf = ChangeBuffer(maxSize: 1) // Very small
        buf.push(topic: "a", payload: Base64Message.from(string: "x"), qos: .atMostOnce, retain: false)
        buf.push(topic: "b", payload: Base64Message.from(string: "y"), qos: .atMostOnce, retain: false)
        // Second push should be dropped since buffer is full
        let popped = buf.popAll()
        XCTAssertLessThanOrEqual(popped.count, 1)
    }
}
