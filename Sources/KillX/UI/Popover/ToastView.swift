import SwiftUI

struct ToastView: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isError ? Color.red.opacity(0.88) : Color.black.opacity(0.82), in: Capsule())
    }
}
