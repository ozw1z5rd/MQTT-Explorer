import SwiftUI
import MQTTExplorerBackend
import Combine

/// ViewModel node that conforms to Destroyable for use as the Tree's generic parameter.
final class AppViewModelNode: Destroyable, @unchecked Sendable {
    func destroy() {}
}

/// Central coordinator: owns the ConnectionManager and Tree, bridges backend events to SwiftUI.
@MainActor
final class AppViewModel: ObservableObject {
    @Published var connectionState: DataSourceState = .init()
    @Published var treeVersion: Int = 0
    @Published var connectedHost: String = ""
    @Published var isConnecting: Bool = false
    @Published var rootEdgeNames: [String] = []
    @Published var totalMessageCount: Int = 0
    @Published var connectionElapsed: String = ""

    let connectionManager = ConnectionManager()
    let tree = Tree<AppViewModelNode>()

    private var currentConnectionId: String = ""

    init() {
        tree.startUpdates()

        // Subscribe once to tree updates
        tree.didUpdate.subscribe { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.treeVersion += 1
                self.rootEdgeNames = self.tree.edgeArray.map(\.name)
            }
        }
    }

    // MARK: - Connection

    func connect(host: String, port: UInt16, tls: Bool, username: String, password: String, subscriptions: [MQTTExplorerBackend.Subscription]) {
        isConnecting = true
        currentConnectionId = UUID().uuidString
        connectedHost = host

        let protocolStr = tls ? "mqtts" : "mqtt"
        let url = "\(protocolStr)://\(host):\(port)"

        let options = MqttOptions(
            url: url,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            tls: tls,
            certValidation: true,
            clientId: "MQTTExplorer-\(UUID().uuidString.prefix(8))",
            subscriptions: subscriptions
        )

        connectionManager.connect(
            id: currentConnectionId,
            options: options,
            onMessage: { [weak self] topic, payload, qos, retain, msgId in
                guard let self else { return }
                self.tree.receiveMessage(
                    topic: topic,
                    payload: payload,
                    qos: qos,
                    retain: retain,
                    messageId: msgId
                )
                Task { @MainActor in
                    self.totalMessageCount &+= 1
                }
            },
            onStateChange: { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    self.connectionState = state
                    if state.connected {
                        self.isConnecting = false
                        self.startElapsedTimer()
                    } else if state.error != nil {
                        self.isConnecting = false
                    }
                }
            }
        )
    }

    func disconnect() {
        connectionManager.disconnect(connectionId: currentConnectionId)
        connectedHost = ""
        connectionState = .init()
        isConnecting = false
        totalMessageCount = 0
        connectionElapsed = ""
    }

    // MARK: - Publish

    func publish(topic: String, payload: String, qos: QoSType = .atMostOnce, retain: Bool = false) {
        let msg = Base64Message.from(string: payload)
        connectionManager.publish(
            connectionId: currentConnectionId,
            topic: topic,
            payload: msg,
            qos: qos,
            retain: retain
        )
    }

    // MARK: - Tree access

    var rootEdges: [MQTTExplorerBackend.Edge<AppViewModelNode>] {
        tree.edgeArray
    }

    // MARK: - Elapsed timer

    private var elapsedTimer: Timer?
    private var connectionStartTime: Date?

    private func startElapsedTimer() {
        let start = Date()
        connectionStartTime = start
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let h = elapsed / 3600
            let m = (elapsed % 3600) / 60
            let s = elapsed % 60
            let text = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
            Task { @MainActor in
                self.connectionElapsed = text
            }
        }
    }
}
