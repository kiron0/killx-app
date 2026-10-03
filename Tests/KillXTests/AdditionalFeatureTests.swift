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
        #expect(all.contains(.shortcuts))
        #expect(all.contains(.support))
        #expect(all.contains(.about))
    }

    @Test("SettingsTab toolbar item identifiers")
    func testSettingsTabToolbarItemIdentifier() {
        #expect(SettingsTab.general.toolbarItemIdentifier.rawValue == "General")
        #expect(SettingsTab.shortcuts.toolbarItemIdentifier.rawValue == "Shortcuts")
        #expect(SettingsTab.support.toolbarItemIdentifier.rawValue == "Support")
        #expect(SettingsTab.about.toolbarItemIdentifier.rawValue == "About")
    }

    @Test("SettingsTab icon names")
    func testSettingsTabIconNames() {
        #expect(SettingsTab.general.iconName == "preferences-general")
        #expect(SettingsTab.shortcuts.iconName == "preferences-shortcuts")
        #expect(SettingsTab.support.iconName == "preferences-support")
        #expect(SettingsTab.about.iconName == "preferences-about")
    }

    @Test("SettingsTab content heights")
    func testSettingsTabContentHeights() {
        #expect(SettingsTab.general.contentHeight == 340)
        #expect(SettingsTab.shortcuts.contentHeight == 215)
        #expect(SettingsTab.support.contentHeight == 139)
        #expect(SettingsTab.about.contentHeight == 130)
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
}

@Suite("Theme and Visual Tokens Tests")
struct ThemeTests {
    @Test("KillXTheme accent color is brand rose")
    func testThemeAccent() {
        let accent = KillXTheme.accentNSColor
        #expect(accent.redComponent > 0.9)
        #expect(accent.greenComponent < 0.35)
        #expect(accent.blueComponent < 0.45)
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
