import SwiftUI

struct ToastView: View {
    let message: String
    let isError: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        message: String,
        isError: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.isError = isError
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(message)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.white.opacity(0.24))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isError ? Color.red.opacity(0.88) : Color.black.opacity(0.78), in: Capsule())
    }
}
