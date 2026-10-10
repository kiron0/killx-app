import SwiftUI

enum LiquidGlass {
    @MainActor
    static var enabled: Bool {
        if #available(macOS 26.0, *) {
            return ConfigStore.shared.config.liquidGlassEnabled
        }
        return false
    }
}

struct LiquidGlassFill<Shape: SwiftUI.Shape>: View {
    let shape: Shape

    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            Color.clear
        }
    }
}
