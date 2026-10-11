import AppKit
import SwiftUI

@MainActor
final class ExcludePortPickerViewModel: ObservableObject {
    @Published private(set) var availablePorts: [PortInfo] = []
    @Published private(set) var isLoading = true
    @Published var selectedPorts: Set<Int> = []
    @Published var searchQuery = ""

    private var hasLoaded = false

    var typedCustomPort: Int? {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let p = Int(trimmed), p >= 1, p <= 65535 else { return nil }
        return p
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        let scanned = await PortService.shared.fetchListeningPorts()
        let nonSystem = scanned.filter { !$0.isSystemProtected }
        availablePorts = nonSystem
        isLoading = false
    }

    func toggle(_ port: Int) {
        if selectedPorts.contains(port) {
            selectedPorts.remove(port)
        } else {
            selectedPorts.insert(port)
        }
    }

    func selectionState(for ports: [PortInfo]) -> (isAll: Bool, isPartial: Bool) {
        guard !ports.isEmpty else { return (false, false) }
        var selectedCount = 0
        for p in ports {
            if selectedPorts.contains(p.port) {
                selectedCount += 1
            }
        }
        if selectedCount == 0 {
            return (false, false)
        } else if selectedCount == ports.count {
            return (true, false)
        } else {
            return (false, true)
        }
    }

    func isAllSelected(for ports: [PortInfo]) -> Bool {
        selectionState(for: ports).isAll
    }

    func isPartiallySelected(for ports: [PortInfo]) -> Bool {
        selectionState(for: ports).isPartial
    }

    func toggleSelectAll(for ports: [PortInfo]) {
        if isAllSelected(for: ports) {
            for p in ports {
                selectedPorts.remove(p.port)
            }
        } else {
            for p in ports {
                selectedPorts.insert(p.port)
            }
        }
    }

    func addSingleCustomPort(_ port: Int, configStore: ConfigStore) {
        _ = configStore.addExcludedPorts([port])
    }
}

@MainActor
final class ExcludePortPickerWindowController: NSObject, NSWindowDelegate {
    static let shared = ExcludePortPickerWindowController()
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func show() {
        if let window {
            if let screen = WindowPositioner.targetScreen {
                window.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: window.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(window)
            return
        }

        let view = ExcludePortPickerView { [weak self] in
            self?.close()
        }
        .environmentObject(ConfigStore.shared)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 480, height: 480))
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.animationBehavior = .none
        window.delegate = self

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: window.frame.size, on: screen)
        } else {
            window.center()
            targetFrame = window.frame
        }

        self.window = window
        WindowActivationCoordinator.update()
        WindowAnimator.present(window, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}

struct ExcludePortPickerView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var viewModel = ExcludePortPickerViewModel()
    let onClose: () -> Void

    private var visiblePorts: [PortInfo] {
        let excluded = Set(configStore.config.excludePorts)
        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.availablePorts.filter { port in
            guard !excluded.contains(port.port) else { return false }
            guard !query.isEmpty else { return true }
            return "\(port.port)".contains(query)
                || port.displayAppName.lowercased().contains(query)
                || port.processName.lowercased().contains(query)
                || port.command.lowercased().contains(query)
                || (port.docker?.name.lowercased().contains(query) == true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            controls
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Group {
                if viewModel.isLoading {
                    PortsSkeletonView()
                } else if visiblePorts.isEmpty {
                    emptyView
                } else {
                    portList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KillXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                KillXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        Text("Add Ports to Exclude List")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(KillXTheme.paneBackground)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                TextField("Search active ports or enter port number", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .disableInitialFocus()
                    .onSubmit {
                        if let customPort = viewModel.typedCustomPort {
                            viewModel.addSingleCustomPort(customPort, configStore: configStore)
                            onClose()
                        }
                    }
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))

            if let customPort = viewModel.typedCustomPort {
                Button("Add :\(customPort)") {
                    viewModel.addSingleCustomPort(customPort, configStore: configStore)
                    onClose()
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.88))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(KillXTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
        }
    }

    private var portList: some View {
        let ports = visiblePorts
        let state = viewModel.selectionState(for: ports)
        return VStack(spacing: 0) {
            Button {
                viewModel.toggleSelectAll(for: ports)
            } label: {
                HStack(spacing: 8) {
                    KillXSelectionCheckbox(
                        isSelected: state.isAll,
                        isPartial: state.isPartial
                    )
                    Text(state.isAll ? "Deselect All" : "Select All")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Text("\(ports.count) ports")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .frame(height: 27)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(ports) { port in
                        Button {
                            viewModel.toggle(port.port)
                        } label: {
                            AvailablePortPickerRow(
                                port: port,
                                isSelected: viewModel.selectedPorts.contains(port.port)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.searchQuery.isEmpty ? "checkmark.circle" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(KillXTheme.accent)
            Text(viewModel.searchQuery.isEmpty ? "No active ports available" : "No matching ports")
                .font(.system(size: 13, weight: .medium))
            Text(viewModel.searchQuery.isEmpty ? "All active listening ports are already excluded." : "Enter a port number above to exclude it.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(viewModel.selectedPorts.count) selected")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)

            Spacer()

            Button("Cancel", action: onClose)
                .keyboardShortcut(.cancelAction)

            Button(viewModel.selectedPorts.count == 1 ? "Add Port" : "Add Ports") {
                _ = configStore.addExcludedPorts(Array(viewModel.selectedPorts))
                onClose()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.selectedPorts.isEmpty)
        }
        .font(.system(size: 11.5))
    }
}

private struct AvailablePortPickerRow: View {
    let port: PortInfo
    let isSelected: Bool
    @StateObject private var state = AvailablePortPickerRowState()

    var body: some View {
        HStack(spacing: 8) {
            KillXSelectionCheckbox(isSelected: isSelected)

            AppIconView(bundleId: port.appBundleId, pid: port.pid, size: 18, cornerRadius: 3.5)

            Text(verbatim: ":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.8)
                .background(
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(Color.primary.opacity(0.08))
                )
                .foregroundStyle(Color.primary)

            Text(port.displayAppName)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if let docker = port.docker {
                Text(docker.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { state.isHovered = $0 }
    }
}

private final class AvailablePortPickerRowState: ObservableObject {
    @Published var isHovered = false
}

private struct PortsSkeletonView: View {
    @StateObject private var state = PortsSkeletonState()

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { index in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).frame(width: 14, height: 14)
                    RoundedRectangle(cornerRadius: 4).frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 3).frame(width: 45, height: 14)
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: CGFloat(90 + ((index % 3) * 24)), height: 10)
                    Spacer()
                }
                .foregroundStyle(Color.primary.opacity(state.isBright ? 0.12 : 0.055))
                .padding(.horizontal, 8)
                .frame(height: 29)
            }
            Spacer(minLength: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                state.isBright = true
            }
        }
    }
}

private final class PortsSkeletonState: ObservableObject {
    @Published var isBright = false
}
