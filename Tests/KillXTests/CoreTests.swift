import Testing
import Foundation
@testable import KillX

@Suite("MemoryFormatter Tests")
struct MemoryFormatterTests {
    @Test("0 bytes formats correctly")
    func testZeroBytes() {
        #expect(MemoryFormatter.format(bytes: 0) == "0 B" || MemoryFormatter.format(bytes: 0) == "0 KB")
    }

    @Test("Small byte amounts under 1KB")
    func testSmallBytes() {
        #expect(MemoryFormatter.format(bytes: 1).contains("B"))
        #expect(MemoryFormatter.format(bytes: 500).contains("B") || MemoryFormatter.format(bytes: 500).contains("KB"))
        #expect(MemoryFormatter.format(bytes: 1023).contains("B") || MemoryFormatter.format(bytes: 1023).contains("KB"))
    }

    @Test("1 KB exact")
    func testOneKB() {
        #expect(MemoryFormatter.format(bytes: 1024).contains("KB") || MemoryFormatter.format(bytes: 1024).contains("1"))
    }

    @Test("512 KB exact")
    func test512KB() {
        #expect(MemoryFormatter.format(bytes: 512 * 1024) == "512 KB")
    }

    @Test("1 MB exact")
    func testOneMB() {
        #expect(MemoryFormatter.format(bytes: 1024 * 1024) == "1 MB" || MemoryFormatter.format(bytes: 1024 * 1024) == "1.0 MB")
    }

    @Test("256 MB exact")
    func test256MB() {
        #expect(MemoryFormatter.format(bytes: 256 * 1024 * 1024) == "256 MB")
    }

    @Test("1 GB exact")
    func testOneGB() {
        let bytes: UInt64 = 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }
}

@Suite("PortInfo Model Tests")
struct PortInfoTests {
    @Test("PortInfo model properties and formatting")
    func testPortInfoModel() {
        let docker = DockerInfo(
            containerId: "c123456",
            name: "web-db",
            image: "postgres:16",
            ports: "0.0.0.0:5432->5432/tcp",
            publishedPort: 5432
        )

        let port = PortInfo(
            port: 5432,
            pid: 1234,
            processName: "postgres",
            command: "/usr/local/bin/postgres -D /data",
            user: "kiron",
            protocolName: "TCP",
            state: "LISTEN",
            memoryBytes: 1024 * 1024 * 64,
            cpuUsage: 1.5,
            cwd: "/var/lib/postgresql",
            docker: docker,
            isDevServer: false
        )

        #expect(port.id == "5432-1234")
        #expect(port.port == 5432)
        #expect(port.pid == 1234)
        #expect(port.processName == "postgres")
        #expect(port.memoryFormatted.contains("MB"))
        #expect(port.cpuFormatted == "1.5%")
        #expect(port.docker?.name == "web-db")
        #expect(port.docker?.publishedPort == 5432)
        #expect(!port.isDevServer)
        #expect(port.portString == "5432")

        let highPort = PortInfo(port: 54564, pid: 999, processName: "node")
        #expect(highPort.portString == "54564")
        #expect(!highPort.portString.contains(","))
    }

    @Test("PortInfo app display and identity")
    func testPortInfoAppIdentity() {
        let portWithApp = PortInfo(
            port: 8080,
            pid: 111,
            processName: "Google Chrome Helper",
            appName: "Google Chrome",
            appBundleId: "com.google.Chrome"
        )
        #expect(portWithApp.displayAppName == "Google Chrome")
        #expect(portWithApp.appName == "Google Chrome")
        #expect(portWithApp.appBundleId == "com.google.Chrome")

        let portFallback = PortInfo(
            port: 5173,
            pid: 222,
            processName: "vite"
        )
        #expect(portFallback.displayAppName == "vite")

        let portDocker = PortInfo(
            port: 6379,
            pid: 333,
            processName: "com.docker.backend",
            docker: DockerInfo(containerId: "redis1", name: "cache-redis", image: "redis", ports: "6379", publishedPort: 6379)
        )
        #expect(portDocker.displayAppName == "cache-redis")
    }

    @Test("ProcessTreeNodeInfo model properties")
    func testProcessTreeNodeInfo() {
        let node = ProcessTreeNodeInfo(
            pid: 1234,
            ppid: 100,
            name: "vite",
            command: "vite dev",
            user: "kiron",
            isListener: true,
            cwd: "/path/to/project",
            startTime: "12:00"
        )

        #expect(node.id == "1234-vite")
        #expect(node.pid == 1234)
        #expect(node.ppid == 100)
        #expect(node.isListener)
        #expect(node.cwd == "/path/to/project")
    }

    @Test("PortInfo equality and hashing")
    func testPortInfoEquality() {
        let p1 = PortInfo(port: 3000, pid: 100, processName: "node")
        let p2 = PortInfo(port: 3000, pid: 100, processName: "node")
        let p3 = PortInfo(port: 3001, pid: 100, processName: "node")

        #expect(p1 == p2)
        #expect(p1 != p3)
    }
}

@Suite("KillXConfig Tests")
struct KillXConfigTests {
    @Test("Default config values match expected specifications")
    func testDefaultConfig() {
        let cfg = KillXConfig.default
        #expect(cfg.excludePorts.isEmpty)
        #expect(cfg.force == .normal)
        #expect(!cfg.defaultSelectAll)
        #expect(cfg.autoUpdate)
        #expect(cfg.confirmKill)
        #expect(cfg.playSounds)
        #expect(!cfg.disableTips)
        #expect(cfg.sortBy == .portAsc)
        #expect(cfg.dockerStopTimeout == 5)
    }

    @Test("Config Codable roundtrip")
    func testConfigCodableRoundtrip() throws {
        var cfg = KillXConfig.default
        cfg.excludePorts = [3000, 8080]
        cfg.force = .force
        cfg.defaultSelectAll = true
        cfg.confirmKill = false
        cfg.playSounds = false
        cfg.disableTips = true
        cfg.sortBy = .memoryDesc
        cfg.dockerStopTimeout = 10

        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(KillXConfig.self, from: data)
        #expect(decoded == cfg)
    }

    @Test("SortBy decode from string variants")
    func testSortByDecode() throws {
        let map: [(String, KillXConfig.SortBy)] = [
            ("Port (Low to High)", .portAsc),
            ("portAsc", .portAsc),
            ("Port (High to Low)", .portDesc),
            ("portDesc", .portDesc),
            ("Process Name (A-Z)", .name),
            ("name", .name),
            ("Memory Usage", .memoryDesc),
            ("memory", .memoryDesc),
            ("CPU Usage", .cpuDesc),
            ("cpu", .cpuDesc)
        ]

        for (str, expected) in map {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(KillXConfig.SortBy.self, from: json)
            #expect(val == expected)
        }
    }

    @Test("SortBy allCases count")
    func testSortByAllCases() {
        #expect(KillXConfig.SortBy.allCases.count == 5)
    }

    @Test("ForceMode enum values")
    func testForceModeValues() {
        #expect(KillXConfig.ForceMode.normal.rawValue == "normal")
        #expect(KillXConfig.ForceMode.force.rawValue == "force")
    }
}
