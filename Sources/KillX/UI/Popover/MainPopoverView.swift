import SwiftUI
import AppKit

private final class PopoverUIState: ObservableObject {
    @Published var isActionButtonHovered = false
    var cachedOptionsMenu: NSMenu? = nil
    var cachedFilterMode: PortFilterMode? = nil
}

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared
    @StateObject private var uiState = PopoverUIState()

    private static let goldColor = QuitXTheme.accent
    private static let goldGradient = LinearGradient(
        colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)],
        startPoint: .top,
        endPoint: .bottom
    )
    private static let forceGradient = LinearGradient(
        colors: [Color.red, Color(red: 210/255, green: 40/255, blue: 40/255)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)

            filterSwitcher
                .padding(.horizontal, 8)
                .padding(.top, 5)
                .padding(.bottom, 4)

            primaryActionButton
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            searchBarRow
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            if vm.isLoading && vm.ports.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if vm.filteredPorts.isEmpty {
                emptyPortsView
                    .frame(maxHeight: .infinity)
            } else {
                PortListView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)

            footerRow
                .padding(.horizontal, 10)
                .padding(.top, 3)
                .padding(.bottom, 6)
        }
        .frame(width: StatusItemController.popoverWidth)
        .frame(minHeight: 220)
        .frame(maxHeight: .infinity)
        .arrowPopoverChrome(arrowX: vm.arrowX, classicBackground: AnyView(QuitXTheme.popoverBackground))
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView(
                    message: vm.toastMessage,
                    isError: vm.toastIsError
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 36)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showToast)
        .overlay {
            if let req = vm.pendingKillConfirmation {
                QuitConfirmationOverlay(
                    title: req.title,
                    subtitle: req.message,
                    confirmTitle: req.confirmButtonTitle,
                    systemImage: req.isForced ? "bolt.trianglebadge.exclamationmark.fill" : "questionmark.circle.fill",
                    isForced: req.isForced,
                    onConfirm: {
                        let action = req.action
                        vm.pendingKillConfirmation = nil
                        Task { await action() }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.pendingKillConfirmation = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: vm.pendingKillConfirmation != nil)
        .clipShape(popoverShape(arrowX: vm.arrowX))
        .onChange(of: vm.visibleCount) {
            StatusItemController.shared?.updatePopoverSize()
        }
        .onChange(of: vm.filterMode) {
            StatusItemController.shared?.updatePopoverSize()
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
                            .background(isSelected ? Self.goldColor.opacity(0.3) : Color.primary.opacity(0.08))
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
                if vm.isBatchKilling {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.black.opacity(0.88))
                        .scaleEffect(0.65)
                    Text("Killing…")
                        .font(.system(size: 12, weight: .bold))
                } else if isForced {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                }
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
                    ? (isForced ? Self.forceGradient : Self.goldGradient)
                    : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(
                color: isEnabled
                    ? (isForced ? Color.red.opacity(uiState.isActionButtonHovered ? 0.35 : 0.15) : Self.goldColor.opacity(uiState.isActionButtonHovered ? 0.3 : 0.12))
                    : Color.clear,
                radius: 2,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || vm.isBatchKilling)
        .onHover { uiState.isActionButtonHovered = $0 }
    }

    // MARK: - Search Bar & Select All

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            Button {
                vm.toggleSelectAll()
            } label: {
                QuitXSelectionCheckbox(
                    isSelected: vm.isAllSelected,
                    isPartial: vm.isPartiallySelected
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(vm.isAllSelected ? "Deselect All" : "Select All")

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                TextField("", text: $vm.searchQuery, prompt: Text("Search port or process").foregroundColor(Color.secondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primary)
                    .disableInitialFocus()

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
                .font(.system(size: 32))
                .foregroundStyle(Self.goldColor)
            Text(vm.searchQuery.isEmpty ? "All clean! No active listening ports." : "No ports match '\(vm.searchQuery)'")
                .font(.system(size: 12.5))
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
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            QuitXMenuButton(
                assetName: "settings",
                selectedAssetName: "settings-selected",
                systemSymbolName: "gearshape",
                symbolPointSize: 13,
                size: NSSize(width: 17, height: 17),
                toolTip: "Options",
                menu: {
                    optionsMenu()
                }
            )
            .frame(width: 22, height: 22)
            .layoutPriority(2)
        }
    }

    private func buildOptionsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(MenuHelper.makeItem(
            title: "Sweep Dev Servers",
            keyEquivalent: "d",
            systemSymbolName: "arrow.triangle.branch",
            action: {
                vm.confirmAndSweepDevServers()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Refresh Ports",
            keyEquivalent: "r",
            systemSymbolName: "arrow.clockwise",
            action: {
                Task { await vm.refresh() }
            }
        ))

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Settings",
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape",
            action: {
                StatusItemController.shared?.closePopover()
                SettingsWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Welcome Guide",
            systemSymbolName: "hand.wave",
            action: {
                StatusItemController.shared?.closePopover()
                WelcomeWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Help",
            keyEquivalent: "?",
            assetName: "settings-help",
            systemSymbolName: "questionmark.circle",
            action: {
                StatusItemController.shared?.closePopover()
                HelpWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Check for Updates",
            keyEquivalent: "u",
            systemSymbolName: "arrow.triangle.2.circlepath",
            action: {
                StatusItemController.shared?.closePopover()
                Task {
                    await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
                }
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "About",
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle",
            action: {
                StatusItemController.shared?.closePopover()
                SettingsWindowController.shared.show(tab: .about)
            }
        ))

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit",
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power",
            action: {
                NSApplication.shared.terminate(nil)
            }
        ))

        return menu
    }

    private func optionsMenu() -> NSMenu {
        if let menu = uiState.cachedOptionsMenu,
           uiState.cachedFilterMode == vm.filterMode {
            return menu
        }
        let menu = buildOptionsMenu()
        uiState.cachedOptionsMenu = menu
        uiState.cachedFilterMode = vm.filterMode
        return menu
    }
}
