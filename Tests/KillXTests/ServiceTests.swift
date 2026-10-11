import Testing
import Foundation
@testable import KillX

@Suite("PortService Tests")
struct PortServiceTests {
    @Test("Dev process name matching")
    func testIsDevProcess() {
        #expect(PortService.isDevProcess(name: "node"))
        #expect(PortService.isDevProcess(name: "vite"))
        #expect(PortService.isDevProcess(name: "next-server"))
        #expect(PortService.isDevProcess(name: "bun"))
        #expect(PortService.isDevProcess(name: "python3"))
        #expect(PortService.isDevProcess(name: "cargo"))
        #expect(PortService.isDevProcess(name: "unknown", command: "/usr/local/bin/node server.js"))
        #expect(PortService.isDevProcess(name: "unknown", command: "bun run dev"))
        #expect(!PortService.isDevProcess(name: "Finder"))
        #expect(!PortService.isDevProcess(name: "ControlCenter"))
    }

    @Test("Port sorting logic")
    func testPortSorting() {
        let p1 = PortInfo(port: 3000, pid: 100, processName: "node", memoryBytes: 200 * 1024 * 1024, cpuUsage: 5.0)
        let p2 = PortInfo(port: 8080, pid: 200, processName: "python", memoryBytes: 50 * 1024 * 1024, cpuUsage: 15.0)
        let p3 = PortInfo(port: 5173, pid: 300, processName: "vite", memoryBytes: 100 * 1024 * 1024, cpuUsage: 1.0)

        let ports = [p1, p2, p3]

        let byPortAsc = ports.sorted { $0.port < $1.port }
        #expect(byPortAsc.map(\.port) == [3000, 5173, 8080])

        let byPortDesc = ports.sorted { $0.port > $1.port }
        #expect(byPortDesc.map(\.port) == [8080, 5173, 3000])

        let byName = ports.sorted { $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending }
        #expect(byName.map(\.processName) == ["node", "python", "vite"])

        let byMemory = ports.sorted { $0.memoryBytes > $1.memoryBytes }
        #expect(byMemory.map(\.port) == [3000, 5173, 8080])

        let byCpu = ports.sorted { $0.cpuUsage > $1.cpuUsage }
        #expect(byCpu.map(\.port) == [8080, 3000, 5173])
    }

    @Test("App resolution for runtimes and docker")
    func testAppResolution() {
        let service = PortService.shared
        let dockerInfo = DockerInfo(
            containerId: "abc",
            name: "postgres-db",
            image: "postgres:15",
            ports: "5432",
            publishedPort: 5432
        )
        let dockerRes = service.resolveApp(pid: 9999, processName: "com.docker.backend", docker: dockerInfo)
        #expect(dockerRes.appName == "Docker (postgres-db)")
        #expect(dockerRes.bundleId == "com.docker.docker")

        let nodeRes = service.resolveApp(pid: 8888, processName: "node")
        #expect(nodeRes.appName == "Node.js")

        let pgRes = service.resolveApp(pid: 7777, processName: "postgres")
        #expect(pgRes.appName == "PostgreSQL")

        let redisRes = service.resolveApp(pid: 6666, processName: "redis-server")
        #expect(redisRes.appName == "Redis")
    }
}

@Suite("DockerService Tests")
struct DockerServiceTests {
    @Test("DockerInfo published port matching")
    func testDockerInfoMatching() {
        let docker = DockerInfo(
            containerId: "abcd1234efgh",
            name: "redis-cache",
            image: "redis:7-alpine",
            ports: "0.0.0.0:6379->6379/tcp, :::6379->6379/tcp",
            publishedPort: 6379
        )

        #expect(docker.name == "redis-cache")
        #expect(docker.publishedPort == 6379)
        #expect(docker.containerId == "abcd1234efgh")
    }
}

@Suite("SoundService Tests")
struct SoundServiceTests {
    @Test("Play sounds when sounds enabled or disabled does not crash")
    func testPlaySounds() {
        SoundService.isAudioDisabledForTesting = true
        ConfigStore.shared.config.playSounds = true
        SoundService.playKillSingle()
        SoundService.playKillAll()
        SoundService.playQuitSingle()
        SoundService.playQuitAll()

        ConfigStore.shared.config.playSounds = false
        SoundService.playKillSingle()
        SoundService.playKillAll()
        SoundService.playQuitSingle()
        SoundService.playQuitAll()
    }
}

@Suite("SystemPortProtection Tests")
struct SystemPortProtectionTests {
    @Test("Critical daemon names are protected")
    func testCriticalDaemons() {
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "rapportd"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "ControlCenter"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "mDNSResponder"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "launchd"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "killx"))
        #expect(!SystemPortProtection.isSystemProtected(pid: 9999, processName: "node"))
    }

    @Test("Critical bundle identifiers and self are protected")
    func testBundleIds() {
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, bundleIdentifier: "com.apple.controlcenter"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, bundleIdentifier: "com.apple.dock"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, bundleIdentifier: "io.coreify.killx"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, bundleIdentifier: "com.killx.app"))
        #expect(!SystemPortProtection.isSystemProtected(pid: 9999, bundleIdentifier: "com.google.Chrome"))
    }

    @Test("Protected path prefixes")
    func testProtectedPaths() {
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, executablePath: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, executablePath: "/usr/libexec/rapportd"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, executablePath: "/usr/sbin/mDNSResponder"))
        #expect(!SystemPortProtection.isSystemProtected(pid: 9999, executablePath: "/opt/homebrew/bin/node"))
    }

    @Test("Special PID protection")
    func testSpecialPids() {
        #expect(SystemPortProtection.isSystemProtected(pid: 0))
        #expect(SystemPortProtection.isSystemProtected(pid: 1))
        #expect(SystemPortProtection.isSystemProtected(pid: ProcessInfo.processInfo.processIdentifier))
    }

    @Test("PortInfo protection and kill rejection")
    func testPortInfoKillRejection() async {
        let protectedPort = PortInfo(
            port: 5000,
            pid: 9999,
            processName: "ControlCenter",
            appBundleId: "com.apple.controlcenter",
            isSystemProtected: true
        )
        #expect(SystemPortProtection.isSystemProtected(port: protectedPort))

        let killed = await PortService.shared.killPort(protectedPort)
        #expect(!killed)

        let killedTree = await PortService.shared.terminateProcessTree(pid: 1)
        #expect(!killedTree)
    }

    @Test("Antigravity and IDE protection")
    func testAntigravityProtection() {
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "antigravity"))
        #expect(SystemPortProtection.isSystemProtected(pid: 9999, processName: "antigravity-ide"))
        #expect(PortService.isHostBoundary(pid: 9999, name: "antigravity"))
        // Electron is only a boundary when its command path is inside a known IDE bundle
        #expect(PortService.isIDEOrEditor("Electron", command: "/Applications/Antigravity IDE.app/Contents/MacOS/Electron"))
        #expect(!PortService.isIDEOrEditor("Electron", command: "/Applications/Slack.app/Contents/MacOS/Electron"))
        #expect(PortService.isHostBoundary(pid: 9999, name: "zsh"))
        #expect(PortService.isHostBoundary(pid: 9999, name: "bash"))
        #expect(!PortService.isHostBoundary(pid: 9999, name: "bun"))
        #expect(!PortService.isHostBoundary(pid: 9999, name: "node"))
        // code-server is a dev server, not an IDE host
        #expect(!PortService.isIDEOrEditor("code-server"))
    }
}

