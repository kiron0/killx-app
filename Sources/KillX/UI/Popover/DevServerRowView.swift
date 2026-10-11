import SwiftUI
import AppKit

private final class DevServerRowUIState: ObservableObject {
    @Published var isHovered = false
}

struct DevServerRowView: View {
    let server: DevServerInfo
    @ObservedObject var vm: AppListViewModel

    @StateObject private var state = DevServerRowUIState()

    private let accentColor = KillXTheme.accent

    private var isSelected: Bool {
        vm.selectedPorts.contains(server.port.id)
    }

    var body: some View {
        HStack(spacing: 6) {

            KillXSelectionCheckbox(isSelected: isSelected)

            AppIconView(bundleId: server.port.appBundleId, pid: server.port.pid, size: 18, cornerRadius: 3.5)

            Text(verbatim: ":\(server.port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(accentColor.opacity(0.35), lineWidth: 0.7)
                )
                .foregroundStyle(accentColor)
                .layoutPriority(1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(server.projectName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("(\(server.port.processName))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                Text(server.displayPath)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(0)

            Spacer(minLength: 4)

            Button {
                ProcessTraceWindowController.shared.show(port: server.port)
            } label: {
                Image(systemName: "point.filled.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(width: 17, height: 17)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
            }
            .buttonStyle(.plain)
            .help("Trace dev server process ancestry")
            .layoutPriority(2)

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
                .background(vm.isOptionKeyPressed ? KillXTheme.forceColor.opacity(0.18) : accentColor.opacity(0.18))
                .foregroundStyle(vm.isOptionKeyPressed ? KillXTheme.forceColor : accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Terminate dev server and process tree")
            .layoutPriority(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.toggleSelection(for: server.port)
        }
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { h in state.isHovered = h }
    }
}
