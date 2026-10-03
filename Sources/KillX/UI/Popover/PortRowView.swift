import SwiftUI
import AppKit

struct PortRowView: View {
    let port: PortInfo
    @ObservedObject var vm: AppListViewModel

    private let accentColor = KillXTheme.accent
    private let forceColor = Color(red: 240/255, green: 70/255, blue: 50/255)

    private var isSelected: Bool {
        vm.selectedPorts.contains(port.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(isSelected ? accentColor : Color.primary.opacity(0.08))
                    .frame(width: 14, height: 14)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black.opacity(0.9))
                }
            }
            .contentShape(Rectangle())

            // Port badge (verbatim integer to prevent comma formatting)
            Text(verbatim: ":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(port.isDevServer ? accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                )
                .foregroundStyle(port.isDevServer ? accentColor : Color.primary)

            // Process info (clean name + pid)
            HStack(spacing: 4) {
                Text(port.processName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

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

            // Row Options Menu button (Details, Trace Tree, Exclude, Copy)
            PortRowOptionsButton(
                port: port,
                isForced: vm.isOptionKeyPressed,
                onKill: { force in
                    vm.confirmAndKillPort(port, force: force, tree: false)
                },
                onTreeKill: { force in
                    vm.confirmAndKillPort(port, force: force, tree: true)
                },
                onTrace: {
                    ProcessTraceWindowController.shared.show(port: port)
                },
                onDetails: {
                    PortDetailsWindowController.shared.show(port: port)
                },
                onExclude: {
                    vm.excludePort(port.port)
                }
            )
            .frame(width: 16, height: 16)

            // Quick Kill button
            Button {
                vm.confirmAndKillPort(port, force: vm.isOptionKeyPressed, tree: false)
            } label: {
                ZStack {
                    Color.clear
                        .frame(width: 18, height: 18)

                    if vm.isOptionKeyPressed {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(forceColor)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(vm.isOptionKeyPressed ? "Force kill :\(port.port) (SIGKILL)" : "Kill :\(port.port) (SIGTERM)")
            .accessibilityLabel("Kill :\(port.port)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.toggleSelection(for: port)
        }
    }
}

private struct PortRowOptionsButton: NSViewRepresentable {
    let port: PortInfo
    let isForced: Bool
    let onKill: (Bool) -> Void
    let onTreeKill: (Bool) -> Void
    let onTrace: () -> Void
    let onDetails: () -> Void
    let onExclude: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        if let img = AssetImages.load("menu-options") {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 14, height: 14)
            copy.isTemplate = true
            button.image = copy
            button.imagePosition = .imageOnly
        } else {
            button.title = "•••"
            button.font = .systemFont(ofSize: 9.5, weight: .bold)
        }
        button.contentTintColor = NSColor.secondaryLabelColor
        button.toolTip = "Port Options"
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PortRowOptionsButton

        init(parent: PortRowOptionsButton) {
            self.parent = parent
        }

        @objc func showMenu(_ button: NSButton) {
            let menu = NSMenu()
            menu.appearance = NSApp.effectiveAppearance

            let portStr = String(parent.port.port)
            let killTitle = parent.isForced ? "Force Kill Port :\(portStr)" : "Kill Port :\(portStr)"
            let killSymbol = parent.isForced ? "bolt.fill" : "power"
            let killMask: NSEvent.ModifierFlags = parent.isForced ? [.command, .option] : [.command]

            menu.addItem(MenuHelper.makeItem(
                title: "Details...",
                action: #selector(handleDetails),
                target: self,
                keyEquivalent: "d",
                systemSymbolName: "info.circle"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Trace Process Tree...",
                action: #selector(handleTrace),
                target: self,
                keyEquivalent: "t",
                systemSymbolName: "point.filled.topleft.down.curvedto.point.bottomright.up"
            ))

            menu.addItem(.separator())

            menu.addItem(MenuHelper.makeItem(
                title: killTitle,
                action: #selector(handleKill),
                target: self,
                keyEquivalent: "k",
                keyEquivalentModifierMask: killMask,
                systemSymbolName: killSymbol
            ))

            let treeTitle = parent.isForced ? "Force Tree Kill" : "Tree Kill (Process Tree)"
            menu.addItem(MenuHelper.makeItem(
                title: treeTitle,
                action: #selector(handleTreeKill),
                target: self,
                systemSymbolName: "arrow.triangle.branch"
            ))

            menu.addItem(.separator())

            menu.addItem(MenuHelper.makeItem(
                title: "Add Port :\(portStr) to Exclude List",
                action: #selector(handleExclude),
                target: self,
                keyEquivalent: "e",
                systemSymbolName: "nosign"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Copy Port Number (:\(portStr))",
                action: #selector(handleCopyPort),
                target: self,
                keyEquivalent: "c",
                systemSymbolName: "doc.on.doc"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Copy PID (\(parent.port.pid))",
                action: #selector(handleCopyPid),
                target: self,
                systemSymbolName: "number"
            ))

            if parent.port.port > 0 && parent.port.port < 65536 {
                menu.addItem(MenuHelper.makeItem(
                    title: "Open in Browser (http://localhost:\(portStr))",
                    action: #selector(handleOpenBrowser),
                    target: self,
                    keyEquivalent: "o",
                    systemSymbolName: "safari"
                ))
            }

            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.maxX, y: button.bounds.minY), in: button)
        }

        @objc private func handleDetails() { parent.onDetails() }
        @objc private func handleKill() { parent.onKill(parent.isForced) }
        @objc private func handleTreeKill() { parent.onTreeKill(parent.isForced) }
        @objc private func handleTrace() { parent.onTrace() }
        @objc private func handleExclude() { parent.onExclude() }

        @objc private func handleCopyPort() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(parent.port.port), forType: .string)
        }

        @objc private func handleCopyPid() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(parent.port.pid), forType: .string)
        }

        @objc private func handleOpenBrowser() {
            if let url = URL(string: "http://localhost:\(parent.port.port)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
