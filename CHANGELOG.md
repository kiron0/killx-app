# Changelog

All notable changes to KillX macOS App will be documented in this file.

## 1.0.2

### Added

- Tree termination by default across all actions, eliminating manual tree toggles.
- App-bundle and IDE process safety protections preventing accidental termination of GUI apps and editors.
- Post-kill port release verification with error toast notifications when termination fails.
- Shortcut modifier validation and dedicated Shortcuts and About settings tabs.
- Dynamic path-based detection rules for dev tools and system-protected services.

### Changed

- Renamed "Tree Kill" terminology and UI actions to unified "Kill" across the entire app.
- Simplified kill confirmation dialog messages to remove verbose caution text.
- Unified action button and quit icon styling to support dynamic force-kill states.
- Optimized process tree scanning, Docker availability caching, and port termination performance.

### Fixed

- Prevented false positive IDE protection matches on generic Electron helper processes.
- Fixed settings tab dimensions and background appearance rendering.

## 1.0.1

### Added

- Exclude tab in Settings to safeguard ports from termination.
- Add Ports picker to search active listeners or exclude custom port numbers.
- Port details inspector with process tree tracer and inline kill confirmation.
- In-app update checker downloading directly from GitHub Releases.

### Changed

- Updated app theme and icon accent to high-visibility sky blue.
- Synchronized confirm prompt buttons to use uniform accent styling.
- Permanently hidden system protected ports to safeguard macOS services.
- Removed dev server sweeping and filters for a cleaner, focused experience.
- Automated release workflows packaging both `.dmg` and `.zip` assets.

## 1.0.0

### Added

- Initial release of KillX for macOS (native Swift, AppKit & SwiftUI).
- Menubar status item with fast popover UI.
- Real-time listening port inspection across all TCP processes.
- One-click port kill and Option-key dynamic SIGKILL escalation.
- Process tree termination (`--tree`) to kill parent supervisor trees (npm, vite, bun, cargo).
- System protected process defense to safeguard macOS core services.
- Docker container port detection and graceful container stopping.
- Instant search filter and port number / process name / RAM / CPU sorting options.
- Native system sound effects and toast notifications.
- Launch at login support and automatic update checks.
