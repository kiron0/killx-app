import Foundation

public final class DockerService {
    public static let shared = DockerService()
    private init() {}

    private var cachedContainers: [DockerInfo] = []
    private var lastFetch: Date?

    public func fetchContainers(forceRefresh: Bool = false) async -> [DockerInfo] {
        if !forceRefresh, let last = lastFetch, Date().timeIntervalSince(last) < 2.0 {
            return cachedContainers
        }

        var output = await runCommand(executable: "/usr/local/bin/docker", arguments: ["ps", "--format", "{{json .}}"])
        if output == nil {
            output = await runCommand(executable: "/opt/homebrew/bin/docker", arguments: ["ps", "--format", "{{json .}}"])
        }
        if output == nil {
            output = await runCommand(executable: "docker", arguments: ["ps", "--format", "{{json .}}"])
        }

        guard let output = output, !output.isEmpty else {
            cachedContainers = []
            lastFetch = Date()
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

                // Extract published ports
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

        cachedContainers = list
        lastFetch = Date()
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
                    if parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]) {
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
