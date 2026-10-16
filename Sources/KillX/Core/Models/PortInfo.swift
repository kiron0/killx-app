import Foundation

public enum PortExposure: String, Codable, Hashable {
    case local
    case network
    case allInterfaces

    public var label: String {
        switch self {
        case .local: return "Local"
        case .network: return "LAN"
        case .allInterfaces: return "Public"
        }
    }
}

public enum TerminationMode: String, Codable, Hashable {
    case interrupt
    case terminate
    case force

    public var signalName: String {
        switch self {
        case .interrupt: return "SIGINT"
        case .terminate: return "SIGTERM"
        case .force: return "SIGKILL"
        }
    }
}

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
    public let appName: String?
    public let appBundleId: String?
    public let command: String
    public let user: String
    public let protocolName: String
    public let state: String
    public let bindAddress: String
    public let memoryBytes: UInt64
    public let cpuUsage: Double
    public let cwd: String?
    public let docker: DockerInfo?
    public let isDevServer: Bool
    public let isSystemProtected: Bool
    public let executablePath: String?
    public let processStartTime: UInt64?
    public let processGroup: String?

    public var exposure: PortExposure {
        let address = bindAddress.lowercased()
        if address == "*" || address == "0.0.0.0" || address == "::" || address == "[::]" {
            return .allInterfaces
        }
        if address == "localhost" || address == "127.0.0.1" || address == "::1" || address == "[::1]" {
            return .local
        }
        return .network
    }

    public var displayAppName: String {
        if let appName, !appName.isEmpty {
            return appName
        }
        if let docker {
            return docker.name
        }
        return processName
    }

    public var memoryFormatted: String {
        MemoryFormatter.format(bytes: memoryBytes)
    }

    public var cpuFormatted: String {
        String(format: "%.1f%%", cpuUsage)
    }

    public var portString: String {
        String(port)
    }

    public init(
        port: Int,
        pid: pid_t,
        processName: String,
        appName: String? = nil,
        appBundleId: String? = nil,
        command: String = "",
        user: String = "",
        protocolName: String = "TCP",
        state: String = "LISTEN",
        bindAddress: String = "*",
        memoryBytes: UInt64 = 0,
        cpuUsage: Double = 0.0,
        cwd: String? = nil,
        docker: DockerInfo? = nil,
        isDevServer: Bool = false,
        isSystemProtected: Bool = false,
        executablePath: String? = nil,
        processStartTime: UInt64? = nil,
        processGroup: String? = nil
    ) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.appName = appName
        self.appBundleId = appBundleId
        self.command = command
        self.user = user
        self.protocolName = protocolName
        self.state = state
        self.bindAddress = bindAddress
        self.memoryBytes = memoryBytes
        self.cpuUsage = cpuUsage
        self.cwd = cwd
        self.docker = docker
        self.isDevServer = isDevServer
        self.isSystemProtected = isSystemProtected
        self.executablePath = executablePath
        self.processStartTime = processStartTime
        self.processGroup = processGroup
    }

    public func updatingStats(memoryBytes: UInt64, cpuUsage: Double) -> PortInfo {
        PortInfo(
            port: port,
            pid: pid,
            processName: processName,
            appName: appName,
            appBundleId: appBundleId,
            command: command,
            user: user,
            protocolName: protocolName,
            state: state,
            bindAddress: bindAddress,
            memoryBytes: memoryBytes,
            cpuUsage: cpuUsage,
            cwd: cwd,
            docker: docker,
            isDevServer: isDevServer,
            isSystemProtected: isSystemProtected,
            executablePath: executablePath,
            processStartTime: processStartTime,
            processGroup: processGroup
        )
    }
}
