import XCTest
@testable import MQTTExplorerBackend

final class RingBufferTests: XCTestCase {
    func testAddAndCount() {
        let buf = RingBuffer<Message>(capacity: 10_000, maxItems: 100)
        let msg = Message(topic: "test", payload: Base64Message.from(string: "x"))
        buf.add(msg)
        XCTAssertEqual(buf.count, 1)
    }

    func testCapacityEnforcement() {
        // Small byte capacity
        let buf = RingBuffer<Message>(capacity: 100, maxItems: 5)
        let longMsg = Message(topic: "test", payload: Base64Message.from(string: String(repeating: "a", count: 80)))

        buf.add(longMsg)
        XCTAssertEqual(buf.count, 1)

        buf.add(longMsg)
        // First one should be evicted
        XCTAssertLessThanOrEqual(buf.count, 2)
    }

    func testMaxItemsEnforcement() {
        let buf = RingBuffer<Message>(capacity: 100_000, maxItems: 3)
        for i in 0..<5 {
            buf.add(Message(topic: "t\(i)", payload: Base64Message.from(string: "x")))
        }
        XCTAssertEqual(buf.count, 3)
    }

    func testToArray() {
        let buf = RingBuffer<Message>(capacity: 10_000, maxItems: 5)
        buf.add(Message(topic: "a", payload: Base64Message.from(string: "1")))
        buf.add(Message(topic: "b", payload: Base64Message.from(string: "2")))
        let arr = buf.toArray()
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0].topic, "a")
        XCTAssertEqual(arr[1].topic, "b")
    }

    func testLast() {
        let buf = RingBuffer<Message>(capacity: 10_000, maxItems: 10)
        buf.add(Message(topic: "first", payload: Base64Message.from(string: "a")))
        buf.add(Message(topic: "last", payload: Base64Message.from(string: "b")))
        XCTAssertEqual(buf.last()?.topic, "last")
    }

    func testClone() {
        let buf = RingBuffer<Message>(capacity: 10_000, maxItems: 10)
        buf.add(Message(topic: "orig", payload: Base64Message.from(string: "val")))
        let copy = buf.clone()
        XCTAssertEqual(copy.count, 1)
        XCTAssertEqual(copy.last()?.topic, "orig")
    }
}
