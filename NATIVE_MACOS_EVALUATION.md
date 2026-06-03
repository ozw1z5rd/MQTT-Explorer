# Native macOS SwiftUI Evaluation

## Summary

Converting MQTT-Explorer to a native Swift macOS app is viable **if the browser mode and React frontend are dropped entirely** and only the MQTT data pipeline is ported. The core data model is ~900 lines of clean TypeScript that maps well to Swift.

**Effort: 2-4 months for 1 skilled Swift developer**

## Architecture: Keep vs. Drop

### Port to Swift (backend/src/)

| File | Lines | Swift Equivalent |
|------|-------|------------------|
| `Model/Base64Message.ts` | ~30 | `Data` + Codable |
| `Model/Message.ts` | ~20 | Struct |
| `Model/RingBuffer.ts` | ~80 | Array + index tracking |
| `Model/ChangeBuffer.ts` | ~30 | Array + timer |
| `Model/TreeNode.ts` | ~200 | `@Observable class` |
| `Model/TreeNodeFactory.ts` | ~100 | Static factory |
| `Model/Tree.ts` | ~100 | `@Observable class` |
| `Model/Edge.ts` | ~30 | Struct/Class |
| `Model/Decoder.ts` | ~20 | Protocol |
| `DataSource/MqttSource.ts` | ~150 | CocoaMQTT wrapper |
| `DataSource/DataSourceState.ts` | ~10 | Publisher |
| `ConfigStorage.ts` | ~100 | UserDefaults / JSON |

**Total: ~900 lines to port (~2-3 weeks)**

### Drop entirely

- `events/EventSystem/` — IPC/Socket.IO is Electron-specific
- `src/server.ts` — Express/Socket.IO browser server
- `src/electron.ts` — Electron main process
- `app/src/` — All React components (~10,000+ lines)
- `app/src/reducers/` — Redux state management
- `app/src/actions/` — Redux actions/thunks
- `src/spec/` — Playwright/SceneBuilder test infra

## SwiftUI Feature Mapping

| Feature | Effort | Notes |
|---------|--------|-------|
| Connection setup form | Low | Native SwiftUI form |
| Topic tree browser | Medium | SwiftUI List / NSOutlineView |
| Message payload viewer | Low | JSON pretty-print with TextEditor |
| Value history chart | Medium | Swift Charts `LineMark` |
| Diff viewer | Low | `CollectionDifference` |
| Topic publishing | Low | Text field + CocoaMQTT publish |
| Pause/resume updates | Trivial | Toggle on Tree |
| SparkplugB decoding | Medium | SwiftProtobuf, needs .proto → Swift |
| Message history sidebar | Low | Scrollable List |
| Dark/light mode | Trivial | Built-in `ColorScheme` |
| Settings persistence | Trivial | `@AppStorage` |

## Key Wins

1. **No state management framework needed** — `@Observable` replaces Redux, `@AppStorage` replaces settings
2. **Swift Charts** replaces visx/d3 entirely
3. **No dual-mode event bus** — CocoaMQTT connects directly, tree mutations are `@Observable` reactions
4. **No JSS/MUI complexity** — SwiftUI modifiers replace the entire styling system
5. **Sparkle** for auto-updates (first-class on macOS)
6. **Binary size** would be ~10-20MB vs Electron's ~200MB

## Remaining Hard Problems

- No native ACE/AST editor for JSON — would need TextEditor with syntax highlighting or WKWebView embed
- SparkplugB proto codegen needs `protoc` Swift plugin setup
- XCTest test suite needs writing from scratch for the model layer

## Comparison: Swift vs Tauri

| Approach | Effort | Keep React? | Binary Size |
|----------|--------|-------------|-------------|
| Native Swift | 2-4 months | No | ~10-20 MB |
| Tauri (Rust backend) | 4-6 weeks | Yes (all JS/TS kept) | ~5-10 MB |
| Electron (current) | — | Yes | ~200 MB |

If the goal is purely smaller binary + better performance with minimal code changes, **Tauri** is the pragmatic choice. If the goal is a fully native macOS experience, the Swift path is achievable but requires a complete UI rebuild.
