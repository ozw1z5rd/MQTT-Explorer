import SwiftUI
import AppKit

@main
struct MQTTExplorerApp: App {
    init() {
        // Ensure the app activates as a proper foreground GUI application,
        // which is needed when launched from Xcode's SPM executable scheme.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
