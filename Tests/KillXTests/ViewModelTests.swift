import Testing
import Foundation
@testable import KillX

@Suite("AppListViewModel State & Selection Tests", .serialized)
@MainActor
struct AppListViewModelTests {
    let vm = AppListViewModel.shared

    let port1 = PortInfo(port: 3000, pid: 101, processName: "node", command: "next dev", isDevServer: true)
    let port2 = PortInfo(port: 5432, pid: 102, processName: "postgres", command: "postgres -D /data", isDevServer: false)
    let port3 = PortInfo(port: 8080, pid: 103, processName: "python", command: "uvicorn main:app", isDevServer: true)

    @Test("Initial quote is non-empty")
    func testInitialQuote() {
        #expect(!vm.currentQuote.isEmpty)
    }

    @Test("Randomize quote changes or preserves non-empty quote")
    func testRandomizeQuote() {
        vm.randomizeQuote()
        #expect(!vm.currentQuote.isEmpty)
    }

    @Test("Filtered ports returns all ports when query empty")
    func testFilteredPortsAll() {
        vm.ports = [port1, port2, port3]
        vm.searchQuery = ""
        #expect(vm.filteredPorts.count == 3)
    }

    @Test("Filtered ports with search query by port number")
    func testFilteredPortsSearchPort() {
        vm.ports = [port1, port2, port3]
        vm.searchQuery = "5432"
        #expect(vm.filteredPorts.count == 1)
        #expect(vm.filteredPorts.first?.port == 5432)
    }

    @Test("Filtered ports with case-insensitive search by process name")
    func testFilteredPortsSearchName() {
        vm.ports = [port1, port2, port3]
        vm.searchQuery = "NODE"
        #expect(vm.filteredPorts.count == 1)
        #expect(vm.filteredPorts.first?.processName == "node")
    }

    @Test("Toggle selection adds unselected port")
    func testToggleSelectionAdd() {
        vm.selectedPorts.removeAll()
        vm.toggleSelection(for: port1)
        #expect(vm.selectedPorts.contains(port1.id))
    }

    @Test("Toggle selection removes selected port")
    func testToggleSelectionRemove() {
        vm.selectedPorts = [port1.id]
        vm.toggleSelection(for: port1)
        #expect(!vm.selectedPorts.contains(port1.id))
    }

    @Test("isAllSelected false when empty ports")
    func testIsAllSelectedEmpty() {
        vm.ports = []
        vm.selectedPorts = []
        #expect(!vm.isAllSelected)
    }

    @Test("isAllSelected true when all visible ports selected")
    func testIsAllSelectedTrue() {
        vm.ports = [port1, port2]
        vm.searchQuery = ""
        vm.selectedPorts = [port1.id, port2.id]
        #expect(vm.isAllSelected)
    }

    @Test("isAllSelected false when some ports unselected")
    func testIsAllSelectedPartial() {
        vm.ports = [port1, port2]
        vm.searchQuery = ""
        vm.selectedPorts = [port1.id]
        #expect(!vm.isAllSelected)
        #expect(vm.isPartiallySelected)
    }

    @Test("Excluded ports do not count as selected visible ports")
    func testExcludedSelectionIsNotVisible() {
        vm.ports = [port1, port2]
        vm.searchQuery = ""
        vm.selectedPorts = [port1.id, port2.id]
        ConfigStore.shared.config.excludePorts = [port2.port]

        #expect(vm.selectedVisibleCount == 1)
        #expect(vm.filteredPorts.map(\.id) == [port1.id])

        ConfigStore.shared.config.excludePorts = []
    }

    @Test("Force kill all confirmation excludes excluded ports")
    func testForceKillAllRespectsExclusions() {
        vm.ports = [port1, port2]
        ConfigStore.shared.config.excludePorts = [port2.port]
        ConfigStore.shared.config.confirmKill = true
        vm.pendingKillConfirmation = nil

        vm.confirmAndForceKillAll()

        #expect(vm.pendingKillConfirmation?.title.contains("(1)") == true)
        #expect(vm.pendingKillConfirmation?.message.contains(":3000") == true)
        #expect(vm.pendingKillConfirmation?.message.contains(":5432") == false)

        vm.pendingKillConfirmation = nil
        ConfigStore.shared.config.excludePorts = []
    }

    @Test("toggleSelectAll toggles between all and none")
    func testToggleSelectAll() {
        vm.ports = [port1, port2]
        vm.searchQuery = ""
        vm.selectedPorts = []

        vm.toggleSelectAll()
        #expect(vm.isAllSelected)

        vm.toggleSelectAll()
        #expect(vm.selectedPorts.isEmpty)
    }

    @Test("confirmAndKillPort shows confirmation prompt when confirmKill is enabled")
    func testConfirmAndKillPortConfirmation() {
        ConfigStore.shared.config.confirmKill = true
        vm.pendingKillConfirmation = nil

        vm.confirmAndKillPort(port1, force: false)

        #expect(vm.pendingKillConfirmation != nil)
        #expect(vm.pendingKillConfirmation?.title.contains("3000") == true)
        #expect(vm.pendingKillConfirmation?.message.contains("node") == true)
        #expect(vm.pendingKillConfirmation?.message.contains("⚠️ Caution") == false)
        #expect(vm.pendingKillConfirmation?.confirmButtonTitle == "Kill")
    }

    @Test("confirmAndKillPort force mode sets isForced and title")
    func testConfirmAndKillPortForceMode() {
        ConfigStore.shared.config.confirmKill = true
        vm.pendingKillConfirmation = nil

        vm.confirmAndKillPort(port1, force: true)

        #expect(vm.pendingKillConfirmation != nil)
        #expect(vm.pendingKillConfirmation?.title.contains("Force Kill") == true)
        #expect(vm.pendingKillConfirmation?.isForced == true)
        #expect(vm.pendingKillConfirmation?.confirmButtonTitle == "Force Kill")
        #expect(vm.pendingKillConfirmation?.message.contains("⚠️ Caution") == false)
    }

    @Test("confirmAndKillSelectedPorts shows confirmation with target summary")
    func testConfirmAndKillSelectedPortsConfirmation() {
        ConfigStore.shared.config.confirmKill = true
        vm.ports = [port1, port2]
        vm.selectedPorts = [port1.id, port2.id]
        vm.pendingKillConfirmation = nil

        vm.confirmAndKillSelectedPorts(force: false)

        #expect(vm.pendingKillConfirmation != nil)
        #expect(vm.pendingKillConfirmation?.title.contains("2") == true)
        #expect(vm.pendingKillConfirmation?.message.contains("3000") == true)
        #expect(vm.pendingKillConfirmation?.message.contains("⚠️ Caution") == false)
    }

    @Test("confirmAndKillPort skips prompt when confirmKill is disabled")
    func testConfirmAndKillPortDisabled() {
        ConfigStore.shared.config.confirmKill = false
        vm.pendingKillConfirmation = nil

        vm.confirmAndKillPort(port1, force: false)

        #expect(vm.pendingKillConfirmation == nil)
        ConfigStore.shared.config.confirmKill = true
    }
}
