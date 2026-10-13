import Foundation

struct KillXConfig: Codable, Equatable {
    var excludePorts: [Int]
    var force: ForceMode
    var treeKillByDefault: Bool
    var defaultSelectAll: Bool
    var autoUpdate: Bool
    var confirmKill: Bool
    var playSounds: Bool
    var disableTips: Bool
    var sortBy: SortBy
    var dockerStopTimeout: Int
    var liquidGlassEnabled: Bool = true

    var disableQuitTips: Bool {
        get { disableTips }
        set { disableTips = newValue }
    }
    var confirmQuitAll: Bool {
        get { confirmKill }
        set { confirmKill = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case excludePorts, force, treeKillByDefault, defaultSelectAll, autoUpdate
        case confirmKill, playSounds, disableTips, sortBy, dockerStopTimeout
        case liquidGlassEnabled
    }

    enum ForceMode: String, Codable, Equatable { case normal, force }

    enum SortBy: String, Codable, Equatable, CaseIterable {
        case portAsc = "Port (Low to High)"
        case portDesc = "Port (High to Low)"
        case name = "Process Name (A-Z)"
        case memoryDesc = "Memory Usage"
        case cpuDesc = "CPU Usage"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "Port (Low to High)", "portAsc", "port": self = .portAsc
            case "Port (High to Low)", "portDesc": self = .portDesc
            case "Process Name (A-Z)", "name", "alphaAsc", "A-Z Alphabetical": self = .name
            case "Memory Usage", "memory", "memoryDesc", "High to Low Memory": self = .memoryDesc
            case "CPU Usage", "cpu", "cpuDesc", "High to Low CPU %": self = .cpuDesc
            default: self = .portAsc
            }
        }
    }

    static var `default`: KillXConfig {
        KillXConfig(
            excludePorts: [],
            force: .normal,
            treeKillByDefault: false,
            defaultSelectAll: false,
            autoUpdate: true,
            confirmKill: true,
            playSounds: true,
            disableTips: false,
            sortBy: .portAsc,
            dockerStopTimeout: 5,
            liquidGlassEnabled: true
        )
    }
}

extension KillXConfig {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KillXConfig.default
        excludePorts = (try? c.decodeIfPresent([Int].self, forKey: .excludePorts)) ?? d.excludePorts
        force = (try? c.decodeIfPresent(ForceMode.self, forKey: .force)) ?? d.force
        treeKillByDefault = (try? c.decodeIfPresent(Bool.self, forKey: .treeKillByDefault)) ?? d.treeKillByDefault
        defaultSelectAll = (try? c.decodeIfPresent(Bool.self, forKey: .defaultSelectAll)) ?? d.defaultSelectAll
        autoUpdate = (try? c.decodeIfPresent(Bool.self, forKey: .autoUpdate)) ?? d.autoUpdate
        confirmKill = (try? c.decodeIfPresent(Bool.self, forKey: .confirmKill)) ?? d.confirmKill
        playSounds = (try? c.decodeIfPresent(Bool.self, forKey: .playSounds)) ?? d.playSounds
        disableTips = (try? c.decodeIfPresent(Bool.self, forKey: .disableTips)) ?? d.disableTips
        sortBy = (try? c.decodeIfPresent(SortBy.self, forKey: .sortBy)) ?? d.sortBy
        dockerStopTimeout = (try? c.decodeIfPresent(Int.self, forKey: .dockerStopTimeout)) ?? d.dockerStopTimeout
        liquidGlassEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .liquidGlassEnabled)) ?? d.liquidGlassEnabled
    }
}
