import XCTest
@testable import MQTTExplorerBackend

final class Base64MessageTests: XCTestCase {
    func testFromString() {
        let msg = Base64Message.from(string: "hello")
        XCTAssertEqual(msg.toUnicodeString(), "hello")
    }

    func testFromBuffer() {
        let data = "world".data(using: .utf8)!
        let msg = Base64Message.from(buffer: data)
        XCTAssertEqual(msg.toUnicodeString(), "world")
    }

    func testFormatJson() {
        let json = #"{"key":"value"}"#
        let msg = Base64Message.from(string: json)
        let (formatted, isJson) = msg.format(type: .json)
        XCTAssertTrue(isJson)
        XCTAssertTrue(formatted.contains(#""key""#))
    }

    func testFormatHex() {
        let msg = Base64Message.from(string: "AB")
        let (formatted, _) = msg.format(type: .hex)
        XCTAssertTrue(formatted.contains("0x41"))
        XCTAssertTrue(formatted.contains("0x42"))
    }

    func testFormatString() {
        let msg = Base64Message.from(string: "plain")
        let (formatted, isJson) = msg.format(type: .string)
        XCTAssertEqual(formatted, "plain")
        XCTAssertFalse(isJson)
    }

    func testEmptyMessage() {
        let msg = Base64Message()
        XCTAssertEqual(msg.toUnicodeString(), "")
        XCTAssertEqual(msg.length, 0)
    }

    func testToBuffer() {
        let msg = Base64Message.from(string: "test")
        let buf = msg.toBuffer()
        XCTAssertNotNil(buf)
        XCTAssertEqual(String(data: buf!, encoding: .utf8), "test")
    }

    func testToHex() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let msg = Base64Message.from(buffer: data)
        let hex = Base64Message.toHex(message: msg)
        XCTAssertTrue(hex.contains("0xDE"))
        XCTAssertTrue(hex.contains("0xAD"))
    }

    func testToDataUri() {
        let msg = Base64Message.from(string: "data")
        let uri = Base64Message.toDataUri(message: msg, mimeType: "text/plain")
        XCTAssertTrue(uri.hasPrefix("data:text/plain;base64,"))
    }
}
