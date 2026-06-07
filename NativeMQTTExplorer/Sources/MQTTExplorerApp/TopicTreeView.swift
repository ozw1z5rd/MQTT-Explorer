import SwiftUI
import MQTTExplorerBackend

struct TopicTreeView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var searchText: String = ""
    @State private var selectedPath: String?
    @State private var expandedPaths: Set<String> = []
    @State private var collapsedPaths: Set<String> = []

    private var selectedNode: TreeNode<AppViewModelNode>? {
        guard let path = selectedPath else { return nil }
        return viewModel.tree.findNode(path: path)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                


                // Connection status
                connectionHeader
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                
                // Debug indicator
                if !viewModel.rootEdgeNames.isEmpty {
                    Text("\(viewModel.totalMessageCount) msgs · Elapsed time: \(viewModel.connectionElapsed)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                }

                Divider()

                // Tree content
                if viewModel.rootEdgeNames.isEmpty {
                    waitingView
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(filteredNames, id: \.self) { name in
                                if let edge = viewModel.tree.edges[name] {
                                    TreeDisclosureGroup(
                                        edge: edge,
                                        selectedPath: $selectedPath,
                                        expandedPaths: $expandedPaths,
                                        collapsedPaths: $collapsedPaths
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.leading, 5)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Filter topics...")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { viewModel.disconnect() }) {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            }
        } detail: {
            if let node = selectedNode {
                NodeDetailView(node: node, viewModel: viewModel)
                    .id(node.path())
            } else {
                placeholderView
            }
        }
    }

    // MARK: - Subviews

    private var waitingView: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView().scaleEffect(0.8)
            Text("Waiting for messages...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholderView: some View {
        VStack {
            Image(systemName: "tree")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a topic to view details")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    private var connectionHeader: some View {
        HStack {
            Circle()
                .fill(viewModel.connectionState.connected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.connectionState.connected
                 ? "Connected to \(viewModel.connectedHost)"
                 : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private var filteredNames: [String] {
        guard !searchText.isEmpty else { return viewModel.rootEdgeNames }
        return viewModel.rootEdgeNames.filter { name in
            guard let edge = viewModel.tree.edges[name] else { return false }
            return edgeMatchesSearch(edge, query: searchText.lowercased())
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
}

// MARK: - Recursive Tree Disclosure Group

private struct TreeDisclosureGroup: View {
    let edge: MQTTExplorerBackend.Edge<AppViewModelNode>
    @Binding var selectedPath: String?
    @Binding var expandedPaths: Set<String>
    @Binding var collapsedPaths: Set<String>

    private var node: TreeNode<AppViewModelNode>? { edge.target }
    private var path: String { node?.path() ?? edge.name }
    private var hasChildren: Bool { !(node?.edgeArray.isEmpty ?? true) }

    var body: some View {
        if hasChildren {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedPaths.contains(path) },
                set: { newValue in
                    if newValue {
                        expandedPaths.insert(path)
                        collapsedPaths.remove(path)
                    } else {
                        expandedPaths.remove(path)
                        collapsedPaths.insert(path)
                    }
                }
            )) {
                ForEach(node?.edgeArray ?? [], id: \.name) { childEdge in
                    TreeDisclosureGroup(
                        edge: childEdge,
                        selectedPath: $selectedPath,
                        expandedPaths: $expandedPaths,
                        collapsedPaths: $collapsedPaths
                    )
                    .padding(.leading, 16)
                }
            } label: {
                rowLabel
            }
        } else {
            rowLabel
                .padding(.leading, 20)
        }
    }

    private var rowLabel: some View {
        Button(action: {
            if hasChildren {
                if expandedPaths.contains(path) {
                    expandedPaths.remove(path)
                    collapsedPaths.insert(path)
                } else {
                    expandedPaths.insert(path)
                    collapsedPaths.remove(path)
                }
            } else {
                selectedPath = path
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: hasChildren ? "folder.fill" : "doc.text")
                    .foregroundColor(hasChildren ? .orange : .blue)
                    .font(.system(size: 12))
                Text(edge.name)
                    .fontWeight(hasChildren ? .semibold : .medium)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                if let msg = node?.message, let payload = msg.payload {
                    Text(payload.toUnicodeString())
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(selectedPath == path
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Node Detail View

private struct NodeDetailView: View {
    let node: TreeNode<AppViewModelNode>
    @ObservedObject var viewModel: AppViewModel

    @State private var publishTopic: String = ""
    @State private var publishPayload: String = ""
    @State private var selectedFormat: TopicDataType = .string
    @State private var isPaused: Bool = false
    @State private var frozenPayload: Base64Message?
    @State private var frozenTimestamp: Date?
    @State private var selectedHistoryId: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Payload").font(.headline)
                    Spacer()
                    Button(action: {
                        isPaused.toggle()
                        if !isPaused && selectedHistoryId != nil {
                            frozenPayload = nil
                            frozenTimestamp = nil
                            selectedHistoryId = nil
                        }
                    }) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.borderless)
                    .help(isPaused ? "Resume live updates" : "Pause live updates")
                    Picker("Format", selection: $selectedFormat) {
                        Text("String").tag(TopicDataType.string)
                        Text("JSON").tag(TopicDataType.json)
                        Text("Hex").tag(TopicDataType.hex)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                let displayPayload: Base64Message? = isPaused ? frozenPayload : node.message?.payload
                if let payload = displayPayload {
                    let (formatted, _) = payload.format(type: selectedFormat)
                    ScrollView {
                        Text(formatted)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .id("\(selectedFormat.rawValue)-\(displayPayload?.base64String.prefix(40) ?? "nil")")
                    .background(isPaused && frozenPayload != nil
                        ? Color.accentColor.opacity(0.08)
                        : Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if let ts = (isPaused ? frozenTimestamp : node.message?.received) {
                        Text("Received: \(ts, style: .date) \(ts, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
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

            if node.messageHistory.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message History (\(node.messageHistory.count))").font(.headline)
                    List(Array(node.messageHistory.toArray().enumerated().reversed()), id: \.offset) { index, msg in
                        Button(action: {
                            frozenPayload = msg.payload
                            frozenTimestamp = msg.received
                            selectedHistoryId = msg.received
                            isPaused = true
                        }) {
                            HStack {
                                Text(msg.received, style: .time)
                                    .font(.caption).foregroundColor(.secondary)
                                Text(msg.topic.components(separatedBy: "/").last ?? msg.topic)
                                    .font(.caption).fontWeight(.medium)
                                if let p = msg.payload {
                                    Text(p.toUnicodeString())
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedHistoryId == msg.received
                            ? Color.accentColor.opacity(0.25)
                            : (index % 2 == 0 ? Color.clear : Color.primary.opacity(0.04)))
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 150)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Publish to this topic").font(.headline)
                HStack {
                    TextField("Topic", text: $publishTopic)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { if publishTopic.isEmpty { publishTopic = node.path() } }
                    Button("Send") {
                        viewModel.publish(topic: publishTopic, payload: publishPayload,
                                          qos: .atMostOnce, retain: false)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(publishTopic.isEmpty)
                }
                TextEditor(text: $publishPayload)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }

            Spacer()
        }
        .padding()
    }
}
