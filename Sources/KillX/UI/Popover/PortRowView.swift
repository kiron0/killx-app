import SwiftUI
import AppKit

struct PortRowView: View {
    let port: PortInfo
    @ObservedObject var vm: AppListViewModel

    private let accentColor = KillXTheme.accent

    var body: some View {
        HStack(spacing: 7) {
            // Checkbox
            Button {
                vm.toggleSelection(for: port)
            } label: {
                Image(systemName: vm.selectedPorts.contains(port.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(vm.selectedPorts.contains(port.id) ? accentColor : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Port badge
            Text(":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(port.isDevServer ? accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                )
                .foregroundStyle(port.isDevServer ? accentColor : Color.primary)

            // Process info
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(port.processName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Text("(\(port.pid))")
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

                HStack(spacing: 4) {
                    if let cwd = port.cwd, !cwd.isEmpty {
                        let display = (cwd as NSString).lastPathComponent
                        Text(display)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    } else {
                        Text(port.user.isEmpty ? "tcp" : port.user)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }

                    if port.memoryBytes > 0 {
                        Text("• \(port.memoryFormatted)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.secondary.opacity(0.8))
                    }
                }
            }

            Spacer(minLength: 4)

            // Action buttons always visible (no hover pop-in, no scale effects)
            HStack(spacing: 4) {
                // Trace Tree button
                Button {
                    Task { await vm.tracePort(port) }
                } label: {
                    Image(systemName: "point.filled.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 9.5, weight: .semibold))
                        .frame(width: 19, height: 19)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Trace process ancestry tree")

                // Tree Kill button
                Button {
                    vm.confirmAndKillPort(port, force: vm.isOptionKeyPressed, tree: true)
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9.5, weight: .semibold))
                        .frame(width: 19, height: 19)
                        .background(Color.orange.opacity(0.14))
                        .foregroundStyle(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Tree kill (supervisor + children)")

                // Single Kill button
                Button {
                    vm.confirmAndKillPort(port, force: vm.isOptionKeyPressed, tree: false)
                } label: {
                    Image(systemName: vm.isOptionKeyPressed ? "bolt.fill" : "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .frame(width: 19, height: 19)
                        .background(vm.isOptionKeyPressed ? Color.red.opacity(0.18) : Color.primary.opacity(0.07))
                        .foregroundStyle(vm.isOptionKeyPressed ? Color.red : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help(vm.isOptionKeyPressed ? "Force kill (SIGKILL)" : "Kill (SIGTERM)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
