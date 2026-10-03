import Foundation

public struct DockerInfo: Hashable, Codable {
    public let containerId: String
    public let name: String
    public let image: String
    public let ports: String
    public let publishedPort: Int

    public init(containerId: String, name: String, image: String, ports: String, publishedPort: Int) {
        self.containerId = containerId
        self.name = name
        self.image = image
        self.ports = ports
        self.publishedPort = publishedPort
    }
}

public struct ProcessTreeNodeInfo: Identifiable, Hashable {
    public var id: String { "\(pid)-\(name)" }
    public let pid: pid_t
    public let ppid: pid_t
    public let name: String
    public let command: String
    public let user: String
    public let isListener: Bool
    public var cwd: String?
    public var startTime: String?

    public init(
        pid: pid_t,
        ppid: pid_t,
        name: String,
        command: String,
        user: String,
        isListener: Bool,
        cwd: String? = nil,
        startTime: String? = nil
    ) {
        self.pid = pid
        self.ppid = ppid
        self.name = name
        self.command = command
        self.user = user
        self.isListener = isListener
        self.cwd = cwd
        self.startTime = startTime
    }
}

public struct PortInfo: Identifiable, Hashable {
    public var id: String { "\(port)-\(pid)" }
    public let port: Int
    public let pid: pid_t
    public let processName: String
    public let command: String
    public let user: String
    public let protocolName: String
    public let state: String
    public let memoryBytes: UInt64
    public let cpuUsage: Double
    public let cwd: String?
    public let docker: DockerInfo?
    public let isDevServer: Bool

    public var memoryFormatted: String {
        MemoryFormatter.format(bytes: memoryBytes)
    }

    public var cpuFormatted: String {
        String(format: "%.1f%%", cpuUsage)
    }

    public init(
        port: Int,
        pid: pid_t,
        processName: String,
        command: String = "",
        user: String = "",
        protocolName: String = "TCP",
        state: String = "LISTEN",
        memoryBytes: UInt64 = 0,
        cpuUsage: Double = 0.0,
        cwd: String? = nil,
        docker: DockerInfo? = nil,
        isDevServer: Bool = false
    ) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.command = command
        self.user = user
        self.protocolName = protocolName
        self.state = state
        self.memoryBytes = memoryBytes
        self.cpuUsage = cpuUsage
        self.cwd = cwd
        self.docker = docker
        self.isDevServer = isDevServer
    }
}
