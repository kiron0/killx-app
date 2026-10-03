import SwiftUI
import AppKit

struct ProcessTraceView: View {
    @ObservedObject var vm: AppListViewModel
    private let accentColor = KillXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    vm.closeTrace()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                if let port = vm.inspectedPort {
                    Text("Trace :\(port.port)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                if let port = vm.inspectedPort {
                    Button {
                        vm.confirmAndKillPort(port, force: vm.isOptionKeyPressed, tree: true)
                        vm.closeTrace()
                    } label: {
                        Text(vm.isOptionKeyPressed ? "Force Tree Kill" : "Tree Kill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(vm.isOptionKeyPressed ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                            .foregroundStyle(vm.isOptionKeyPressed ? Color.red : Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))

            Divider()

            // Tree list
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if vm.inspectedAncestry.isEmpty {
                        Text("No process ancestry found.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(vm.inspectedAncestry.enumerated()), id: \.element.id) { index, node in
                            HStack(alignment: .top, spacing: 6) {
                                // Tree branch indicator
                                Text(index == 0 ? "●" : "└─")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(node.isListener ? accentColor : Color.secondary.opacity(0.7))
                                    .padding(.leading, CGFloat(max(0, index - 1)) * 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(node.name)
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(node.isListener ? accentColor : Color.primary)

                                        Text("PID \(node.pid)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(Color.secondary)

                                        if node.isListener {
                                            Text("LISTENER")
                                                .font(.system(size: 8.5, weight: .bold))
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(accentColor.opacity(0.2))
                                                .foregroundStyle(accentColor)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                    }

                                    if !node.command.isEmpty && node.command != node.name {
                                        Text(node.command)
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(2)
                                    }

                                    if let cwd = node.cwd, !cwd.isEmpty {
                                        let display = cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                                        Text("cwd: \(display)")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.secondary.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: 280)
    }
}
