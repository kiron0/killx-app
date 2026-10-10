import SwiftUI
import AppKit

enum AssetImages {
    static func load(_ name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let localPath = "Support/Icons/\(name).png"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            return img
        }
        return nil
    }

    static var appIcon: NSImage? {
        if let img = load("icon_128x128") ?? load("icon_256x256") ?? load("icon_512x512") {
            return img
        }
        if let bundleImage = Bundle.main.image(forResource: "AppIcon") {
            return bundleImage
        }
        let localPath = "Support/Icons/icon_128x128.png"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            return img
        }
        return NSApp.applicationIconImage
    }
}

struct KillXAppIconView: View {
    var size: CGFloat = 70
    var cornerRadius: CGFloat = 0

    var body: some View {
        Group {
            if let image = AssetImages.appIcon {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "target")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(KillXTheme.accent)
                    .frame(width: size, height: size)
            }
        }
    }
}

typealias QuitXAppIconView = KillXAppIconView

enum MenuHelper {
    final class ClosureMenuItem: NSMenuItem {
        private let handler: () -> Void

        init(title: String, keyEquivalent: String, handler: @escaping () -> Void) {
            self.handler = handler
            super.init(title: title, action: #selector(didClick), keyEquivalent: keyEquivalent)
            self.target = self
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func didClick() {
            handler()
        }
    }

    static func makeItem(
        title: String,
        action: Selector?,
        target: AnyObject?,
        keyEquivalent: String = "",
        keyEquivalentModifierMask: NSEvent.ModifierFlags = [.command],
        assetName: String? = nil,
        systemSymbolName: String? = nil,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        item.isEnabled = isEnabled
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = keyEquivalentModifierMask
        }

        var image: NSImage?
        if let assetName = assetName, let loaded = AssetImages.load(assetName) {
            let copy = loaded.copy() as? NSImage ?? loaded
            copy.size = NSSize(width: 15, height: 15)
            copy.isTemplate = true
            image = copy
        } else if let systemSymbolName = systemSymbolName,
                  let sym = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .regular)
            let configured = sym.withSymbolConfiguration(config) ?? sym
            let copy = configured.copy() as? NSImage ?? configured
            copy.size = NSSize(width: 15, height: 15)
            copy.isTemplate = true
            image = copy
        }

        if let image = image {
            item.image = image
            if item.responds(to: Selector(("setPreferredImageVisibility:"))) {
                item.setValue(1, forKey: "preferredImageVisibility")
            }
        }

        return item
    }

    static func makeItem(
        title: String,
        keyEquivalent: String = "",
        keyEquivalentModifierMask: NSEvent.ModifierFlags = [.command],
        assetName: String? = nil,
        systemSymbolName: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: keyEquivalent, handler: action)
        item.isEnabled = isEnabled
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = keyEquivalentModifierMask
        }

        var image: NSImage?
        if let assetName = assetName, let loaded = AssetImages.load(assetName) {
            let copy = loaded.copy() as? NSImage ?? loaded
            copy.size = NSSize(width: 15, height: 15)
            copy.isTemplate = true
            image = copy
        } else if let systemSymbolName = systemSymbolName,
                  let sym = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .regular)
            let configured = sym.withSymbolConfiguration(config) ?? sym
            let copy = configured.copy() as? NSImage ?? configured
            copy.size = NSSize(width: 15, height: 15)
            copy.isTemplate = true
            image = copy
        }

        if let image = image {
            item.image = image
            if item.responds(to: Selector(("setPreferredImageVisibility:"))) {
                item.setValue(1, forKey: "preferredImageVisibility")
            }
        }

        return item
    }

    static func makeSubmenuItem(
        title: String,
        assetName: String? = nil,
        systemSymbolName: String? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        item.submenu?.autoenablesItems = false

        var image: NSImage?
        if let assetName = assetName, let loaded = AssetImages.load(assetName) {
            let copy = loaded.copy() as? NSImage ?? loaded
            copy.size = NSSize(width: 15, height: 15)
            copy.isTemplate = true
            image = copy
        } else if let systemSymbolName = systemSymbolName,
                  let sym = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .regular)
            let configured = sym.withSymbolConfiguration(config) ?? sym
            let copy = configured.copy() as? NSImage ?? configured
            copy.size = NSSize(width: 15, height: 15)
            copy.isTemplate = true
            image = copy
        }

        if let image = image {
            item.image = image
            if item.responds(to: Selector(("setPreferredImageVisibility:"))) {
                item.setValue(1, forKey: "preferredImageVisibility")
            }
        }

        return item
    }
}
