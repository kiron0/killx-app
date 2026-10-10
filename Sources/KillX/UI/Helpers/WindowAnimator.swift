import AppKit
import QuartzCore

@MainActor
enum WindowAnimator {
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.processName.contains("Tests")
            || ProcessInfo.processInfo.processName == "xctest"
    }

    static func present(
        _ window: NSWindow,
        targetFrame: NSRect,
        duration: TimeInterval = 0.25
    ) {
        guard !isRunningTests else {
            window.setFrame(targetFrame, display: false)
            return
        }

        let isFullSize = window.styleMask.contains(.fullSizeContentView) && window.toolbar == nil
        let hasToolbar = window.toolbar != nil

        if isFullSize {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else if hasToolbar {
            if LiquidGlass.enabled {
                window.isOpaque = false
                window.backgroundColor = .clear
            } else {
                window.isOpaque = true
                window.backgroundColor = QuitXTheme.toolbarBackgroundNSColor
            }
        } else {
            window.isOpaque = true
            window.backgroundColor = QuitXTheme.windowBackgroundNSColor
        }

        window.animationBehavior = .none
        window.alphaValue = 0.0
        window.setFrame(targetFrame, display: true)

        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let animTarget: NSView?
        if hasToolbar {
            animTarget = window.contentView
        } else {
            animTarget = window.contentView?.superview ?? window.contentView
        }

        guard let view = animTarget else {
            window.alphaValue = 1.0
            return
        }
        view.wantsLayer = true
        guard let layer = view.layer else {
            window.alphaValue = 1.0
            return
        }

        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            window.alphaValue = 1.0
            return
        }

        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, bounds.midX, bounds.midY, 0)
        t = CATransform3DScale(t, 0.94, 0.94, 1.0)
        t = CATransform3DTranslate(t, -bounds.midX, -bounds.midY, 0)

        let scaleAnim = CABasicAnimation(keyPath: "transform")
        scaleAnim.fromValue = NSValue(caTransform3D: t)
        scaleAnim.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        scaleAnim.duration = duration
        scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        scaleAnim.fillMode = .both
        scaleAnim.isRemovedOnCompletion = true

        layer.removeAnimation(forKey: "killxWindowOpenAnimation")
        layer.add(scaleAnim, forKey: "killxWindowOpenAnimation")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            window.animator().alphaValue = 1.0
        }
    }

    static func activateExisting(_ window: NSWindow) {
        guard !isRunningTests else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        guard let view = window.contentView?.superview ?? window.contentView else { return }
        view.wantsLayer = true
        guard let layer = view.layer else { return }

        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, bounds.midX, bounds.midY, 0)
        t = CATransform3DScale(t, 1.025, 1.025, 1.0)
        t = CATransform3DTranslate(t, -bounds.midX, -bounds.midY, 0)

        let pulseAnim = CAKeyframeAnimation(keyPath: "transform")
        pulseAnim.values = [
            NSValue(caTransform3D: CATransform3DIdentity),
            NSValue(caTransform3D: t),
            NSValue(caTransform3D: CATransform3DIdentity)
        ]
        pulseAnim.keyTimes = [0.0, 0.45, 1.0]
        pulseAnim.duration = 0.22
        pulseAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer.removeAnimation(forKey: "killxWindowPulseAnimation")
        layer.add(pulseAnim, forKey: "killxWindowPulseAnimation")
    }
}
