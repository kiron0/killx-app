import AppKit

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    enum Slot: Equatable {
        case activateMenu
        case quitAll
        case forceQuitAll
    }

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

    @Published private(set) var shortcutError: String? = nil
    @Published private(set) var registrationError: String? = nil

    func keys(for slot: Slot) -> [String] {
        switch slot {
        case .activateMenu: return activateMenuKeys
        case .quitAll: return quitAllKeys
        case .forceQuitAll: return forceQuitAllKeys
        }
    }

    func isEnabled(_ slot: Slot) -> Bool {
        switch slot {
        case .activateMenu: return activateMenuEnabled
        case .quitAll: return quitAllEnabled
        case .forceQuitAll: return forceQuitAllEnabled
        }
    }

    func conflicts(keys: [String], excluding slot: Slot) -> Bool {
        guard !keys.isEmpty else { return false }
        let others: [Slot] = [.activateMenu, .quitAll, .forceQuitAll].filter { $0 != slot }
        return others.contains { other in
            isEnabled(other) && self.keys(for: other) == keys
        }
    }

    @discardableResult
    func setKeys(_ newKeys: [String], for slot: Slot) -> Bool {
        guard conflicts(keys: newKeys, excluding: slot) else {
            shortcutError = nil
            switch slot {
            case .activateMenu: activateMenuKeys = newKeys
            case .quitAll: quitAllKeys = newKeys
            case .forceQuitAll: forceQuitAllKeys = newKeys
            }
            return true
        }
        shortcutError = "This shortcut is already assigned to another action."
        return false
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

    private nonisolated static let primaryKeyMap: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`"
    ]

    nonisolated static func keyCodeToString(_ keyCode: UInt16) -> String? {
        primaryKeyMap[keyCode]
    }

    nonisolated static func eventToKeys(_ event: NSEvent) -> [String] {
        var keys: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { keys.append("^") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }

        if let mapped = keyCodeToString(event.keyCode) {
            keys.append(mapped)
        } else if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let scalar = chars.unicodeScalars.first?.value ?? 0
            if scalar >= 32 && scalar < 127 {
                keys.append(chars)
            } else if scalar >= 1 && scalar <= 26 {
                keys.append(String(UnicodeScalar(scalar + 64)!))
            }
        }
        return keys
    }
}
