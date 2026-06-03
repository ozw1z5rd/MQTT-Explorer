import Foundation

/// Wraps MQTT payload as a base64-encoded string, mirroring the TS Base64Message.
public final class Base64Message: @unchecked Sendable {
    public let base64String: String

    private var _unicodeCache: String?

    public var length: Int {
        base64String.count
    }

    private var unicodeValue: String {
        if let cached = _unicodeCache {
            return cached
        }
        guard let data = Data(base64Encoded: base64String),
              let str = String(data: data, encoding: .utf8) else {
            _unicodeCache = ""
            return ""
        }
        _unicodeCache = str
        return str
    }

    public init(base64String: String = "") {
        self.base64String = base64String
        self._unicodeCache = nil
    }

    public init?(copying other: Base64Message?) {
        guard let other else { return nil }
        base64String = other.base64String
        _unicodeCache = nil
    }

    public func toUnicodeString() -> String {
        unicodeValue
    }

    public static func from(buffer: Data) -> Base64Message {
        Base64Message(base64String: buffer.base64EncodedString())
    }

    public func toBuffer() -> Data? {
        Data(base64Encoded: base64String)
    }

    public static func from(string: String) -> Base64Message {
        let encoded = string.data(using: .utf8)?.base64EncodedString() ?? ""
        return Base64Message(base64String: encoded)
    }

    public func format(type: TopicDataType = .string) -> (String, Bool) {
        switch type {
        case .json:
            if let jsonData = unicodeValue.data(using: .utf8),
               let jsonObj = try? JSONSerialization.jsonObject(with: jsonData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted]),
               let prettyStr = String(data: prettyData, encoding: .utf8) {
                return (prettyStr, true)
            }
            return (unicodeValue, false)
        case .hex:
            return (Base64Message.toHex(message: self), false)
        case .string:
            return (unicodeValue, false)
        }
    }

    public static func toHex(message: Base64Message) -> String {
        guard let buf = Data(base64Encoded: message.base64String) else { return "" }
        return buf.map { b in
            let hex = String(b, radix: 16, uppercase: true)
            return "0x\(hex.count < 2 ? "0" + hex : hex)"
        }.joined(separator: " ")
    }

    public static func toDataUri(message: Base64Message, mimeType: String) -> String {
        "data:\(mimeType);base64,\(message.base64String)"
    }
}

// MARK: - Codable
extension Base64Message: Codable {
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let b64 = try container.decode(String.self, forKey: .base64String)
        self.init(base64String: b64)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(base64String, forKey: .base64String)
    }

    private enum CodingKeys: String, CodingKey {
        case base64String
    }
}
