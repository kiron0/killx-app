import Foundation
import UserNotifications

struct PortWatchEvent: Equatable {
    enum Kind: String { case opened, closed, ownerChanged }
    let port: Int
    let kind: Kind
    let message: String
}

final class ListenerWatchService {
    static let shared = ListenerWatchService()
    private init() {}

    static func events(previous: [PortInfo], current: [PortInfo], watched: Set<Int>) -> [PortWatchEvent] {
        let old = previous.filter { watched.contains($0.port) }.reduce(into: [Int: PortInfo]()) { $0[$1.port] = $0[$1.port] ?? $1 }
        let new = current.filter { watched.contains($0.port) }.reduce(into: [Int: PortInfo]()) { $0[$1.port] = $0[$1.port] ?? $1 }
        return watched.sorted().compactMap { port in
            switch (old[port], new[port]) {
            case (nil, let value?):
                return PortWatchEvent(port: port, kind: .opened, message: ":\(port) opened by \(value.displayAppName)")
            case (let value?, nil):
                return PortWatchEvent(port: port, kind: .closed, message: ":\(port) closed; previous owner was \(value.displayAppName)")
            case (let before?, let after?) where before.pid != after.pid:
                return PortWatchEvent(port: port, kind: .ownerChanged, message: ":\(port) changed owner to \(after.displayAppName)")
            default:
                return nil
            }
        }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(_ events: [PortWatchEvent]) {
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = "KillX Port Watch"
            content.body = event.message
            let request = UNNotificationRequest(identifier: "killx-watch-\(event.port)-\(UUID())", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
