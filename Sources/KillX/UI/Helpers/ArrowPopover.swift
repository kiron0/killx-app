import AppKit
import SwiftUI

final class ArrowPopoverWindow: NSPanel {
    init(level: NSWindow.Level = .statusBar) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

func popoverShape(arrowX: CGFloat?) -> PopoverContainerShape {
    if let arrowX {
        return PopoverContainerShape(arrowX: arrowX, centeredArrow: false, cornerRadius: 14)
    }
    return PopoverContainerShape(centeredArrow: true, cornerRadius: 14)
}

struct ArrowPopoverChrome: ViewModifier {
    var arrowX: CGFloat? = nil
    var classicBackground: AnyView = AnyView(
        VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
    )

    func body(content: Content) -> some View {
        let shape = popoverShape(arrowX: arrowX)
        return content
            .background {
                if LiquidGlass.enabled {
                    LiquidGlassFill(shape: shape)
                } else {
                    classicBackground.clipShape(shape)
                }
            }
            .overlay {
                if !LiquidGlass.enabled {
                    shape
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
            }
            .clipShape(shape)
    }
}

extension View {
    func arrowPopoverChrome(
        arrowX: CGFloat? = nil,
        classicBackground: AnyView = AnyView(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
    ) -> some View {
        modifier(ArrowPopoverChrome(arrowX: arrowX, classicBackground: classicBackground))
    }
}
