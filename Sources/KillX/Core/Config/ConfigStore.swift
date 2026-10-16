import Foundation

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: KillXConfig = .default

    private static let userDefaultsKey = "KillXConfig"
    private var lastListConfig: (exclude: [Int], sort: KillXConfig.SortBy)?
    private let userDefaults: UserDefaults
    private let enableAppSideEffects: Bool

    init(userDefaults: UserDefaults = .standard, enableAppSideEffects: Bool = true) {
        self.userDefaults = userDefaults
        self.enableAppSideEffects = enableAppSideEffects
        load()
        lastListConfig = (config.excludePorts, config.sortBy)
    }

    func load() {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode(KillXConfig.self, from: data) else {
            return
        }
        config = decoded
    }

    func save() {
        guard let json = try? JSONEncoder().encode(config) else { return }
        userDefaults.set(json, forKey: Self.userDefaultsKey)

        let current = (config.excludePorts, config.sortBy)
        if let lastListConfig, lastListConfig == current { return }
        lastListConfig = current

        guard enableAppSideEffects else { return }
        Task { @MainActor in
            await AppListViewModel.shared.resort()
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    @discardableResult
    func addExcludedPorts(_ ports: [Int]) -> Int {
        var added = 0
        var exclude = config.excludePorts
        var currentSet = Set(exclude)
        for p in ports where p > 0 && p <= 65535 {
            if currentSet.insert(p).inserted {
                exclude.append(p)
                added += 1
            }
        }
        guard added > 0 else { return 0 }
        config.excludePorts = exclude.sorted()
        save()
        return added
    }

    func removeExcludedPorts(_ ports: Set<Int>) {
        guard !ports.isEmpty else { return }
        let oldCount = config.excludePorts.count
        config.excludePorts.removeAll { ports.contains($0) }
        if config.excludePorts.count != oldCount {
            save()
        }
    }

    func removeAllExcludedPorts() {
        guard !config.excludePorts.isEmpty else { return }
        config.excludePorts.removeAll()
        save()
    }
}
