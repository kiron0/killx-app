import AppKit

@MainActor
enum WindowPositioner {
    static var targetScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    static func topBiasedFrame(for size: NSSize, on screen: NSScreen? = nil, topOffset: CGFloat = 110) -> NSRect {
        guard let screen = screen ?? targetScreen else {
            return NSRect(origin: .zero, size: size)
        }
        let sf = screen.visibleFrame
        let x = min(max(sf.minX, sf.midX - (size.width / 2)), sf.maxX - size.width)
        let y = min(max(sf.minY, sf.maxY - size.height - topOffset), sf.maxY - size.height)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    static func topBiasedOrigin(for size: NSSize, on screen: NSScreen? = nil, topOffset: CGFloat = 110) -> NSPoint {
        topBiasedFrame(for: size, on: screen, topOffset: topOffset).origin
    }
}
