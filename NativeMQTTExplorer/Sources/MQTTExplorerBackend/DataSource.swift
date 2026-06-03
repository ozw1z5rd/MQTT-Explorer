import Foundation

/// Protocol for an MQTT data source. Mirroring the TS DataSource interface.
public protocol DataSource: AnyObject {
    associatedtype Options

    var topicSeparator: String { get }
    var stateMachine: DataSourceStateMachine { get }

    func connect(options: Options)
    func disconnect()
    func onMessage(_ callback: @escaping (String, Data, MqttPacketInfo) -> Void)
    func publish(topic: String, payload: Base64Message?, qos: QoSType, retain: Bool)
}

/// QoS levels, matching MQTT spec.
public enum QoSType: Int, Sendable {
    case atMostOnce = 0
    case atLeastOnce = 1
    case exactlyOnce = 2
}

/// Minimal packet info passed to message callbacks.
public struct MqttPacketInfo: Sendable {
    public let qos: QoSType
    public let retain: Bool
    public let messageId: Int?

    public init(qos: QoSType = .atMostOnce, retain: Bool = false, messageId: Int? = nil) {
        self.qos = qos
        self.retain = retain
        self.messageId = messageId
    }
}
