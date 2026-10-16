import Foundation
import AppKit
import Darwin

public struct PortScanMetrics: Equatable {
    public var discovery: TimeInterval = 0
    public var metadata: TimeInterval = 0
    public var assembly: TimeInterval = 0
    public var total: TimeInterval = 0

    public init(
        discovery: TimeInterval = 0,
        metadata: TimeInterval = 0,
        assembly: TimeInterval = 0,
        total: TimeInterval = 0
    ) {
        self.discovery = discovery
        self.metadata = metadata
        self.assembly = assembly
        self.total = total
    }
}

struct ProcessIdentitySnapshot: Equatable {
    let pid: pid_t
    let executablePath: String?
    let startTime: UInt64?
}

private actor PortScanGate {
    private var inFlight: (id: UUID, key: String, task: Task<[PortInfo], Never>)?
    private var cached: (key: String, date: Date, ports: [PortInfo])?

    func run(cacheKey: String, _ operation: @escaping @Sendable () async -> [PortInfo]) async -> [PortInfo] {
        if let inFlight {
            if inFlight.key == cacheKey { return await inFlight.task.value }
            _ = await inFlight.task.value
            return await run(cacheKey: cacheKey, operation)
        }
        if let cached, cached.key == cacheKey, Date().timeIntervalSince(cached.date) < 1 { return cached.ports }
        let id = UUID()
        let task = Task { await operation() }
        inFlight = (id, cacheKey, task)
        let result = await task.value
        cached = (cacheKey, Date(), result)
        if inFlight?.id == id { inFlight = nil }
        return result
    }
}

public final class PortService {
    public static let shared = PortService()
    private let scanGate = PortScanGate()
    private let metricsLock = NSLock()
    private var storedScanMetrics = PortScanMetrics()
    private init() {}

    public var lastScanMetrics: PortScanMetrics {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return storedScanMetrics
    }

    private func updateScanMetrics(_ metrics: PortScanMetrics) {
        metricsLock.lock()
        storedScanMetrics = metrics
        metricsLock.unlock()
    }

    public static let devProcessNames: Set<String> = [
        "node", "bun", "deno", "npm", "yarn", "pnpm", "vite", "next",
        "next-server", "python", "python3", "django", "rails", "ruby", "php",
        "java", "cargo", "go", "air", "nodemon", "webpack", "esbuild",
        "turbo", "nuxt", "astro", "remix", "svelte", "nest", "flask",
        "uvicorn", "gunicorn", "fastapi", "uv", "poetry", "pipenv", "dotnet",
        "mvn", "gradle", "hypercorn", "granian", "daphne", "ts-node", "ts-node-dev",
        "tsx", "wrangler", "prisma", "mongod", "postgres", "redis-server",
        "mysqld", "mariadbd",
        "nginx", "caddy"
    ]

    public static func isDevProcess(name: String, command: String = "") -> Bool {
        let lowerName = name.lowercased().replacingOccurrences(of: ".exe", with: "")
        if devProcessNames.contains(lowerName) { return true }
        guard !command.isEmpty else { return false }
        let tokens = command.lowercased().split(whereSeparator: { $0.isWhitespace })
        for token in tokens {
            let base = token.split(separator: "/").last.map(String.init) ?? String(token)
            let cleaned = base.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if devProcessNames.contains(cleaned) { return true }
            if let dot = cleaned.firstIndex(of: ".") {
                let stem = String(cleaned[..<dot])
                if devProcessNames.contains(stem) { return true }
            }
        }
        return false
    }

    public func fetchListeningPorts() async -> [PortInfo] {
        let cacheKey = ConfigStore.shared.config.includeUDP ? "tcp+udp" : "tcp"
        return await scanGate.run(cacheKey: cacheKey) { [weak self] in
            await self?.performListeningPortScan() ?? []
        }
    }

    private func performListeningPortScan() async -> [PortInfo] {
        let scanStarted = Date()
        guard let output = await runLsof() else { return [] }
        let discoveryFinished = Date()
        let parsed = parseLsofOutput(output)
        if parsed.isEmpty { return [] }

        let pids = Array(Set(parsed.map(\.pid)))
        async let processLookup = fetchAllProcesses()
        async let cwdLookup = fetchCwds(for: pids)
        async let dockerLookup = DockerService.shared.fetchContainers()
        let (allProcs, cwdMap, dockerContainers) = await (processLookup, cwdLookup, dockerLookup)
        let metadataFinished = Date()

        var dockerByPort: [Int: DockerInfo] = [:]
        dockerByPort.reserveCapacity(dockerContainers.count)
        for container in dockerContainers {
            dockerByPort[container.publishedPort] = container
        }

        var results: [PortInfo] = []
        var seenKeys = Set<String>()

        for item in parsed {
            let key = "\(item.port)-\(item.pid)"
            if seenKeys.contains(key) { continue }
            seenKeys.insert(key)

            let rawProc = allProcs[item.pid]
            let cmd = rawProc?.command ?? item.process
            let cwd = cwdMap[item.pid] ?? rawProc?.cwd
            let cpu = rawProc?.cpuUsage ?? 0.0
            let memory = memoryUsage(pid: item.pid)

            let docker = dockerByPort[item.port]
            let appResolution = resolveApp(pid: item.pid, processName: item.process, command: cmd, docker: docker, allProcs: allProcs)
            let processRoot = Self.buildAncestry(pid: item.pid, allProcs: allProcs).last

            let ownBundleId = NSRunningApplication(processIdentifier: item.pid)?.bundleIdentifier ?? appFromProcPath(pid: item.pid)?.bundleId
            let isProtected = SystemPortProtection.isSystemProtected(
                pid: item.pid,
                processName: item.process,
                bundleIdentifier: ownBundleId,
                executablePath: appResolution.executablePath
            )

            if isProtected && docker == nil {
                continue
            }

            results.append(PortInfo(
                port: item.port,
                pid: item.pid,
                processName: item.process,
                appName: appResolution.appName,
                appBundleId: appResolution.bundleId,
                command: cmd,
                user: item.user,
                protocolName: item.proto,
                state: item.state,
                bindAddress: item.address,
                memoryBytes: memory,
                cpuUsage: cpu,
                cwd: cwd,
                docker: docker,
                isDevServer: PortService.isDevProcess(name: item.process, command: cmd),
                isSystemProtected: false,
                executablePath: appResolution.executablePath,
                processStartTime: processIdentity(pid: item.pid)?.startTime,
                processGroup: processRoot.map { "\($0.name) (\($0.pid))" }
            ))
        }

        results.sort {
            if $0.port == $1.port {
                return $0.pid < $1.pid
            }
            return $0.port < $1.port
        }
        let finished = Date()
        updateScanMetrics(PortScanMetrics(
            discovery: discoveryFinished.timeIntervalSince(scanStarted),
            metadata: metadataFinished.timeIntervalSince(discoveryFinished),
            assembly: finished.timeIntervalSince(metadataFinished),
            total: finished.timeIntervalSince(scanStarted)
        ))
        return results
    }

    public func refreshStats(for ports: [PortInfo]) async -> [PortInfo] {
        guard !ports.isEmpty else { return [] }
        let processes = await fetchAllProcesses()
        return ports.map { port in
            port.updatingStats(
                memoryBytes: memoryUsage(pid: port.pid),
                cpuUsage: processes[port.pid]?.cpuUsage ?? port.cpuUsage
            )
        }
    }

    @discardableResult
    public func killPort(_ port: PortInfo, force: Bool = false) async -> Bool {
        await killPort(port, mode: force ? .force : .terminate)
    }

    @discardableResult
    public func killPort(_ port: PortInfo, mode: TerminationMode) async -> Bool {
        await killPort(port, mode: mode, progress: { _ in })
    }

    @discardableResult
    public func killPort(
        _ port: PortInfo,
        mode: TerminationMode,
        progress: @escaping @Sendable (String) -> Void
    ) async -> Bool {
        progress("Sending \(mode.signalName)")
        if let docker = port.docker {
            let timeout = max(1, ConfigStore.shared.config.dockerStopTimeout)
            guard await DockerService.shared.stopContainer(
                containerId: docker.containerId,
                force: mode == .force,
                timeoutSeconds: timeout
            ) else { return false }
            progress("Waiting for Docker port release")
            return await waitUntilPortReleased(port.port, timeout: 5, retryListeners: false)
        }

        if port.isSystemProtected || SystemPortProtection.isSystemProtected(port: port) {
            return false
        }

        let expectedIdentity = ProcessIdentitySnapshot(
            pid: port.pid,
            executablePath: port.executablePath,
            startTime: port.processStartTime
        )
        guard processIdentityMatches(expectedIdentity) else { return false }

        if await stopHomebrewServiceIfNeeded(pid: port.pid) == true {
            progress("Waiting for Homebrew service to stop")
            return await waitUntilPortReleased(port.port, timeout: 8, retryListeners: false)
        }

        let treeDone = await terminateProcessTree(
            pid: port.pid,
            mode: mode,
            expectedIdentity: expectedIdentity,
            progress: progress
        )
        if !treeDone {
            guard await signalProcess(identity: expectedIdentity, mode: mode, progress: progress) else { return false }
        }
        progress("Verifying port release")
        return await waitUntilPortReleased(port.port, timeout: 5, retryListeners: false)
    }

    private func signalProcess(
        identity: ProcessIdentitySnapshot,
        mode: TerminationMode,
        progress: @escaping @Sendable (String) -> Void
    ) async -> Bool {
        guard processIdentityMatches(identity) else { return false }
        let signal = mode == .interrupt ? SIGINT : (mode == .force ? SIGKILL : SIGTERM)
        guard Darwin.kill(identity.pid, signal) == 0 else { return errno == ESRCH }
        if mode == .force { return true }
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Darwin.kill(identity.pid, 0) != 0 { return errno == ESRCH }
            guard processIdentityMatches(identity) else { return true }
        }
        guard processIdentityMatches(identity) else { return true }
        if mode == .interrupt {
            progress("Escalating to SIGTERM")
            _ = Darwin.kill(identity.pid, SIGTERM)
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Darwin.kill(identity.pid, 0) != 0 { return errno == ESRCH }
            guard processIdentityMatches(identity) else { return true }
        }
        progress("Escalating to SIGKILL")
        return Darwin.kill(identity.pid, SIGKILL) == 0 || errno == ESRCH
    }

    private func waitUntilPortReleased(
        _ port: Int,
        timeout: TimeInterval,
        retryListeners: Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var releasedSince: Date?
        var retryCount = 0

        while Date() < deadline {
            guard let listenerPids = await listeningPids(port: port) else {
                releasedSince = nil
                try? await Task.sleep(nanoseconds: 200_000_000)
                continue
            }

            if listenerPids.isEmpty {
                if let releasedSince, Date().timeIntervalSince(releasedSince) >= 0.75 {
                    return true
                }
                if releasedSince == nil { releasedSince = Date() }
            } else {
                releasedSince = nil
                if retryListeners {
                    let useForce = retryCount > 0
                    for pid in listenerPids {
                        _ = await terminateProcessTree(pid: pid, force: useForce)
                    }
                    retryCount += 1
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        guard let releasedSince else { return false }
        return Date().timeIntervalSince(releasedSince) >= 0.75
    }

    private func listeningPids(port: Int) async -> Set<pid_t>? {
        guard port > 0, port <= 65535 else { return nil }
        guard let out = await runLsofListeningPids(port: port) else { return nil }
        return Set(out.split(whereSeparator: { $0.isWhitespace }).compactMap { pid_t(String($0)) })
    }

    private func runLsofListeningPids(port: Int) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                proc.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private struct HomebrewServiceRecord: Decodable {
        let name: String
        let file: String?
    }

    private static let homebrewServiceProcessNames: Set<String> = [
        "mongod", "postgres", "redis-server", "mysqld", "mariadbd",
        "nginx", "caddy", "httpd", "memcached", "rabbitmq-server"
    ]

    private func stopHomebrewServiceIfNeeded(pid: pid_t) async -> Bool? {
        guard let executablePath = executablePath(pid: pid),
              executablePath.hasPrefix("/opt/homebrew/") || executablePath.hasPrefix("/usr/local/"),
              Self.homebrewServiceProcessNames.contains(URL(fileURLWithPath: executablePath).lastPathComponent) else {
            return nil
        }

        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }),
              let serviceData = await runCommandData(
                executable: brewPath,
                arguments: ["services", "list", "--json"]
              ),
              let services = try? JSONDecoder().decode([HomebrewServiceRecord].self, from: serviceData) else {
            return nil
        }

        for service in services {
            guard let plistPath = service.file,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dictionary = plist as? [String: Any],
                  let arguments = dictionary["ProgramArguments"] as? [String],
                  Self.homebrewServiceMatches(executablePath: executablePath, arguments: arguments) else {
                continue
            }

            return await runCommandData(
                executable: brewPath,
                arguments: ["services", "stop", service.name]
            ) != nil
        }
        return nil
    }

    static func homebrewServiceMatches(executablePath: String, arguments: [String]) -> Bool {
        guard let serviceExecutable = arguments.first, !serviceExecutable.isEmpty else { return false }
        let isHomebrewProcess = executablePath.hasPrefix("/opt/homebrew/")
            || executablePath.hasPrefix("/usr/local/")
        let isHomebrewService = serviceExecutable.hasPrefix("/opt/homebrew/")
            || serviceExecutable.hasPrefix("/usr/local/")
        guard isHomebrewProcess, isHomebrewService else { return false }

        let runningURL = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath()
        let serviceURL = URL(fileURLWithPath: serviceExecutable).resolvingSymlinksInPath()
        if runningURL.path == serviceURL.path { return true }

        guard let runningFormula = homebrewFormulaName(for: runningURL.path),
              let serviceFormula = homebrewFormulaName(for: serviceURL.path) else { return false }
        return runningFormula == serviceFormula
    }

    private static func homebrewFormulaName(for path: String) -> String? {
        let parts = path.split(separator: "/")
        if let cellarIndex = parts.firstIndex(of: "Cellar"), parts.count > cellarIndex + 1 {
            return String(parts[cellarIndex + 1])
        }
        if let optIndex = parts.firstIndex(of: "opt"), parts.count > optIndex + 1 {
            return String(parts[optIndex + 1])
        }
        return nil
    }

    private func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private func processIdentity(pid: pid_t) -> ProcessIdentitySnapshot? {
        guard pid > 1 else { return nil }
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.stride
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == Int32(size) else {
            return nil
        }
        let seconds = UInt64(info.pbi_start_tvsec)
        let microseconds = UInt64(info.pbi_start_tvusec)
        return ProcessIdentitySnapshot(
            pid: pid,
            executablePath: executablePath(pid: pid),
            startTime: seconds &* 1_000_000 &+ microseconds
        )
    }

    private func processIdentityMatches(_ expected: ProcessIdentitySnapshot) -> Bool {
        guard let current = processIdentity(pid: expected.pid) else { return false }
        return Self.identitiesMatch(expected: expected, current: current)
    }

    static func identitiesMatch(expected: ProcessIdentitySnapshot, current: ProcessIdentitySnapshot) -> Bool {
        guard expected.pid == current.pid else { return false }
        if let path = expected.executablePath, current.executablePath != path { return false }
        if let start = expected.startTime, current.startTime != start { return false }
        return true
    }

    private func runCommandData(executable: String, arguments: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let output = Pipe()
                process.standardOutput = output
                process.standardError = output

                do {
                    try process.run()
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @discardableResult
    public func killMultiplePorts(_ ports: [PortInfo], force: Bool = false) async -> Int {
        var unique: [String: PortInfo] = [:]
        for port in ports {
            let key = port.docker.map { "docker:\($0.containerId)" } ?? "pid:\(port.pid)"
            unique[key] = unique[key] ?? port
        }
        let targets = Array(unique.values)
        var success = 0
        for start in stride(from: 0, to: targets.count, by: 4) {
            let batch = Array(targets[start..<min(start + 4, targets.count)])
            success += await withTaskGroup(of: Bool.self) { group in
                for port in batch {
                    group.addTask { await self.killPort(port, force: force) }
                }
                var count = 0
                for await result in group where result { count += 1 }
                return count
            }
        }
        return success
    }

    public func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo] {
        let allProcs = await fetchAllProcesses()
        return Self.buildAncestry(pid: pid, allProcs: allProcs)
    }

    static func buildAncestry(pid: pid_t, allProcs: [pid_t: RawProcessItem]) -> [ProcessTreeNodeInfo] {
        var ancestry: [ProcessTreeNodeInfo] = []
        var seen = Set<pid_t>()

        var curr: pid_t? = pid
        while let currentPid = curr, currentPid > 1, !seen.contains(currentPid) {
            seen.insert(currentPid)
            guard let raw = allProcs[currentPid] else { break }

            let isListener = currentPid == pid
            ancestry.append(ProcessTreeNodeInfo(
                pid: raw.pid,
                ppid: raw.ppid,
                name: raw.name,
                command: raw.command,
                user: raw.user,
                isListener: isListener,
                cwd: raw.cwd,
                startTime: raw.startTime
            ))

            if !isListener && PortService.isHostBoundary(pid: raw.pid, name: raw.name, command: raw.command) {
                break
            }

            if raw.ppid <= 1 {
                break
            }

            if let parent = allProcs[raw.ppid] {
                if PortService.isHostBoundary(pid: parent.pid, name: parent.name, command: parent.command) {
                    break
                }
            } else {
                if raw.ppid <= 1 || SystemPortProtection.isSystemProtected(pid: raw.ppid) {
                    break
                }
            }

            curr = raw.ppid
        }

        return ancestry
    }

    @discardableResult
    public func terminateProcessTree(pid: pid_t, force: Bool = false) async -> Bool {
        let identity = processIdentity(pid: pid)
        guard let identity else { return false }
        return await terminateProcessTree(
            pid: pid,
            mode: force ? .force : .terminate,
            expectedIdentity: identity,
            progress: { _ in }
        )
    }

    private func terminateProcessTree(
        pid: pid_t,
        mode: TerminationMode,
        expectedIdentity: ProcessIdentitySnapshot,
        progress: @escaping @Sendable (String) -> Void
    ) async -> Bool {
        guard pid > 1, pid != ProcessInfo.processInfo.processIdentifier else { return false }
        guard processIdentityMatches(expectedIdentity) else { return false }
        if SystemPortProtection.isSystemProtected(pid: pid) {
            return false
        }

        let allProcs = await fetchAllProcesses()
        let ancestry = Self.buildAncestry(pid: pid, allProcs: allProcs)

        let rootPid = getSupervisorRootPid(ancestry: ancestry) ?? pid
        if rootPid <= 1 || SystemPortProtection.isSystemProtected(pid: rootPid) {
            return false
        }
        if let rootProc = allProcs[rootPid], PortService.isHostBoundary(pid: rootPid, name: rootProc.name, command: rootProc.command) {
            return false
        }

        let descendants = getAllDescendantPids(rootPid: rootPid, procs: allProcs)
        var allPids = [rootPid] + descendants
        if !allPids.contains(pid) {
            allPids.append(pid)
        }

        allPids = allPids.filter { p in
            guard p > 1, p != ProcessInfo.processInfo.processIdentifier else { return false }
            guard !SystemPortProtection.isSystemProtected(pid: p) else { return false }
            let name = allProcs[p]?.name ?? ""
            let cmd = allProcs[p]?.command ?? ""
            guard !PortService.isHostBoundary(pid: p, name: name, command: cmd) else { return false }
            return true
        }

        guard !allPids.isEmpty else { return false }

        let reversed = Array(allPids.reversed())
        let sig = mode == .interrupt ? SIGINT : (mode == .force ? SIGKILL : SIGTERM)
        let identities = Dictionary(uniqueKeysWithValues: reversed.compactMap { processIdentity(pid: $0).map { ($0.pid, $0) } })

        var signalledAny = false
        for p in reversed {
            guard let identity = identities[p], processIdentityMatches(identity) else { continue }
            if Darwin.kill(p, sig) == 0 || errno == ESRCH {
                signalledAny = true
            }
        }

        if mode != .force {
            var anyAlive = false
            for _ in 0..<8 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                anyAlive = reversed.contains { Darwin.kill($0, 0) == 0 }
                if !anyAlive { break }
            }
            if anyAlive {
                if mode == .interrupt {
                    progress("Escalating process tree to SIGTERM")
                    for p in reversed {
                        guard let identity = identities[p], processIdentityMatches(identity) else { continue }
                        _ = Darwin.kill(p, SIGTERM)
                    }
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    anyAlive = reversed.contains { Darwin.kill($0, 0) == 0 }
                }
            }
            if anyAlive {
                progress("Escalating process tree to SIGKILL")
                for p in reversed {
                    guard let identity = identities[p], processIdentityMatches(identity) else { continue }
                    if Darwin.kill(p, SIGKILL) == 0 || errno == ESRCH {
                        signalledAny = true
                    }
                }
            }
        }

        return signalledAny
    }

    struct RawParsedLsof: Equatable {
        var pid: pid_t = 0
        var port: Int = 0
        var process: String = "unknown"
        var user: String = ""
        var proto: String = "TCP"
        var state: String = "LISTEN"
        var address: String = "*"
    }

    func parseLsofOutput(_ output: String) -> [RawParsedLsof] {
        var results: [RawParsedLsof] = []
        var current = RawParsedLsof()

        let flush = {
            if current.pid > 0 && current.port > 0 {
                results.append(current)
            }
            current.port = 0
        }

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let tag = trimmed.prefix(1)
            let val = String(trimmed.dropFirst())

            switch tag {
            case "p":
                flush()
                current = RawParsedLsof()
                current.pid = pid_t(val) ?? 0
            case "c":
                current.process = val
            case "L":
                current.user = val
            case "n":
                flush()
                current.port = portFromAddress(val)
                current.address = bindAddress(from: val)
            case "T":
                if val.hasPrefix("ST=") {
                    current.state = String(val.dropFirst(3)).uppercased()
                }
            case "P":
                current.proto = val.uppercased()
            default:
                break
            }
        }
        flush()
        return results
    }

    private func portFromAddress(_ address: String) -> Int {
        guard let idx = address.lastIndex(of: ":") else { return 0 }
        let raw = address[address.index(after: idx)...]
            .replacingOccurrences(of: " (LISTEN)", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Int(raw) ?? 0
    }

    private func bindAddress(from value: String) -> String {
        guard let index = value.lastIndex(of: ":") else { return "*" }
        var address = String(value[..<index])
        if address.hasPrefix("[") && address.hasSuffix("]") {
            address.removeFirst()
            address.removeLast()
        }
        return address.isEmpty ? "*" : address
    }

    private func runLsof() async -> String? {
        let includeUDP = ConfigStore.shared.config.includeUDP
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                var arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
                if includeUDP { arguments.append("-iUDP") }
                arguments.append("-FpcLntTP")
                proc.arguments = arguments
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func fetchCwds(for pids: [pid_t]) async -> [pid_t: String] {
        guard !pids.isEmpty else { return [:] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                let pidArgs = pids.map { "\($0)" }.joined(separator: ",")
                proc.arguments = ["-a", "-p", pidArgs, "-d", "cwd", "-Fn"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                var map: [pid_t: String] = [:]
                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    if let text = String(data: data, encoding: .utf8) {
                        var currentPid: pid_t = 0
                        for line in text.components(separatedBy: "\n") {
                            if line.hasPrefix("p"), let p = pid_t(line.dropFirst()) {
                                currentPid = p
                            } else if line.hasPrefix("n"), currentPid > 0 {
                                map[currentPid] = String(line.dropFirst())
                            }
                        }
                    }
                    continuation.resume(returning: map)
                } catch {
                    continuation.resume(returning: [:])
                }
            }
        }
    }

    struct RawProcessItem {
        let pid: pid_t
        let ppid: pid_t
        let user: String
        let name: String
        let command: String
        let cpuUsage: Double
        var cwd: String?
        var startTime: String?
    }

    private func fetchAllProcesses() async -> [pid_t: RawProcessItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/ps")
                proc.arguments = ["-axo", "pid=,ppid=,user=,pcpu=,args="]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                var map: [pid_t: RawProcessItem] = [:]
                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: "\n")
                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { continue }
                            let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
                            if parts.count >= 5,
                               let pid = pid_t(parts[0]),
                               let ppid = pid_t(parts[1]) {
                                let user = String(parts[2])
                                let cpu = Double(parts[3]) ?? 0
                                let command = String(parts[4]).trimmingCharacters(in: .whitespaces)
                                let name = PortService.processName(pid: pid, fallbackCommand: command)

                                map[pid] = RawProcessItem(
                                    pid: pid,
                                    ppid: ppid,
                                    user: user,
                                    name: name,
                                    command: command.isEmpty ? name : command,
                                    cpuUsage: cpu,
                                    cwd: nil,
                                    startTime: nil
                                )
                            }
                        }
                    }
                    continuation.resume(returning: map)
                } catch {
                    continuation.resume(returning: [:])
                }
            }
        }
    }

    private static func processName(pid: pid_t, fallbackCommand: String) -> String {
        var buffer = [CChar](repeating: 0, count: 1024)
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 {
            return String(cString: buffer)
        }

        guard let executable = fallbackCommand.split(whereSeparator: { $0.isWhitespace }).first else {
            return "unknown"
        }
        return URL(fileURLWithPath: String(executable)).lastPathComponent
    }

    private func getSupervisorRootPid(ancestry: [ProcessTreeNodeInfo]) -> pid_t? {
        guard !ancestry.isEmpty else { return nil }

        var supervisorPid = ancestry[0].pid
        for node in ancestry {
            if PortService.isHostBoundary(pid: node.pid, name: node.name, command: node.command) {
                break
            }
            supervisorPid = node.pid
        }
        if let first = ancestry.first(where: { $0.pid == supervisorPid }),
           PortService.isHostBoundary(pid: supervisorPid, name: first.name, command: first.command) {
            return ancestry[0].pid
        }
        return supervisorPid
    }

    private func getAllDescendantPids(rootPid: pid_t, procs: [pid_t: RawProcessItem]) -> [pid_t] {
        var childrenMap: [pid_t: [pid_t]] = [:]
        childrenMap.reserveCapacity(procs.count)
        for (pid, proc) in procs {
            childrenMap[proc.ppid, default: []].append(pid)
        }

        var pids: [pid_t] = []
        var queue = [rootPid]
        var seen = Set<pid_t>([rootPid])

        var queueIndex = 0
        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            guard let children = childrenMap[current] else { continue }
            for pid in children where !seen.contains(pid) {
                seen.insert(pid)
                pids.append(pid)
                queue.append(pid)
            }
        }
        return pids
    }

    public static func isShell(_ name: String) -> Bool {
        let n = name.lowercased()
        return ["sh", "bash", "zsh", "fish", "csh", "tcsh", "dash", "ksh", "nu", "elvish"].contains(n)
    }

    public static func isTerminalOrMultiplexer(_ name: String) -> Bool {
        let n = name.lowercased()
        return [
            "terminal", "iterm", "iterm2", "alacritty", "kitty", "wezterm",
            "hyper", "warp", "rio", "ghostty", "tabby", "tmux", "screen",
            "launchd", "init", "systemd", "login", "sshd"
        ].contains(n)
    }

    public static func isIDEOrEditor(_ name: String, command: String = "") -> Bool {
        SystemPortProtection.isEditorHelperProcess(name: name, command: command)
            || SystemPortProtection.isAppBundleExecutable(command)
    }

    public static func isGUIApplication(pid: pid_t) -> Bool {
        guard pid > 1 else { return false }
        if let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier != nil {
            return true
        }
        var buffer = [CChar](repeating: 0, count: 4096)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if ret > 0 {
            let path = String(cString: buffer)
            if path.contains(".app/") {
                return true
            }
        }
        return false
    }

    public static func isHostBoundary(pid: pid_t, name: String, command: String = "") -> Bool {
        if pid <= 1 { return true }
        if isShell(name) { return true }
        if isTerminalOrMultiplexer(name) { return true }
        if isIDEOrEditor(name, command: command) { return true }
        if SystemPortProtection.isSystemProtected(pid: pid, processName: name, bundleIdentifier: nil, executablePath: nil) {
            return true
        }

         var buffer = [CChar](repeating: 0, count: 4096)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if ret > 0 {
            let path = String(cString: buffer)
            if isIDEOrEditor((path as NSString).lastPathComponent, command: path) {
                return true
            }
            if SystemPortProtection.isSystemProtected(pid: pid, processName: name, bundleIdentifier: nil, executablePath: path) {
                return true
            }
        }

        if isGUIApplication(pid: pid) { return true }
        return false
    }

    private func memoryUsage(pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        if result == Int32(size) {
            return UInt64(info.pti_resident_size)
        }
        return 0
    }

    public struct AppResolution: Sendable {
        public let appName: String
        public let bundleId: String?
        public let executablePath: String?

        public init(appName: String, bundleId: String? = nil, executablePath: String? = nil) {
            self.appName = appName
            self.bundleId = bundleId
            self.executablePath = executablePath
        }
    }

    func resolveApp(
        pid: pid_t,
        processName: String,
        command: String = "",
        docker: DockerInfo? = nil,
        allProcs: [pid_t: RawProcessItem]? = nil
    ) -> AppResolution {
        var execPath: String? = nil
        var buffer = [CChar](repeating: 0, count: 4096)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if ret > 0 {
            execPath = String(cString: buffer)
        }

        if let docker {
            let name = docker.name.isEmpty ? "Docker" : "Docker (\(docker.name))"
            return AppResolution(appName: name, bundleId: "com.docker.docker", executablePath: execPath)
        }

        if PortService.isDevProcess(name: processName, command: command) {
            let cleanName = cleanRuntimeName(processName: processName, command: command)
            return AppResolution(appName: cleanName, bundleId: nil, executablePath: execPath)
        }

        if let running = NSRunningApplication(processIdentifier: pid),
           let name = running.localizedName, !name.isEmpty {
            return AppResolution(appName: name, bundleId: running.bundleIdentifier, executablePath: execPath ?? running.executableURL?.path)
        }

        if let app = appFromProcPath(pid: pid) {
            return app
        }

        if let procs = allProcs {
            var curr = pid
            var seen = Set<pid_t>()
            while curr > 1 && !seen.contains(curr) {
                seen.insert(curr)
                guard let item = procs[curr] else { break }
                let parentPid = item.ppid
                if parentPid <= 1 { break }

                if PortService.isShell(item.name) || PortService.isTerminalOrMultiplexer(item.name) || PortService.isIDEOrEditor(item.name, command: item.command) {
                    break
                }
                if let parentProc = procs[parentPid] {
                    if PortService.isShell(parentProc.name) || PortService.isTerminalOrMultiplexer(parentProc.name) || PortService.isIDEOrEditor(parentProc.name, command: parentProc.command) {
                        break
                    }
                }

                if let running = NSRunningApplication(processIdentifier: parentPid),
                   let name = running.localizedName, !name.isEmpty {
                    return AppResolution(appName: name, bundleId: running.bundleIdentifier, executablePath: execPath ?? running.executableURL?.path)
                }

                if let app = appFromProcPath(pid: parentPid) {
                    return app
                }

                curr = parentPid
            }
        }

        let cleanName = cleanRuntimeName(processName: processName, command: command)
        return AppResolution(appName: cleanName, bundleId: nil, executablePath: execPath)
    }

    private func appFromProcPath(pid: pid_t) -> AppResolution? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard ret > 0 else { return nil }
        let path = String(cString: buffer)
        guard let appRange = path.range(of: ".app") else { return nil }

        let appBundlePath = String(path[..<appRange.upperBound])
        if let bundle = Bundle(path: appBundlePath) {
            let bundleId = bundle.bundleIdentifier
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? URL(fileURLWithPath: appBundlePath).deletingPathExtension().lastPathComponent
            return AppResolution(appName: name, bundleId: bundleId, executablePath: path)
        }
        let fallbackName = URL(fileURLWithPath: appBundlePath).deletingPathExtension().lastPathComponent
        return AppResolution(appName: fallbackName, bundleId: nil, executablePath: path)
    }

    private func cleanRuntimeName(processName: String, command: String) -> String {
        let lower = processName.lowercased()
        switch lower {
        case "node": return "Node.js"
        case "bun": return "Bun"
        case "deno": return "Deno"
        case "python", "python3": return "Python"
        case "postgres": return "PostgreSQL"
        case "redis-server": return "Redis"
        case "mongod": return "MongoDB"
        case "mysqld": return "MySQL"
        case "nginx": return "Nginx"
        case "caddy": return "Caddy"
        case "cargo": return "Cargo"
        case "go": return "Go"
        case "ruby": return "Ruby"
        case "java": return "Java"
        case "php": return "PHP"
        case "docker", "com.docker.backend": return "Docker"
        default:
            return processName
        }
    }
}
