import AppKit
import SwiftUI

final class MenuPopupWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = false
        self.isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }
}

@MainActor
final class StatusItemController: NSObject {
    static weak var shared: StatusItemController?

    private var statusItem: NSStatusItem
    private var window: MenuPopupWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var refreshTask: Task<Void, Never>?
    private var liveMonitoringTask: Task<Void, Never>?
    private var lastCloseTimestamp: Date = .distantPast

    var isShown: Bool {
        window?.isVisible ?? false
    }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        Self.shared = self

        configureButton()
        configureWindow()
        startEventMonitor()
    }

    deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        refreshTask?.cancel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "KillX"
        button.setAccessibilityLabel("KillX")

        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
    }

    private func makeMenuBarIcon() -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let icon = NSImage(size: targetSize)
        let iconNames = ["status-icon", "menubar"]
        var loaded = false

        for name in iconNames {
            let path1x = Bundle.main.path(forResource: name, ofType: "png") ?? "Support/Icons/\(name).png"
            let path2x = Bundle.main.path(forResource: "\(name)@2x", ofType: "png") ?? "Support/Icons/\(name)@2x.png"

            var reps: [NSImageRep] = []
            if FileManager.default.fileExists(atPath: path1x),
               let rep1 = NSImageRep(contentsOfFile: path1x) {
                rep1.size = targetSize
                reps.append(rep1)
            }
            if FileManager.default.fileExists(atPath: path2x),
               let rep2 = NSImageRep(contentsOfFile: path2x) {
                rep2.size = targetSize
                reps.append(rep2)
            }

            if !reps.isEmpty {
                reps.forEach { icon.addRepresentation($0) }
                loaded = true
                break
            }
        }

        if loaded {
            icon.isTemplate = true
            return icon
        }

        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.black.setFill()
        let rounded = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 17, height: 17), xRadius: 4, yRadius: 4)
        rounded.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @MainActor
    private func configureWindow() {
        let rootView = AnyView(
            MainPopoverView()
                .environmentObject(ConfigStore.shared)
        )
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = 10
        hosting.view.layer?.masksToBounds = true
        self.hostingController = hosting

        let win = MenuPopupWindow(contentRect: NSRect(x: 0, y: 0, width: 280, height: 200))
        win.contentViewController = hosting
        win.appearance = NSApp.effectiveAppearance
        self.window = win

        updatePopoverSize()

        Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            self?.updatePopoverSize()
        }
    }

    @MainActor
    func updatePopoverSize() {
        let count = AppListViewModel.shared.visibleCount

        var calculated: CGFloat
        if count == 0 {
            calculated = 190
        } else {
            let baseHeight: CGFloat = 126
            let rowHeight: CGFloat = 28
            calculated = baseHeight + (CGFloat(count) * rowHeight)
        }
        if AppListViewModel.shared.pendingKillConfirmation != nil {
            calculated = max(calculated, 240)
        }

        let arrowHeight: CGFloat = 12
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 800
        // Cap maximum height to 420px (QuitX replica pattern) so it never overflows display
        let maximumHeight = min(420, max(180, screenHeight - 60))
        let targetHeight = min(maximumHeight, calculated)
        AppListViewModel.shared.listNeedsScrolling = calculated > maximumHeight

        let totalHeight = targetHeight + arrowHeight
        let newSize = NSSize(width: 280, height: totalHeight)
        guard let win = window else { return }

        var frame = win.frame
        let oldHeight = frame.height
        frame.size = newSize
        frame.origin.y += (oldHeight - totalHeight)

        if let button = statusItem.button, let btnWindow = button.window {
            let buttonScreenRect = btnWindow.convertToScreen(button.bounds)
            var originX = buttonScreenRect.midX - (newSize.width / 2)

            if let scr = screen {
                let screenMinX = scr.visibleFrame.minX
                let screenMaxX = scr.visibleFrame.maxX
                originX = max(screenMinX + 4, min(originX, screenMaxX - newSize.width - 4))
            }
            let originY = buttonScreenRect.minY - totalHeight - 2
            frame.origin = NSPoint(x: originX, y: originY)

            let arrowX = max(18, min(buttonScreenRect.midX - originX, newSize.width - 18))
            AppListViewModel.shared.arrowX = arrowX
        }

        win.setFrame(frame, display: true, animate: false)
        win.invalidateShadow()
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseDown || event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func closePopover() {
        lastCloseTimestamp = Date()
        stopLiveMonitoring()
        window?.orderOut(nil)
    }

    @MainActor
    func showPopover() {
        if !isShown {
            togglePopover()
        }
    }

    @MainActor
    func togglePopover() {
        if isShown {
            closePopover()
        } else {
            if Date().timeIntervalSince(lastCloseTimestamp) < 0.25 {
                return
            }
            guard let win = window else { return }
            win.appearance = NSApp.effectiveAppearance
            NSApp.activate(ignoringOtherApps: true)
            updatePopoverSize()
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(nil)
            refreshVisibleApps()
            startLiveMonitoring()
        }
    }

    private func startLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = Task { @MainActor [weak self] in
            while let self = self, self.isShown {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, self.isShown else { break }
                await AppListViewModel.shared.updateLiveStats()
                self.updatePopoverSize()
            }
        }
    }

    private func stopLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = nil
    }

    private func refreshVisibleApps() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            guard !Task.isCancelled else { return }
            self?.updatePopoverSize()
        }
    }

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()
        menu.appearance = NSApp.effectiveAppearance

        menu.addItem(MenuHelper.makeItem(
            title: "Settings...",
            action: #selector(openSettings),
            target: self,
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Welcome Guide",
            action: #selector(openWelcomeGuide),
            target: self,
            systemSymbolName: "hand.wave"
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Sweep Dev Servers",
            action: #selector(sweepDevServers),
            target: self,
            keyEquivalent: "d",
            systemSymbolName: "arrow.triangle.branch"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Refresh Ports",
            action: #selector(refreshPorts),
            target: self,
            keyEquivalent: "r",
            systemSymbolName: "arrow.clockwise"
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "About KillX",
            action: #selector(openSettings),
            target: self,
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle"
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit",
            action: #selector(quitApp),
            target: self,
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power"
        ))

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openWelcomeGuide() {
        WelcomeWindowController.shared.show()
    }

    @objc private func sweepDevServers() {
        showPopover()
        AppListViewModel.shared.confirmAndSweepDevServers()
    }

    @objc private func refreshPorts() {
        Task {
            await AppListViewModel.shared.refresh()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func startEventMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isShown else { return }

            if AppListViewModel.shared.pendingKillConfirmation != nil {
                return
            }

            if let button = self.statusItem.button, let buttonWindow = button.window {
                let mouseLoc = NSEvent.mouseLocation
                let buttonScreenFrame = buttonWindow.convertToScreen(button.bounds)
                if buttonScreenFrame.contains(mouseLoc) {
                    return
                }
            }

            Task { @MainActor in
                self.closePopover()
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.isShown else { return event }

            if event.type == .keyDown, event.keyCode == 53 {
                if AppListViewModel.shared.pendingKillConfirmation != nil {
                    AppListViewModel.shared.pendingKillConfirmation = nil
                    return nil
                }
                self.closePopover()
                return nil
            }

            let popupWindow = self.window
            let statusWindow = self.statusItem.button?.window
            if let eventWin = event.window,
               (eventWin === popupWindow || eventWin === statusWindow || eventWin.parent === popupWindow || eventWin.sheetParent === popupWindow) {
                return event
            }
            if AppListViewModel.shared.pendingKillConfirmation != nil {
                return event
            }
            self.closePopover()
            return event
        }
    }
}
