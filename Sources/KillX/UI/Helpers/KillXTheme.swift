import SwiftUI
import AppKit

enum QuitXTheme {
    static let accent = Color(red: 232/255, green: 50/255, blue: 62/255)
    static let accentNSColor = NSColor(srgbRed: 232/255, green: 50/255, blue: 62/255, alpha: 1.0)
    static let accentSecondary = Color(red: 200/255, green: 30/255, blue: 42/255)
    static let accentLight = Color(red: 245/255, green: 75/255, blue: 85/255)
    static let redGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .top,
        endPoint: .bottom
    )
    static let accentGradient = redGradient
    static let goldGradient = redGradient
    static let forceColor = Color(red: 255/255, green: 40/255, blue: 40/255)
    static let forceGradient = LinearGradient(
        colors: [Color(red: 255/255, green: 55/255, blue: 55/255), Color(red: 195/255, green: 20/255, blue: 25/255)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let windowBackgroundColor = Color(NSColor.windowBackgroundColor)
    static let windowBackgroundNSColor = NSColor.windowBackgroundColor
    static let cardBackground = Color.primary.opacity(0.035)
    static let cardBackgroundNSColor: NSColor = {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            var baseColor: NSColor = .windowBackgroundColor
            appearance.performAsCurrentDrawingAppearance {
                baseColor = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB) ?? .windowBackgroundColor
            }
            let tintColor: NSColor = isDark ? .white : .black
            return baseColor.blended(withFraction: 0.035, of: tintColor) ?? baseColor
        }
    }()
    static let toolbarBackground = cardBackground
    static let toolbarBackgroundNSColor = cardBackgroundNSColor

    static var popoverBackground: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            Color(NSColor.windowBackgroundColor)
                .opacity(0.88)
        }
    }

    static var windowBackground: some View {
        Color(NSColor.windowBackgroundColor)
    }

    @MainActor
    @ViewBuilder
    static var paneBackground: some View {
        if LiquidGlass.enabled {
            Color.clear
        } else {
            Color(NSColor.windowBackgroundColor)
        }
    }
}

typealias KillXTheme = QuitXTheme

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
