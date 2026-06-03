import Foundation

/// A type-safe event dispatcher (replaceable with Combine for SwiftUI integration).
public final class EventDispatcher<Msg>: @unchecked Sendable {
    private var callbacks: [(UUID, (Msg) -> Void)] = []

    public init() {}

    public func dispatch(_ msg: Msg) {
        let snapshot = callbacks
        for (_, cb) in snapshot {
            cb(msg)
        }
    }

    @discardableResult
    public func subscribe(_ callback: @escaping (Msg) -> Void) -> UUID {
        let id = UUID()
        callbacks.append((id, callback))
        return id
    }

    public func unsubscribe(id: UUID) {
        callbacks.removeAll { $0.0 == id }
    }

    public func removeAllListeners() {
        callbacks.removeAll()
    }
}
