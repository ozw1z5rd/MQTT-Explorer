# Native MQTT Explorer

A native macOS app for browsing and visualizing MQTT topics in real-time. Built with SwiftUI and CocoaMQTT.

<img src="Images/NativeMQTTExplorer.png" width="512" alt="Native MQTT Explorer">


## Features

### Connection
- **MQTT broker connection** via `mqtt://`, `mqtts://`, `ws://`, `wss://`
- TLS/SSL support with optional certificate validation
- Username/password authentication
- Custom topic subscriptions (comma-separated, default `#`)
- Quick-connect presets: `test.mosquitto.org`, `mqtt.eclipseprojects.io`, `broker.emqx.io`
- Connection status indicator (connecting/connected/error)

### Topic Tree Browser
- **Hierarchical tree view** of all MQTT topics
- Expandable/collapsible folders (persistent across updates)
- New branches auto-expand, manually collapsed ones stay closed
- Live updates every 300ms as messages arrive
- Topic search/filter
- Inline payload preview next to topic names
- Click any topic to view details

### Payload Viewer
- **String** — raw UTF-8 text
- **JSON** — pretty-printed with indentation (auto-detected)
- **Hex** — byte-by-byte hex dump (`0x41 0x42`)
- Format picker (segmented control)
- Pause/resume live updates to freeze a payload for inspection
- Timestamp of last received message

### Message History
- **Per-topic history** showing the last 100 messages
- Click any history entry to freeze and inspect its payload
- History timestamps
- Alternating row colors for readability

### Publishing
- Publish messages to any topic
- Payload editor (multi-line)
- Configurable QoS and retain flag

### Architecture
- Pure Swift — no JavaScript, no Electron
- CocoaMQTT for MQTT protocol
- SwiftUI for the entire UI
- Event-driven tree model with batched updates
- ~10-20 MB binary (vs ~200 MB Electron)

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ (to build from source)

## Build & Run

### From Xcode
```bash
open MQTTExplorer.xcodeproj
```
Press **Cmd+R** to build and run.

### From command line
```bash
./build-app.sh     # interactive menu (Xcode / SPM / swift run)
```

### SPM only
```bash
swift build
swift run
```

## Project Structure

```
NativeMQTTExplorer/
├── Sources/
│   ├── MQTTExplorerApp/       # SwiftUI app
│   │   ├── MQTTExplorerApp.swift   # @main entry point
│   │   ├── ContentView.swift        # Root view (setup vs tree)
│   │   ├── ConnectionSetupView.swift # MQTT connection form
│   │   ├── TopicTreeView.swift      # Tree browser + detail panel
│   │   ├── LogViewerView.swift      # Log viewer panel
│   │   ├── AppViewModel.swift       # State management
│   │   └── AboutView.swift          # About dialog
│   └── MQTTExplorerBackend/   # Backend library
│       ├── Tree.swift               # Topic tree root
│       ├── TreeNode.swift           # Individual topic node
│       ├── Edge.swift               # Tree edge
│       ├── TreeNodeFactory.swift    # Node creation from messages
│       ├── Base64Message.swift      # Payload wrapper
│       ├── Message.swift            # Message metadata
│       ├── ChangeBuffer.swift       # Pre-tree message buffer
│       ├── RingBuffer.swift         # Circular message history
│       ├── EventDispatcher.swift    # Type-safe pub/sub
│       ├── MqttSource.swift         # CocoaMQTT wrapper
│       ├── ConnectionManager.swift  # Multi-connection manager
│       ├── DataSource.swift         # Data source protocol
│       ├── DataSourceStateMachine.swift # Connection state
│       ├── ConfigStorage.swift      # JSON file persistence
│       ├── JsonAstParser.swift      # JSON path extraction
│       ├── Logger.swift             # Thread-safe logger
│       ├── Decoder.swift, Destroyable.swift, HashableProtocol.swift
│       └── ...
├── Tests/
│   └── MQTTExplorerBackendTests/    # Unit tests (mocha-style port)
├── Assets.xcassets/
│   └── AppIcon.appiconset/          # App icon
├── Package.swift                    # SPM manifest
├── MQTTExplorer.xcodeproj           # Xcode project
├── Info.plist                       # App bundle metadata
└── build-app.sh                     # Build helper script
```

## License

AGPLv3
