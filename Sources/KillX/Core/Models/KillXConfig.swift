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

    // Backward compatibility properties
    var disableQuitTips: Bool {
        get { disableTips }
        set { disableTips = newValue }
    }
    var confirmQuitAll: Bool {
        get { confirmKill }
        set { confirmKill = newValue }
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
            dockerStopTimeout: 5
        )
    }
}

typealias QuitXConfig = KillXConfig
