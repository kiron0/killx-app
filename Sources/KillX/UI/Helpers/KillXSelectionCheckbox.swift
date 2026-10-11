import SwiftUI

struct KillXSelectionCheckbox: View {
    let isSelected: Bool
    var isPartial = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected || isPartial ? KillXTheme.accent : Color.primary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isSelected || isPartial ? KillXTheme.accent : Color.primary.opacity(0.18), lineWidth: 0.7)
                )
                .frame(width: 14, height: 14)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white)
            } else if isPartial {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 6, height: 2)
            }
        }
        .frame(width: 14, height: 14)
        .contentShape(Rectangle())
    }
}
