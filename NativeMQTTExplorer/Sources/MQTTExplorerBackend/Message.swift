import Foundation

/// MQTT message metadata + payload, mirroring the TS Message interface.
public struct Message: Sendable {
    public var payload: Base64Message?
    public var messageId: Int?
    public var retain: Bool
    public var qos: QoSType
    public var length: Int
    public var received: Date
    public var messageNumber: Int
    public var topic: String

    public init(
        topic: String,
        payload: Base64Message?,
        qos: QoSType = .atMostOnce,
        retain: Bool = false,
        messageId: Int? = nil,
        messageNumber: Int = 0,
        received: Date = Date()
    ) {
        self.topic = topic
        self.payload = payload
        self.qos = qos
        self.retain = retain
        self.messageId = messageId
        self.length = payload?.length ?? 0
        self.received = received
        self.messageNumber = messageNumber
    }
}
