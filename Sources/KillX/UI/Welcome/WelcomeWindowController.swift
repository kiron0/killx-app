import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowController()
    private let windowWidth: CGFloat = 390
    private var window: NSWindow?

    static var firstLaunchSeenKey: String {
        "killx_first_launch_seen_v1"
    }

    var isOpen: Bool { window != nil }

    func showIfFirstLaunch(defaults: UserDefaults = .standard) {
        if !defaults.bool(forKey: Self.firstLaunchSeenKey) {
            defaults.set(true, forKey: Self.firstLaunchSeenKey)
            show()
        }
    }

    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.processName.contains("Tests")
            || ProcessInfo.processInfo.processName == "xctest"
    }

    func show() {
        StatusItemController.shared?.closePopover()

        if let win = window {
            if !Self.isRunningTests {
                if let screen = WindowPositioner.targetScreen {
                    win.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: win.frame.size, on: screen))
                }
                WindowAnimator.activateExisting(win)
            }
            return
        }

        let rootView = WelcomeView(
            onDismiss: { [weak self] in
                self?.close()
                StatusItemController.shared?.showPopover()
            }
        ).environmentObject(ConfigStore.shared)

        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        let fittingSize = hosting.sizeThatFits(
            in: NSSize(width: windowWidth, height: .greatestFiniteMagnitude)
        )
        win.setContentSize(NSSize(width: windowWidth, height: ceil(fittingSize.height)))
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isMovableByWindowBackground = true
        win.hidesOnDeactivate = false
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.animationBehavior = .none
        win.delegate = self
        self.window = win

        guard !Self.isRunningTests else { return }

        WindowActivationCoordinator.update()
        win.orderFrontRegardless()

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: win.frame.size, on: screen)
        } else {
            win.center()
            targetFrame = win.frame
        }

        WindowAnimator.present(win, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
        window = nil
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}
