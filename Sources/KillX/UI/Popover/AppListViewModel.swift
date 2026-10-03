import SwiftUI
import AppKit

public enum PortFilterMode: String, CaseIterable, Identifiable {
    case all = "All Ports"
    case dev = "Dev Servers"
    public var id: String { rawValue }
}

struct KillConfirmationRequest: Identifiable {
    var id: String { "\(title)-\(message)" }
    let title: String
    let message: String
    let confirmButtonTitle: String
    let isForced: Bool
    let action: () async -> Void
}

@MainActor
final class AppListViewModel: ObservableObject {
    static let shared = AppListViewModel()

    @Published var filterMode: PortFilterMode = .all
    @Published var ports: [PortInfo] = []
    @Published var selectedPorts: Set<String> = []
    @Published var devServers: [DevServerInfo] = []

    @Published var searchQuery: String = ""
    @Published var isOptionKeyPressed: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastQuitCount: Int = 0
    @Published var lastActionMessage: String = ""
    @Published var showToast: Bool = false
    @Published var currentQuote: String = "Find and kill the process using a port ⚡"
    @Published var listNeedsScrolling: Bool = false

    @Published var inspectedPort: PortInfo? = nil
    @Published var inspectedAncestry: [ProcessTreeNodeInfo] = []
    @Published var isTracingTree: Bool = false
    @Published var pendingKillConfirmation: KillConfirmationRequest? = nil

    private var hasInitializedSelection = false

    private let quotes = [
        "Find and kill the process using a port ⚡",
        "Free up port 3000 in one click 🤘",
        "Hung dev server no more 🧹",
        "Kill listener or entire supervisor tree 🎯",
        "Clean ports, clear mind 🚀",
        "Docker container stopped cleanly 🐳"
    ]

    private let configStore = ConfigStore.shared
    private var flagsMonitor: Any?

    init() {
        startModifierMonitor()
        randomizeQuote()
    }

    deinit {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func startModifierMonitor() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async {
                self?.isOptionKeyPressed = event.modifierFlags.contains(.option)
            }
            return event
        }
    }

    func randomizeQuote() {
        currentQuote = quotes.randomElement() ?? "Find and kill the process using a port ⚡"
    }

    // MARK: - Filtered Lists

    var filteredPorts: [PortInfo] {
        var list = ports
        if filterMode == .dev {
            list = list.filter(\.isDevServer)
        }
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter {
            "\($0.port)".contains(q) ||
            $0.processName.lowercased().contains(q) ||
            $0.command.lowercased().contains(q) ||
            ($0.docker?.name.lowercased().contains(q) == true) ||
            ($0.cwd?.lowercased().contains(q) == true)
        }
    }

    var visibleCount: Int {
        filteredPorts.count
    }

    // MARK: - Selection

    var isAllSelected: Bool {
        let visible = filteredPorts
        return !visible.isEmpty && visible.allSatisfy { selectedPorts.contains($0.id) }
    }

    var isPartiallySelected: Bool {
        let visibleIds = Set(filteredPorts.map(\.id))
        let intersection = selectedPorts.intersection(visibleIds)
        return !intersection.isEmpty && intersection.count < visibleIds.count
    }

    func toggleSelectAll() {
        let visibleIds = Set(filteredPorts.map(\.id))
        if visibleIds.isSubset(of: selectedPorts) {
            selectedPorts.subtract(visibleIds)
        } else {
            selectedPorts.formUnion(visibleIds)
        }
    }

    func toggleSelection(for port: PortInfo) {
        if selectedPorts.contains(port.id) {
            selectedPorts.remove(port.id)
        } else {
            selectedPorts.insert(port.id)
        }
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        let selectedAllBeforeRefresh = isAllSelected

        let fetchedPorts = await PortService.shared.fetchListeningPorts()
        ports = sort(ports: fetchedPorts)
        devServers = await DevServerService.shared.fetchDevServers()

        let validPortIds = Set(ports.map(\.id))
        selectedPorts = selectedPorts.intersection(validPortIds)

        let cfg = configStore.config
        if !hasInitializedSelection {
            if cfg.defaultSelectAll {
                selectedPorts = Set(filteredPorts.map(\.id))
            } else {
                selectedPorts = []
            }
            hasInitializedSelection = true
        } else if selectedAllBeforeRefresh {
            if cfg.defaultSelectAll {
                selectedPorts = Set(filteredPorts.map(\.id))
            }
        }

        isLoading = false
        StatusItemController.shared?.updatePopoverSize()
    }

    func updateLiveStats() async {
        guard !isLoading else { return }
        let fetchedPorts = await PortService.shared.fetchListeningPorts()
        ports = sort(ports: fetchedPorts)
        devServers = await DevServerService.shared.fetchDevServers()

        let validPortIds = Set(ports.map(\.id))
        selectedPorts = selectedPorts.intersection(validPortIds)
    }

    // MARK: - Port Actions
 
    func confirmAndKillPort(_ port: PortInfo, force: Bool = false, tree: Bool = false) {
        let isForced = force || isOptionKeyPressed || configStore.config.force == .force
        let useTree = tree || configStore.config.treeKillByDefault

        guard configStore.config.confirmKill else {
            Task { await killPort(port, force: isForced, tree: useTree) }
            return
        }

        let title: String
        if isForced {
            title = useTree ? "Force Tree Kill Port :\(port.port)?" : "Force Kill Port :\(port.port)?"
        } else {
            title = useTree ? "Tree Kill Port :\(port.port)?" : "Kill Port :\(port.port)?"
        }

        var msg = "Process: \(port.processName) (PID \(port.pid))\n"
        if let cwd = port.cwd, !cwd.isEmpty {
            let displayPath = (cwd as NSString).lastPathComponent
            msg += "Directory: \(displayPath)\n"
        }
        msg += "\n⚠️ Caution: "
        if useTree {
            msg += "Terminating will kill the supervisor process and all child processes in its process tree.\n\n"
        } else {
            msg += "Terminating this process will close port :\(port.port) and sever active connections.\n\n"
        }
        if isForced {
            msg += "SIGKILL will be sent immediately without allowing graceful cleanup. Any unsaved data will be lost."
        } else {
            msg += "Any unsaved data or state in this service will be lost. Are you sure you want to proceed?"
        }

        let confirmTitle = isForced ? "Force Kill" : (useTree ? "Tree Kill" : "Kill")

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: confirmTitle,
            isForced: isForced,
            action: { [weak self] in
                await self?.killPort(port, force: isForced, tree: useTree)
            }
        )
    }

    func confirmAndKillSelectedPorts(force: Bool = false, tree: Bool = false) {
        let targets = ports.filter { selectedPorts.contains($0.id) }
        guard !targets.isEmpty else { return }

        let isForced = force || isOptionKeyPressed || configStore.config.force == .force
        let useTree = tree || configStore.config.treeKillByDefault

        guard configStore.config.confirmKill else {
            Task { await killSelectedPorts(force: isForced, tree: useTree) }
            return
        }

        let count = targets.count
        let title: String
        if isForced {
            title = useTree ? "Force Tree Kill (\(count)) Ports?" : "Force Kill (\(count)) Ports?"
        } else {
            title = useTree ? "Tree Kill (\(count)) Ports?" : "Kill (\(count)) Ports?"
        }

        let portList = targets.prefix(5).map { ":\($0.port) (\($0.processName))" }.joined(separator: ", ")
        let remainder = targets.count > 5 ? " and \(targets.count - 5) more" : ""

        var msg = "Selected targets: \(portList)\(remainder)\n\n"
        msg += "⚠️ Caution: Terminating these \(count) processes will shut down all associated network listeners.\n\n"
        if isForced {
            msg += "SIGKILL will terminate all processes immediately without graceful cleanup. Unsaved data will be lost."
        } else {
            msg += "Any active connections and unsaved progress will be lost. Are you sure you want to proceed?"
        }

        let confirmTitle = isForced ? "Force Kill (\(count))" : "Kill (\(count))"

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: confirmTitle,
            isForced: isForced,
            action: { [weak self] in
                await self?.killSelectedPorts(force: isForced, tree: useTree)
            }
        )
    }

    func confirmAndSweepDevServers(force: Bool = false) {
        let devPorts = ports.filter(\.isDevServer)
        guard !devPorts.isEmpty else {
            showToastMessage("No dev servers found")
            return
        }

        let isForced = force || isOptionKeyPressed || configStore.config.force == .force

        guard configStore.config.confirmKill else {
            Task { await sweepDevServers(force: isForced) }
            return
        }

        let count = devPorts.count
        let title = isForced ? "Force Sweep Dev Servers (\(count))?" : "Sweep Dev Servers (\(count))?"

        let portList = devPorts.prefix(5).map { ":\($0.port) (\($0.processName))" }.joined(separator: ", ")
        let remainder = devPorts.count > 5 ? " and \(devPorts.count - 5) more" : ""

        var msg = "Dev servers: \(portList)\(remainder)\n\n"
        msg += "⚠️ Caution: This will terminate all \(count) development server processes and their full process trees.\n\n"
        if isForced {
            msg += "SIGKILL will terminate all dev server trees immediately."
        } else {
            msg += "Ensure all changes are saved before terminating. Are you sure you want to proceed?"
        }

        let confirmTitle = isForced ? "Force Sweep (\(count))" : "Sweep Dev Servers"

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: confirmTitle,
            isForced: isForced,
            action: { [weak self] in
                await self?.sweepDevServers(force: isForced)
            }
        )
    }

    func confirmAndKillDevServer(_ server: DevServerInfo, force: Bool = false) {
        let isForced = force || isOptionKeyPressed || configStore.config.force == .force

        guard configStore.config.confirmKill else {
            Task { await killDevServer(server, force: isForced) }
            return
        }

        let title = isForced ? "Force Kill Dev Server :\(server.port.port)?" : "Kill Dev Server :\(server.port.port)?"

        var msg = "Project: \(server.projectName)\nProcess: \(server.port.processName) (PID \(server.port.pid))\n"
        if !server.displayPath.isEmpty {
            msg += "Path: \(server.displayPath)\n"
        }
        msg += "\n⚠️ Caution: This will terminate the dev server and its entire process tree.\n\n"
        if isForced {
            msg += "SIGKILL will be sent immediately without allowing graceful shutdown."
        } else {
            msg += "Any unsaved code execution or active build will stop. Proceed?"
        }

        let confirmTitle = isForced ? "Force Kill" : "Kill Server"

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: confirmTitle,
            isForced: isForced,
            action: { [weak self] in
                await self?.killDevServer(server, force: isForced)
            }
        )
    }

    func killPort(_ port: PortInfo, force: Bool = false, tree: Bool = false) async {
        let ok = await PortService.shared.killPort(port, force: force, tree: tree)
        if ok {
            SoundService.playQuitSingle()
            showToastMessage("Killed :\(port.port) (\(port.processName))")
            await refresh()
        }
    }

    func killSelectedPorts(force: Bool = false, tree: Bool = false) async {
        let targets = ports.filter { selectedPorts.contains($0.id) }
        guard !targets.isEmpty else { return }
        let count = await PortService.shared.killMultiplePorts(targets, force: force, tree: tree)
        if count > 0 {
            SoundService.playQuitAll()
            showToastMessage("Killed \(count) ports")
            await refresh()
        }
    }

    // MARK: - Dev Server Sweeper

    func sweepDevServers(force: Bool = false) async {
        let count = await DevServerService.shared.sweepAllDevServers(force: force)
        if count > 0 {
            SoundService.playQuitAll()
            showToastMessage("Swept \(count) dev servers")
            await refresh()
        } else {
            showToastMessage("No dev servers found")
        }
    }

    func killDevServer(_ server: DevServerInfo, force: Bool = false) async {
        await killPort(server.port, force: force, tree: true)
    }

    func quitAll(force: Bool = false) async {
        confirmAndKillSelectedPorts(force: force, tree: configStore.config.treeKillByDefault)
    }

    // MARK: - Process Tree Trace

    func tracePort(_ port: PortInfo) async {
        inspectedPort = port
        isTracingTree = true
        inspectedAncestry = await PortService.shared.traceProcessTree(pid: port.pid)
    }

    func closeTrace() {
        inspectedPort = nil
        isTracingTree = false
        inspectedAncestry = []
    }

    private func showToastMessage(_ msg: String) {
        lastActionMessage = msg
        triggerToast()
    }

    private func triggerToast() {
        showToast = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showToast = false
        }
    }

    private func sort(ports: [PortInfo]) -> [PortInfo] {
        switch configStore.config.sortBy {
        case .portAsc:
            return ports.sorted { $0.port < $1.port }
        case .portDesc:
            return ports.sorted { $0.port > $1.port }
        case .name:
            return ports.sorted { $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending }
        case .memoryDesc:
            return ports.sorted { $0.memoryBytes > $1.memoryBytes }
        case .cpuDesc:
            return ports.sorted { $0.cpuUsage > $1.cpuUsage }
        }
    }
}
