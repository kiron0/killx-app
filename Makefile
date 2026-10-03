APP_NAME = KillX
BUNDLE_ID = io.coreify.killx
VERSION = 1.0.0
APP_DIR = .build/$(APP_NAME).app
CONTENTS = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources

.PHONY: all build bundle run clean test ship

## Default: build + bundle
all: bundle

## Compile with SPM (release)
build:
	@swift build -c release --build-system native 2>&1 | grep -v "build-system native" || true

## Wrap binary in a minimal .app bundle
bundle: build
	@echo "▶ Creating $(APP_NAME).app bundle..."
	@rm -rf $(APP_DIR)
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@if [ -f .build/release/$(APP_NAME) ]; then \
		cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME); \
	elif [ -f .build/arm64-apple-macosx/release/$(APP_NAME) ]; then \
		cp .build/arm64-apple-macosx/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME); \
	elif [ -f .build/debug/$(APP_NAME) ]; then \
		cp .build/debug/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME); \
	else \
		cp .build/arm64-apple-macosx/debug/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME); \
	fi
	@chmod +x $(MACOS_DIR)/$(APP_NAME)
	@cp Support/Info.plist $(CONTENTS)/Info.plist
	@cp Support/Icons/* $(RESOURCES_DIR)/ 2>/dev/null || true
	@cp Support/Sounds/* $(RESOURCES_DIR)/ 2>/dev/null || true
	@cp Support/Assets.car $(RESOURCES_DIR)/ 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" $(CONTENTS)/Info.plist 2>/dev/null || true
	@codesign --force --deep --sign - $(APP_DIR) 2>/dev/null || true
	@echo "✅ Bundle ready: $(APP_DIR)"

## Create DMG installer
dmg: bundle
	@echo "▶ Creating $(APP_NAME).dmg..."
	@rm -rf .build/dmg-staging
	@mkdir -p .build/dmg-staging
	@cp -R $(APP_DIR) .build/dmg-staging/
	@ln -s /Applications .build/dmg-staging/Applications
	@hdiutil create -volname "$(APP_NAME)" -srcfolder .build/dmg-staging -ov -format UDZO .build/$(APP_NAME).dmg
	@rm -rf .build/dmg-staging
	@echo "✅ DMG ready: .build/$(APP_NAME).dmg"

## Launch the app bundle
run: bundle
	@echo "▶ Launching $(APP_NAME)..."
	@open $(APP_DIR)

## Build debug + run binary directly (fast iteration, no bundle)
dev:
	@swift build --build-system native 2>&1 | grep -v "build-system native" || true
	@.build/debug/$(APP_NAME)

## Run tests
test:
	@swift test --build-system native -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks 2>&1 | grep -v "build-system native" || true

## Test, bundle, kill, install, and open in one go
ship:
	@Scripts/ship.sh

## Clean build artifacts
clean:
	@swift package clean
	@rm -rf .build/$(APP_NAME).app
	@echo "✅ Cleaned"

## Print project info
info:
	@echo "App:      $(APP_NAME)"
	@echo "Bundle:   $(BUNDLE_ID)"
	@echo "Version:  $(VERSION)"
	@swift --version
