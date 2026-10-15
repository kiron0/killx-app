import Foundation

public final class DockerService {
    public static let shared = DockerService()
    private init() {}

    private let lock = NSLock()
    private var cachedContainers: [DockerInfo] = []
    private var lastFetch: Date?
    private var dockerUnavailableUntil: Date?

    private func readCache() -> (containers: [DockerInfo], last: Date)? {
        lock.lock()
        defer { lock.unlock() }
        guard let last = lastFetch else { return nil }
        return (cachedContainers, last)
    }

    private func writeCache(_ containers: [DockerInfo]) {
        lock.lock()
        defer { lock.unlock() }
        cachedContainers = containers
        lastFetch = Date()
    }

    private func clearUnavailableMarker() {
        lock.lock()
        defer { lock.unlock() }
        dockerUnavailableUntil = nil
    }

    private func invalidateCache() {
        lock.lock()
        defer { lock.unlock() }
        lastFetch = nil
        dockerUnavailableUntil = nil
    }

    private func unavailableUntil() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return dockerUnavailableUntil
    }

    private func markUnavailable(seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        dockerUnavailableUntil = Date().addingTimeInterval(seconds)
    }

    public func fetchContainers(forceRefresh: Bool = false) async -> [DockerInfo] {
        if !forceRefresh, let cache = readCache(), Date().timeIntervalSince(cache.last) < 2.0 {
            return cache.containers
        }
        if !forceRefresh, let until = unavailableUntil(), Date() < until {
            return readCache()?.containers ?? []
        }

        let paths = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "docker"]
        var output: String?
        var binaryPresent = false
        for path in paths {
            if path.hasPrefix("/") {
                guard FileManager.default.isExecutableFile(atPath: path) else { continue }
                binaryPresent = true
            }
            output = await runCommand(executable: path, arguments: ["ps", "--format", "{{json .}}"])
            if output != nil { break }
        }

        guard let output = output, !output.isEmpty else {
            markUnavailable(seconds: binaryPresent ? 15 : 120)
            writeCache([])
            return []
        }

        var list: [DockerInfo] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let id = (obj["ID"] as? String) ?? (obj["Id"] as? String) ?? ""
                let name = (obj["Names"] as? String) ?? id
                let image = (obj["Image"] as? String) ?? "unknown"
                let ports = (obj["Ports"] as? String) ?? ""

                let published = extractPorts(from: ports)
                for port in published {
                    list.append(DockerInfo(
                        containerId: id,
                        name: name,
                        image: image,
                        ports: ports,
                        publishedPort: port
                    ))
                }
            }
        }

        clearUnavailableMarker()
        writeCache(list)
        return list
    }

    public func findContainer(for port: Int) async -> DockerInfo? {
        let containers = await fetchContainers()
        return containers.first(where: { $0.publishedPort == port })
    }

    public func stopContainer(containerId: String, force: Bool = false, timeoutSeconds: Int = 5) async -> Bool {
        let dockerPath = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "docker"].first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) ?? "docker"

        let args: [String]
        if force {
            args = ["kill", containerId]
        } else {
            args = ["stop", "-t", "\(timeoutSeconds)", containerId]
        }

        let result = await runCommand(executable: dockerPath, arguments: args)
        if result != nil { invalidateCache() }
        return result != nil
    }

    private func extractPorts(from portsStr: String) -> [Int] {
        guard !portsStr.isEmpty else { return [] }
        var result: [Int] = []
        let mappings = portsStr.components(separatedBy: ",")
        for mapping in mappings {
            let trimmed = mapping.trimmingCharacters(in: .whitespaces)
            guard let arrowRange = trimmed.range(of: "->") else { continue }
            let hostPart = String(trimmed[..<arrowRange.lowerBound])
            if let lastColon = hostPart.lastIndex(of: ":") {
                let portSpec = String(hostPart[hostPart.index(after: lastColon)...])
                if portSpec.contains("-") {
                    let parts = portSpec.components(separatedBy: "-")
                    if parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]), start <= end {
                        for p in start...end { result.append(p) }
                    }
                } else if let p = Int(portSpec) {
                    result.append(p)
                }
            }
        }
        return result
    }

    private func runCommand(executable: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                if executable.hasPrefix("/") {
                    process.executableURL = URL(fileURLWithPath: executable)
                } else {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [executable] + arguments
                }
                if process.arguments == nil || process.arguments?.isEmpty == true {
                    process.arguments = arguments
                }

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        let str = String(data: data, encoding: .utf8)
                        continuation.resume(returning: str)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
