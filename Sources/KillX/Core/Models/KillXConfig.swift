import Foundation

enum ListenerGrouping: String, Codable, Equatable, CaseIterable {
    case none = "None"
    case project = "Project"
    case docker = "Docker"
    case process = "Process"
}

struct KillXConfig: Codable, Equatable {
    var excludePorts: [Int]
    var force: ForceMode
    var defaultSelectAll: Bool
    var autoUpdate: Bool
    var confirmKill: Bool
    var playSounds: Bool
    var disableTips: Bool
    var sortBy: SortBy
    var dockerStopTimeout: Int
    var liquidGlassEnabled: Bool = true
    var watchedPorts: [Int] = []
    var favoritePorts: [Int] = []
    var includeUDP: Bool = false
    var grouping: ListenerGrouping = .none
    var showMenuBarCount: Bool = false

    var disableQuitTips: Bool {
        get { disableTips }
        set { disableTips = newValue }
    }
    var confirmQuitAll: Bool {
        get { confirmKill }
        set { confirmKill = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case excludePorts, force, defaultSelectAll, autoUpdate
        case confirmKill, playSounds, disableTips, sortBy, dockerStopTimeout
        case liquidGlassEnabled
        case watchedPorts, favoritePorts, includeUDP, grouping, showMenuBarCount
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
            defaultSelectAll: false,
            autoUpdate: true,
            confirmKill: true,
            playSounds: true,
            disableTips: false,
            sortBy: .portAsc,
            dockerStopTimeout: 5,
            liquidGlassEnabled: true,
            watchedPorts: [],
            favoritePorts: [],
            includeUDP: false,
            grouping: .none,
            showMenuBarCount: false
        )
    }
}

extension KillXConfig {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KillXConfig.default
        let decodedPorts = (try? c.decodeIfPresent([Int].self, forKey: .excludePorts)) ?? d.excludePorts
        excludePorts = Array(Set(decodedPorts.filter { (1...65535).contains($0) })).sorted()
        force = (try? c.decodeIfPresent(ForceMode.self, forKey: .force)) ?? d.force
        defaultSelectAll = (try? c.decodeIfPresent(Bool.self, forKey: .defaultSelectAll)) ?? d.defaultSelectAll
        autoUpdate = (try? c.decodeIfPresent(Bool.self, forKey: .autoUpdate)) ?? d.autoUpdate
        confirmKill = (try? c.decodeIfPresent(Bool.self, forKey: .confirmKill)) ?? d.confirmKill
        playSounds = (try? c.decodeIfPresent(Bool.self, forKey: .playSounds)) ?? d.playSounds
        disableTips = (try? c.decodeIfPresent(Bool.self, forKey: .disableTips)) ?? d.disableTips
        sortBy = (try? c.decodeIfPresent(SortBy.self, forKey: .sortBy)) ?? d.sortBy
        let decodedTimeout = (try? c.decodeIfPresent(Int.self, forKey: .dockerStopTimeout)) ?? d.dockerStopTimeout
        dockerStopTimeout = min(max(decodedTimeout, 1), 60)
        liquidGlassEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .liquidGlassEnabled)) ?? d.liquidGlassEnabled
        watchedPorts = Self.validPorts((try? c.decodeIfPresent([Int].self, forKey: .watchedPorts)) ?? d.watchedPorts)
        favoritePorts = Self.validPorts((try? c.decodeIfPresent([Int].self, forKey: .favoritePorts)) ?? d.favoritePorts)
        includeUDP = (try? c.decodeIfPresent(Bool.self, forKey: .includeUDP)) ?? d.includeUDP
        grouping = (try? c.decodeIfPresent(ListenerGrouping.self, forKey: .grouping)) ?? d.grouping
        showMenuBarCount = (try? c.decodeIfPresent(Bool.self, forKey: .showMenuBarCount)) ?? d.showMenuBarCount
    }

    private static func validPorts(_ ports: [Int]) -> [Int] {
        Array(Set(ports.filter { (1...65535).contains($0) })).sorted()
    }
}
