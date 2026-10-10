import SwiftUI
import AppKit
import Combine

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case support = "Support"
    case about = "About"

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }

    var iconName: String {
        switch self {
        case .general:   return "preferences-general"
        case .shortcuts: return "preferences-shortcuts"
        case .support:   return "preferences-support"
        case .about:     return "preferences-about"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .general:   return "gearshape"
        case .shortcuts: return "command"
        case .support:   return "bubble.left.and.bubble.right"
        case .about:     return "bolt.horizontal.fill"
        }
    }

    var toolbarImage: NSImage? {
        if let img = AssetImages.load(iconName) {
            let copy = img.copy() as! NSImage
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
            if #available(macOS 26.0, *) { return 370 }
            return 340
        case .shortcuts: return 215
        case .support:   return 139
        case .about:     return 130
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
        .arrowPopoverChrome(arrowX: arrowX, classicBackground: AnyView(QuitXTheme.popoverBackground))
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
                .foregroundStyle(isActive ? QuitXTheme.accent : Color.secondary)
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
            case .shortcuts:
                ShortcutsTabCloneView()
            case .support:
                SupportTabCloneView()
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
                        QuitXTheme.cardBackground
                            .frame(height: tabModel.glassTopInset)
                    }
                }
                .ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground
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
            QuitXSelectionCheckbox(isSelected: isOn.wrappedValue)

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
                        selected ? QuitXTheme.accent : Color.secondary.opacity(0.5),
                        lineWidth: 1.5
                    )
                    .frame(width: 14, height: 14)
                if selected {
                    Circle()
                        .fill(QuitXTheme.accent)
                        .frame(width: 7, height: 7)
                }
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary)
        }
    }
    .buttonStyle(.plain)
}

struct GeneralTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared

    private var tabHeight: CGFloat {
        if #available(macOS 26.0, *) { return 370 }
        return 340
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

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

            row(label: "Process Tree:") {
                toggle("Terminate process tree by default", isOn: Binding(
                    get: { configStore.config.treeKillByDefault },
                    set: { configStore.config.treeKillByDefault = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Automatically terminate root supervisors (npm, yarn, pnpm, cargo, vite) and all child processes instead of only the listener.")
            }

            row(label: "Safety:") {
                toggle("Confirm before killing ports", isOn: Binding(
                    get: { configStore.config.confirmKill },
                    set: { configStore.config.confirmKill = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Show a caution prompt before terminating ports or dev servers.")
            }

            row(label: "") {
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

            row(label: "") {
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
                HelpPopoverButton(text: "You can also hold ⌥ (Option key) at any time to toggle force kill on demand.")
            }

            row(label: "Reset:") {
                Button("Reset all defaults") {
                    configStore.config = KillXConfig.default
                    configStore.save()
                }
                .font(.system(size: 11.5))
            } help: {
                Color.clear.frame(width: 20, height: 20)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 480, height: tabHeight, alignment: .topLeading)
    }

    private func row<Content: View, Help: View>(
        label: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder help: () -> Help
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: 90, alignment: .trailing)

            content()

            Spacer(minLength: 0)

            help()
        }
        .frame(height: 25)
    }
}

@MainActor
final class ShortcutsViewState: ObservableObject {
    @Published var recordingRow: String? = nil
    var localMonitor: Any? = nil
    var globalMonitor: Any? = nil

    func startMonitor(sm: ShortcutManager) {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return event }
            if self.processEvent(event, row: row, sm: sm) {
                return nil
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return }
            _ = self.processEvent(event, row: row, sm: sm)
        }
    }

    func stopMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func processEvent(_ event: NSEvent, row: String, sm: ShortcutManager) -> Bool {
        if event.keyCode == 53 {
            DispatchQueue.main.async { self.recordingRow = nil }
            return true
        }
        if event.keyCode == 51 {
            DispatchQueue.main.async {
                self.applyKeys([], for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }
        let symbols = self.eventToKeySymbols(event)
        if !symbols.isEmpty {
            DispatchQueue.main.async {
                self.applyKeys(symbols, for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }
        return false
    }

    func applyKeys(_ keys: [String], for row: String, sm: ShortcutManager) {
        switch row {
        case "showPopover":
            sm.showPopoverKeys = keys
            sm.saveShowPopover()
        case "quitAll":
            sm.quitAllKeys = keys
            sm.saveQuitAll()
        case "forceQuitAll":
            sm.forceQuitAllKeys = keys
            sm.saveForceQuitAll()
        default:
            break
        }
    }

    private func eventToKeySymbols(_ event: NSEvent) -> [String] {
        var result: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.control) { result.append("⌃") }
        if flags.contains(.option)  { result.append("⌥") }
        if flags.contains(.shift)   { result.append("⇧") }
        if flags.contains(.command) { result.append("⌘") }

        let specialMap: [UInt16: String] = [
            49: "Space", 36: "↩", 48: "⇥", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            117: "⌦", 51: "⌫"
        ]
        if let special = specialMap[event.keyCode] {
            result.append(special)
            return result
        }

        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let upper = chars.uppercased()
            if upper.count == 1, let scalar = upper.unicodeScalars.first, scalar.value >= 32, scalar.value < 127 {
                result.append(upper)
                return result
            }
        }
        return result
    }
}

struct ShortcutsTabCloneView: View {
    @ObservedObject private var sm = ShortcutManager.shared
    @StateObject private var viewState = ShortcutsViewState()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            shortcutRow(
                id: "showPopover",
                title: "Toggle Menu Bar Popover",
                isEnabled: $sm.showPopoverEnabled,
                keyList: sm.showPopoverKeys
            )

            shortcutRow(
                id: "quitAll",
                title: "Sweep Dev Servers",
                isEnabled: $sm.quitAllEnabled,
                keyList: sm.quitAllKeys
            )

            shortcutRow(
                id: "forceQuitAll",
                title: "Force Kill Selected Ports",
                isEnabled: $sm.forceQuitAllEnabled,
                keyList: sm.forceQuitAllKeys
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(width: 480, height: 215, alignment: .topLeading)
        .onAppear {
            viewState.startMonitor(sm: sm)
        }
        .onDisappear {
            viewState.stopMonitor()
        }
    }

    private func shortcutRow(
        id: String,
        title: String,
        isEnabled: Binding<Bool>,
        keyList: [String]
    ) -> some View {
        let isRecording = (viewState.recordingRow == id)
        let active = isEnabled.wrappedValue

        return HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: 170, alignment: .leading)

            Button {
                isEnabled.wrappedValue.toggle()
            } label: {
                QuitXSelectionCheckbox(isSelected: active)
            }
            .buttonStyle(.plain)

            Button {
                if active {
                    viewState.recordingRow = (viewState.recordingRow == id ? nil : id)
                }
            } label: {
                HStack(spacing: 3) {
                    if isRecording {
                        Text("Type keys...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(QuitXTheme.accent)
                    } else if keyList.isEmpty {
                        Text("None")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    } else {
                        ForEach(keyList, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(active ? Color.primary : Color.secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 3.5)
                                        .fill(active ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06))
                                 )
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .frame(width: 105, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(active ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? QuitXTheme.accent : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Button {
                viewState.applyKeys([], for: id, sm: sm)
                if viewState.recordingRow == id { viewState.recordingRow = nil }
            } label: {
                if let img = AssetImages.load("recorder-delete") {
                    Image(nsImage: img)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 13, height: 13)
                        .foregroundStyle((active && !keyList.isEmpty) ? Color.secondary : Color.secondary.opacity(0.3))
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle((active && !keyList.isEmpty) ? Color.secondary : Color.secondary.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .disabled(!active || keyList.isEmpty)
            .frame(width: 18, height: 18)

            Spacer()
        }
    }
}

struct SupportTabCloneView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Get in touch for any feedback, bug reports, or feature requests!")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineSpacing(3)
                .padding(.top, 24)

            Button("GitHub Issues") {
                if let url = URL(string: "https://github.com/kiron0/killx/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(width: 480, height: 139, alignment: .topLeading)
    }
}

struct AboutTabCloneView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            KillXAppIconView(size: 70, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("KillX")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Text("⚡️ Version \(updateChecker.currentVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }

                Text("Copyright © 2026 Toufiq Hasan Kiron")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 10) {
                    Button(updateChecker.isChecking ? "Checking..." : "Check Updates") {
                        Task {
                            await updateChecker.checkForUpdates(isUserInitiated: true)
                        }
                    }
                    .disabled(updateChecker.isChecking)
                    .font(.system(size: 11.5))
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .frame(width: 480, height: 130)
    }
}
