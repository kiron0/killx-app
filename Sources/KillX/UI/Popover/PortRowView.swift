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

    private let goldColor = QuitXTheme.accent
    private let forceColor = Color.red

    private var isSelected: Bool {
        vm.selectedPorts.contains(port.id)
    }

    private var isPending: Bool {
        vm.pendingPortIds.contains(port.id)
    }

    var body: some View {
        let isForced = vm.isOptionKeyPressed || ConfigStore.shared.config.force == .force

        HStack(spacing: 6) {
            // Checkbox matching QuitX
            QuitXSelectionCheckbox(isSelected: isSelected)

            // App Icon
            AppIconView(bundleId: port.appBundleId, pid: port.pid, size: 18, cornerRadius: 3.5)

            // Port badge
            Text(verbatim: ":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.8)
                .background(
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(port.isDevServer ? goldColor.opacity(0.18) : Color.primary.opacity(0.08))
                )
                .foregroundStyle(port.isDevServer ? goldColor : Color.primary)

            // Process & App info
            HStack(spacing: 4) {
                Text(port.displayAppName)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(port.command.isEmpty ? port.displayAppName : "\(port.displayAppName)\n\(port.command)")

                Text(verbatim: "(\(port.pid))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.secondary)

                if let docker = port.docker {
                    Text("docker")
                        .font(.system(size: 8.5, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .help(docker.name)
                }
            }

            Spacer(minLength: 4)

            let usage = usageText
            if !usage.isEmpty {
                Text(usage)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 48, alignment: .trailing)
            }

            // Row Options Menu button using QuitXMenuButton
            QuitXMenuButton(
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

            // Quick Kill button matching QuitX styling
            Button {
                vm.confirmAndKillPort(port, force: isForced, tree: false)
            } label: {
                quitButtonIcon(isForced: isForced)
            }
            .buttonStyle(.plain)
            .disabled(isPending)
            .help(isPending ? "Operation in progress" : (isForced ? "Force kill :\(port.port) (SIGKILL)" : "Kill :\(port.port) (SIGTERM)"))
            .accessibilityLabel("Kill :\(port.port)")
            .onHover { h in state.isQuitHovered = h }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPending {
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

    @ViewBuilder
    private func quitButtonIcon(isForced: Bool) -> some View {
        let activeColor = isForced ? forceColor : goldColor

        ZStack {
            Color.clear
                .frame(width: 18, height: 18)

            if isPending {
                ProgressView()
                    .controlSize(.small)
                    .tint(goldColor)
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

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: killTitle,
            keyEquivalent: "k",
            keyEquivalentModifierMask: killMask,
            assetName: killAsset,
            systemSymbolName: killSymbol,
            action: {
                vm.confirmAndKillPort(port, force: isForced, tree: false)
            }
        ))

        let treeTitle = isForced ? "Force Tree Kill" : "Tree Kill (Process Tree)"
        menu.addItem(MenuHelper.makeItem(
            title: treeTitle,
            systemSymbolName: "arrow.triangle.branch",
            action: {
                vm.confirmAndKillPort(port, force: isForced, tree: true)
            }
        ))

        menu.addItem(.separator())

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
