import SwiftUI
import AppKit

struct WelcomeView: View {
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    private let accent = KillXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 24)

            VStack(spacing: 8) {
                guideRow(
                    icon: "network",
                    title: "Active Port Monitor",
                    detail: "Click the KillX menu bar icon to inspect open listening TCP ports in real time."
                )
                guideRow(
                    icon: "arrow.triangle.branch",
                    title: "Process Tree Kill",
                    detail: "Terminate parent supervisors (npm, vite, cargo) and child processes cleanly."
                )
                guideRow(
                    icon: "bolt.fill",
                    title: "Dev Server Sweeper",
                    detail: "Detect and sweep hung development servers in one click."
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                Button("Settings") {
                    onOpenSettings()
                }
                .buttonStyle(WelcomeSecondaryButtonStyle())

                Button("Get Started") {
                    onDismiss()
                }
                .buttonStyle(WelcomePrimaryButtonStyle(color: accent))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .frame(width: 360, height: 370)
        .background(KillXTheme.windowBackground)
        .ignoresSafeArea(edges: .top)
    }

    private var hero: some View {
        VStack(spacing: 8) {
            KillXAppIconView(size: 54, cornerRadius: 12)

            Text("Welcome to KillX")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Find and kill the process using a port.")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
    }

    private func guideRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct WelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(configuration.isPressed ? 0.55 : 0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Color.primary.opacity(configuration.isPressed ? 0.04 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
