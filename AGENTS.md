# MQTT Explorer — Agent Guide

## Project Overview

MQTT Explorer is an Electron + React application for browsing and visualizing MQTT topics in real-time. It can also run as a web application (browser mode) via a Node.js/Express server. Users connect to MQTT brokers and see a live topic tree with message payloads, charts, diff views, history, and an AI assistant.

**Key repos**: single monorepo at `thomasnordquist/MQTT-Explorer` on GitHub.

---

## Architecture

### Monorepo Structure (three package.json files)

| Directory | Role | Entry |
|-----------|------|-------|
| `/` (root) | Electron main process + Express server | `src/electron.ts` or `src/server.ts` |
| `app/` | React frontend (renderer) | `app/src/index.tsx` |
| `backend/` | MQTT backend logic (tree model, data sources) | `backend/src/index.ts` |
| `events/` | Shared event system (IPC for Electron, Socket.IO for browser) | `events/index.ts` |

### Data Flow

```
MQTT Broker → backend/DataSource (MqttSource) → EventBus → React app
```

1. **`backend/`** (`ConnectionManager`) connects to MQTT brokers via `mqtt` npm package
2. Messages arrive as `MqttMessage` and are emitted on the **EventBus** (typed, topic-based pub/sub)
3. **`Tree<ViewModel>`** subscribes to connection message events via `updateWithConnection()` and populates a `TreeNode` hierarchy — messages are buffered in a `ChangeBuffer` and applied every 300ms via `requestIdleCallback`
4. **React components** read the tree from Redux state (immutable stores) and subscribe to `TreeNode.onMessage`/`onMerge` for live updates

### EventBus Dual-Mode Architecture

One of the most important patterns to understand:

- **Electron mode**: Uses Electron IPC (`ipcMain`/`ipcRenderer`) via `events/EventSystem/Ipc*.ts`
- **Browser mode**: Uses Socket.IO via `events/EventSystem/SocketIO*.ts`
- **Abstraction**: Both implement `EventBusInterface` (subscribe/unsubscribeAll/emit). The `app/src/eventBus.ts` file uses lazy-loading Proxies to dynamically pick the right implementation at runtime based on `isBrowserMode` (detected as: `typeof window !== 'undefined' && (typeof process === 'undefined' || process.env?.BROWSER_MODE === 'true')`)

This means any code using `eventBus.ts` imports works transparently in both modes.

### State Management

- **Redux** with immutable.js `Record` for state shapes
- **Reducers** use a custom `createReducer` helper (`app/src/reducers/lib.ts`) — a simple function that maps action type strings to handler functions
- **Actions** are plain Redux actions with thunks via `redux-thunk` for async flows
- **Redux slice reducers**: `Tree`, `Connection`, `ConnectionManager`, `Settings`, `Global`, `Sidebar`, `Charts`, `Publish`
- The `Tree` and `Connection` reducers store a reference to the `q.Tree<TopicViewModel>` — the actual tree with all live MQTT data
- **Store**: `app/src/store.ts` — single store with `redux-thunk` and `redux-batched-actions` middleware

### Styling

- Material-UI v7 with **JSS via `withStyles` HOC** (`@mui/styles` v6 for backward compat)
- Both `ThemeProvider` (MUI v7) and **`LegacyThemeProvider`** (`@mui/styles` v6) are wrapped in `app/src/index.tsx` — both are needed
- Theme defined in `app/src/theme.ts` (light/dark modes, primary `#335C67`)
- Type assertions like `display: 'block' as 'block'` for JSS type safety
- See `STYLING.md` for full conventions

### LLM Integration

An AI assistant component lives at `app/src/components/Sidebar/AIAssistant.tsx` with service at `app/src/services/llmService.ts`. Supports OpenAI and Gemini providers. API keys can be configured via env vars (`OPENAI_API_KEY`, `GEMINI_API_KEY`, `LLM_API_KEY`) or localStorage. Server broadcasts LLM availability to the client via the `llm-available` Socket.IO event (`browserEventBus.ts:112`).

---

## Essential Commands

### Setup & Install
```bash
yarn install          # Installs root + app/ dependencies (via postinstall script)
```

### Development
```bash
yarn dev:server       # Hot-reload browser mode (webpack dev server + backend)
yarn dev:electron     # TypeScript compile + Electron with --development flag
```

### Build
```bash
yarn build            # Full build (TypeScript + webpack for Electron)
yarn build:server     # Browser mode build only (dist/src/server.js + app/build/)
yarn start:server     # Run browser mode server (NODE_ENV may need setting)
```

### Linting (MUST run before committing)
```bash
yarn lint:prettier:fix   # Format all TypeScript files
yarn lint:fix             # Fix ESLint + Prettier
yarn lint                 # Check Prettier + ESLint + spellcheck
```

### Testing
```bash
yarn test                # Unit tests (app + backend)
yarn test:app            # Frontend unit tests only (mocha in app/)
yarn test:backend        # Backend unit tests only (mocha in backend/)
yarn test:ui             # Electron UI tests (requires build first)
./scripts/runBrowserTests.sh  # Browser mode Playwright tests
```

**Important**: Unit tests use `mocha` + `chai` + `tsx` (not Jest). Tests are co-located with source as `.spec.ts` files.

### Packaging
```bash
yarn package             # Electron packages via electron-builder
yarn prepare-release     # Version bump + changelog
```

---

## Code Conventions & Gotchas

### TypeScript Patterns
- **Target**: ES2020, `commonjs` modules
- **No strict typing everywhere**: Many components use `any` for `classes` prop (JSS style injection), and some props/interfaces cast to `any` (e.g., `ReactSplitPaneImport as any`, `ConnectionSettingsAny`)
- **Backend model re-exported**: The `backend/` model is imported from the `app/` layer via relative path: `import * as q from '../../../backend/src/Model'` — there is no separate package build

### Key Gotchas

1. **`withStyles` + `connect` ordering**: Components use `withStyles(styles)(connect(...)(Component))` — note `withStyles` wraps `connect`, not the other way
2. **Tooltip test attributes**: When adding `data-test-type` / `data-test` to elements inside MUI Tooltips, the attributes must go on the **inner clickable child**, not the outer wrapper — see `.github/copilot-instructions.md` for the correct pattern
3. **Two ThemeProviders**: `app/src/index.tsx` wraps with both `<ThemeProvider theme={theme}>` and `<LegacyThemeProvider theme={theme}>` — components using `withStyles` from `@mui/styles` need the legacy provider
4. **`this.props.classes.any`**: Components using `withStyles` receive a `classes: any` prop — the JSS class names are not typed
5. **`browserEventBus.ts` is only imported from `eventBus.ts`** via lazy `require()` calls — never import `browserEventBus.ts` directly
6. **Tree updates are batched**: The `Tree` class batches incoming messages in a `ChangeBuffer` and applies them every 300ms via `requestIdleCallback` — don't expect immediate tree state after emitting a message
7. **Message payload truncation**: Messages over 20000 bytes are truncated by `ConnectionManager` before emitting
8. **ESLint is allowed to fail CI**: The lint workflow has `continue-on-error: true` for ESLint
9. **`.env.llm-tests` must be sourced** before running LLM tests — not just present in the directory
10. **Prettier config**: `app/src/reducers/lib.ts` has `hasOwnProperty` check that may flag linting — this is intentional pattern use

### Styling patterns
- `withStyles` HOC from `@mui/styles` is primary approach
- `sx` prop used for simple cases (e.g., `sx={{ color: 'primary.contrastText' }}`)
- `display: 'block' as 'block'` type assertions required for JSS string union types
- Theme-conditional styling via `theme.palette.mode === 'light'`
- Spacing via 8px grid: `theme.spacing(1)` = 8px

### Import Pattern
```typescript
// Frontend imports backend model via relative path:
import * as q from '../../../backend/src/Model'
// This works because tsconfig paths resolve node_modules, but the actual file is a sibling directory
```

### Reducer Pattern
```typescript
// app/src/reducers/lib.ts
export const createReducer = (initialState: any, handlers: any) =>
  (state = initialState, action: any) => {
    if (handlers.hasOwnProperty(action.type)) {
      return handlers[action.type](state, action)
    }
    return state
  }
```
Some reducers use `immutable.Record` (e.g., `Tree`, `Settings`) producing immutable state; others (e.g., `Connection`) use plain objects.

---

## Testing Details

### Unit Tests
- **Framework**: `mocha` + `chai` (not Jest)
- **Runner**: `tsx` (TypeScript execution), `source-map-support` for stack traces
- **Pattern**: `*.spec.ts` files co-located with source
- **Backend model tests**: `backend/src/Model/spec/` — test `TreeNode`, `Tree`, `RingBuffer`, etc.

### UI Tests (Playwright)
- **Scenarios**: `src/spec/scenarios/*.ts` — reusable action sequences (connect, search, publish, plot, etc.)
- **Test files**: `src/spec/ui-tests.spec.ts` — main test suite, `src/spec/demoVideo.ts` — video generation
- **Selectors**: `data-test-type` and `data-test` attributes (not `data-testid` — there's a mix in the codebase)
- **SceneBuilder**: `src/spec/SceneBuilder.ts` — records timed scenes for demo video generation
- **Mock MQTT**: `src/spec/mock-mqtt.ts` and `src/spec/mock-mqtt-test.ts` — local MQTT broker mock

### Demo Video
- **Script**: `./scripts/uiTests.sh` — Electron demo video generation
- **Mobile**: `./scripts/uiTestsMobile.sh` — mobile viewport demo
- **CI**: Produces GIF/MP4 segments uploaded to S3 and posted as PR comments

---

## CI/CD

- **PR trigger**: `pull_request_target` on `master`, `beta`, `release`
- **CI jobs**: `test` (unit), `browser-ui-tests`, `demo-video`, `demo-video-mobile`, `test-browser`
- **Docker test container**: `ghcr.io/thomasnordquist/mqtt-explorer-ui-tests:latest` — pre-configured with Electron, Xvfb, ffmpeg, mosquitto
- **Release**: `semantic-release` via `.releaserc` — publishes to `release` and `beta` branches

---

## Docker

- **Dev container**: `.devcontainer/` with VSCode config, mosquitto, VNC, noVNC
- **Browser mode Docker**: `Dockerfile.browser` — lightweight Node.js deployment
- **Docker compose**: `docker-compose.yml` at root — runs MQTT broker + app

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `src/electron.ts` | Electron main process entry |
| `src/server.ts` | Express/Socket.IO server for browser mode |
| `backend/src/index.ts` | `ConnectionManager` — MQTT connection lifecycle |
| `backend/src/Model/Tree.ts` | Topic tree with batched updates |
| `backend/src/Model/TreeNode.ts` | Individual topic node with edges, message history |
| `events/Events.ts` | All event type definitions (connection, publish, message, etc.) |
| `events/EventSystem/` | IPC and Socket.IO event bus implementations |
| `app/src/eventBus.ts` | Lazy-loading Proxy to pick correct event bus at runtime |
| `app/src/browserEventBus.ts` | Socket.IO client event bus implementation |
| `app/src/store.ts` | Redux store configuration |
| `app/src/reducers/lib.ts` | `createReducer` helper |
| `app/src/theme.ts` | MUI theme (light + dark) |
| `app/src/components/App.tsx` | Root React component |
| `app/src/components/ConnectionSetup/ConnectionSetup.tsx` | MQTT connection dialog |
| `app/src/components/Sidebar/AIAssistant.tsx` | LLM AI assistant chat |
| `src/spec/SceneBuilder.ts` | Demo video scene recording |
| `src/spec/ui-tests.spec.ts` | Main Playwright UI test suite |
| `SECURITY.md` | Security policy and vulnerability reporting |
| `STYLING.md` | Full styling conventions reference |
| `BROWSER_MODE.md` | Browser mode deployment and security |
