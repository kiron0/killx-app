import SwiftUI
import AppKit

struct KillConfirmationRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmButtonTitle: String
    let isForced: Bool
    let action: () async -> Void
}

@MainActor
final class AppListViewModel: ObservableObject {
    static let shared = AppListViewModel()

    @Published var ports: [PortInfo] = []
    @Published var selectedPorts: Set<String> = []

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
    @Published var pendingKillConfirmation: KillConfirmationRequest? = nil {
        didSet {
            StatusItemController.shared?.updatePopoverSize()
        }
    }
    @Published var arrowX: CGFloat = 135
    var popoverArrowX: CGFloat? {
        get { arrowX }
        set { arrowX = newValue ?? 135 }
    }
    @Published var toastMessage: String = ""
    @Published var toastIsError: Bool = false
    @Published var pendingPortIds: Set<String> = []
    @Published var isBatchKilling: Bool = false

    private var hasInitializedSelection = false
    private var toastTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var fetchGeneration = 0

    private let quotes = [
        "Find and kill the process using a port ⚡",
        "Free up port 3000 in one click 🤘",
        "Free up occupied ports 🧹",
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
        toastTask?.cancel()
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

    var filteredPorts: [PortInfo] {
        let excluded = configStore.config.excludePorts
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        return ports.filter { port in
            if port.isSystemProtected || excluded.contains(port.port) { return false }
            guard !q.isEmpty else { return true }
            return "\(port.port)".contains(q) ||
                port.displayAppName.lowercased().contains(q) ||
                port.processName.lowercased().contains(q) ||
                port.command.lowercased().contains(q) ||
                (port.docker?.name.lowercased().contains(q) == true) ||
                (port.cwd?.lowercased().contains(q) == true)
        }
    }

    func excludePort(_ portNumber: Int) {
        if !configStore.config.excludePorts.contains(portNumber) {
            _ = configStore.addExcludedPorts([portNumber])
            showToastMessage("Port :\(portNumber) added to exclude list")
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    var visibleCount: Int {
        filteredPorts.count
    }

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
        let visibleIds = Set(filteredPorts.filter { !$0.isSystemProtected }.map(\.id))
        if visibleIds.isSubset(of: selectedPorts) {
            selectedPorts.subtract(visibleIds)
        } else {
            selectedPorts.formUnion(visibleIds)
        }
    }

    func toggleSelection(for port: PortInfo) {
        guard !port.isSystemProtected else { return }
        if selectedPorts.contains(port.id) {
            selectedPorts.remove(port.id)
        } else {
            selectedPorts.insert(port.id)
        }
    }

    func refresh() async {
        isLoading = true
        fetchGeneration += 1
        let gen = fetchGeneration
        let selectedAllBeforeRefresh = isAllSelected

        let fetchedPorts = await PortService.shared.fetchListeningPorts()
        guard gen == fetchGeneration else {
            return
        }
        ports = sort(ports: fetchedPorts)

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
        fetchGeneration += 1
        let gen = fetchGeneration
        let fetchedPorts = await PortService.shared.fetchListeningPorts()
        guard gen == fetchGeneration else { return }
        ports = sort(ports: fetchedPorts)

        let validPortIds = Set(ports.map(\.id))
        selectedPorts = selectedPorts.intersection(validPortIds)
    }

    func resort() async {
        fetchGeneration += 1
        ports = sort(ports: ports)
        selectedPorts = selectedPorts.intersection(Set(ports.map(\.id)))
    }

    func confirmAndKillPort(_ port: PortInfo, force: Bool = false, tree: Bool = false) {
        guard !port.isSystemProtected else {
            showToastMessage("Port is protected by system", isError: true)
            return
        }

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
        let targets = ports.filter { selectedPorts.contains($0.id) && !$0.isSystemProtected }
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

    func killPort(_ port: PortInfo, force: Bool = false, tree: Bool = false) async {
        guard !port.isSystemProtected else {
            showToastMessage("Port is protected by system", isError: true)
            return
        }
        pendingPortIds.insert(port.id)
        defer { pendingPortIds.remove(port.id) }
        let ok = await PortService.shared.killPort(port, force: force, tree: tree)
        if ok {
            SoundService.playKillSingle()
            showToastMessage("Killed :\(port.port) (\(port.processName))")
            await refresh()
        }
    }

    func killSelectedPorts(force: Bool = false, tree: Bool = false) async {
        let targets = ports.filter { selectedPorts.contains($0.id) && !$0.isSystemProtected }
        guard !targets.isEmpty else { return }
        isBatchKilling = true
        pendingPortIds.formUnion(targets.map(\.id))
        defer {
            isBatchKilling = false
            pendingPortIds.subtract(targets.map(\.id))
        }
        let count = await PortService.shared.killMultiplePorts(targets, force: force, tree: tree)
        if count > 0 {
            SoundService.playKillAll()
            showToastMessage("Killed \(count) ports")
            await refresh()
        }
    }

    func quitAll(force: Bool = false) async {
        confirmAndKillSelectedPorts(force: force, tree: configStore.config.treeKillByDefault)
    }

    func confirmAndForceKillAll() {
        let targets = ports.filter { !$0.isSystemProtected }
        guard !targets.isEmpty else { return }

        let useTree = configStore.config.treeKillByDefault
        let count = targets.count

        guard configStore.config.confirmKill else {
            Task { await forceKillAll() }
            return
        }

        let title = useTree ? "Force Tree Kill All (\(count)) Ports?" : "Force Kill All (\(count)) Ports?"
        let portList = targets.prefix(5).map { ":\($0.port) (\($0.processName))" }.joined(separator: ", ")
        let remainder = targets.count > 5 ? " and \(targets.count - 5) more" : ""

        var msg = "All targets: \(portList)\(remainder)\n\n"
        msg += "⚠️ Caution: Force killing will immediately send SIGKILL to all non-system ports and terminate them without allowing graceful shutdown.\n\n"
        msg += "Unsaved work in all running dev servers and processes will be lost."

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: "Force Kill All (\(count))",
            isForced: true,
            action: { [weak self] in
                await self?.forceKillAll()
            }
        )
    }

    func forceKillAll() async {
        let targets = ports.filter { !$0.isSystemProtected }
        guard !targets.isEmpty else { return }
        isBatchKilling = true
        pendingPortIds.formUnion(targets.map(\.id))
        defer {
            isBatchKilling = false
            pendingPortIds.subtract(targets.map(\.id))
        }
        let count = await PortService.shared.killMultiplePorts(targets, force: true, tree: configStore.config.treeKillByDefault)
        if count > 0 {
            SoundService.playKillAll()
            showToastMessage("Force killed \(count) ports")
            await refresh()
        }
    }

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

    func showToastMessage(_ msg: String, isError: Bool = false) {
        lastActionMessage = msg
        toastMessage = msg
        toastIsError = isError
        triggerToast()
    }

    private func triggerToast() {
        showToast = true
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
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
