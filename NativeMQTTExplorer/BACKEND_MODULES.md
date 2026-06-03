# MQTTExplorerBackend — Module Reference

Each file in `Sources/MQTTExplorerBackend/` is a direct Swift port of a corresponding TypeScript module from `backend/src/`. The overall design replaces Electron's dual-mode IPC/Socket.IO event bus with `EventDispatcher<T>`, Redux/immutable.js with `@Observable` classes (for SwiftUI), and the `mqtt` npm package with CocoaMQTT.

---

## Core Data Model

### Tree.swift
Root of the topic hierarchy. Extends `TreeNode` and adds batch processing:
- Accumulates incoming messages in a `ChangeBuffer`
- A `DispatchSourceTimer` fires every 300ms to apply unmerged changes via `TreeNodeFactory.fromMessage()` + `updateWithNode()`
- Exposes `didUpdate` event, `pause()` / `resume()`, and `destroy()` lifecycle
- Supports optional `nodeFilter` to skip unwanted topics before merge

**TS origin:** `backend/src/Model/Tree.ts`

### TreeNode.swift
A single segment in an MQTT topic path (e.g., `"kitchen"` in `"home/kitchen/temperature"`). Core properties:
- `message: Message?` — the last received payload for this topic
- `messageHistory: RingBuffer<Message>` — bounded history of past messages
- `edges: [String: Edge]` — children keyed by segment name
- `viewModel: ViewModel?` — generic UI model attached by the app layer
- Event dispatchers: `onMerge`, `onMessage`, `onEdgesChange`, `onDestroy`
- Tree navigation: `path()`, `findNode()`, `branch()`, `firstNode()`, `childTopics()`
- Merge logic: `updateWithNode()` merges messages, edges, and dispatches events
- Cached computed properties (`leafMessageCount`, `childTopicCount`) invalidated on merge

**TS origin:** `backend/src/Model/TreeNode.ts`

### Edge.swift
Connects parent and child `TreeNode`s by segment name. Produces a SHA1-based hash for tree identity tracking — the hash chains from the tree root through edge names, enabling efficient diff detection.

**TS origin:** `backend/src/Model/Edge.ts`

### TreeNodeFactory.swift
Static factory that builds a `TreeNode` chain from an MQTT topic string:
- Splits `"a/b/c"` into segments, creates an `Edge` + `TreeNode` for each
- Assigns the `Message` (with auto-incrementing message number) to the leaf
- Used by `Tree.applyUnmergedChanges()` for every buffered message

**TS origin:** `backend/src/Model/TreeNodeFactory.ts`

---

## Message Model

### Base64Message.swift
Wraps MQTT payloads as base64-encoded strings. Key features:
- Lazy UTF-8 decode (`toUnicodeString()`) with caching
- Formatting: JSON pretty-print, hex dump (`0x41 0x42`), plain string
- `Codable` conformance for persistence
- Static helpers: `toDataUri(message:mimeType:)`, `toHex(message:)`
- Factory methods: `from(string:)`, `from(buffer:)`

**TS origin:** `backend/src/Model/Base64Message.ts`

### Message.swift
Value type (`struct`) holding all MQTT message metadata:
- `topic`, `payload: Base64Message?`, `qos: QoSType`, `retain: Bool`
- `messageId`, `messageNumber`, `received: Date`
- Conforms to `MemoryConsumptionExpressedByLength` so it can be stored in `RingBuffer`

**TS origin:** `backend/src/Model/Message.ts`

---

## Data Flow & Buffering

### ChangeBuffer.swift
Thread-safe pre-tree buffer that accumulates `MqttMessageEvent`s before they're merged into the tree. Enforces a byte-size limit (default 100MB) — messages that would exceed the limit are silently dropped.

**TS origin:** `backend/src/Model/ChangeBuffer.ts`

### RingBuffer.swift
Fixed-capacity circular buffer for message history on each `TreeNode`. Evicts oldest items when either:
- Total byte size exceeds `capacity`
- Item count exceeds `maxItems`
Supports `clone()` for creating unconnected tree copies (used when detaching a subtree for inspection).

**TS origin:** `backend/src/Model/RingBuffer.ts`

---

## Event System

### EventDispatcher.swift
Type-safe pub/sub dispatcher that replaces Electron's dual-mode (IPC + Socket.IO) event bus:
- `subscribe(_:) -> UUID` — register a callback, returns an ID for unsubscription
- `dispatch(_:)` — fire all callbacks with the given value
- `unsubscribe(id:)` / `removeAllListeners()` — cleanup
- Snapshots callbacks before iterating to avoid mutation-during-dispatch issues

**TS origin:** concept from `events/EventSystem/` but simplified to a single in-process implementation

---

## MQTT Connection Layer

### DataSource.swift
Protocol defining the MQTT data source interface. Implemented by `MqttSource`:
- `associatedtype Options` — connection configuration
- `connect(options:)`, `disconnect()`, `publish(topic:payload:qos:retain:)`
- `onMessage(_:)` — register a raw message callback
- Also defines `QoSType` enum (0/1/2) and `MqttPacketInfo` struct

**TS origin:** `backend/src/DataSource/DataSource.ts`

### DataSourceStateMachine.swift
Tracks connection lifecycle state and emits updates:
- States: `connecting`, `connected` (with error string)
- `onUpdate: EventDispatcher<DataSourceState>` — observed by the UI layer
- Methods: `setConnecting()`, `setConnected(_:)`, `setError(_:)`

**TS origin:** `backend/src/DataSource/DataSourceState.ts`

### MqttSource.swift
CocoaMQTT wrapper implementing the `DataSource` protocol:
- Parses `mqtt://`, `mqtts://`, `ws://`, `wss://` URLs with port defaults
- Configures TLS, certificates, auto-reconnect, keep-alive
- Subscribes to topics on successful connect
- Routes incoming messages through both a raw `messageCallback` and the `ConnectionManager` pipeline
- `CocoaMQTTDelegate` implementation: handles connect ack, publish ack, incoming messages, subscribe results, disconnect

**TS origin:** `backend/src/DataSource/MqttSource.ts`

### ConnectionManager.swift
Manages multiple MQTT connections by string ID:
- `connect(id:options:onMessage:onStateChange:)` — creates `MqttSource`, wires callbacks
- `publish(connectionId:topic:payload:qos:retain:)` — publishes on a specific connection
- `disconnect(connectionId:)` / `disconnectAll()` — cleanup
- Thread-safe via `NSLock`, prevents double connections

**TS origin:** `backend/src/index.ts` (ConnectionManager)

---

## Utilities

### ConfigStorage.swift
JSON file-based key-value persistence:
- `load()` — reads from disk, creates directory if needed
- `save()` — writes atomically to disk (auto-called by `set`/`remove`/`clear`)
- Generic `get<T>(_ key:)`, `set(_:value:)`, `remove(_:)`, `clear()`, `allKeys()`

**TS origin:** `backend/src/ConfigStorage.ts` (simplified — no RPC layer)

### JsonAstParser.swift
Recursively walks parsed JSON to extract property paths:
- `parse(_:) -> [JsonPropertyLocation]` — extracts `path`, `value`, `line`, `column` for every leaf
- `literalsMappedByLines(_:) -> [Int: JsonPropertyLocation]` — index by line number
- Handles nested objects, arrays, and dot-escaped keys (`"foo\.bar"`)

**TS origin:** `backend/src/Model/JsonAstParser.ts`

### Decoder.swift
Enums shared across the backend:
- `TopicDataType`: `string`, `json`, `hex` — controls how payloads are displayed
- `DecoderType`: `none`, `sparkplug` — specialized decoding mode

### Destroyable.swift
Protocol with a single requirement: `func destroy()`. Conformance is required for the generic `ViewModel` type parameter in `Tree<ViewModel>` and `TreeNode<ViewModel>`, ensuring the tree can recursively clean up view models.

**TS origin:** interface pattern from `backend/src/Model/TreeNode.ts`

### HashableProtocol.swift
Protocol with a single requirement: `func hash() -> String`. Used by `Edge` to produce a deterministic hash string for tree identity comparison.

---

## Test Coverage Status

| File | Tests | Notes |
|------|-------|-------|
| `Tree.swift` | ✅ `TreeTests.swift` | Batch updates, pause/resume, destroy |
| `TreeNode.swift` | ✅ `TreeNodeTests.swift` | Merge, navigation, events, counts |
| `Edge.swift` | ❌ | Hash computation |
| `TreeNodeFactory.swift` | ❌ | Indirectly tested via Tree/TreeNode tests |
| `Base64Message.swift` | ✅ `Base64MessageTests.swift` | Encoding, formatting, hex, data URI |
| `Message.swift` | ❌ | Simple struct — tested via TreeNode |
| `ChangeBuffer.swift` | ✅ `ChangeBufferTests.swift` | Push/pop, full buffer, fill ratio |
| `RingBuffer.swift` | ✅ `RingBufferTests.swift` | Capacity, max items, clone |
| `EventDispatcher.swift` | ✅ `EventDispatcherTests.swift` | Subscribe, unsubscribe, removeAll |
| `DataSource.swift` | ❌ | Protocol definition |
| `DataSourceStateMachine.swift` | ❌ | State transitions |
| `MqttSource.swift` | ❌ | Requires real/mock CocoaMQTT |
| `ConnectionManager.swift` | ❌ | Requires MqttSource mock |
| `ConfigStorage.swift` | ❌ | File I/O |
| `JsonAstParser.swift` | ❌ | JSON path extraction |
| `Decoder.swift` | ❌ | Enum definitions |
| `Destroyable.swift` | ❌ | Protocol definition |
| `HashableProtocol.swift` | ❌ | Protocol definition |

**Covered:** 6/18 source files (33%)  
**Untested:** 12 files — 3 are protocol/enum definitions, 3 require MQTT broker mocking, the remaining 6 (`Edge`, `TreeNodeFactory`, `Message`, `ConfigStorage`, `JsonAstParser`, `DataSourceStateMachine`) are straightforward and testable without external dependencies.
