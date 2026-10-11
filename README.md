<p align="center">
  <img src="Support/Icons/icon_256x256.png" width="96" height="96" alt="KillX Icon" />
</p>

<h1 align="center">KillX for macOS</h1>

<p align="center">
  Fast, minimal menubar companion to find, trace, and terminate listening ports, dev servers, and applications.
</p>

<p align="center">
  <a href="https://github.com/kiron0/killx/actions/workflows/ci.yml"><img src="https://github.com/kiron0/killx/actions/workflows/ci.yml/badge.svg" alt="CI Status" /></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift 6" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" /></a>
</p>

<p align="center">
  <a href="https://github.com/kiron0/killx/releases/latest">
    <img src="https://img.shields.io/github/v/release/kiron0/killx?label=Download%20KillX%20for%20macOS&style=for-the-badge&color=FFB800&labelColor=1a1a1a&logo=apple" alt="Download KillX for macOS" height="38" />
  </a>
</p>

---

## Features

- **Ports Management (`Ports` tab)**:
  - Real-time inspection of active TCP listening ports (`:3000`, `:5173`, `:8080`, etc.).
  - Identify process names, PIDs, memory usage, and commands.
  - Kill single port listeners gracefully (`SIGTERM`) or hold <kbd>⌥ Option</kbd> for force kill (`SIGKILL`).
  - **Process Tree Killing (`--tree`)**: Terminate root supervisors (npm, yarn, pnpm, cargo, vite) and all child processes cleanly.
  - **Docker-Aware**: Detects Docker container port forwards and allows stopping containers gracefully.
- **Deep Process Trace (`killx trace`)**:
  - Interactive process tree visualizer detailing parent PIDs, PPIDs, working directories, and startup commands.
- **macOS Applications (`Apps` tab)**:
  - Inspect and quit running applications and background daemon processes.
  - Session stash and restore support.

---

## Install

1. Download the latest release `.dmg`.
2. Drag **KillX** into `/Applications`.
3. Launch from Applications or Spotlight. It lives in your menu bar.

---

## CLI Companion

KillX also includes a Node-based terminal CLI and Go CLI:

```bash
npm install -g killx
# or run directly
npx killx 3000
```

---

## License

MIT © [Toufiq Hasan Kiron](https://github.com/kiron0)
