import AppKit
import SwiftUI
import Combine

private final class SettingsWindow: NSWindow {
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        0.18
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var activeTab: SettingsTab = .general
    private let tabModel = SettingsTabViewModel()
    private var hostingController: NSHostingController<AnyView>?
    private var toolbar: NSToolbar?
    private var appliedGlass = false
    private var chromeObserver: AnyCancellable?

    private override init() {
        super.init()
        chromeObserver = ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyWindowChrome() }
            }
    }

    func applyWindowChrome() {
        guard let win = window else { return }
        let enabled = LiquidGlass.enabled
        guard appliedGlass != enabled else { return }
        appliedGlass = enabled
        let savedFrame = win.frame
        if enabled {
            if !win.styleMask.contains(.fullSizeContentView) {
                win.styleMask.insert(.fullSizeContentView)
            }
            win.isOpaque = false
            win.backgroundColor = .clear
            let inset = win.frame.height - win.contentRect(forFrameRect: win.frame).height
            if inset > 0 {
                tabModel.glassTopInset = inset
            }
        } else {
            if win.styleMask.contains(.fullSizeContentView) {
                win.styleMask.remove(.fullSizeContentView)
            }
            win.backgroundColor = KillXTheme.toolbarBackgroundNSColor
            win.isOpaque = true
            tabModel.glassTopInset = 0
        }
        win.titlebarAppearsTransparent = true
        if win.frame != savedFrame {
            win.setFrame(savedFrame, display: true, animate: false)
        }
    }

    var isOpen: Bool { window != nil }

    func show(tab: SettingsTab? = nil) {
        StatusItemController.shared?.closePopover()

        let targetTab = tab ?? .general

        if let win = window {
            dismissTooltips(for: win)
            if let tab = tab {
                switchToTab(tab)
            }
            if let screen = WindowPositioner.targetScreen {
                let targetFrame = targetFrameFor(win, tab: activeTab, screen: screen)
                win.setFrame(targetFrame, display: true)
            }
            WindowAnimator.activateExisting(win)
            return
        }

        activeTab = targetTab
        tabModel.activeTab = targetTab

        let initialContentRect = NSRect(x: 0, y: 0, width: 480, height: targetTab.contentHeight)

        let win = SettingsWindow(
            contentRect: initialContentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = targetTab.rawValue
        if LiquidGlass.enabled {
            win.styleMask.insert(.fullSizeContentView)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.titlebarAppearsTransparent = true
        } else {
            win.styleMask.remove(.fullSizeContentView)
            win.isOpaque = true
            win.backgroundColor = KillXTheme.toolbarBackgroundNSColor
            win.titlebarAppearsTransparent = true
        }
        appliedGlass = LiquidGlass.enabled
        win.titlebarSeparatorStyle = .line
        win.isMovableByWindowBackground = false
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.animationBehavior = .documentWindow
        win.delegate = self

        let tb = NSToolbar(identifier: "KillXSettingsToolbar")
        tb.allowsUserCustomization = false
        tb.autosavesConfiguration = false
        tb.displayMode = .iconAndLabel
        tb.delegate = self
        tb.selectedItemIdentifier = targetTab.toolbarItemIdentifier
        self.toolbar = tb
        win.toolbar = tb
        win.toolbarStyle = .preference

        let container = SettingsContainerView(tabModel: tabModel)
            .environmentObject(ConfigStore.shared)

        let hosting = NSHostingController(rootView: AnyView(container))
        self.hostingController = hosting
        win.contentViewController = hosting
        self.window = win

        WindowActivationCoordinator.update()

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = targetFrameFor(win, tab: targetTab, screen: screen)
        } else {
            win.center()
            targetFrame = win.frame
        }
        WindowAnimator.present(win, targetFrame: targetFrame)

        if LiquidGlass.enabled {
            let inset = win.frame.height - win.contentRect(forFrameRect: win.frame).height
            if inset > 0 {
                tabModel.glassTopInset = inset
            }
        }
    }

    private func targetHeight(for win: NSWindow, tab: SettingsTab) -> CGFloat {
        let chromeHeight = win.frame.height - win.contentLayoutRect.height
        let effectiveChrome = chromeHeight > 0 ? chromeHeight : 88
        return tab.contentHeight + effectiveChrome
    }

    private func targetFrameFor(_ win: NSWindow, tab: SettingsTab, screen: NSScreen) -> NSRect {
        let height = targetHeight(for: win, tab: tab)
        let size = NSSize(width: 480, height: height)
        return WindowPositioner.topBiasedFrame(for: size, on: screen)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
        toolbar = nil
        WindowActivationCoordinator.update()
    }

    private func dismissTooltips(for win: NSWindow) {
        HelpPopoverState.closeAll()
        for child in win.childWindows ?? [] {
            if "\(type(of: child))".contains("Popover") || child.className.contains("Popover") {
                child.orderOut(nil)
                win.removeChildWindow(child)
            }
        }
        for w in NSApp.windows where w.parent === win {
            if "\(type(of: w))".contains("Popover") || w.className.contains("Popover") {
                w.orderOut(nil)
                win.removeChildWindow(w)
            }
        }
    }

    func switchToTab(_ tab: SettingsTab) {
        guard let win = window else { return }
        dismissTooltips(for: win)
        if activeTab == tab { return }
        activeTab = tab

        toolbar?.selectedItemIdentifier = tab.toolbarItemIdentifier
        win.title = tab.rawValue

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tabModel.activeTab = tab
        }

        let currentFrame = win.frame
        let height = targetHeight(for: win, tab: tab)
        let newY = currentFrame.maxY - height
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: 480, height: height)

        win.setFrame(newFrame, display: true, animate: false)
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map { $0.toolbarItemIdentifier }
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    nonisolated func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    @objc func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.rawValue
        item.paletteLabel = tab.rawValue
        item.image = tab.toolbarImage
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab(rawValue: sender.itemIdentifier.rawValue) else { return }
        if let win = window {
            dismissTooltips(for: win)
        }
        switchToTab(tab)
    }
}
