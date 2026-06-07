import SwiftUI
import AppKit

@main
struct MQTTExplorerApp: App {
    init() {
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
            CommandGroup(replacing: .appInfo) {
                Button("About MQTT Explorer") {
                    let controller = NSHostingController(rootView: AboutView())
                    let window = NSWindow(contentViewController: controller)
                    window.title = "About MQTT Explorer"
                    window.styleMask = [.titled, .closable]
                    window.setContentSize(NSSize(width: 320, height: 340))
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
