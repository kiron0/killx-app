import SwiftUI
import AppKit

private final class PortDetailsUIState: ObservableObject {
    @Published var copied = false
    @Published var showingKillConfirmation = false
    @Published var isKilling = false
}

struct PortDetailsView: View {
    let port: PortInfo
    var onClose: () -> Void

    @StateObject private var uiState = PortDetailsUIState()
    private let accentColor = KillXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 12) {
                AppIconView(bundleId: port.appBundleId, pid: port.pid, size: 36, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(port.displayAppName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Text(verbatim: ":\(port.port)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .foregroundStyle(Color.primary)
                    }

                    Text(verbatim: "\(port.processName) • PID \(port.pid) • \(port.protocolName) \(port.state)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(label: "Application", value: port.displayAppName)
                    if let bundleId = port.appBundleId {
                        detailRow(label: "Bundle Identifier", value: bundleId)
                    }
                    detailRow(label: "Port Number", value: String(port.port))
                    detailRow(label: "Process ID", value: String(port.pid))
                    detailRow(label: "Process Name", value: port.processName)

                    if !port.user.isEmpty {
                        detailRow(label: "User", value: port.user)
                    }

                    if port.memoryBytes > 0 {
                        detailRow(label: "Memory Usage", value: port.memoryFormatted)
                    }

                    if port.cpuUsage > 0 {
                        detailRow(label: "CPU Usage", value: port.cpuFormatted)
                    }

                    if let cwd = port.cwd, !cwd.isEmpty {
                        detailRow(label: "Working Directory", value: cwd)
                    }

                    if !port.command.isEmpty {
                        detailRow(label: "Command", value: port.command)
                    }

                    if let docker = port.docker {
                        Divider().padding(.vertical, 4)
                        detailRow(label: "Docker Container", value: docker.name)
                        detailRow(label: "Docker Image", value: docker.image)
                        detailRow(label: "Container ID", value: docker.containerId)
                        detailRow(label: "Port Mappings", value: docker.ports)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 10) {
                Button {
                    copyAllDetails()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: uiState.copied ? "checkmark" : "doc.on.doc")
                        Text(uiState.copied ? "Copied!" : "Copy Details")
                    }
                    .font(.system(size: 11))
                }

                Button {
                    ProcessTraceWindowController.shared.show(port: port)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "point.filled.topleft.down.curvedto.point.bottomright.up")
                        Text("Trace Tree")
                    }
                    .font(.system(size: 11))
                }

                Spacer()

                Button("Close") {
                    onClose()
                }
                .font(.system(size: 11))
                .keyboardShortcut(.cancelAction)

                Button("Kill Port") {
                    if ConfigStore.shared.config.confirmKill {
                        uiState.showingKillConfirmation = true
                    } else {
                        performKill()
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .disabled(uiState.isKilling)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 440, maxWidth: .infinity, minHeight: 380, maxHeight: .infinity)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                KillXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if uiState.showingKillConfirmation {
                KillConfirmationOverlay(
                    title: "Kill Port :\(port.port)?",
                    subtitle: "Terminating \(port.processName) (PID \(port.pid)) will close this port listener.",
                    confirmTitle: "Kill Port",
                    systemImage: "questionmark.circle.fill",
                    isForced: false,
                    cardWidth: 260,
                    onConfirm: {
                        uiState.showingKillConfirmation = false
                        performKill()
                    },
                    onCancel: {
                        uiState.showingKillConfirmation = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: uiState.showingKillConfirmation)
        .ignoresSafeArea()
    }

    private func performKill() {
        uiState.isKilling = true
        Task {
            let ok = await PortService.shared.killPort(port, force: false, tree: false)
            if ok {
                SoundService.playKillSingle()
                AppListViewModel.shared.showToastMessage("Killed :\(port.port) (\(port.processName))")
                await AppListViewModel.shared.refresh()
            }
            onClose()
        }
    }

    private var header: some View {
        Text(verbatim: "Port :\(port.port) Details")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(KillXTheme.cardBackground)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.secondary)

            Text(verbatim: value)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Color.primary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copyAllDetails() {
        var lines: [String] = [
            "Port: \(port.port)",
            "PID: \(port.pid)",
            "Process: \(port.processName)",
            "Protocol: \(port.protocolName)",
            "State: \(port.state)"
        ]
        if let cwd = port.cwd, !cwd.isEmpty { lines.append("CWD: \(cwd)") }
        if !port.command.isEmpty { lines.append("Command: \(port.command)") }
        if port.memoryBytes > 0 { lines.append("Memory: \(port.memoryFormatted)") }
        if port.cpuUsage > 0 { lines.append("CPU: \(port.cpuFormatted)") }
        if let docker = port.docker {
            lines.append("Docker Container: \(docker.name)")
            lines.append("Docker Image: \(docker.image)")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        uiState.copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak uiState] in
            uiState?.copied = false
        }
    }
}

@MainActor
final class PortDetailsWindowController: NSObject, NSWindowDelegate {
    static let shared = PortDetailsWindowController()
    private var window: NSWindow?

    func show(port: PortInfo) {
        StatusItemController.shared?.closePopover()

        if let win = self.window {
            let rootView = PortDetailsView(port: port, onClose: { [weak self] in self?.close() })
            win.contentViewController = NSHostingController(rootView: rootView)
            if let screen = WindowPositioner.targetScreen {
                win.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: win.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(win)
            return
        }

        let rootView = PortDetailsView(port: port, onClose: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        win.setContentSize(NSSize(width: 440, height: 380))
        win.minSize = win.frame.size
        win.maxSize = win.frame.size
        win.collectionBehavior = [.fullScreenNone]
        if LiquidGlass.enabled {
            win.isOpaque = false
            win.backgroundColor = .clear
        } else {
            win.isOpaque = true
            win.backgroundColor = KillXTheme.windowBackgroundNSColor
        }
        win.isReleasedWhenClosed = false
        win.appearance = NSApp.effectiveAppearance
        win.isMovableByWindowBackground = true
        win.animationBehavior = .none
        win.delegate = self
        self.window = win

        WindowActivationCoordinator.update()
        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: win.frame.size, on: screen)
        } else {
            win.center()
            targetFrame = win.frame
        }
        WindowAnimator.present(win, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
        window = nil
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}
