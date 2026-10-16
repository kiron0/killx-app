import Foundation
@testable import KillX

final class StubPortService: PortServicing, @unchecked Sendable {
    var ports: [PortInfo]
    var killResult: Bool

    init(ports: [PortInfo] = [], killResult: Bool = true) {
        self.ports = ports
        self.killResult = killResult
    }

    func fetchListeningPorts() async -> [PortInfo] { ports }
    func refreshStats(for ports: [PortInfo]) async -> [PortInfo] { ports }
    func killPort(_ port: PortInfo, mode: TerminationMode, progress: @escaping @Sendable (String) -> Void) async -> Bool {
        progress(killResult ? "Port released" : "Failed")
        return killResult
    }
    func killMultiplePorts(_ ports: [PortInfo], force: Bool) async -> Int { killResult ? ports.count : 0 }
    func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo] { [] }
}
