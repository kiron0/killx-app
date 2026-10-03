import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {

        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController()
        _ = ShortcutManager.shared
        WelcomeWindowController.shared.showIfFirstLaunch()

        let handleShowSettings: (Notification) -> Void = { notif in
            Task { @MainActor in
                let tab = (notif.userInfo?["tab"] as? String).flatMap { SettingsTab(rawValue: $0) }
                SettingsWindowController.shared.show(tab: tab)
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showSettings"),
            object: nil,
            queue: .main,
            using: handleShowSettings
        )
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showPreferences"),
            object: nil,
            queue: .main,
            using: handleShowSettings
        )

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showPopover"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.statusItemController?.showPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController = nil
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc func showPreferencesWindow(_ sender: Any?) {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }
}
