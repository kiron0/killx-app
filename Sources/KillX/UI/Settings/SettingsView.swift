import SwiftUI
import AppKit
import Combine

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case monitoring = "Monitoring"
    case exclude = "Exclude"
    case shortcuts = "Shortcuts"
    case about = "About"

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }

    var iconName: String {
        switch self {
        case .general:   return "preferences-general"
        case .monitoring: return "preferences-monitoring"
        case .exclude:   return "preferences-exclude"
        case .shortcuts: return "preferences-shortcuts"
        case .about:     return "preferences-about"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .general:   return "gearshape"
        case .monitoring: return "waveform.path.ecg"
        case .exclude:   return "nosign"
        case .shortcuts: return "command"
        case .about:     return "bolt.horizontal.fill"
        }
    }

    var toolbarImage: NSImage? {
        if let img = AssetImages.load(iconName) {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 19, height: 19)
            copy.isTemplate = true
            return copy
        }
        let sym = NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: rawValue)
        let copy = sym?.copy() as? NSImage
        copy?.size = NSSize(width: 19, height: 19)
        copy?.isTemplate = true
        return copy ?? sym
    }

    var contentHeight: CGFloat {
        switch self {
        case .general:
            if #available(macOS 26.0, *) { return 266 }
            return 236
        case .monitoring: return 146
        case .exclude:   return 306
        case .shortcuts: return 221
        case .about:     return 186
        }
    }
}

final class HelpPopoverState: NSObject, ObservableObject {
    private static var activeStates = NSHashTable<HelpPopoverState>.weakObjects()

    @Published var isShowing = false
    @Published var isHovered = false
    weak var anchorView: NSView?
    private var window: ArrowPopoverWindow?
    private var dismissObserver: AnyCancellable?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    static func closeAll() {
        for state in activeStates.allObjects { state.close() }
    }

    override init() {
        super.init()
        dismissObserver = NotificationCenter.default.publisher(for: KillXConstants.Notifications.dismissSettingsTooltips)
            .sink { [weak self] notification in
                guard let self else { return }
                if let obj = notification.object as? NSObject, obj === self { return }
                self.close()
            }
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        window?.orderOut(nil)
    }

    func toggle(text: String) {
        if isShowing { close() } else { show(text: text) }
    }

    func hide() { close() }

    private func close() {
        if isShowing {
            window?.orderOut(nil)
            isShowing = false
            isHovered = false
            Self.activeStates.remove(self)
        }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
    }

    private func show(text: String) {
        guard let anchor = anchorView, let anchorWindow = anchor.window else { return }
        NotificationCenter.default.post(name: KillXConstants.Notifications.dismissSettingsTooltips, object: self)

        let anchorScreenRect = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let hostView = NSHostingView(rootView: HelpPopoverContentView(text: text))
        let size = hostView.fittingSize

        var originX = anchorScreenRect.midX - size.width / 2
        if let screen = anchorWindow.screen ?? NSScreen.main {
            originX = max(screen.visibleFrame.minX + 4, min(originX, screen.visibleFrame.maxX - size.width - 4))
        }
        let originY = anchorScreenRect.minY - size.height - 2
        let arrowX = anchorScreenRect.midX - originX
        hostView.rootView = HelpPopoverContentView(text: text, arrowX: arrowX)

        let win: ArrowPopoverWindow
        if let existing = window {
            win = existing
        } else {
            let created = ArrowPopoverWindow()
            window = created
            win = created
        }
        win.contentView = hostView
        win.setContentSize(size)
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.invalidateShadow()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.isShowing else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
                return event
            }
            guard let anchor = self.anchorView, let anchorWindow = anchor.window else {
                self.close()
                return event
            }
            guard event.window === anchorWindow else {
                self.close()
                return event
            }
            let onAnchor: Bool
            if let superview = anchor.superview {
                let point = superview.convert(event.locationInWindow, from: nil)
                onAnchor = anchor.frame.contains(point)
            } else {
                onAnchor = false
            }
            self.close()
            return onAnchor ? nil : event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        isShowing = true
        Self.activeStates.add(self)
    }
}

private struct HelpPopoverContentView: View {
    let text: String
    var arrowX: CGFloat? = nil

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primary)
                .lineSpacing(2.5)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(width: 230)
        }
        .arrowPopoverChrome(arrowX: arrowX, classicBackground: AnyView(KillXTheme.popoverBackground))
    }
}

private struct PopoverAnchorView: NSViewRepresentable {
    var onResolve: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView) }
    }
}

struct HelpPopoverButton: View {
    let text: String
    @StateObject private var state = HelpPopoverState()

    var body: some View {
        Button {
            state.toggle(text: text)
        } label: {
            let isActive = state.isShowing || state.isHovered
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? KillXTheme.accent : Color.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in state.isHovered = h }
        .onDisappear {
            state.hide()
        }
        .background(PopoverAnchorView { state.anchorView = $0 })
    }
}

final class SettingsTabViewModel: ObservableObject {
    @Published var activeTab: SettingsTab = .general
    @Published var glassTopInset: CGFloat = 0
}

struct SettingsContainerView: View {
    @ObservedObject var tabModel: SettingsTabViewModel
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        ZStack(alignment: .top) {
            switch tabModel.activeTab {
            case .general:
                GeneralTabCloneView()
                    .environmentObject(configStore)
            case .monitoring:
                MonitoringTabView()
                    .environmentObject(configStore)
            case .exclude:
                ExcludeTabView()
                    .environmentObject(configStore)
            case .shortcuts:
                ShortcutsTabCloneView()
            case .about:
                AboutTabCloneView()
            }
        }
        .frame(width: 480, height: tabModel.activeTab.contentHeight, alignment: .top)
        .overlay(alignment: .top) {
            if LiquidGlass.enabled {
                Color.primary.opacity(0.12)
                    .frame(height: 0.5)
            }
        }
        .background {
            if LiquidGlass.enabled {
                ZStack(alignment: .top) {
                    LiquidGlassFill(shape: Rectangle())
                    if tabModel.glassTopInset > 0 {
                        KillXTheme.cardBackground
                            .frame(height: tabModel.glassTopInset)
                    }
                }
                .ignoresSafeArea()
            } else {
                KillXTheme.windowBackground
            }
        }
        .onChange(of: tabModel.activeTab) { _, _ in
            HelpPopoverState.closeAll()
            NotificationCenter.default.post(name: KillXConstants.Notifications.dismissSettingsTooltips, object: nil)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var tabModel = SettingsTabViewModel()

    var body: some View {
        SettingsContainerView(tabModel: tabModel)
            .environmentObject(configStore)
    }
}

fileprivate func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
    Button {
        isOn.wrappedValue.toggle()
    } label: {
        HStack(spacing: 8) {
            KillXSelectionCheckbox(isSelected: isOn.wrappedValue)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
        }
    }
    .buttonStyle(.plain)
}

fileprivate func appearanceRadio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(
                        selected ? KillXTheme.accent : Color.secondary.opacity(0.5),
                        lineWidth: 1.5
                    )
                    .frame(width: 14, height: 14)
                if selected {
                    Circle()
                        .fill(KillXTheme.accent)
                        .frame(width: 7, height: 7)
                }
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

fileprivate let labelColumnWidth: CGFloat = 90

fileprivate func row<Content: View, Help: View>(
    label: String,
    @ViewBuilder content: () -> Content,
    @ViewBuilder help: () -> Help
) -> some View {
    HStack(alignment: .center, spacing: 10) {
        Text(label)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color.primary)
            .frame(width: labelColumnWidth, alignment: .trailing)

        content().fixedSize()

        Spacer(minLength: 0)

        help()
    }
    .frame(height: 25)
}

final class GeneralTabViewState: ObservableObject {
    @Published var showResetConfirmation = false
}

struct GeneralTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared
    @StateObject private var viewState = GeneralTabViewState()

    private var tabHeight: CGFloat {
        SettingsTab.general.contentHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            row(label: "Startup:") {
                toggle("Open KillX at login", isOn: $launchService.isEnabled)
            } help: {
                HelpPopoverButton(text: "Launch KillX automatically in your menu bar when you start your Mac.")
            }

            row(label: "Sounds:") {
                toggle("Play audio effects", isOn: Binding(
                    get: { configStore.config.playSounds },
                    set: { configStore.config.playSounds = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Play a crisp sound whenever ports or dev processes are terminated. 👾⚡")
            }

            row(label: "Safety:") {
                toggle("Confirm before killing ports", isOn: Binding(
                    get: { configStore.config.confirmKill },
                    set: { configStore.config.confirmKill = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Show a confirmation prompt before terminating ports.")
            }

            row(label: "Selection:") {
                toggle("Deselect ports by default", isOn: Binding(
                    get: { !configStore.config.defaultSelectAll },
                    set: {
                        configStore.config.defaultSelectAll = !$0
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Keep port list unselected on refresh instead of selecting everything.")
            }

            row(label: "Footer:") {
                toggle("Disable tips in footer", isOn: Binding(
                    get: { configStore.config.disableTips },
                    set: { configStore.config.disableTips = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Hide the rotating tips at the bottom of the KillX popover.")
            }

            if #available(macOS 26.0, *) {
                row(label: "Appearance:") {
                    HStack(spacing: 18) {
                        appearanceRadio("Classic", selected: !configStore.config.liquidGlassEnabled) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                configStore.config.liquidGlassEnabled = false
                            }
                            SettingsWindowController.shared.applyWindowChrome()
                            configStore.save()
                        }
                        appearanceRadio("Liquid Glass", selected: configStore.config.liquidGlassEnabled) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                configStore.config.liquidGlassEnabled = true
                            }
                            SettingsWindowController.shared.applyWindowChrome()
                            configStore.save()
                        }
                    }
                    .fixedSize()
                } help: {
                    HelpPopoverButton(text: "Classic retro solidity or futuristic translucent Liquid Glass drip. Dress your windows for success. 🔮🪞")
                }
            }

            row(label: "Sort by:") {
                Picker("", selection: Binding(
                    get: { configStore.config.sortBy },
                    set: { configStore.config.sortBy = $0; configStore.save() }
                )) {
                    ForEach(KillXConfig.SortBy.allCases, id: \.self) { sortOpt in
                        Text(sortOpt.rawValue).tag(sortOpt)
                    }
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Sort listening ports by port number, process name, memory, or CPU.")
            }

            row(label: "Reset:") {
                Button("Reset all") {
                    viewState.showResetConfirmation = true
                }
                .font(.system(size: 11.5))
            } help: {
                HelpPopoverButton(text: "The nuclear option! Wipes your preferences clean back to factory fresh. No hard feelings. 🧼💥")
            }

        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 480, height: tabHeight, alignment: .topLeading)
        .background(KillXTheme.paneBackground)
        .overlay {
            if viewState.showResetConfirmation {
                KillConfirmationOverlay(
                    title: "Reset All Preferences?",
                    subtitle: "This will restore KillX to default factory settings.",
                    confirmTitle: "Reset All",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    isForced: false,
                    cardWidth: 260,
                    onConfirm: {
                        configStore.config = KillXConfig.default
                        configStore.save()
                        ShortcutManager.shared.resetDefaults()
                        LaunchAtLoginService.shared.isEnabled = false
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewState.showResetConfirmation = false
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewState.showResetConfirmation = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewState.showResetConfirmation)
    }
}

struct MonitoringTabView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row(label: "Discovery:") {
                toggle("Include UDP listeners", isOn: Binding(
                    get: { configStore.config.includeUDP },
                    set: { enabled in
                        configStore.config.includeUDP = enabled
                        configStore.save()
                        Task { await AppListViewModel.shared.refresh() }
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Include UDP sockets alongside TCP listeners. UDP discovery can show system and local network services.")
            }

            row(label: "Menu bar:") {
                toggle("Show listener count", isOn: Binding(
                    get: { configStore.config.showMenuBarCount },
                    set: { enabled in
                        configStore.config.showMenuBarCount = enabled
                        configStore.save()
                        StatusItemController.shared?.updateMenuBarCount(AppListViewModel.shared.visibleCount)
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Show the current visible listener count beside the KillX menu bar icon.")
            }

            row(label: "Group by:") {
                Picker("", selection: Binding(
                    get: { configStore.config.grouping },
                    set: { configStore.config.grouping = $0; configStore.save() }
                )) {
                    ForEach(ListenerGrouping.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Group listeners by project directory, Docker container, or process tree.")
            }

            row(label: "Default signal:") {
                Picker("", selection: Binding(
                    get: { configStore.config.force == .force ? "Force (SIGKILL)" : "Graceful (SIGTERM)" },
                    set: { configStore.config.force = ($0 == "Force (SIGKILL)" ? .force : .normal); configStore.save() }
                )) {
                    Text("Graceful (SIGTERM)").tag("Graceful (SIGTERM)")
                    Text("Force (SIGKILL)").tag("Force (SIGKILL)")
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Choose the default signal. Hold ⌥ Option to use SIGKILL temporarily.")
            }

        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 480, height: SettingsTab.monitoring.contentHeight, alignment: .topLeading)
        .background(KillXTheme.paneBackground)
    }
}
