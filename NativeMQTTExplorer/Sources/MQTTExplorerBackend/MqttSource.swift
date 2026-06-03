import Foundation
import CocoaMQTT

/// MQTT connection options.
public struct MqttOptions: Sendable {
    public var url: String
    public var username: String?
    public var password: String?
    public var tls: Bool
    public var certValidation: Bool
    public var clientId: String?
    public var subscriptions: [Subscription]
    public var certificateAuthority: String?
    public var clientCertificate: String?
    public var clientKey: String?

    public init(
        url: String,
        username: String? = nil,
        password: String? = nil,
        tls: Bool = false,
        certValidation: Bool = true,
        clientId: String? = nil,
        subscriptions: [Subscription] = [Subscription(topic: "#", qos: .atMostOnce)],
        certificateAuthority: String? = nil,
        clientCertificate: String? = nil,
        clientKey: String? = nil
    ) {
        self.url = url
        self.username = username
        self.password = password
        self.tls = tls
        self.certValidation = certValidation
        self.clientId = clientId
        self.subscriptions = subscriptions
        self.certificateAuthority = certificateAuthority
        self.clientCertificate = clientCertificate
        self.clientKey = clientKey
    }
}

public struct Subscription: Sendable {
    public var topic: String
    public var qos: QoSType

    public init(topic: String, qos: QoSType) {
        self.topic = topic
        self.qos = qos
    }
}

/// MQTT data source backed by CocoaMQTT.
/// Mirroring the TS MqttSource.
public final class MqttSource: NSObject, DataSource, @unchecked Sendable {
    public typealias Options = MqttOptions

    public let stateMachine = DataSourceStateMachine()
    public let topicSeparator = "/"

    private var client: CocoaMQTT?
    private var messageCallback: ((String, Data, MqttPacketInfo) -> Void)?
    private var pendingSubscriptions: [Subscription] = []

    // Internal routing callback set by ConnectionManager
    internal var pendingRouteCallback: ((String, Base64Message?, QoSType, Bool, Int?) -> Void)?

    public override init() {
        super.init()
    }

    public func onMessage(_ callback: @escaping (String, Data, MqttPacketInfo) -> Void) {
        messageCallback = callback
    }

    public func connect(options: MqttOptions) {
        stateMachine.setConnecting()
        Logger.shared.info(category: "MqttSource", "Connecting to \(options.url)...")

        let urlStr: String
        if options.tls {
            if options.url.hasPrefix("mqtt://") {
                urlStr = options.url.replacingOccurrences(of: "mqtt://", with: "mqtts://")
            } else if options.url.hasPrefix("ws://") {
                urlStr = options.url.replacingOccurrences(of: "ws://", with: "wss://")
            } else {
                urlStr = options.url
            }
        } else {
            urlStr = options.url
        }

        // Parse host and port
        guard let parsed = parseMQTTURL(urlStr) else {
            let errMsg = "Invalid MQTT URL: \(urlStr)"
            Logger.shared.error(category: "MqttSource", errMsg)
            stateMachine.setError(NSError(domain: "MqttSource", code: -1,
                userInfo: [NSLocalizedDescriptionKey: errMsg]))
            return
        }

        let useTLS = parsed.scheme == "mqtts" || parsed.scheme == "wss" || options.tls
        let useWebSocket = parsed.scheme == "ws" || parsed.scheme == "wss"
        _ = useWebSocket

        let clientId = options.clientId ?? "MQTTExplorer-\(UUID().uuidString.prefix(8))"
        let mqttClient = CocoaMQTT(clientID: clientId, host: parsed.host, port: parsed.port)

        mqttClient.username = options.username ?? ""
        mqttClient.password = options.password ?? ""
        mqttClient.enableSSL = useTLS
        mqttClient.allowUntrustCACertificate = !options.certValidation
        mqttClient.autoReconnect = true
        mqttClient.keepAlive = 60
        mqttClient.delegate = self

        // TLS certificates
        if useTLS {
            if let ca = options.certificateAuthority,
               let _ = Data(base64Encoded: ca) {
                // CocoaMQTT uses SSL settings through its own mechanism;
                // for server-side CA, we set allowUntrustCACertificate above.
                // Client certs not fully exposed; this would require CocoaMQTT fork or custom SSL stream.
            }
        }

        pendingSubscriptions = options.subscriptions
        self.client = mqttClient
        Logger.shared.debug(category: "MqttSource", "Client \(clientId) connecting to \(parsed.host):\(parsed.port) tls=\(useTLS) ws=\(useWebSocket)")
        let _ = mqttClient.connect()
    }

    public func disconnect() {
        Logger.shared.info(category: "MqttSource", "Disconnecting...")
        client?.disconnect()
        client = nil
    }

    public func publish(topic: String, payload: Base64Message?, qos: QoSType, retain: Bool) {
        guard let client else { return }
        let data = payload?.toBuffer() ?? Data()
        let cQos = CocoaMQTTQoS(rawValue: UInt8(qos.rawValue)) ?? .qos0
        let msg = CocoaMQTTMessage(
            topic: topic,
            payload: [UInt8](data),
            qos: cQos,
            retained: retain
        )
        Logger.shared.info(category: "MqttSource", "Publishing to \(topic) qos=\(qos.rawValue) retain=\(retain) size=\(data.count)B")
        client.publish(msg)
    }
}

// MARK: - CocoaMQTTDelegate
extension MqttSource: CocoaMQTTDelegate {
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            Logger.shared.info(category: "MqttSource", "Connected successfully. Subscribing to \(pendingSubscriptions.count) topic(s)")
            stateMachine.setConnected(true)
            for sub in pendingSubscriptions {
                Logger.shared.debug(category: "MqttSource", "Subscribing to \(sub.topic) qos=\(sub.qos.rawValue)")
                let cQos = CocoaMQTTQoS(rawValue: UInt8(sub.qos.rawValue)) ?? .qos0
                mqtt.subscribe(sub.topic, qos: cQos)
            }
        } else {
            let errMsg = "Connection refused: \(ack)"
            Logger.shared.error(category: "MqttSource", errMsg)
            stateMachine.setError(NSError(domain: "MqttSource", code: Int(ack.rawValue),
                userInfo: [NSLocalizedDescriptionKey: errMsg]))
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let rawBytes = message.payload
        let data = Data(rawBytes)
        let payload = data.isEmpty ? nil : Base64Message.from(buffer: data)
        let qosVal = QoSType(rawValue: Int(message.qos.rawValue)) ?? .atMostOnce
        let packet = MqttPacketInfo(
            qos: qosVal,
            retain: message.retained
        )

        let payloadPreview: String
        if let p = payload {
            let text = p.toUnicodeString()
            payloadPreview = text.count > 80 ? String(text.prefix(80)) + "..." : text
        } else {
            payloadPreview = "<empty>"
        }
        Logger.shared.debug(category: "MQTT", "\(message.topic) qos=\(qosVal.rawValue) retain=\(message.retained) size=\(data.count)B payload=\(payloadPreview)")

        messageCallback?(message.topic, data, packet)

        // Route through the connection manager pipeline
        pendingRouteCallback?(message.topic, payload, packet.qos, packet.retain, nil)
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        Logger.shared.info(category: "MqttSource", "Subscribed to \(success.count) topic(s)")
        let errors = failed.map { "Failed to subscribe to \($0)" }
        if !errors.isEmpty {
            for err in errors {
                Logger.shared.error(category: "MqttSource", err)
            }
            stateMachine.setError(NSError(domain: "MqttSource", code: -2,
                userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: ", ")]))
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}

    public func mqttDidPing(_ mqtt: CocoaMQTT) {}
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}

    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        if let err {
            Logger.shared.error(category: "MqttSource", "Disconnected with error: \(err.localizedDescription)")
            stateMachine.setError(err)
        } else {
            Logger.shared.info(category: "MqttSource", "Disconnected")
            stateMachine.setConnected(false)
        }
    }
}

// MARK: - URL Parsing
private struct ParsedMQTTURL {
    let scheme: String
    let host: String
    let port: UInt16
}

private func parseMQTTURL(_ urlString: String) -> ParsedMQTTURL? {
    let lower = urlString.lowercased()
    var scheme = "mqtt"
    var hostPart = urlString

    if lower.hasPrefix("mqtts://") {
        scheme = "mqtts"
        hostPart = String(urlString.dropFirst(8))
    } else if lower.hasPrefix("mqtt://") {
        scheme = "mqtt"
        hostPart = String(urlString.dropFirst(7))
    } else if lower.hasPrefix("ws://") {
        scheme = "ws"
        hostPart = String(urlString.dropFirst(5))
    } else if lower.hasPrefix("wss://") {
        scheme = "wss"
        hostPart = String(urlString.dropFirst(6))
    }

    let components = hostPart.split(separator: ":", maxSplits: 1)
    guard let host = components.first.map(String.init), !host.isEmpty else { return nil }

    let port: UInt16
    if components.count == 2, let p = UInt16(components[1]) {
        port = p
    } else {
        port = (scheme == "mqtts" || scheme == "wss") ? 8883 : 1883
    }

    return ParsedMQTTURL(scheme: scheme, host: host, port: port)
}
