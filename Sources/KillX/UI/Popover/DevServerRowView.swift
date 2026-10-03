import SwiftUI
import AppKit

struct DevServerRowView: View {
    let server: DevServerInfo
    @ObservedObject var vm: AppListViewModel

    private let accentColor = KillXTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Button {
                vm.toggleSelection(for: server.port)
            } label: {
                Image(systemName: vm.selectedPorts.contains(server.port.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(vm.selectedPorts.contains(server.port.id) ? accentColor : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Port badge
            Text(":\(server.port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor.opacity(0.18))
                )
                .foregroundStyle(accentColor)

            // Details
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(server.projectName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Text("(\(server.port.processName))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }

                Text(server.displayPath)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Tree kill button
            Button {
                vm.confirmAndKillDevServer(server, force: vm.isOptionKeyPressed)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(vm.isOptionKeyPressed ? "Force" : "Kill")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(vm.isOptionKeyPressed ? Color.red.opacity(0.18) : Color.orange.opacity(0.18))
                .foregroundStyle(vm.isOptionKeyPressed ? Color.red : Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Terminate dev server and process tree")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
