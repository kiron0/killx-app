import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()

    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UserDefaults.standard.set(isEnabled, forKey: "killx_launch_at_login")
            applyRegistration(isEnabled)
        }
    }

    private init() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval {
                self.isEnabled = true
            } else {
                self.isEnabled = UserDefaults.standard.bool(forKey: "killx_launch_at_login")
            }
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "killx_launch_at_login")
        }
    }

    private func applyRegistration(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("SMAppService.mainApp registration failed: \(error)")
            }
        }
    }
}
