import Foundation

/// Topic data type for display/formatting.
public enum TopicDataType: String, Sendable {
    case string
    case json
    case hex
}

/// Decoder type for specialized payload decoding.
public enum DecoderType: Sendable {
    case none
    case sparkplug
}
