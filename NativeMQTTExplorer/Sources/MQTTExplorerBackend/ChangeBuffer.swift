import Foundation

/// Buffer for incoming MQTT messages before they are merged into the tree.
/// Mirroring the TS ChangeBuffer.
public final class ChangeBuffer: @unchecked Sendable {
    private var buffer: [BufferedMessage] = []
    private var size: Int = 0
    private let maxSize: Int
    public let estimatedMessageOverhead: Int

    private let lock = NSLock()

    public init(maxSize: Int = 100_000_000, estimatedMessageOverhead: Int = 24) {
        self.maxSize = maxSize
        self.estimatedMessageOverhead = estimatedMessageOverhead
    }

    public var length: Int {
        lock.lock(); defer { lock.unlock() }
        return buffer.count
    }

    public var fillRatio: Double {
        lock.lock(); defer { lock.unlock() }
        return Double(size) / Double(maxSize)
    }

    public var isFull: Bool {
        lock.lock(); defer { lock.unlock() }
        return size >= maxSize
    }

    public func push(topic: String, payload: Base64Message?, qos: QoSType, retain: Bool, messageId: Int? = nil) {
        lock.lock()
        if size < maxSize {
            let msg = MqttMessageEvent(
                topic: topic,
                payload: payload,
                qos: qos,
                retain: retain,
                messageId: messageId
            )
            buffer.append(BufferedMessage(message: msg, received: Date()))
            size += estimatedMessageOverhead + (payload?.length ?? 0)
        }
        lock.unlock()
    }

    public func popAll() -> [BufferedMessage] {
        lock.lock()
        let tmp = buffer
        buffer = []
        size = 0
        lock.unlock()
        return tmp
    }
}

// MARK: - Types

public struct MqttMessageEvent: Sendable {
    public let topic: String
    public let payload: Base64Message?
    public let qos: QoSType
    public let retain: Bool
    public let messageId: Int?

    public init(topic: String, payload: Base64Message?, qos: QoSType, retain: Bool, messageId: Int? = nil) {
        self.topic = topic
        self.payload = payload
        self.qos = qos
        self.retain = retain
        self.messageId = messageId
    }
}

public struct BufferedMessage: Sendable {
    public let message: MqttMessageEvent
    public let received: Date
}
