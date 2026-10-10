import AppKit
import SwiftUI

@MainActor
final class AppUpdateWindowController: NSObject, NSWindowDelegate {
    static let shared = AppUpdateWindowController()
    private let windowWidth: CGFloat = 390
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func showCheckWindow() {
        StatusItemController.shared?.closePopover()

        if let win = window {
            if let screen = WindowPositioner.targetScreen {
                win.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: win.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(win)
            return
        }

        buildAndPresentWindow()
    }

    private func buildAndPresentWindow() {
        let contentView = AppUpdateView(
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        let hosting = NSHostingController(rootView: contentView)
        hosting.safeAreaRegions = []
        hosting.sizingOptions = [.preferredContentSize]
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        let fittingSize = hosting.sizeThatFits(
            in: NSSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        win.setContentSize(NSSize(width: windowWidth, height: ceil(fittingSize.height)))
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.animationBehavior = .none
        win.delegate = self
        self.window = win
        WindowActivationCoordinator.update()

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
        UpdateChecker.shared.resetState()
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        UpdateChecker.shared.resetState()
        WindowActivationCoordinator.update()
    }
}
