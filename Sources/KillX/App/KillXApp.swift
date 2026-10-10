import AppKit
import SwiftUI

@main
struct KillXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("KillX Help") {
                    HelpWindowController.shared.show()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
