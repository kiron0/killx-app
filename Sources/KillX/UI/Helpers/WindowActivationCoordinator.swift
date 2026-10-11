import AppKit

@MainActor
enum WindowActivationCoordinator {
    static func update() {
        let hasOpenWindow = SettingsWindowController.shared.isOpen
            || WelcomeWindowController.shared.isOpen
            || HelpWindowController.shared.isOpen
            || ExcludePortPickerWindowController.shared.isOpen
        NSApp.setActivationPolicy(hasOpenWindow ? .regular : .accessory)
    }
}
