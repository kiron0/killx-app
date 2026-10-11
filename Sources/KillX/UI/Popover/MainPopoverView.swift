import SwiftUI
import AppKit

private final class PopoverUIState: ObservableObject {
    @Published var isActionButtonHovered = false
    var cachedOptionsMenu: NSMenu? = nil
}

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared
    @StateObject private var uiState = PopoverUIState()

    private static let accentColor = KillXTheme.accent
    private static let accentGradient = KillXTheme.accentGradient
    private static let forceGradient = KillXTheme.forceGradient
    private static let forceColor = KillXTheme.forceColor

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)

            primaryActionButton
                .padding(.horizontal, 8)
                .padding(.top, 4)
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
        .arrowPopoverChrome(arrowX: vm.arrowX, classicBackground: AnyView(KillXTheme.popoverBackground))
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
                KillConfirmationOverlay(
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
        .tint(Self.accentColor)
        .accentColor(Self.accentColor)
        .onChange(of: vm.visibleCount) {
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    private var primaryActionButton: some View {
        let isForced = vm.isOptionKeyPressed || configStore.config.force == .force
        let selectedCount = vm.selectedPorts.count

        let (title, isEnabled, action): (String, Bool, () -> Void) = {
            if selectedCount > 0 {
                let text = isForced ? "Force Kill Selected (\(selectedCount))" : "Kill Selected Ports (\(selectedCount))"
                return (text, true, {
                    vm.confirmAndKillSelectedPorts(force: isForced, tree: configStore.config.treeKillByDefault)
                })
            } else {
                let text = isForced ? "Force Kill Selected Ports" : "Kill Selected Ports"
                return (text, false, {})
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
                    ? Color.white
                    : Color.primary.opacity(0.35)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isEnabled
                    ? (isForced ? Self.forceGradient : Self.accentGradient)
                    : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(
                color: isEnabled
                    ? (isForced ? Self.forceColor.opacity(uiState.isActionButtonHovered ? 0.35 : 0.15) : Self.accentColor.opacity(uiState.isActionButtonHovered ? 0.3 : 0.12))
                    : Color.clear,
                radius: 2,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || vm.isBatchKilling)
        .onHover { uiState.isActionButtonHovered = $0 }
    }

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            Button {
                vm.toggleSelectAll()
            } label: {
                KillXSelectionCheckbox(
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

    private var emptyPortsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Self.accentColor)
            Text(vm.searchQuery.isEmpty ? "All clean! No active listening ports." : "No ports match '\(vm.searchQuery)'")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

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

            KillXMenuButton(
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
        if let menu = uiState.cachedOptionsMenu {
            return menu
        }
        let menu = buildOptionsMenu()
        uiState.cachedOptionsMenu = menu
        return menu
    }
}
