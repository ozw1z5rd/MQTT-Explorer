import Foundation

/// Severity level for log entries.
public enum LogLevel: String, Sendable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// A single log entry emitted by the backend.
public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String

    public var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let time = formatter.string(from: timestamp)
        return "[\(time)] [\(level.rawValue)] [\(category)] \(message)"
    }
}

/// A thread-safe in-memory log ring that retains the most recent entries
/// and dispatches each new entry to registered callbacks.
public final class Logger: @unchecked Sendable {
    public static let shared = Logger()

    private var entries: [LogEntry] = []
    private let maxEntries: Int
    private let lock = NSLock()
    private var callbacks: [(LogEntry) -> Void] = []

    /// Subscribe to every new log entry (called on an arbitrary thread).
    @discardableResult
    public func onEntry(_ callback: @escaping (LogEntry) -> Void) -> UUID {
        lock.lock()
        let id = UUID()
        callbacks.append(callback)
        lock.unlock()
        return id
    }

    public init(maxEntries: Int = 2000) {
        self.maxEntries = maxEntries
    }

    // MARK: - Writing

    public func log(level: LogLevel, category: String, _ message: String) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        let snapshot = callbacks
        lock.unlock()
        for cb in snapshot {
            cb(entry)
        }
    }

    public func debug(category: String, _ message: String) {
        log(level: .debug, category: category, message)
    }

    public func info(category: String, _ message: String) {
        log(level: .info, category: category, message)
    }

    public func warn(category: String, _ message: String) {
        log(level: .warning, category: category, message)
    }

    public func error(category: String, _ message: String) {
        log(level: .error, category: category, message)
    }

    // MARK: - Reading

    public func allEntries() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func entries(matching level: LogLevel) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.level == level }
    }

    public func entries(containing text: String) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        let lower = text.lowercased()
        return entries.filter { $0.message.lowercased().contains(lower) }
    }

    public var entryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    public func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
