import SwiftUI
import AppKit

private final class AboutTabState: ObservableObject {
    @Published var isContactHovered = false
}

struct AboutTabCloneView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @StateObject private var state = AboutTabState()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                KillXAppIconView(size: 70, cornerRadius: 14)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(KillXConstants.appName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Text("⚡️ Version \(updateChecker.currentVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Text(KillXConstants.copyright)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)

                    HStack(spacing: 10) {
                        Button("Say hi 👋") {
                            if let url = KillXConstants.sayHiURL() {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.system(size: 11.5))

                        Button(updateChecker.isChecking ? "Checking..." : "Check Updates") {
                            Task {
                                await updateChecker.checkForUpdates(isUserInitiated: true)
                            }
                        }
                        .disabled(updateChecker.isChecking)
                        .font(.system(size: 11.5))
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KillXTheme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KillXTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Questions, feedback or ideas?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)

                    Text("We'd love to hear from you. Get in touch with us.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    if let url = KillXConstants.contactURL() {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Contact")
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(state.isContactHovered ? KillXTheme.accent : Color.primary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(state.isContactHovered ? KillXTheme.accent.opacity(0.14) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(state.isContactHovered ? KillXTheme.accent.opacity(0.35) : Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .onHover { state.isContactHovered = $0 }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(KillXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: 480, height: 186, alignment: .topLeading)
        .background(KillXTheme.paneBackground)
    }
}
