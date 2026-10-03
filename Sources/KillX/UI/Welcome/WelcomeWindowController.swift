import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowController()
    private var window: NSWindow?

    func showIfFirstLaunch() {
        let key = "killx_first_launch_seen_v1"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            show()
        }
    }

    func show() {
        StatusItemController.shared?.closePopover()

        if let win = window {
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.origin.x + (screenFrame.width - 360) / 2
                let y = screenFrame.origin.y + screenFrame.height - 370 - 110
                win.setFrame(NSRect(x: x, y: y, width: 360, height: 370), display: true)
            }
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = WelcomeView(
            onDismiss: { [weak self] in
                self?.close()
            },
            onOpenSettings: { [weak self] in
                self?.close()
                SettingsWindowController.shared.show()
            }
        ).environmentObject(ConfigStore.shared)

        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        win.setContentSize(NSSize(width: 360, height: 370))
        win.isOpaque = true
        win.backgroundColor = KillXTheme.windowBackgroundNSColor
        win.appearance = NSApp.effectiveAppearance
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.delegate = self
        self.window = win

        let targetFrame: NSRect
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.origin.x + (screenFrame.width - 360) / 2
            let y = screenFrame.origin.y + screenFrame.height - 370 - 110
            targetFrame = NSRect(x: x, y: y, width: 360, height: 370)
        } else {
            win.center()
            targetFrame = win.frame
        }

        win.setFrame(targetFrame, display: false)
        win.alphaValue = 0.0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().alphaValue = 1.0
        }
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
