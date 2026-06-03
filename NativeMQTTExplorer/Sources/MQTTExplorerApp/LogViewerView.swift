import SwiftUI
import MQTTExplorerBackend

struct LogViewerView: View {
    @State private var entries: [LogEntry] = []
    @State private var levelFilter: LogLevel? = nil
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Picker("Level", selection: $levelFilter) {
                    Text("All").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level as LogLevel?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                TextField("Filter...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)

                Spacer()

                Text("\(filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button(action: {
                    Logger.shared.clear()
                    entries = []
                }) {
                    Image(systemName: "trash")
                }
                .help("Clear logs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Log list
            ScrollViewReader { proxy in
                List(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
                .listStyle(.plain)
                .onChange(of: entries.count) { _ in
                    if autoScroll, let last = filteredEntries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .onAppear {
            entries = Logger.shared.allEntries()
            Logger.shared.onEntry { entry in
                DispatchQueue.main.async {
                    entries.append(entry)
                }
            }
        }
    }

    private var filteredEntries: [LogEntry] {
        var result = entries
        if let level = levelFilter {
            result = result.filter { $0.level == level }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.message.lowercased().contains(query) ||
                $0.category.lowercased().contains(query)
            }
        }
        return result
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Level badge
            Text(entry.level.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(levelColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Timestamp
            Text(formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            // Category
            Text("[\(entry.category)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.accentColor)

            // Message
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(entry.level == .error ? nil : 2)
        }
        .padding(.vertical, 1)
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: entry.timestamp)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
