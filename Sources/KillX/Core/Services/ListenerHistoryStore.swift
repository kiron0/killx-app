import Foundation

struct ListenerHistoryEntry: Codable, Equatable {
    let date: Date
    let port: Int
    let pid: pid_t
    let event: String
    let detail: String
}

@MainActor
final class ListenerHistoryStore: ObservableObject {
    static let shared = ListenerHistoryStore()
    @Published private(set) var entries: [ListenerHistoryEntry] = []
    private let limit = 200
    private let defaultsKey = "KillXListenerHistory"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ListenerHistoryEntry].self, from: data) else { return }
        entries = Array(decoded.prefix(limit))
    }

    func record(port: PortInfo, event: String, detail: String) {
        entries.insert(ListenerHistoryEntry(date: Date(), port: port.port, pid: port.pid, event: event, detail: Self.redact(detail)), at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    func recordChanges(previous: [PortInfo], current: [PortInfo]) {
        let old = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let new = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for port in current where old[port.id] == nil { record(port: port, event: "opened", detail: port.command) }
        for port in previous where new[port.id] == nil { record(port: port, event: "closed", detail: port.command) }
    }

    func diagnostics(ports: [PortInfo], metrics: PortScanMetrics) -> String {
        var lines = [
            "KillX diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "Ports: \(ports.count)",
            String(format: "Scan: %.3fs total, %.3fs discovery, %.3fs metadata", metrics.total, metrics.discovery, metrics.metadata)
        ]
        lines += ports.map {
            ":\($0.port) \($0.protocolName) \($0.bindAddress) pid=\($0.pid) app=\($0.displayAppName) command=\(Self.redact($0.command))"
        }
        lines.append("History:")
        lines += entries.prefix(50).map { "\($0.date) :\($0.port) pid=\($0.pid) \($0.event) \($0.detail)" }
        return lines.joined(separator: "\n")
    }

    nonisolated static func redact(_ text: String) -> String {
        let patterns = [
            #"(?i)(token|password|secret|api[_-]?key)=([^\s]+)"#,
            #"(?i)(authorization:\s*bearer\s+)([^\s]+)"#
        ]
        return patterns.reduce(text) { value, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
            let range = NSRange(value.startIndex..., in: value)
            return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "$1=<redacted>")
        }
    }
}
