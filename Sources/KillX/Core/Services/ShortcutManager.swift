import AppKit

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    @Published var activateMenuEnabled: Bool {
        didSet { UserDefaults.standard.set(activateMenuEnabled, forKey: "sc_activate_enabled"); restartMonitoring() }
    }
    @Published var activateMenuKeys: [String] {
        didSet { UserDefaults.standard.set(activateMenuKeys, forKey: "sc_activate_keys"); restartMonitoring() }
    }

    @Published var quitAllEnabled: Bool {
        didSet { UserDefaults.standard.set(quitAllEnabled, forKey: "sc_quit_enabled"); restartMonitoring() }
    }
    @Published var quitAllKeys: [String] {
        didSet { UserDefaults.standard.set(quitAllKeys, forKey: "sc_quit_keys"); restartMonitoring() }
    }

    @Published var forceQuitAllEnabled: Bool {
        didSet { UserDefaults.standard.set(forceQuitAllEnabled, forKey: "sc_force_enabled"); restartMonitoring() }
    }
    @Published var forceQuitAllKeys: [String] {
        didSet { UserDefaults.standard.set(forceQuitAllKeys, forKey: "sc_force_keys"); restartMonitoring() }
    }

    var showPopoverEnabled: Bool {
        get { activateMenuEnabled }
        set { activateMenuEnabled = newValue }
    }
    var showPopoverKeys: [String] {
        get { activateMenuKeys }
        set { activateMenuKeys = newValue }
    }

    func saveShowPopover() {
        UserDefaults.standard.set(activateMenuKeys, forKey: "sc_activate_keys")
        UserDefaults.standard.set(activateMenuEnabled, forKey: "sc_activate_enabled")
        restartMonitoring()
    }

    func saveQuitAll() {
        UserDefaults.standard.set(quitAllKeys, forKey: "sc_quit_keys")
        UserDefaults.standard.set(quitAllEnabled, forKey: "sc_quit_enabled")
        restartMonitoring()
    }

    func saveForceQuitAll() {
        UserDefaults.standard.set(forceQuitAllKeys, forKey: "sc_force_keys")
        UserDefaults.standard.set(forceQuitAllEnabled, forKey: "sc_force_enabled")
        restartMonitoring()
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init() {
        self.activateMenuEnabled = UserDefaults.standard.object(forKey: "sc_activate_enabled") as? Bool ?? true
        self.activateMenuKeys = UserDefaults.standard.stringArray(forKey: "sc_activate_keys") ?? ["^", "⌥", "A"]

        self.quitAllEnabled = UserDefaults.standard.object(forKey: "sc_quit_enabled") as? Bool ?? false
        self.quitAllKeys = UserDefaults.standard.stringArray(forKey: "sc_quit_keys") ?? ["^", "⌥", "Q"]

        self.forceQuitAllEnabled = UserDefaults.standard.object(forKey: "sc_force_enabled") as? Bool ?? false
        self.forceQuitAllKeys = UserDefaults.standard.stringArray(forKey: "sc_force_keys") ?? ["^", "⌥", "⌘", "Q"]

        restartMonitoring()
    }

    func restartMonitoring() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let pressedKeys = Self.eventToKeys(event)
        guard !pressedKeys.isEmpty else { return false }

        if activateMenuEnabled && pressedKeys == activateMenuKeys {
            StatusItemController.shared?.togglePopover()
            return true
        }

        if quitAllEnabled && pressedKeys == quitAllKeys {
            Task { await AppListViewModel.shared.quitAll(force: false) }
            return true
        }

        if forceQuitAllEnabled && pressedKeys == forceQuitAllKeys {
            Task { await AppListViewModel.shared.quitAll(force: true) }
            return true
        }

        return false
    }

    nonisolated static func eventToKeys(_ event: NSEvent) -> [String] {
        var keys: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { keys.append("^") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }

        if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let scalar = chars.unicodeScalars.first?.value ?? 0
            if scalar >= 32 && scalar < 127 {
                keys.append(chars)
            } else {
                switch event.keyCode {
                case 36: keys.append("↩")
                case 49: keys.append("Space")
                case 48: keys.append("Tab")
                default: break
                }
            }
        }
        return keys
    }
}
