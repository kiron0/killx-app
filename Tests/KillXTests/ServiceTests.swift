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

@Suite("DevServerService Tests")
struct DevServerServiceTests {
    @Test("Project root detection from start directory")
    func testFindProjectRoot() {
        let service = DevServerService.shared
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("killx-test-project-\(UUID().uuidString)")
        let subDir = tempDir.appendingPathComponent("src/components")

        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let packageJson = tempDir.appendingPathComponent("package.json")
        try? "{}".write(to: packageJson, atomically: true, encoding: .utf8)

        let detectedRoot = service.findProjectRoot(from: subDir.path)
        #expect(detectedRoot == tempDir.path)

        try? FileManager.default.removeItem(at: tempDir)
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
