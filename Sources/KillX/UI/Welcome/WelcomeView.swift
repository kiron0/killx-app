import SwiftUI
import AppKit

struct WelcomeView: View {
    var onDismiss: () -> Void

    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared

    private let gold = QuitXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 22)
                .padding(.bottom, 20)

            quickSetup
                .padding(.horizontal, 22)

            Button("Get Started") {
                onDismiss()
            }
            .buttonStyle(WelcomePrimaryButtonStyle(color: gold))
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
    }

    private var quickSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)

            setupToggle("Open KillX at login", isOn: $launchService.isEnabled)
            setupToggle("Play sounds", isOn: Binding(
                get: { configStore.config.playSounds },
                set: {
                    configStore.config.playSounds = $0
                    configStore.save()
                }
            ))
            setupToggle("Select ports by default", isOn: Binding(
                get: { configStore.config.defaultSelectAll },
                set: {
                    configStore.config.defaultSelectAll = $0
                    configStore.save()
                }
            ))

            if #available(macOS 26.0, *) {
                HStack(spacing: 12) {
                    Text("Appearance")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary)
                        .layoutPriority(1)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { configStore.config.liquidGlassEnabled },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                configStore.config.liquidGlassEnabled = newValue
                            }
                            configStore.save()
                        }
                    )) {
                        Text("Classic").tag(false)
                        Text("Liquid Glass").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 168)
                }
            }

            HStack(spacing: 12) {
                Text("Default kill signal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .layoutPriority(1)

                Spacer()

                Picker("", selection: Binding(
                    get: { configStore.config.force },
                    set: {
                        configStore.config.force = $0
                        configStore.save()
                    }
                )) {
                    Text("SIGTERM").tag(KillXConfig.ForceMode.normal)
                    Text("SIGKILL").tag(KillXConfig.ForceMode.force)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 168)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func setupToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                QuitXSelectionCheckbox(isSelected: isOn.wrappedValue)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            KillXAppIconView(size: 58, cornerRadius: 13)

            Text("Welcome to KillX")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Find and kill the process using a port.")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
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
