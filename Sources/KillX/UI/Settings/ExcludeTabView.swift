import SwiftUI
import AppKit

struct ExcludeTabView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = ExcludeTabState()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ports on this list stay out of manual and automatic kill actions.")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Group {
                if configStore.config.excludePorts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "nosign")
                            .font(.system(size: 24))
                            .foregroundStyle(KillXTheme.accent)
                        Text("No excluded ports")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Text("Use a port's ••• menu in the KillX popover or click Add Ports below.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Button {
                            state.toggleAll(configStore.config.excludePorts)
                        } label: {
                            HStack(spacing: 8) {
                                KillXSelectionCheckbox(
                                    isSelected: state.allSelected(configStore.config.excludePorts),
                                    isPartial: state.partiallySelected(configStore.config.excludePorts)
                                )
                                Text(state.allSelected(configStore.config.excludePorts) ? "Deselect All" : "Select All")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(configStore.config.excludePorts.count) excluded")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 27)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 2) {
                                ForEach(configStore.config.excludePorts, id: \.self) { port in
                                    ExcludedPortRow(
                                        port: port,
                                        isSelected: state.selectedPorts.contains(port),
                                        onToggle: {
                                            state.toggle(port)
                                        },
                                        onRemove: {
                                            state.pendingRemoval = ExcludeRemovalRequest(
                                                ports: [port],
                                                totalCount: configStore.config.excludePorts.count
                                            )
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KillXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )

            HStack {
                Button {
                    ExcludePortPickerWindowController.shared.show()
                } label: {
                    Label("Add Ports…", systemImage: "plus")
                }

                Spacer()

                Button(removeButtonTitle) {
                    let ports = configStore.config.excludePorts.filter {
                        state.selectedPorts.contains($0)
                    }
                    state.pendingRemoval = ExcludeRemovalRequest(
                        ports: ports,
                        totalCount: configStore.config.excludePorts.count
                    )
                }
                .disabled(state.selectedPorts.isEmpty)
            }
            .font(.system(size: 11.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 480, height: 306, alignment: .topLeading)
        .background(KillXTheme.paneBackground)
        .overlay {
            if let request = state.pendingRemoval {
                KillConfirmationOverlay(
                    title: request.title,
                    subtitle: request.message,
                    confirmTitle: request.removesAll ? "Remove All" : "Remove",
                    systemImage: "trash.fill",
                    isForced: false,
                    cardWidth: 260,
                    onConfirm: {
                        configStore.removeExcludedPorts(Set(request.ports))
                        state.selectedPorts.removeAll()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.pendingRemoval = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.pendingRemoval = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state.pendingRemoval != nil)
    }

    private var removeButtonTitle: String {
        if state.allSelected(configStore.config.excludePorts) {
            return "Remove All"
        }
        if state.selectedPorts.count > 1 {
            return "Remove Selected (\(state.selectedPorts.count))"
        }
        return "Remove Selected"
    }
}

final class ExcludeTabState: ObservableObject {
    @Published var pendingRemoval: ExcludeRemovalRequest?
    @Published var selectedPorts: Set<Int> = []

    func toggle(_ port: Int) {
        if selectedPorts.contains(port) {
            selectedPorts.remove(port)
        } else {
            selectedPorts.insert(port)
        }
    }

    func allSelected(_ ports: [Int]) -> Bool {
        let all = Set(ports)
        return !all.isEmpty && all.isSubset(of: selectedPorts)
    }

    func partiallySelected(_ ports: [Int]) -> Bool {
        let all = Set(ports)
        let intersection = selectedPorts.intersection(all)
        return !intersection.isEmpty && intersection.count < all.count
    }

    func toggleAll(_ ports: [Int]) {
        let all = Set(ports)
        if all.isSubset(of: selectedPorts) {
            selectedPorts.subtract(all)
        } else {
            selectedPorts.formUnion(all)
        }
    }
}

struct ExcludeRemovalRequest: Identifiable {
    let ports: [Int]
    let removesAll: Bool
    let displayName: String

    var id: String { ports.map(String.init).sorted().joined(separator: "|") }

    var title: String {
        if removesAll {
            return "Remove all excluded ports?"
        }
        if ports.count == 1 {
            return "Remove Port :\(ports[0])?"
        }
        return "Remove \(ports.count) excluded ports?"
    }

    var message: String {
        if removesAll {
            return "All ports will no longer be protected and will appear in KillX."
        }
        if ports.count == 1 {
            return "Port :\(ports[0]) will no longer be protected and will appear in KillX."
        }
        return "These \(ports.count) ports will no longer be protected and will appear in KillX."
    }

    init(ports: [Int], totalCount: Int) {
        self.ports = ports
        self.removesAll = !ports.isEmpty && ports.count == totalCount
        if ports.count == 1 {
            self.displayName = ":\(ports[0])"
        } else {
            self.displayName = ""
        }
    }
}

private struct ExcludedPortRow: View {
    let port: Int
    let isSelected: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @StateObject private var state: ExcludedPortRowState

    init(port: Int, isSelected: Bool, onToggle: @escaping () -> Void, onRemove: @escaping () -> Void) {
        self.port = port
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onRemove = onRemove
        _state = StateObject(wrappedValue: ExcludedPortRowState(port: port))
    }

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onToggle) {
                KillXSelectionCheckbox(isSelected: isSelected)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if let active = state.activePort {
                    AppIconView(bundleId: active.appBundleId, pid: active.pid, size: 18, cornerRadius: 3.5)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(KillXTheme.accent.opacity(0.12))
                        Image(systemName: "network")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(KillXTheme.accent)
                    }
                    .frame(width: 18, height: 18)
                }

                Text(verbatim: ":\(port)")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .foregroundStyle(Color.primary)

                Text(state.displayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(state.isRemoveHovered ? Color.red : Color.secondary.opacity(state.isHovered ? 0.75 : 0.35))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(state.isRemoveHovered ? Color.red.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Remove :\(port) from exclusions")
            .onHover { state.isRemoveHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { state.isHovered = $0 }
    }
}

@MainActor
private final class ExcludedPortRowState: ObservableObject {
    @Published var isHovered = false
    @Published var isRemoveHovered = false
    let port: Int
    let activePort: PortInfo?
    let displayName: String

    init(port: Int) {
        self.port = port
        let active = AppListViewModel.shared.ports.first(where: { $0.port == port })
        self.activePort = active
        if let active {
            self.displayName = active.displayAppName
        } else {
            self.displayName = "Port \(port)"
        }
    }
}
