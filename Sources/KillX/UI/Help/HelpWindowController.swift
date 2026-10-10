import AppKit
import SwiftUI

@MainActor
final class HelpWindowController: NSObject, NSWindowDelegate {
    static let shared = HelpWindowController()

    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func show() {
        StatusItemController.shared?.closePopover()

        if let window {
            if let screen = WindowPositioner.targetScreen {
                window.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: window.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(window)
            return
        }

        let hosting = NSHostingController(rootView: HelpView())
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 740, height: 520))
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.animationBehavior = .none
        window.delegate = self

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: window.frame.size, on: screen)
        } else {
            window.center()
            targetFrame = window.frame
        }

        self.window = window
        WindowActivationCoordinator.update()
        WindowAnimator.present(window, targetFrame: targetFrame)
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
