import Foundation

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: KillXConfig = .default

    private static let userDefaultsKey = "KillXConfig"
    private static let legacyUserDefaultsKey = "QuitXConfig"

    private init() { load() }

    func load() {
        let key = UserDefaults.standard.data(forKey: Self.userDefaultsKey) != nil ? Self.userDefaultsKey : Self.legacyUserDefaultsKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(KillXConfig.self, from: data) else {
            return
        }
        config = decoded
    }

    func save() {
        guard let json = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(json, forKey: Self.userDefaultsKey)
        Task { @MainActor in
            await AppListViewModel.shared.refresh()
            StatusItemController.shared?.updatePopoverSize()
        }
    }
}
