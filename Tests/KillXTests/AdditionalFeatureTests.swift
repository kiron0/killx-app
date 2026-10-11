import Testing
import AppKit
import SwiftUI
@testable import KillX

@Suite("Settings Tab Tests")
struct SettingsTabTests {
    @Test("SettingsTab all cases")
    func testSettingsTabCases() {
        let all = SettingsTab.allCases
        #expect(all.count == 4)
        #expect(all.contains(.general))
        #expect(all.contains(.exclude))
        #expect(all.contains(.shortcuts))
        #expect(all.contains(.about))
    }

    @Test("SettingsTab toolbar item identifiers")
    func testSettingsTabToolbarItemIdentifier() {
        #expect(SettingsTab.general.toolbarItemIdentifier.rawValue == "General")
        #expect(SettingsTab.exclude.toolbarItemIdentifier.rawValue == "Exclude")
        #expect(SettingsTab.shortcuts.toolbarItemIdentifier.rawValue == "Shortcuts")
        #expect(SettingsTab.about.toolbarItemIdentifier.rawValue == "About")
    }

    @Test("SettingsTab icon names")
    func testSettingsTabIconNames() {
        #expect(SettingsTab.general.iconName == "preferences-general")
        #expect(SettingsTab.exclude.iconName == "preferences-exclude")
        #expect(SettingsTab.shortcuts.iconName == "preferences-shortcuts")
        #expect(SettingsTab.about.iconName == "preferences-about")
    }

    @Test("SettingsTab content heights")
    func testSettingsTabContentHeights() {
        if #available(macOS 26.0, *) {
            #expect(SettingsTab.general.contentHeight == 330)
        } else {
            #expect(SettingsTab.general.contentHeight == 300)
        }
        #expect(SettingsTab.exclude.contentHeight == 306)
        #expect(SettingsTab.shortcuts.contentHeight == 221)
        #expect(SettingsTab.about.contentHeight == 186)
    }

    @Test("SettingsTab URLs")
    func testSettingsTabURLs() {
        let sayHi = KillXConstants.sayHiURL()
        #expect(sayHi != nil)
        #expect(sayHi?.scheme == "mailto")

        let contact = KillXConstants.contactURL()
        #expect(contact != nil)
        #expect(contact?.scheme == "mailto")
    }

    @Test("SettingsTab toolbar images generated and template")
    func testSettingsTabToolbarImages() {
        for tab in SettingsTab.allCases {
            let img = tab.toolbarImage
            #expect(img != nil)
            #expect(img?.isTemplate == true)
            #expect(img?.size == NSSize(width: 19, height: 19))
        }
    }

    @Test("ConfigStore add and remove excluded ports")
    @MainActor
    func testConfigStoreExcludePorts() {
        let store = ConfigStore.shared
        store.removeAllExcludedPorts()
        #expect(store.config.excludePorts.isEmpty)

        let added = store.addExcludedPorts([3000, 8080, 3000])
        #expect(added == 2)
        #expect(store.config.excludePorts == [3000, 8080])

        store.removeExcludedPorts([3000])
        #expect(store.config.excludePorts == [8080])

        store.removeAllExcludedPorts()
        #expect(store.config.excludePorts.isEmpty)
    }

    @Test("ExcludeRemovalRequest titles and messages")
    func testExcludeRemovalRequest() {
        let single = ExcludeRemovalRequest(ports: [3000], totalCount: 5)
        #expect(single.title == "Remove Port :3000?")
        #expect(single.removesAll == false)

        let all = ExcludeRemovalRequest(ports: [3000, 8080], totalCount: 2)
        #expect(all.title == "Remove all excluded ports?")
        #expect(all.removesAll == true)
    }
}

@Suite("Theme and Visual Tokens Tests")
struct ThemeTests {
    @Test("KillXTheme accent color is high visibility sky")
    func testThemeAccent() {
        let accent = KillXTheme.accentNSColor
        #expect(accent.blueComponent > 0.90)
        #expect(accent.greenComponent > 0.65)
        #expect(accent.redComponent < 0.30)
    }

    @Test("KillXTheme window background color available")
    func testThemeWindowBackground() {
        let bg = KillXTheme.windowBackgroundNSColor
        #expect(bg == NSColor.windowBackgroundColor)
    }
}

@Suite("Asset Images Tests")
struct AssetImagesTests {
    @Test("App icon returns valid image")
    func testAppIconValid() {
        let img = AssetImages.appIcon
        #expect(img != nil)
    }

    @Test("Load existing bundle/support icon")
    func testLoadSettingsIcon() {
        let img = AssetImages.load("settings")
        #expect(img != nil)
    }

    @Test("Load menu-options icon")
    func testLoadMenuOptionsIcon() {
        let img = AssetImages.load("menu-options")
        #expect(img != nil)
    }

    @Test("Load status-icon")
    func testLoadStatusIcon() {
        let img = AssetImages.load("status-icon")
        #expect(img != nil)
    }

    @Test("Load non-existent image returns nil")
    func testLoadNonExistentImage() {
        let img = AssetImages.load("non_existent_image_foo_bar_xyz")
        #expect(img == nil)
    }
}

@Suite("ConfigStore & Persistence Tests")
struct ConfigStoreTests {
    @Test("Shared instance exists and loads default")
    func testConfigStoreShared() {
        let store = ConfigStore.shared
        #expect(store.config.autoUpdate == true)
    }

    @Test("Config encoding format is valid JSON")
    func testConfigJSONSerialization() throws {
        let cfg = KillXConfig.default
        let data = try JSONEncoder().encode(cfg)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString != nil)
        #expect(jsonString?.contains("force") == true)
        #expect(jsonString?.contains("sortBy") == true)
    }

    @Test("Corrupted JSON does not crash and decodes default gracefully")
    func testCorruptedJSONHandling() {
        let corrupted = "INVALID_JSON_DATA{{{".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(KillXConfig.self, from: corrupted)
        #expect(decoded == nil)
    }
}

@Suite("UpdateChecker Version Parsing Tests")
struct UpdateCheckerTests {
    @Test("Version comparison detects newer semantic versions")
    @MainActor
    func testVersionComparison() {
        let checker = UpdateChecker.shared
        #expect(checker.isVersion("1.1.0", greaterThan: "1.0.0"))
        #expect(checker.isVersion("2.0.0", greaterThan: "1.9.9"))
        #expect(checker.isVersion("1.0.1", greaterThan: "1.0.0"))
        #expect(!checker.isVersion("1.0.0", greaterThan: "1.0.0"))
        #expect(!checker.isVersion("0.9.0", greaterThan: "1.0.0"))
    }
}
