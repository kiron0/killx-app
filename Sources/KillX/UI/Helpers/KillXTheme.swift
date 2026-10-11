import SwiftUI
import AppKit

enum KillXTheme {
    static let accent = Color(red: 56/255, green: 189/255, blue: 248/255)
    static let accentNSColor = NSColor(srgbRed: 56/255, green: 189/255, blue: 248/255, alpha: 1.0)
    static let accentSecondary = Color(red: 2/255, green: 132/255, blue: 199/255)
    static let accentLight = Color(red: 125/255, green: 211/255, blue: 252/255)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 56/255, green: 189/255, blue: 248/255), Color(red: 2/255, green: 132/255, blue: 199/255)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let skyGradient = accentGradient
    static let forceColor = Color(red: 99/255, green: 102/255, blue: 241/255)
    static let forceGradient = LinearGradient(
        colors: [Color(red: 129/255, green: 140/255, blue: 248/255), Color(red: 79/255, green: 70/255, blue: 229/255)],
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
