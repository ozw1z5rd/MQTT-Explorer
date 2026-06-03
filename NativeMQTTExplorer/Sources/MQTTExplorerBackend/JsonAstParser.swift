import Foundation

/// Parse JSON text to extract property paths and locations.
/// Mirroring the TS JsonAstParser.
public enum JsonAstParser {
    public struct JsonPropertyLocation: @unchecked Sendable {
        public let path: String
        public let line: Int
        public let value: Any
        public let column: Int

        public init(path: String, line: Int, value: Any, column: Int) {
            self.path = path
            self.line = line
            self.value = value
            self.column = column
        }
    }

    /// Parse formatted JSON and return an array of property locations.
    public static func parse(_ formattedJson: String) -> [JsonPropertyLocation] {
        guard let data = formattedJson.data(using: .utf8) else { return [] }
        return extractPropertyPaths(from: data, previousPath: [])
    }

    private static func extractPropertyPaths(from data: Data, previousPath: [String]) -> [JsonPropertyLocation] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        return extractFromAny(json, path: previousPath)
    }

    private static func extractFromAny(_ value: Any, path: [String]) -> [JsonPropertyLocation] {
        if let dict = value as? [String: Any] {
            return dict.flatMap { (key, val) -> [JsonPropertyLocation] in
                let escapedKey = key.replacingOccurrences(of: ".", with: "\\.")
                let newPath = path + [escapedKey]
                return extractFromAny(val, path: newPath)
            }
        } else if let arr = value as? [Any] {
            return arr.enumerated().flatMap { (idx, val) -> [JsonPropertyLocation] in
                let newPath = path + [String(idx)]
                return extractFromAny(val, path: newPath)
            }
        } else {
            return [JsonPropertyLocation(
                path: path.joined(separator: "."),
                line: 0,
                value: value,
                column: 0
            )]
        }
    }

    /// Return literals mapped by line number (1-based indexing).
    public static func literalsMappedByLines(_ formattedJson: String) -> [Int: JsonPropertyLocation] {
        let properties = parse(formattedJson)
        var result: [Int: JsonPropertyLocation] = [:]
        for prop in properties {
            result[prop.line > 0 ? prop.line - 1 : 0] = prop
        }
        return result
    }
}
