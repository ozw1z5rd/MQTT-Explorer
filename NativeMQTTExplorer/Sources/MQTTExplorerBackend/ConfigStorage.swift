import Foundation

/// Persistent configuration storage using a local JSON file.
/// Mirroring the TS ConfigStorage (simplified — no RPC layer needed).
public final class ConfigStorage: @unchecked Sendable {
    private let fileURL: URL
    private var data: [String: Any] = [:]
    private let lock = NSLock()

    public init(filePath: String) {
        self.fileURL = URL(fileURLWithPath: filePath)
    }

    /// Load existing data or create an empty store.
    public func load() {
        lock.lock()
        defer { lock.unlock() }

        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        guard let existingData = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] else {
            data = [:]
            return
        }
        data = json
    }

    /// Save all data to disk.
    public func save() {
        lock.lock()
        defer { lock.unlock() }

        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted]) else {
            return
        }
        try? jsonData.write(to: fileURL, options: .atomic)
    }

    public func get<T>(_ key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return data[key] as? T
    }

    public func set<T>(_ key: String, value: T) {
        lock.lock()
        data[key] = value
        lock.unlock()
        save()
    }

    public func remove(_ key: String) {
        lock.lock()
        data.removeValue(forKey: key)
        lock.unlock()
        save()
    }

    public func clear() {
        lock.lock()
        data.removeAll()
        lock.unlock()
        save()
    }

    public func allKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(data.keys)
    }
}
