#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Choose build method:"
echo "  [1] Xcode project  (opens MQTTExplorer.xcodeproj — press Cmd+R to run)"
echo "  [2] SPM + app bundle (swift build + manual .app wrapper)"
echo "  [3] SPM run         (swift run — launches directly from terminal)"
read -p "> " choice

case "$choice" in
    1)
        echo "→ Opening Xcode project..."
        open "$ROOT/MQTTExplorer.xcodeproj"
        echo "→ Press Cmd+R in Xcode to build and run."
        ;;
    2)
        BUILD_DIR="$ROOT/.build/x86_64-apple-macosx/debug"
        EXECUTABLE="$BUILD_DIR/MQTTExplorer"
        APP_BUNDLE="$BUILD_DIR/MQTT Explorer.app"

        echo "→ Building executable..."
        swift build --product MQTTExplorer -c debug

        echo "→ Creating app bundle..."
        rm -rf "$APP_BUNDLE"
        mkdir -p "$APP_BUNDLE/Contents/MacOS"
        mkdir -p "$APP_BUNDLE/Contents/Resources"

        cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/MQTTExplorer"
        cp "$ROOT/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

        for dylib in "$BUILD_DIR"/*.dylib; do
            [ -f "$dylib" ] && cp "$dylib" "$APP_BUNDLE/Contents/MacOS/"
        done

        codesign --sign - --force --deep "$APP_BUNDLE" 2>/dev/null || true

        echo "→ Launching: $APP_BUNDLE"
        open "$APP_BUNDLE"
        ;;
    3)
        echo "→ Building and running..."
        swift run --product MQTTExplorer
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac
