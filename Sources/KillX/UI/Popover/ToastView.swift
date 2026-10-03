import SwiftUI

struct ToastView: View {
    var count: Int = 0
    var message: String? = nil

    var body: some View {
        let text = message ?? (count == 1 ? "1 app quit" : "\(count) apps quit")
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.black.opacity(0.8), in: Capsule())
    }
}
