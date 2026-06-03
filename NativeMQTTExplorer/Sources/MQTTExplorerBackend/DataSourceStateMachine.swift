import Foundation

/// Connection state for a data source.
public struct DataSourceState: Sendable, CustomStringConvertible {
    public var connecting: Bool
    public var connected: Bool
    public var error: String?

    public init(connecting: Bool = false, connected: Bool = false, error: String? = nil) {
        self.connecting = connecting
        self.connected = connected
        self.error = error
    }

    public var description: String {
        if let err = error { return "Error: \(err)" }
        if connecting { return "Connecting..." }
        if connected { return "Connected" }
        return "Disconnected"
    }
}

/// State machine that tracks connection lifecycle and dispatches updates.
public final class DataSourceStateMachine: @unchecked Sendable {
    public let onUpdate = EventDispatcher<DataSourceState>()

    private var state: DataSourceState = DataSourceState()

    public init() {}

    public var currentState: DataSourceState { state }

    public func setConnected(_ connected: Bool) {
        state = DataSourceState(connecting: false, connected: connected, error: nil)
        onUpdate.dispatch(state)
    }

    public func setError(_ error: Error) {
        state = DataSourceState(
            connecting: state.connecting,
            connected: state.connected,
            error: error.localizedDescription
        )
        onUpdate.dispatch(state)
    }

    public func setConnecting() {
        state = DataSourceState(connecting: true, connected: false, error: nil)
        onUpdate.dispatch(state)
    }
}
