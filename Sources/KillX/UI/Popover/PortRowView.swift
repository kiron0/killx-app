import SwiftUI
import AppKit

private final class RowUIState: ObservableObject {
    @Published var isHovered = false
    @Published var isQuitHovered = false
}

struct PortRowView: View {
    let port: PortInfo
    @ObservedObject var vm: AppListViewModel

    @StateObject private var state = RowUIState()

    private let accentColor = KillXTheme.accent
    private let forceColor = KillXTheme.forceColor

    private var isSelected: Bool {
        vm.selectedPorts.contains(port.id)
    }

    private var isPending: Bool {
        vm.pendingPortIds.contains(port.id)
    }

    var body: some View {
        let isForced = vm.isOptionKeyPressed || ConfigStore.shared.config.force == .force

        HStack(spacing: 6) {

            KillXSelectionCheckbox(isSelected: isSelected)
                .opacity(port.isSystemProtected ? 0.3 : 1)

            AppIconView(bundleId: port.appBundleId, pid: port.pid, size: 18, cornerRadius: 3.5)

            Text(verbatim: ":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.8)
                .background(
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(Color.primary.opacity(0.08))
                )
                .foregroundStyle(Color.primary)
                .layoutPriority(1)

            HStack(spacing: 4) {
                if ConfigStore.shared.config.favoritePorts.contains(port.port) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.yellow)
                        .help("Favorite port")
                }

                Text(port.displayAppName)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(port.command.isEmpty ? "\(port.displayAppName) (PID \(port.pid))" : "\(port.displayAppName) (PID \(port.pid))\n\(port.command)")

                if let docker = port.docker {
                    Text("docker")
                        .font(.system(size: 8.5, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .help(docker.name)
                        .layoutPriority(1)
                }

                Text(port.exposure.label)
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(exposureColor.opacity(0.16))
                    .foregroundStyle(exposureColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .help("Bound to \(port.bindAddress)")
            }
            .layoutPriority(0)

            Spacer(minLength: 4)

            let usage = usageText
            if !usage.isEmpty {
                Text(usage)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 48, alignment: .trailing)
                    .lineLimit(1)
                    .layoutPriority(2)
            }

            KillXMenuButton(
                assetName: "menu-options",
                systemSymbolName: "ellipsis",
                symbolPointSize: 12,
                size: NSSize(width: 14, height: 14),
                toolTip: "Options",
                isEnabled: !isPending,
                menu: {
                    buildMenu(isForced: isForced)
                }
            )
            .frame(width: 16, height: 16)
            .layoutPriority(2)

            Button {
                if !port.isSystemProtected {
                    vm.confirmAndKillPort(port, force: isForced)
                }
            } label: {
                if port.isSystemProtected {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 18, height: 18)
                } else {
                    quitButtonIcon(isForced: isForced)
                }
            }
            .buttonStyle(.plain)
            .disabled(isPending || port.isSystemProtected)
            .help(port.isSystemProtected ? "System protected port" : (isPending ? (vm.terminationStages[port.id] ?? "Operation in progress") : (isForced ? "Force kill :\(port.port) (SIGKILL)" : "Kill :\(port.port) (SIGTERM)")))
            .accessibilityLabel(port.isSystemProtected ? "System protected port" : "Kill :\(port.port)")
            .onHover { h in state.isQuitHovered = h }
            .layoutPriority(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPending && !port.isSystemProtected {
                vm.toggleSelection(for: port)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { h in state.isHovered = h }
        .opacity(isPending ? 0.72 : 1)
    }

    private var usageText: String {
        switch ConfigStore.shared.config.sortBy {
        case .memoryDesc:
            return port.memoryBytes > 0 ? port.memoryFormatted : ""
        case .cpuDesc:
            return port.cpuUsage > 0 ? port.cpuFormatted : ""
        case .portAsc, .portDesc, .name:
            if port.memoryBytes > 0 { return port.memoryFormatted }
            if port.cpuUsage > 0 { return port.cpuFormatted }
            return ""
        }
    }

    private var exposureColor: Color {
        switch port.exposure {
        case .local: return .secondary
        case .network: return .orange
        case .allInterfaces: return .red
        }
    }

    @ViewBuilder
    private func quitButtonIcon(isForced: Bool) -> some View {
        let activeColor = isForced ? forceColor : accentColor

        ZStack {
            Color.clear
                .frame(width: 18, height: 18)

            if isPending {
                ProgressView()
                    .controlSize(.small)
                    .tint(accentColor)
                    .scaleEffect(0.55)
                    .frame(width: 18, height: 18)
            } else if isForced {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(activeColor)
            } else {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.isQuitHovered ? activeColor : Color.secondary)
            }
        }
        .frame(width: 18, height: 18)
    }

    private func buildMenu(isForced: Bool) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let portStr = String(port.port)
        let killTitle = isForced ? "Force Kill Port :\(portStr)" : "Kill Port :\(portStr)"
        let killSymbol = isForced ? "bolt.fill" : "power"
        let killAsset = isForced ? "settings-force-quit" : "settings-quit"
        let killMask: NSEvent.ModifierFlags = isForced ? [.command, .option] : [.command]

        menu.addItem(MenuHelper.makeItem(
            title: "Details...",
            keyEquivalent: "d",
            systemSymbolName: "info.circle",
            action: {
                PortDetailsWindowController.shared.show(port: port)
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Trace Process Tree...",
            keyEquivalent: "t",
            systemSymbolName: "point.filled.topleft.down.curvedto.point.bottomright.up",
            action: {
                ProcessTraceWindowController.shared.show(port: port)
            }
        ))

        let appUrl = (NSRunningApplication(processIdentifier: port.pid)?.bundleURL)
            ?? (port.appBundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
        if let url = appUrl {
            menu.addItem(MenuHelper.makeItem(
                title: "Reveal App in Finder",
                keyEquivalent: "f",
                systemSymbolName: "folder",
                action: {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            ))
        }

        if !port.isSystemProtected {
            menu.addItem(.separator())

            menu.addItem(MenuHelper.makeItem(
                title: "Interrupt Port :\(portStr) (SIGINT)",
                keyEquivalent: "i",
                keyEquivalentModifierMask: [.command, .shift],
                systemSymbolName: "pause.circle",
                action: {
                    vm.confirmAndInterruptPort(port)
                }
            ))

            menu.addItem(MenuHelper.makeItem(
                title: killTitle,
                keyEquivalent: "k",
                keyEquivalentModifierMask: killMask,
                assetName: killAsset,
                systemSymbolName: killSymbol,
                action: {
                    vm.confirmAndKillPort(port, force: isForced)
                }
            ))
        }

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: ConfigStore.shared.config.favoritePorts.contains(port.port) ? "Remove Port from Favorites" : "Add Port to Favorites",
            systemSymbolName: ConfigStore.shared.config.favoritePorts.contains(port.port) ? "star.slash" : "star",
            action: { vm.toggleFavorite(port.port) }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: ConfigStore.shared.config.watchedPorts.contains(port.port) ? "Stop Watching Port" : "Watch Port Changes",
            systemSymbolName: ConfigStore.shared.config.watchedPorts.contains(port.port) ? "bell.slash" : "bell",
            action: { vm.toggleWatch(port.port) }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Add Port :\(portStr) to Exclude List",
            keyEquivalent: "e",
            systemSymbolName: "nosign",
            action: {
                vm.excludePort(port.port)
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Copy Port Number (:\(portStr))",
            keyEquivalent: "c",
            systemSymbolName: "doc.on.doc",
            action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(String(port.port), forType: .string)
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Copy PID (\(port.pid))",
            systemSymbolName: "number",
            action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(String(port.pid), forType: .string)
            }
        ))

        if !port.command.isEmpty {
            menu.addItem(MenuHelper.makeItem(
                title: "Copy Restart Command",
                systemSymbolName: "terminal",
                action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(port.command, forType: .string)
                }
            ))
        }

        if let cwd = port.cwd, FileManager.default.fileExists(atPath: cwd) {
            menu.addItem(MenuHelper.makeItem(
                title: "Open Terminal Here",
                systemSymbolName: "apple.terminal",
                action: {
                    let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                    let configuration = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.open(
                        [URL(fileURLWithPath: cwd)],
                        withApplicationAt: terminal,
                        configuration: configuration
                    ) { _, _ in }
                }
            ))
        }

        if port.port > 0 && port.port < 65536 {
            menu.addItem(MenuHelper.makeItem(
                title: "Open in Browser (http://localhost:\(portStr))",
                keyEquivalent: "o",
                systemSymbolName: "safari",
                action: {
                    if let url = URL(string: "http://localhost:\(port.port)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            ))
        }

        return menu
    }
}
