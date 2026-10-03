import Foundation

public struct DevServerInfo: Identifiable, Hashable {
    public var id: String { "\(port.port)-\(port.pid)" }
    public let port: PortInfo
    public let projectName: String
    public let projectRoot: String
    public let displayPath: String

    public init(port: PortInfo, projectName: String, projectRoot: String, displayPath: String) {
        self.port = port
        self.projectName = projectName
        self.projectRoot = projectRoot
        self.displayPath = displayPath
    }
}

public final class DevServerService {
    public static let shared = DevServerService()
    private init() {}

    private let rootIndicators = [
        ".git", "package.json", "go.mod", "Cargo.toml", "pyproject.toml", "pom.xml", "build.gradle"
    ]

    public func findProjectRoot(from startDir: String) -> String {
        var current = (startDir as NSString).standardizingPath
        let fm = FileManager.default

        while !current.isEmpty && current != "/" {
            for indicator in rootIndicators {
                let candidate = (current as NSString).appendingPathComponent(indicator)
                if fm.fileExists(atPath: candidate) {
                    return current
                }
            }
            let parent = (current as NSString).deletingLastPathComponent
            if parent == current { break }
            current = parent
        }
        return startDir
    }

    public func fetchDevServers() async -> [DevServerInfo] {
        let ports = await PortService.shared.fetchListeningPorts()
        let devPorts = ports.filter(\.isDevServer)

        var list: [DevServerInfo] = []
        for port in devPorts {
            let cwd = port.cwd ?? ""
            let root = !cwd.isEmpty ? findProjectRoot(from: cwd) : ""
            let projectName = !root.isEmpty ? (root as NSString).lastPathComponent : port.processName
            let displayPath = !cwd.isEmpty ? cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~") : "-"

            list.append(DevServerInfo(
                port: port,
                projectName: projectName,
                projectRoot: root,
                displayPath: displayPath
            ))
        }
        return list
    }

    @discardableResult
    public func sweepAllDevServers(force: Bool = false) async -> Int {
        let devServers = await fetchDevServers()
        var count = 0
        for s in devServers {
            let ok = await PortService.shared.killPort(s.port, force: force, tree: true)
            if ok { count += 1 }
        }
        return count
    }
}
