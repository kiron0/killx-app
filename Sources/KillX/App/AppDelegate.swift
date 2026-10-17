import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var distributedObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor [weak self] in
            guard await SingleInstanceService.shared.prepareForLaunch() else {
                NSApp.terminate(nil)
                return
            }
            self?.finishLaunching()
        }
    }

    private func finishLaunching() {
        statusItemController = StatusItemController()
        SingleInstanceService.shared.startMonitoring()
        _ = ShortcutManager.shared
        WelcomeWindowController.shared.showIfFirstLaunch()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard ConfigStore.shared.config.autoUpdate else { return }
            await UpdateChecker.shared.checkForUpdates(isUserInitiated: false)
        }

        let handleShowSettings: @Sendable (Notification) -> Void = { notif in
            let rawTab = notif.userInfo?["tab"] as? String
            Task { @MainActor in
                let tab = rawTab.flatMap { SettingsTab(rawValue: $0) }
                SettingsWindowController.shared.show(tab: tab)
            }
        }
        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showSettings"),
            object: nil,
            queue: .main,
            using: handleShowSettings
        ))
        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showPreferences"),
            object: nil,
            queue: .main,
            using: handleShowSettings
        ))

        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showPopover"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.statusItemController?.showPopover()
            }
        })

        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.killx.showHelp"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                HelpWindowController.shared.show()
            }
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        for token in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(token)
        }
        distributedObservers.removeAll()
        SingleInstanceService.shared.stopMonitoring()
        statusItemController = nil
    }

    @objc func showHelp(_ sender: Any?) {
        Task { @MainActor in
            HelpWindowController.shared.show()
        }
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
