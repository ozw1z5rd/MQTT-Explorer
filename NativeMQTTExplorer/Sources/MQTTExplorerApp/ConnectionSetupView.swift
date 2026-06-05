import SwiftUI
import MQTTExplorerBackend

struct ConnectionSetupView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var host: String = ""
    @State private var portText: String = "1883"
    @State private var tls: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var subscriptionText: String = "#"

    private var port: UInt16 {
        UInt16(portText) ?? 1883
    }

    private var subscriptions: [MQTTExplorerBackend.Subscription] {
        subscriptionText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { MQTTExplorerBackend.Subscription(topic: $0, qos: .atMostOnce) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("MQTT Explorer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Connect to an MQTT broker")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Error banner
            if let error = viewModel.connectionState.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 16)
            }

            // Form
            Form {
                Section("Server") {
                    TextField("Host (e.g. test.mosquitto.org)", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    HStack {
                        TextField("Port", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Toggle("TLS", isOn: $tls)
                    }
                }

                Section("Authentication (optional)") {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Subscriptions") {
                    TextField("Topics (comma-separated)", text: $subscriptionText)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    Text("Use # to subscribe to all topics, or specify individual topics.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quick connect presets
                Section("Quick Connect") {
                    HStack(spacing: 12) {
                        QuickConnectButton(label: "homebridge.local", host: "homebridge.local", port: "1883") {
                            fillConnection(host: "homebridge.local", port: "1883")
                        }
                        QuickConnectButton(label: "eclipseprojects.io", host: "mqtt.eclipseprojects.io", port: "1883") {
                            fillConnection(host: "mqtt.eclipseprojects.io", port: "1883")
                        }
                        QuickConnectButton(label: "broker.emqx.io", host: "broker.emqx.io", port: "1883") {
                            fillConnection(host: "broker.emqx.io", port: "1883")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            // Connect button
            VStack(spacing: 12) {
                Button(action: connect) {
                    HStack {
                        if viewModel.isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        Text(viewModel.isConnecting ? "Connecting..." : "Connect")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isConnecting)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 580)
    }

    private func fillConnection(host: String, port: String) {
        self.host = host
        self.portText = port
        self.tls = false
        self.username = ""
        self.password = ""
        self.subscriptionText = "#"
    }

    private func connect() {
        viewModel.connect(
            host: host.trimmingCharacters(in: .whitespaces),
            port: port,
            tls: tls,
            username: username,
            password: password,
            subscriptions: subscriptions
        )
    }
}

// MARK: - Quick Connect Button

private struct QuickConnectButton: View {
    let label: String
    let host: String
    let port: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
