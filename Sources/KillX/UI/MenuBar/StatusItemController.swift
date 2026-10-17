import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    static weak var shared: StatusItemController?
    static let popoverWidth: CGFloat = 320

    private var statusItem: NSStatusItem
    private var window: ArrowPopoverWindow?
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
        refreshTask?.cancel()
        liveMonitoringTask?.cancel()
        if let g = globalEventMonitor { NSEvent.removeMonitor(g) }
        if let l = localEventMonitor { NSEvent.removeMonitor(l) }
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

    func updateMenuBarCount(_ count: Int) {
        guard let button = statusItem.button else { return }
        if ConfigStore.shared.config.showMenuBarCount {
            button.title = " \(count)"
            button.imagePosition = .imageLeading
            button.toolTip = "KillX — \(count) listeners"
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            button.toolTip = "KillX"
        }
    }

    private var cachedMenuBarIcon: NSImage?

    private func makeMenuBarIcon() -> NSImage {
        if let cached = cachedMenuBarIcon {
            return cached
        }
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
            cachedMenuBarIcon = icon
            return icon
        }

        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.black.setFill()
        let rounded = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 17, height: 17), xRadius: 4, yRadius: 4)
        rounded.fill()
        image.unlockFocus()
        image.isTemplate = true
        cachedMenuBarIcon = image
        return image
    }

    @MainActor
    private func configureWindow() {
        let rootView = AnyView(
            MainPopoverView()
                .environmentObject(ConfigStore.shared)
        )
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = []
        hosting.view.wantsLayer = true
        self.hostingController = hosting

        let win = ArrowPopoverWindow(level: .popUpMenu)
        win.contentViewController = hosting
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
        let calculated: CGFloat
        if count == 0 {
            calculated = 175
        } else {
            let baseHeight: CGFloat = 95
            let rowHeight: CGFloat = 27
            calculated = baseHeight + (CGFloat(count) * rowHeight)
        }

        let minPopoverHeight: CGFloat = 220
        let effectiveCalculated = max(calculated, minPopoverHeight)
        let arrowHeight: CGFloat = 12
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 800
        let maximumHeight = max(100, screenHeight - 48)
        let targetHeight = min(maximumHeight, effectiveCalculated)
        let needsScrolling = calculated > maximumHeight
        if AppListViewModel.shared.listNeedsScrolling != needsScrolling {
            AppListViewModel.shared.listNeedsScrolling = needsScrolling
        }

        let totalHeight = targetHeight + arrowHeight
        let newSize = NSSize(width: Self.popoverWidth, height: totalHeight)
        guard let win = window else { return }

        var frame = win.frame
        frame.size = newSize

        var originX = frame.origin.x
        var originY = frame.origin.y
        var arrowX: CGFloat = 170

        if let button = statusItem.button, let btnWindow = button.window {
            let buttonScreenRect = btnWindow.convertToScreen(button.bounds)
            originX = buttonScreenRect.midX - (newSize.width / 2)
            originY = buttonScreenRect.minY - totalHeight - 2

            if let scr = screen {
                let screenMinX = scr.visibleFrame.minX
                let screenMaxX = scr.visibleFrame.maxX
                originX = max(screenMinX + 4, min(originX, screenMaxX - newSize.width - 4))
            }
            arrowX = buttonScreenRect.midX - originX
        } else if let scr = screen ?? NSScreen.main {
            originX = scr.visibleFrame.midX - (newSize.width / 2)
            originY = scr.visibleFrame.maxY - totalHeight - 2
        }

        frame.origin = NSPoint(x: originX, y: originY)
        frame = frame.integral
        if abs(AppListViewModel.shared.arrowX - arrowX) >= 0.5 {
            AppListViewModel.shared.arrowX = arrowX
        }
        guard frame != win.frame else { return }
        win.setFrame(frame, display: win.isVisible, animate: false)
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
        AppListViewModel.shared.pendingKillConfirmation = nil
        if isShown {
            lastCloseTimestamp = Date()
        }
        stopLiveMonitoring()
        removeOutsideClickMonitor()
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
            updatePopoverSize()
            win.contentView?.layoutSubtreeIfNeeded()
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(nil)
            win.invalidateShadow()
            refreshVisibleApps()
            installOutsideClickMonitor()
            startLiveMonitoring()
        }
    }

    private func refreshVisibleApps() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            guard !Task.isCancelled, let self else { return }
            self.updatePopoverSize()
        }
    }

    private func startLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = Task { @MainActor [weak self] in
            var tick = 0
            while let self = self, self.isShown {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, self.isShown else { break }
                tick += 1
                if tick % 5 == 0 {
                    await AppListViewModel.shared.refresh()
                } else {
                    await AppListViewModel.shared.updateLiveStats()
                }
                self.updatePopoverSize()
            }
        }
    }

    private func stopLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = nil
    }

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(MenuHelper.makeItem(
            title: "Settings",
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape",
            action: {
                SettingsWindowController.shared.show()
            }
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Refresh Ports",
            keyEquivalent: "r",
            systemSymbolName: "arrow.clockwise",
            action: {
                Task {
                    await AppListViewModel.shared.refresh()
                }
            }
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Help",
            keyEquivalent: "?",
            assetName: "settings-help",
            systemSymbolName: "questionmark.circle",
            action: { [weak self] in
                self?.closePopover()
                HelpWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "About KillX",
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle",
            action: {
                SettingsWindowController.shared.show(tab: .about)
            }
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit",
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power",
            action: {
                NSApplication.shared.terminate(nil)
            }
        ))

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    private func startEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.isShown else { return event }

            if event.type == .keyDown {
                if event.keyCode == 53 {
                    if AppListViewModel.shared.pendingKillConfirmation != nil {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            AppListViewModel.shared.pendingKillConfirmation = nil
                        }
                        return nil
                    }
                    self.closePopover()
                    return nil
                }
                if event.keyCode == 36 {
                    if let req = AppListViewModel.shared.pendingKillConfirmation {
                        let action = req.action
                        AppListViewModel.shared.pendingKillConfirmation = nil
                        Task { await action() }
                        return nil
                    }
                }

                if event.modifierFlags.contains(.command) {
                    let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
                    if chars == "a" {
                        let isEditingText = self.window?.firstResponder is NSText
                        if !isEditingText {
                            AppListViewModel.shared.toggleSelectAll()
                            return nil
                        }
                    } else if chars == "," {
                        self.closePopover()
                        SettingsWindowController.shared.show()
                        return nil
                    } else if chars == "h" || chars == "?" || (chars == "/" && event.modifierFlags.contains(.shift)) {
                        self.closePopover()
                        HelpWindowController.shared.show()
                        return nil
                    } else if chars == "i" {
                        self.closePopover()
                        SettingsWindowController.shared.show(tab: .about)
                        return nil
                    }
                }
            }

            let popupWindow = self.window
            let statusWindow = self.statusItem.button?.window
            if event.window !== popupWindow, event.window !== statusWindow {
                self.closePopover()
            }
            return event
        }
    }

    private func installOutsideClickMonitor() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.isShown else { return }

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
    }

    private func removeOutsideClickMonitor() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
}
