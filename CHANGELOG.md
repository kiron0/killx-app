# Changelog

All notable changes to KillX macOS App will be documented in this file.

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
