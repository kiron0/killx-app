import SwiftUI
import AppKit

protocol PortServicing {
    func fetchListeningPorts() async -> [PortInfo]
    func refreshStats(for ports: [PortInfo]) async -> [PortInfo]
    func killPort(
        _ port: PortInfo,
        mode: TerminationMode,
        progress: @escaping @Sendable (String) -> Void
    ) async -> Bool
    func killMultiplePorts(_ ports: [PortInfo], force: Bool) async -> Int
    func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo]
}

extension PortService: PortServicing {}

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
    @Published var terminationStages: [String: String] = [:]

    private var hasInitializedSelection = false
    private var hasLoadedOnce = false
    private var toastTask: Task<Void, Never>?
    private var fetchGeneration = 0
    private var activeRefreshes = 0
    private let portService: PortServicing

    private let quotes = [
        "Find and kill the process using a port ⚡",
        "Free up port 3000 in one click 🤘",
        "Free up occupied ports 🧹",
        "Kill the port and everything behind it 🎯",
        "Clean ports, clear mind 🚀",
        "Docker container stopped cleanly 🐳"
    ]

    private let configStore: ConfigStore
    private var flagsMonitor: Any?

    init(
        portService: PortServicing = PortService.shared,
        configStore: ConfigStore = ConfigStore.shared
    ) {
        self.portService = portService
        self.configStore = configStore
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

    func toggleFavorite(_ portNumber: Int) {
        var values = Set(configStore.config.favoritePorts)
        if !values.insert(portNumber).inserted { values.remove(portNumber) }
        configStore.config.favoritePorts = values.sorted()
        configStore.save()
        ports = sort(ports: ports)
    }

    func toggleWatch(_ portNumber: Int) {
        var values = Set(configStore.config.watchedPorts)
        if values.insert(portNumber).inserted {
            ListenerWatchService.shared.requestPermission()
        } else {
            values.remove(portNumber)
        }
        configStore.config.watchedPorts = values.sorted()
        configStore.save()
    }

    func saveProfile(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let visible = filteredPorts
        let directory = visible.compactMap(\.cwd).first
        let profile = ProjectProfile(
            name: cleanName,
            ports: Array(Set(visible.map(\.port))).sorted(),
            label: cleanName,
            directory: directory
        )
        configStore.config.profiles.removeAll { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }
        configStore.config.profiles.append(profile)
        configStore.save()
        showToastMessage("Saved profile \(cleanName)")
    }

    func applyProfile(_ profile: ProjectProfile) {
        let ports = Set(profile.ports)
        selectedPorts = Set(self.ports.filter { ports.contains($0.port) }.map(\.id))
        searchQuery = ""
        showToastMessage("Selected \(selectedPorts.count) ports from \(profile.name)")
    }

    var visibleCount: Int {
        filteredPorts.count
    }

    var selectedVisibleCount: Int {
        let visibleIds = Set(filteredPorts.map(\.id))
        return selectedPorts.intersection(visibleIds).count
    }

    private var killablePorts: [PortInfo] {
        let excluded = Set(configStore.config.excludePorts)
        return ports.filter { !$0.isSystemProtected && !excluded.contains($0.port) }
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
        activeRefreshes += 1
        if !hasLoadedOnce { isLoading = true }
        fetchGeneration += 1
        let gen = fetchGeneration
        let selectedAllBeforeRefresh = isAllSelected
        defer {
            activeRefreshes -= 1
            if activeRefreshes == 0 { isLoading = false }
        }

        let fetchedPorts = await portService.fetchListeningPorts()
        guard gen == fetchGeneration else {
            return
        }
        let previousPorts = ports
        let sortedPorts = sort(ports: fetchedPorts)
        if sortedPorts != ports { ports = sortedPorts }
        if hasLoadedOnce {
            ListenerHistoryStore.shared.recordChanges(previous: previousPorts, current: sortedPorts)
            let events = ListenerWatchService.events(
                previous: previousPorts,
                current: sortedPorts,
                watched: Set(configStore.config.watchedPorts)
            )
            ListenerWatchService.shared.notify(events)
        }

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

        hasLoadedOnce = true
        StatusItemController.shared?.updateMenuBarCount(sortedPorts.count)
        StatusItemController.shared?.updatePopoverSize()
    }

    func updateLiveStats() async {
        guard !isLoading else { return }
        fetchGeneration += 1
        let gen = fetchGeneration
        let fetchedPorts = await portService.refreshStats(for: ports)
        guard gen == fetchGeneration else { return }
        let sortedPorts = sort(ports: fetchedPorts)
        if sortedPorts != ports { ports = sortedPorts }

        let validPortIds = Set(ports.map(\.id))
        selectedPorts = selectedPorts.intersection(validPortIds)
    }

    func resort() async {
        fetchGeneration += 1
        ports = sort(ports: ports)
        selectedPorts = selectedPorts.intersection(Set(ports.map(\.id)))
    }

    func confirmAndKillPort(_ port: PortInfo, force: Bool = false) {
        confirmAndKillPort(port, mode: force ? .force : .terminate)
    }

    func confirmAndInterruptPort(_ port: PortInfo) {
        confirmAndKillPort(port, mode: .interrupt)
    }

    private func confirmAndKillPort(_ port: PortInfo, mode: TerminationMode) {
        guard !port.isSystemProtected else {
            showToastMessage("Port is protected by system", isError: true)
            return
        }

        let effectiveMode: TerminationMode = (isOptionKeyPressed || configStore.config.force == .force) ? .force : mode
        let isForced = effectiveMode == .force

        guard configStore.config.confirmKill else {
            Task { await killPort(port, mode: effectiveMode) }
            return
        }

        let title: String
        if isForced {
            title = "Force Kill Port :\(port.port)?"
        } else if effectiveMode == .interrupt {
            title = "Interrupt Port :\(port.port)?"
        } else {
            title = "Kill Port :\(port.port)?"
        }

        var msg = "Process: \(port.processName) (PID \(port.pid))"
        if let cwd = port.cwd, !cwd.isEmpty {
            let displayPath = (cwd as NSString).lastPathComponent
            msg += "\nDirectory: \(displayPath)"
        }

        let confirmTitle = isForced ? "Force Kill" : (effectiveMode == .interrupt ? "Interrupt" : "Kill")

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: confirmTitle,
            isForced: isForced,
            action: { [weak self] in
                await self?.killPort(port, mode: effectiveMode)
            }
        )
    }

    func confirmAndKillSelectedPorts(force: Bool = false) {
        let targets = killablePorts.filter { selectedPorts.contains($0.id) }
        guard !targets.isEmpty else { return }

        let isForced = force || isOptionKeyPressed || configStore.config.force == .force

        guard configStore.config.confirmKill else {
            Task { await killSelectedPorts(force: isForced) }
            return
        }

        let count = targets.count
        let title: String
        if isForced {
            title = "Force Kill (\(count)) Ports?"
        } else {
            title = "Kill (\(count)) Ports?"
        }

        let portList = targets.prefix(5).map { ":\($0.port) (\($0.processName))" }.joined(separator: ", ")
        let remainder = targets.count > 5 ? " and \(targets.count - 5) more" : ""
        let msg = "Selected targets: \(portList)\(remainder)"

        let confirmTitle = isForced ? "Force Kill (\(count))" : "Kill (\(count))"

        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: confirmTitle,
            isForced: isForced,
            action: { [weak self] in
                await self?.killSelectedPorts(force: isForced)
            }
        )
    }

    func killPort(_ port: PortInfo, force: Bool = false) async {
        await killPort(port, mode: force ? .force : .terminate)
    }

    func killPort(_ port: PortInfo, mode: TerminationMode) async {
        guard !port.isSystemProtected else {
            showToastMessage("Port is protected by system", isError: true)
            return
        }
        pendingPortIds.insert(port.id)
        terminationStages[port.id] = "Sending \(mode.signalName)"
        ListenerHistoryStore.shared.record(port: port, event: "signal", detail: mode.signalName)
        defer {
            pendingPortIds.remove(port.id)
            terminationStages.removeValue(forKey: port.id)
        }
        let ok = await portService.killPort(port, mode: mode) { [weak self] stage in
            Task { @MainActor [weak self] in
                self?.terminationStages[port.id] = stage
            }
        }
        if ok {
            terminationStages[port.id] = "Port released"
            ListenerHistoryStore.shared.record(port: port, event: "released", detail: mode.signalName)
            SoundService.playKillSingle()
            showToastMessage("Killed :\(port.port) (\(port.processName))")
        } else {
            terminationStages[port.id] = "Listener remained or changed owner"
            ListenerHistoryStore.shared.record(port: port, event: "failed", detail: mode.signalName)
            showToastMessage("Couldn't free :\(port.port) — it kept re-opening", isError: true)
        }
        await refresh()
    }

    func killSelectedPorts(force: Bool = false) async {
        let targets = killablePorts.filter { selectedPorts.contains($0.id) }
        guard !targets.isEmpty else { return }
        isBatchKilling = true
        pendingPortIds.formUnion(targets.map(\.id))
        defer {
            isBatchKilling = false
            pendingPortIds.subtract(targets.map(\.id))
        }
        let count = await portService.killMultiplePorts(targets, force: force)
        if count > 0 {
            SoundService.playKillAll()
            showToastMessage("Killed \(count) ports")
        } else {
            showToastMessage("No ports freed — listeners kept re-opening", isError: true)
        }
        await refresh()
    }

    func quitAll(force: Bool = false) async {
        confirmAndKillSelectedPorts(force: force)
    }

    func confirmAndForceKillAll() {
        let targets = killablePorts
        guard !targets.isEmpty else { return }

        let count = targets.count

        guard configStore.config.confirmKill else {
            Task { await forceKillAll() }
            return
        }

        let title = "Force Kill All (\(count)) Ports?"
        let portList = targets.prefix(5).map { ":\($0.port) (\($0.processName))" }.joined(separator: ", ")
        let remainder = targets.count > 5 ? " and \(targets.count - 5) more" : ""
        let msg = "All targets: \(portList)\(remainder)"

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
        let targets = killablePorts
        guard !targets.isEmpty else { return }
        isBatchKilling = true
        pendingPortIds.formUnion(targets.map(\.id))
        defer {
            isBatchKilling = false
            pendingPortIds.subtract(targets.map(\.id))
        }
        let count = await portService.killMultiplePorts(targets, force: true)
        if count > 0 {
            SoundService.playKillAll()
            showToastMessage("Force killed \(count) ports")
        } else {
            showToastMessage("No ports freed — listeners kept re-opening", isError: true)
        }
        await refresh()
    }

    func tracePort(_ port: PortInfo) async {
        inspectedPort = port
        isTracingTree = true
        inspectedAncestry = await portService.traceProcessTree(pid: port.pid)
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
        let sorted: [PortInfo]
        switch configStore.config.sortBy {
        case .portAsc:
            sorted = ports.sorted { $0.port < $1.port }
        case .portDesc:
            sorted = ports.sorted { $0.port > $1.port }
        case .name:
            sorted = ports.sorted { $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending }
        case .memoryDesc:
            sorted = ports.sorted { $0.memoryBytes > $1.memoryBytes }
        case .cpuDesc:
            sorted = ports.sorted { $0.cpuUsage > $1.cpuUsage }
        }
        let favorites = Set(configStore.config.favoritePorts)
        return sorted.enumerated().sorted {
            let left = favorites.contains($0.element.port)
            let right = favorites.contains($1.element.port)
            return left == right ? $0.offset < $1.offset : left && !right
        }.map(\.element)
    }
}
