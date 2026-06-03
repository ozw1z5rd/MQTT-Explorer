import SwiftUI
import MQTTExplorerBackend

/// Identifiable wrapper for tree nodes so they can be used with List selection.
private struct NodeIdentifier: Hashable {
    let path: String

    init(_ node: TreeNode<AppViewModelNode>) {
        self.path = node.path()
    }
}

struct TopicTreeView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var searchText: String = ""
    @State private var selectedPath: String?
    @State private var showLogs: Bool = false

    private var selectedNode: TreeNode<AppViewModelNode>? {
        guard let path = selectedPath else { return nil }
        return viewModel.tree.findNode(path: path)
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: tree
            List(selection: $selectedPath) {
                Section(header: connectionHeader) {
                    if rootEdges.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Waiting for messages...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        ForEach(filteredEdges, id: \.name) { edge in
                            TreeNodeRow(edge: edge, searchFilter: searchText)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Filter topics...")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { viewModel.disconnect() }) {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showLogs.toggle() }) {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
                    .help("Show message log")
                }
            }
        } detail: {
            // Detail: selected node info
            if let node = selectedNode {
                NodeDetailView(node: node, viewModel: viewModel)
            } else {
                VStack {
                    Image(systemName: "tree")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a topic to view details")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showLogs) {
            LogViewerView()
                .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 600)
        }
    }

    // MARK: - Helpers

    private var rootEdges: [MQTTExplorerBackend.Edge<AppViewModelNode>] {
        viewModel.rootEdges
    }

    private var filteredEdges: [MQTTExplorerBackend.Edge<AppViewModelNode>] {
        guard !searchText.isEmpty else { return rootEdges }
        return rootEdges.filter { edge in
            edgeMatchesSearch(edge, query: searchText.lowercased())
        }
    }

    private func edgeMatchesSearch(_ edge: MQTTExplorerBackend.Edge<AppViewModelNode>, query: String) -> Bool {
        guard let node = edge.target else { return false }
        if node.path().lowercased().contains(query) { return true }
        for child in node.edgeArray {
            if edgeMatchesSearch(child, query: query) { return true }
        }
        return false
    }

    private var connectionHeader: some View {
        HStack {
            Circle()
                .fill(viewModel.connectionState.connected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.connectionState.connected ? "Connected to \(viewModel.connectedHost)" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Tree Node Row

private struct TreeNodeRow: View {
    let edge: MQTTExplorerBackend.Edge<AppViewModelNode>
    var searchFilter: String

    var body: some View {
        if let node = edge.target {
            if node.edgeArray.isEmpty {
                // Leaf
                Label {
                    Text(edge.name)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                }
                .tag(node.path())
            } else {
                // Branch
                DisclosureGroup {
                    ForEach(node.edgeArray, id: \.name) { childEdge in
                        TreeNodeRow(edge: childEdge, searchFilter: searchFilter)
                    }
                } label: {
                    Label {
                        Text(edge.name)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "folder")
                            .foregroundColor(.orange)
                    }
                }
                .tag(node.path())
            }
        }
    }
}

// MARK: - Node Detail View

private struct NodeDetailView: View {
    let node: TreeNode<AppViewModelNode>
    @ObservedObject var viewModel: AppViewModel

    @State private var publishTopic: String = ""
    @State private var publishPayload: String = ""
    @State private var selectedFormat: TopicDataType = .string

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Topic info header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                    Text(node.path())
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                }
                HStack(spacing: 12) {
                    if let msg = node.message {
                        Text("QoS: \(msg.qos.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if msg.retain {
                            Text("Retained")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Text("Messages: \(node.messages)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Payload display
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Payload")
                        .font(.headline)
                    Spacer()
                    Picker("Format", selection: $selectedFormat) {
                        Text("String").tag(TopicDataType.string)
                        Text("JSON").tag(TopicDataType.json)
                        Text("Hex").tag(TopicDataType.hex)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if let message = node.message, let payload = message.payload {
                    let (formatted, _) = payload.format(type: selectedFormat)
                    ScrollView {
                        Text(formatted)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("No payload")
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            // Message history
            if node.messageHistory.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message History (\(node.messageHistory.count))")
                        .font(.headline)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(node.messageHistory.toArray().enumerated().reversed()), id: \.offset) { _, msg in
                                HStack {
                                    Text(msg.received, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(msg.topic.components(separatedBy: "/").last ?? msg.topic)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let p = msg.payload {
                                        Text(p.toUnicodeString().prefix(60))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Divider()

            // Publish
            VStack(alignment: .leading, spacing: 8) {
                Text("Publish to this topic")
                    .font(.headline)
                HStack {
                    TextField("Topic", text: $publishTopic)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            if publishTopic.isEmpty {
                                publishTopic = node.path()
                            }
                        }
                    Button("Send") {
                        viewModel.publish(
                            topic: publishTopic,
                            payload: publishPayload,
                            qos: .atMostOnce,
                            retain: false
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(publishTopic.isEmpty)
                }
                TextEditor(text: $publishPayload)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            Spacer()
        }
        .padding()
    }
}
