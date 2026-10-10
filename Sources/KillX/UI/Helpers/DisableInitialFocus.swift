import AppKit
import SwiftUI

private struct InitialFocusDisabler: NSViewRepresentable {
    final class Coordinator {
        var hasDisabledFocus = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        disableFocus(whenReady: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        disableFocus(whenReady: view, coordinator: context.coordinator)
    }

    private func disableFocus(whenReady view: NSView, coordinator: Coordinator) {
        guard !coordinator.hasDisabledFocus else { return }

        DispatchQueue.main.async { [weak view, weak coordinator] in
            guard let view, let coordinator, !coordinator.hasDisabledFocus,
                  let window = view.window else { return }
            window.makeFirstResponder(nil)
            coordinator.hasDisabledFocus = true
        }
    }
}

extension View {
    func disableInitialFocus() -> some View {
        background(InitialFocusDisabler())
    }
}
