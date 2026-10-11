import Foundation
import AppKit
import Darwin

public final class PortService {
    public static let shared = PortService()
    private init() {}

    public static let devProcessNames: Set<String> = [
        "node", "bun", "deno", "npm", "yarn", "pnpm", "vite", "next",
        "next-server", "python", "python3", "django", "rails", "ruby", "php",
        "java", "cargo", "go", "air", "nodemon", "webpack", "esbuild",
        "turbo", "nuxt", "astro", "remix", "svelte", "nest", "flask",
        "uvicorn", "gunicorn", "fastapi", "uv", "poetry", "pipenv", "dotnet",
        "mvn", "gradle", "hypercorn", "granian", "daphne", "ts-node", "ts-node-dev",
        "tsx", "wrangler", "prisma"
    ]

    public static func isDevProcess(name: String, command: String = "") -> Bool {
        let lowerName = name.lowercased().replacingOccurrences(of: ".exe", with: "")
        if devProcessNames.contains(lowerName) { return true }
        let lowerCmd = command.lowercased()
        for devName in devProcessNames {
            if lowerCmd.contains(devName) { return true }
        }
        return false
    }

    public func fetchListeningPorts() async -> [PortInfo] {
        guard let output = await runLsof() else { return [] }
        let parsed = parseLsofOutput(output)
        if parsed.isEmpty { return [] }

        let pids = Array(Set(parsed.map(\.pid)))
        let commandMap = await fetchCommandLines(for: pids)
        let cwdMap = await fetchCwds(for: pids)
        let cpuMap = fetchCpuUsages()
        let dockerContainers = await DockerService.shared.fetchContainers()
        let allProcs = await fetchAllProcesses()

        var results: [PortInfo] = []
        var seenKeys = Set<String>()

        for item in parsed {
            let key = "\(item.port)-\(item.pid)"
            if seenKeys.contains(key) { continue }
            seenKeys.insert(key)

            let cmd = commandMap[item.pid] ?? item.process
            let cwd = cwdMap[item.pid]
            let cpu = cpuMap[item.pid] ?? 0.0
            let memory = memoryUsage(pid: item.pid)

            let docker = dockerContainers.first(where: { $0.publishedPort == item.port })
            let appResolution = resolveApp(pid: item.pid, processName: item.process, command: cmd, docker: docker, allProcs: allProcs)

            let isProtected = SystemPortProtection.isSystemProtected(
                pid: item.pid,
                processName: item.process,
                bundleIdentifier: appResolution.bundleId,
                executablePath: appResolution.executablePath
            )

            if isProtected {
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
                memoryBytes: memory,
                cpuUsage: cpu,
                cwd: cwd,
                docker: docker,
                isDevServer: PortService.isDevProcess(name: item.process, command: cmd),
                isSystemProtected: false
            ))
        }

        results.sort {
            if $0.port == $1.port {
                return $0.pid < $1.pid
            }
            return $0.port < $1.port
        }
        return results
    }

    @discardableResult
    public func killPort(_ port: PortInfo, force: Bool = false, tree: Bool = false) async -> Bool {
        if port.isSystemProtected || SystemPortProtection.isSystemProtected(port: port) {
            return false
        }

        if let docker = port.docker {
            return await DockerService.shared.stopContainer(containerId: docker.containerId, force: force)
        }

        let shouldKillTree = tree || ConfigStore.shared.config.treeKillByDefault || PortService.isDevProcess(name: port.processName, command: port.command)
        if shouldKillTree {
            return await terminateProcessTree(pid: port.pid, force: force)
        }

        let sig = force ? SIGKILL : SIGTERM
        let res = Darwin.kill(port.pid, sig)
        if res == 0 {
            if !force {
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Darwin.kill(port.pid, 0) != 0 { return true }
                }
                _ = Darwin.kill(port.pid, SIGKILL)
            }
            return true
        }
        return false
    }

    @discardableResult
    public func killMultiplePorts(_ ports: [PortInfo], force: Bool = false, tree: Bool = false) async -> Int {
        var killedCount = 0
        for port in ports {
            let ok = await killPort(port, force: force, tree: tree)
            if ok { killedCount += 1 }
        }
        return killedCount
    }

    public func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo] {
        let allProcs = await fetchAllProcesses()
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

            // Stop climbing if current node is a host boundary (shell, terminal, IDE, GUI app)
            if !isListener && PortService.isHostBoundary(pid: raw.pid, name: raw.name, command: raw.command) {
                break
            }

            if raw.ppid <= 1 {
                break
            }

            // Stop before ascending into IDE, GUI app, or system protected parent
            if let parent = allProcs[raw.ppid] {
                if PortService.isIDEOrEditor(parent.name, command: parent.command) ||
                   PortService.isGUIApplication(pid: parent.pid) ||
                   SystemPortProtection.isSystemProtected(pid: parent.pid, processName: parent.name) {
                    break
                }
            }

            curr = raw.ppid
        }

        return ancestry
    }

    @discardableResult
    public func terminateProcessTree(pid: pid_t, force: Bool = false) async -> Bool {
        guard pid > 1, pid != ProcessInfo.processInfo.processIdentifier else { return false }
        if SystemPortProtection.isSystemProtected(pid: pid) {
            return false
        }

        let allProcs = await fetchAllProcesses()
        let ancestry = await traceProcessTree(pid: pid)

        let rootPid = getSupervisorRootPid(ancestry: ancestry) ?? pid
        if SystemPortProtection.isSystemProtected(pid: rootPid) {
            return false
        }
        let descendants = getAllDescendantPids(rootPid: rootPid, procs: allProcs)
        var allPids = [rootPid] + descendants
        if !allPids.contains(pid) {
            allPids.append(pid)
        }

        // HARD SAFETY FILTER: Never terminate shells, terminals, IDEs, GUI apps, or system processes!
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
        let sig = force ? SIGKILL : SIGTERM

        for p in reversed {
            Darwin.kill(p, sig)
        }

        if !force {
            var anyAlive = false
            for _ in 0..<8 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                anyAlive = reversed.contains { Darwin.kill($0, 0) == 0 }
                if !anyAlive { break }
            }
            if anyAlive {
                for p in reversed {
                    Darwin.kill(p, SIGKILL)
                }
            }
        }

        return true
    }

    private struct RawParsedLsof {
        var pid: pid_t = 0
        var port: Int = 0
        var process: String = "unknown"
        var user: String = ""
        var proto: String = "TCP"
        var state: String = "LISTEN"
    }

    private func parseLsofOutput(_ output: String) -> [RawParsedLsof] {
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
            case "T":
                if val.hasPrefix("ST=") {
                    current.state = String(val.dropFirst(3)).uppercased()
                }
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

    private func runLsof() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                proc.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcLntT"]
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

    private func fetchCommandLines(for pids: [pid_t]) async -> [pid_t: String] {
        guard !pids.isEmpty else { return [:] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/ps")
                proc.arguments = ["-eo", "pid,command"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                var map: [pid_t: String] = [:]
                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    if let text = String(data: data, encoding: .utf8) {
                        for line in text.components(separatedBy: "\n") {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                            if parts.count >= 2, let pid = pid_t(parts[0]) {
                                map[pid] = String(parts[1])
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
        var cwd: String?
        var startTime: String?
    }

    private func fetchAllProcesses() async -> [pid_t: RawProcessItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/ps")
                proc.arguments = ["-eo", "pid,ppid,user,comm,command"]
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
                        for line in lines.dropFirst() {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
                            if parts.count >= 4,
                               let pid = pid_t(parts[0]),
                               let ppid = pid_t(parts[1]) {
                                let user = String(parts[2])
                                let comm = String(parts[3])
                                let name = (comm as NSString).lastPathComponent
                                let command = parts.dropFirst(4).joined(separator: " ")
                                map[pid] = RawProcessItem(
                                    pid: pid,
                                    ppid: ppid,
                                    user: user,
                                    name: name,
                                    command: command.isEmpty ? name : command,
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

    private func getSupervisorRootPid(ancestry: [ProcessTreeNodeInfo]) -> pid_t? {
        guard !ancestry.isEmpty else { return nil }

        // Start from listener (index 0) and climb up towards parents as long as it's a dev process.
        // Stop before any shell, terminal, IDE, GUI app, or system host boundary.
        var supervisorPid = ancestry[0].pid
        for node in ancestry {
            if PortService.isHostBoundary(pid: node.pid, name: node.name, command: node.command) {
                break
            }
            supervisorPid = node.pid
        }
        return supervisorPid
    }

    private func getAllDescendantPids(rootPid: pid_t, procs: [pid_t: RawProcessItem]) -> [pid_t] {
        var pids: [pid_t] = []
        var queue = [rootPid]
        var seen = Set<pid_t>([rootPid])

        while !queue.isEmpty {
            let current = queue.removeFirst()
            for (pid, proc) in procs {
                if proc.ppid == current && !seen.contains(pid) {
                    seen.insert(pid)
                    pids.append(pid)
                    queue.append(pid)
                }
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
        let lowerName = name.lowercased()
        let lowerCmd = command.lowercased()

        // Exact process-name matches for known IDE executables
        let exactNames: Set<String> = [
            "zed", "xcode", "sublime_text", "idea", "pycharm", "webstorm",
            "goland", "clion", "phpstorm", "rider", "rubymine", "fleet",
            "eclipse", "atom", "ptyhost", "cursor", "windsurf"
        ]
        if exactNames.contains(lowerName) { return true }

        // Prefix/substring matches safe enough to avoid false positives
        let namePrefixes = ["antigravity", "vscode", "code helper"]
        for prefix in namePrefixes {
            if lowerName.hasPrefix(prefix) { return true }
        }

        // Electron = host boundary only when the command path is inside a known IDE .app bundle
        // Standalone user Electron apps (Slack, Discord, Figma) are NOT treated as boundaries.
        let ideBundlePaths = [
            "antigravity ide.app", "cursor.app", "visual studio code.app", "code.app",
            "zed.app", "windsurf.app", "fleet.app", "webstorm.app", "pycharm.app",
            "goland.app", "clion.app", "phpstorm.app", "rider.app", "rubymine.app",
            "idea.app", "xcode.app"
        ]
        for bundlePath in ideBundlePaths {
            if lowerCmd.contains(bundlePath) { return true }
        }

        return false
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
        if isGUIApplication(pid: pid) { return true }
        if SystemPortProtection.isSystemProtected(pid: pid, processName: name) { return true }
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

    private func fetchCpuUsages() -> [pid_t: Double] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "pid,%cpu"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        var usages: [pid_t: Double] = [:]
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count >= 2, let pid = pid_t(parts[0]), let cpu = Double(parts[1]) {
                        usages[pid] = cpu
                    }
                }
            }
        } catch {}
        return usages
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
