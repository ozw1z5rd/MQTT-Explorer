import Foundation

/// Manages MQTT connections and routes messages to trees.
/// Mirroring the TS ConnectionManager.
public final class ConnectionManager: @unchecked Sendable {
    private var connections: [String: MqttSource] = [:]
    private var messageCallbacks: [String: (String, Base64Message?, QoSType, Bool, Int?) -> Void] = [:]
    private let lock = NSLock()

    public init() {}

    /// Connect and start receiving messages into the provided callback.
    @discardableResult
    public func connect(
        id connectionId: String,
        options: MqttOptions,
        onMessage: @escaping (String, Base64Message?, QoSType, Bool, Int?) -> Void,
        onStateChange: @escaping (DataSourceState) -> Void
    ) -> MqttSource {
        lock.lock()
        if let existing = connections[connectionId] {
            existing.disconnect()
        }

        let source = MqttSource()
        connections[connectionId] = source
        messageCallbacks[connectionId] = onMessage
        lock.unlock()

        source.stateMachine.onUpdate.subscribe { state in
            onStateChange(state)
        }

        source.pendingRouteCallback = { [weak self] topic, payload, qos, retain, msgId in
            guard let self else { return }
            self.lock.lock()
            let cb = self.messageCallbacks[connectionId]
            self.lock.unlock()
            cb?(topic, payload, qos, retain, msgId)
        }

        source.connect(options: options)
        return source
    }

    public func publish(connectionId: String, topic: String, payload: Base64Message?, qos: QoSType, retain: Bool) {
        lock.lock()
        let source = connections[connectionId]
        lock.unlock()
        source?.publish(topic: topic, payload: payload, qos: qos, retain: retain)
    }

    public func disconnect(connectionId: String) {
        lock.lock()
        let source = connections[connectionId]
        connections.removeValue(forKey: connectionId)
        messageCallbacks.removeValue(forKey: connectionId)
        lock.unlock()
        source?.disconnect()
    }

    public func disconnectAll() {
        lock.lock()
        let all = connections
        connections.removeAll()
        messageCallbacks.removeAll()
        lock.unlock()
        for (_, source) in all {
            source.disconnect()
        }
    }
}
