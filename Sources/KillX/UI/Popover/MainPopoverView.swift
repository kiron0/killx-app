import SwiftUI
import AppKit

private final class PopoverUIState: ObservableObject {
    @Published var isActionButtonHovered = false
}

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared
    @StateObject private var uiState = PopoverUIState()
    @FocusState private var isSearchFocused: Bool

    private let accentColor = KillXTheme.accent
    private let accentGradient = LinearGradient(
        colors: [KillXTheme.accent, KillXTheme.accentLight],
        startPoint: .top,
        endPoint: .bottom
    )
    private let forceGradient = LinearGradient(
        colors: [Color(red: 240/255, green: 70/255, blue: 50/255), Color(red: 210/255, green: 40/255, blue: 30/255)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 0) {
            // Filter mode: All Ports | Dev Servers
            filterSwitcher
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)

            // Primary action button
            primaryActionButton
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            // Search bar & select all toggle
            searchBarRow
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            // Main Content Area
            if vm.isTracingTree {
                ProcessTraceView(vm: vm)
            } else if vm.isLoading && vm.ports.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if vm.filteredPorts.isEmpty {
                emptyPortsView
            } else if vm.listNeedsScrolling {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 2) {
                        ForEach(vm.filteredPorts) { port in
                            PortRowView(port: port, vm: vm)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                VStack(spacing: 2) {
                    ForEach(vm.filteredPorts) { port in
                        PortRowView(port: port, vm: vm)
                    }
                }
                .padding(.vertical, 2)
                .fixedSize(horizontal: false, vertical: true)
            }

            footerRow
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(KillXTheme.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear {
            isSearchFocused = false
        }
        .onChange(of: vm.visibleCount) {
            StatusItemController.shared?.updatePopoverSize()
        }
        .onChange(of: vm.filterMode) {
            StatusItemController.shared?.updatePopoverSize()
        }
        .onChange(of: vm.pendingKillConfirmation != nil) {
            StatusItemController.shared?.updatePopoverSize()
        }
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView(count: vm.lastQuitCount, message: vm.lastActionMessage.isEmpty ? nil : vm.lastActionMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 36)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showToast)
        .alert(
            vm.pendingKillConfirmation?.title ?? "Kill Process?",
            isPresented: Binding(
                get: { vm.pendingKillConfirmation != nil },
                set: { if !$0 { vm.pendingKillConfirmation = nil } }
            ),
            presenting: vm.pendingKillConfirmation
        ) { req in
            Button(req.confirmButtonTitle, role: .destructive) {
                let action = req.action
                vm.pendingKillConfirmation = nil
                Task {
                    await action()
                }
            }
            Button("Cancel", role: .cancel) {
                vm.pendingKillConfirmation = nil
            }
        } message: { req in
            Text(req.message)
        }
    }

    // MARK: - Filter Switcher

    private var filterSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(PortFilterMode.allCases) { mode in
                let isSelected = vm.filterMode == mode
                let count: Int = {
                    switch mode {
                    case .all: return vm.ports.count
                    case .dev: return vm.ports.filter(\.isDevServer).count
                    }
                }()

                Button {
                    vm.filterMode = mode
                    StatusItemController.shared?.updatePopoverSize()
                } label: {
                    HStack(spacing: 4) {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        Text("\(count)")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? accentColor.opacity(0.3) : Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? Color(NSColor.textBackgroundColor).opacity(0.85) : Color.clear)
                    )
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.06))
        )
    }

    // MARK: - Primary Action Button

    private var primaryActionButton: some View {
        let isForced = vm.isOptionKeyPressed || configStore.config.force == .force
        let selectedCount = vm.selectedPorts.count

        let (title, isEnabled, action): (String, Bool, () -> Void) = {
            if selectedCount > 0 {
                let text = isForced ? "Force Kill Selected (\(selectedCount))" : "Kill Selected Ports (\(selectedCount))"
                return (text, true, {
                    vm.confirmAndKillSelectedPorts(force: isForced, tree: configStore.config.treeKillByDefault)
                })
            } else if vm.filterMode == .dev {
                let devCount = vm.ports.filter(\.isDevServer).count
                let text = isForced ? "Force Sweep Dev Servers (\(devCount))" : "Sweep Dev Servers (\(devCount))"
                return (text, devCount > 0, {
                    vm.confirmAndSweepDevServers(force: isForced)
                })
            } else {
                let devCount = vm.ports.filter(\.isDevServer).count
                let text = devCount > 0 ? (isForced ? "Force Kill Dev Ports (\(devCount))" : "Kill Dev Ports (\(devCount))") : "Kill Selected Ports"
                return (text, devCount > 0, {
                    vm.confirmAndSweepDevServers(force: isForced)
                })
            }
        }()

        return Button {
            action()
        } label: {
            HStack(spacing: 5) {
                if isForced {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(
                isEnabled
                    ? (isForced ? Color.white : Color.black.opacity(0.88))
                    : Color.primary.opacity(0.35)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isEnabled
                    ? (isForced ? forceGradient : accentGradient)
                    : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(
                color: isEnabled ? (isForced ? Color.red.opacity(0.3) : accentColor.opacity(uiState.isActionButtonHovered ? 0.3 : 0.12)) : Color.clear,
                radius: 2,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { uiState.isActionButtonHovered = $0 }
    }

    // MARK: - Search Bar & Select All

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            Button {
                vm.toggleSelectAll()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(vm.isAllSelected || vm.isPartiallySelected ? accentColor : Color.primary.opacity(0.08))
                        .frame(width: 14, height: 14)

                    if vm.isAllSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.9))
                    } else if vm.isPartiallySelected {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.9))
                            .frame(width: 6, height: 2)
                    }
                }
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(vm.isAllSelected ? "Deselect All" : "Select All")

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                TextField("", text: $vm.searchQuery, prompt: Text("Search port or process").foregroundColor(Color.secondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primary)
                    .focused($isSearchFocused)

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Empty State

    private var emptyPortsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(accentColor)
            Text(vm.searchQuery.isEmpty ? "All clean! No active listening ports." : "No ports match '\(vm.searchQuery)'")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            if !configStore.config.disableTips {
                Text(vm.currentQuote)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            PopoverOptionsButton(
                onSweepDev: { vm.confirmAndSweepDevServers() },
                onRefresh: { Task { await vm.refresh() } }
            )
            .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Popover Options Menu Button

private struct PopoverOptionsButton: NSViewRepresentable {
    var onSweepDev: () -> Void
    var onRefresh: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        if let img = AssetImages.load("settings") {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 17, height: 17)
            copy.isTemplate = true
            button.image = copy
            button.imagePosition = .imageOnly
        } else if let sym = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Options") {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let copy = (sym.withSymbolConfiguration(config) ?? sym).copy() as? NSImage ?? sym
            copy.size = NSSize(width: 17, height: 17)
            copy.isTemplate = true
            button.image = copy
            button.imagePosition = .imageOnly
        }
        button.contentTintColor = NSColor.secondaryLabelColor
        button.toolTip = "Options"
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PopoverOptionsButton

        init(parent: PopoverOptionsButton) {
            self.parent = parent
        }

        @objc func showMenu(_ button: NSButton) {
            let menu = NSMenu()
            menu.appearance = NSApp.effectiveAppearance

            menu.addItem(MenuHelper.makeItem(
                title: "Sweep Dev Servers",
                action: #selector(sweepDev),
                target: self,
                keyEquivalent: "d",
                systemSymbolName: "arrow.triangle.branch"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Refresh Ports",
                action: #selector(refresh),
                target: self,
                keyEquivalent: "r",
                systemSymbolName: "arrow.clockwise"
            ))

            menu.addItem(.separator())

            menu.addItem(MenuHelper.makeItem(
                title: "Settings",
                action: #selector(openSettings),
                target: self,
                keyEquivalent: ",",
                assetName: "settings-preferences",
                systemSymbolName: "gearshape"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Help & Docs",
                action: #selector(openHelp),
                target: self,
                keyEquivalent: "h",
                assetName: "settings-help",
                systemSymbolName: "questionmark.circle"
            ))

            menu.addItem(.separator())

            menu.addItem(MenuHelper.makeItem(
                title: "Quit KillX",
                action: #selector(quitApp),
                target: self,
                keyEquivalent: "q",
                assetName: "settings-quit",
                systemSymbolName: "power"
            ))

            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.maxX, y: button.bounds.minY), in: button)
        }

        @objc private func sweepDev() { parent.onSweepDev() }
        @objc private func refresh() { parent.onRefresh() }

        @objc private func openSettings() {
            StatusItemController.shared?.closePopover()
            SettingsWindowController.shared.show()
        }

        @objc private func openHelp() {
            StatusItemController.shared?.closePopover()
            guard let url = URL(string: "https://killx.js.org") else { return }
            NSWorkspace.shared.open(url)
        }

        @objc private func quitApp() {
            NSApplication.shared.terminate(nil)
        }
    }
}
