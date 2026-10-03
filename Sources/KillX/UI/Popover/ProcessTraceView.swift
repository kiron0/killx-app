import SwiftUI
import AppKit

struct ProcessTraceWindowView: View {
    let port: PortInfo
    let ancestry: [ProcessTreeNodeInfo]
    var onClose: () -> Void

    private let accentColor = KillXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            header

            // Header info
            HStack(spacing: 12) {
                Text(verbatim: ":\(port.port)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(port.isDevServer ? accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                    )
                    .foregroundStyle(port.isDevServer ? accentColor : Color.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(port.processName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text(verbatim: "PID \(port.pid) • Process Ancestry Tree")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Button {
                    onClose()
                    AppListViewModel.shared.confirmAndKillPort(port, force: false, tree: true)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Tree Kill")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)

            Divider()

            // Tree list
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if ancestry.isEmpty {
                        VStack(spacing: 8) {
                            Text("No process ancestry found.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(Array(ancestry.enumerated()), id: \.element.id) { index, node in
                            HStack(alignment: .top, spacing: 8) {
                                // Tree branch indicator
                                Text(index == 0 ? "●" : "└─")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(node.isListener ? accentColor : Color.secondary.opacity(0.7))
                                    .padding(.leading, CGFloat(max(0, index - 1)) * 14)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(node.name)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(node.isListener ? accentColor : Color.primary)

                                        Text(verbatim: "PID \(node.pid)")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(Color.secondary)

                                        if node.isListener {
                                            Text("LISTENER")
                                                .font(.system(size: 8.5, weight: .heavy))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1.5)
                                                .background(accentColor.opacity(0.2))
                                                .foregroundStyle(accentColor)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                    }

                                    if !node.command.isEmpty && node.command != node.name {
                                        Text(verbatim: node.command)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(3)
                                            .textSelection(.enabled)
                                    }

                                    if let cwd = node.cwd, !cwd.isEmpty {
                                        let display = cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                                        Text(verbatim: "cwd: \(display)")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(Color.secondary.opacity(0.8))
                                            .lineLimit(1)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Close") {
                    onClose()
                }
                .font(.system(size: 11))
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 460, height: 380)
        .background(KillXTheme.windowBackground)
        .ignoresSafeArea(edges: .top)
    }

    private var header: some View {
        Text("Process Tree — Port :\(port.port)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(KillXTheme.windowBackground)
    }
}

@MainActor
final class ProcessTraceWindowController: NSObject, NSWindowDelegate {
    static let shared = ProcessTraceWindowController()
    private var window: NSWindow?

    func show(port: PortInfo) {
        StatusItemController.shared?.closePopover()

        Task { [weak self] in
            guard let self = self else { return }
            let ancestry = await PortService.shared.traceProcessTree(pid: port.pid)

            if let win = self.window {
                let rootView = ProcessTraceWindowView(port: port, ancestry: ancestry, onClose: { [weak self] in self?.close() })
                win.contentViewController = NSHostingController(rootView: rootView)
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let rootView = ProcessTraceWindowView(port: port, ancestry: ancestry, onClose: { [weak self] in self?.close() })
            let hosting = NSHostingController(rootView: rootView)
            let win = NSWindow(contentViewController: hosting)
            win.title = ""
            win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titlebarSeparatorStyle = .none
            win.titleVisibility = .hidden
            win.setContentSize(NSSize(width: 460, height: 380))
            win.minSize = NSSize(width: 380, height: 260)
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
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
