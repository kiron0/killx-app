import SwiftUI
import AppKit

final class AppIconLoader: ObservableObject {
    @Published var icon: NSImage?

    func load(bundleId: String?) {
        guard let bid = bundleId,
              let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSWorkspace.shared.icon(forFile: path)
            DispatchQueue.main.async { self.icon = img }
        }
    }
}

struct AppIconView: View {
    let bundleId: String?
    @StateObject private var loader = AppIconLoader()

    var body: some View {
        Group {
            if let icon = loader.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(5)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.1))
            }
        }
        .onAppear { loader.load(bundleId: bundleId) }
    }
}
