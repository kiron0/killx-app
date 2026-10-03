import SwiftUI
import AppKit

private final class PortDetailsUIState: ObservableObject {
    @Published var copied = false
}

struct PortDetailsView: View {
    let port: PortInfo
    var onClose: () -> Void

    @StateObject private var uiState = PortDetailsUIState()
    private let accentColor = KillXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            header

            // Header info
            HStack(spacing: 12) {
                Text(verbatim: ":\(port.port)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(port.isDevServer ? accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                    )
                    .foregroundStyle(port.isDevServer ? accentColor : Color.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(port.processName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Text(verbatim: "PID \(port.pid) • \(port.protocolName) \(port.state)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 12)

            Divider()

            // Details list
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
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
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }

            Divider()

            // Footer actions
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

                Button("Kill Port", role: .destructive) {
                    onClose()
                    AppListViewModel.shared.confirmAndKillPort(port, force: false, tree: false)
                }
                .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 380)
        .background(KillXTheme.windowBackground)
        .ignoresSafeArea(edges: .top)
    }

    private var header: some View {
        Text("Port :\(port.port) Details")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(KillXTheme.windowBackground)
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
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = PortDetailsView(port: port, onClose: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        win.setContentSize(NSSize(width: 440, height: 380))
        win.minSize = NSSize(width: 380, height: 280)
        win.isOpaque = true
        win.isReleasedWhenClosed = false
        win.backgroundColor = KillXTheme.windowBackgroundNSColor
        win.appearance = NSApp.effectiveAppearance
        win.isMovableByWindowBackground = true
        win.delegate = self
        win.center()
        self.window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
