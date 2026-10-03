import SwiftUI
import AppKit

enum KillXTheme {
    static let accent = Color(red: 244/255, green: 63/255, blue: 94/255)
    static let accentNSColor = NSColor(red: 244/255, green: 63/255, blue: 94/255, alpha: 1.0)
    static let accentLight = Color(red: 251/255, green: 113/255, blue: 133/255)
    static let windowBackgroundColor = Color(NSColor.windowBackgroundColor)
    static let windowBackgroundNSColor = NSColor.windowBackgroundColor
    static let toolbarBackground = Color(NSColor.windowBackgroundColor)
    static let toolbarBackgroundNSColor = NSColor.windowBackgroundColor

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
}

typealias QuitXTheme = KillXTheme

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
