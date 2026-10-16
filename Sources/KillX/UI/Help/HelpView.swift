import AppKit
import SwiftUI

enum KillXHelpCategory: String, CaseIterable, Identifiable, Sendable {
    case essentials = "Essentials"
    case features = "Features"
    case preferences = "Preferences"
    case support = "Support"

    var id: String { rawValue }
}

struct KillXHelpSection: Hashable, Sendable {
    let title: String
    let body: String
    let bullets: [String]

    init(title: String, body: String, bullets: [String] = []) {
        self.title = title
        self.body = body
        self.bullets = bullets
    }
}

struct KillXHelpTopic: Identifiable, Hashable, Sendable {
    let id: String
    let category: KillXHelpCategory
    let title: String
    let symbol: String
    let summary: String
    let sections: [KillXHelpSection]
    let searchableContent: String

    init(
        id: String,
        category: KillXHelpCategory,
        title: String,
        symbol: String,
        summary: String,
        sections: [KillXHelpSection]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.sections = sections
        self.searchableContent = ([title, summary] + sections.flatMap { [$0.title, $0.body] + $0.bullets })
            .joined(separator: " ")
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return searchableContent.localizedCaseInsensitiveContains(trimmed)
    }

    static let all: [KillXHelpTopic] = [
        KillXHelpTopic(
            id: "quick-start",
            category: .essentials,
            title: "Quick Start",
            symbol: "bolt.fill",
            summary: "Open KillX, view listening ports, and terminate processes occupying ports in one click.",
            sections: [
                KillXHelpSection(
                    title: "Open KillX",
                    body: "Click the KillX menu bar icon or press your configured global shortcut. The popover instantly lists all active listening ports with real-time CPU and memory metrics."
                ),
                KillXHelpSection(
                    title: "Filter & Select",
                    body: "Search by port number, process name, PID, or working directory. Toggle individual checkboxes or use the master checkbox to select all visible matching ports."
                ),
                KillXHelpSection(
                    title: "Kill Ports",
                    body: "Click the primary action button to terminate all selected ports, or click the kill button on any port row to terminate a single listener."
                )
            ]
        ),
        KillXHelpTopic(
            id: "port-list",
            category: .essentials,
            title: "Port List & Actions",
            symbol: "network",
            summary: "Understand bind addresses, process trees, quick actions, and row menus.",
            sections: [
                KillXHelpSection(
                    title: "Process & Address Badges",
                    body: "Each row displays the port number, bind address exposure (Localhost, LAN, or All Interfaces), process name, PID, and live resource usage. Docker containers show dedicated container tags."
                ),
                KillXHelpSection(
                    title: "Row Context Menu",
                    body: "Click the three-dot button on any row for quick actions:",
                    bullets: [
                        "View Port Details & process tree hierarchy",
                        "Copy Port Number, PID, or restart command",
                        "Open Terminal at listener working directory (CWD)",
                        "Open in Browser (http://localhost:port)",
                        "Add port to Exclude List or Favorites"
                    ]
                ),
                KillXHelpSection(
                    title: "Favorites & Quick Access",
                    body: "Star frequently monitored ports to pin them at the top of the list for quick access and batch operations."
                )
            ]
        ),
        KillXHelpTopic(
            id: "kill-modes",
            category: .features,
            title: "Kill Signals & Termination",
            symbol: "power",
            summary: "Graceful SIGTERM, interrupt SIGINT, and immediate SIGKILL force termination.",
            sections: [
                KillXHelpSection(
                    title: "Graceful Kill (SIGTERM)",
                    body: "SIGTERM asks the process to exit cleanly, finish active requests, and release ports. This is the default safe mode."
                ),
                KillXHelpSection(
                    title: "Interrupt Signal (SIGINT)",
                    body: "Sends Ctrl+C interrupt signals to processes that respond better to interactive cancellation."
                ),
                KillXHelpSection(
                    title: "Force Kill (SIGKILL)",
                    body: "Hold ⌥ Option while clicking any kill button to force terminate immediately with SIGKILL, bypassing unresponsive loops."
                ),
                KillXHelpSection(
                    title: "Process Tree & PID Verification",
                    body: "KillX terminates the supervisor and all child processes so file watchers (nodemon, cargo watch, vite) cannot re-bind the port. PID identity checks prevent signaling recycled process IDs."
                )
            ]
        ),
        KillXHelpTopic(
            id: "port-watching",
            category: .features,
            title: "Port Watching & Alerts",
            symbol: "eye.fill",
            summary: "Watch critical ports and receive system notifications on state or owner changes.",
            sections: [
                KillXHelpSection(
                    title: "Watch Selected Ports",
                    body: "Enable port watching to monitor specific development ports in the background. KillX alerts you when a port is claimed, closed, or switched to a different process."
                ),
                KillXHelpSection(
                    title: "Menu Bar Listener Count",
                    body: "Optionally show the active listening port count directly in your macOS menu bar next to the KillX icon."
                )
            ]
        ),
        KillXHelpTopic(
            id: "listener-grouping",
            category: .features,
            title: "Listener Grouping",
            symbol: "folder.fill",
            summary: "Group listeners by project, Docker container, or process tree.",
            sections: [
                KillXHelpSection(
                    title: "Grouping Modes",
                    body: "Organize the port list by project workspace directory, Docker container, or parent process tree to manage complex multi-service stacks at a glance."
                )
            ]
        ),
        KillXHelpTopic(
            id: "history-diagnostics",
            category: .features,
            title: "History & Diagnostics",
            symbol: "clock.arrow.circlepath",
            summary: "Review recent port bindings, termination audit logs, and export redacted diagnostics.",
            sections: [
                KillXHelpSection(
                    title: "Listener & Kill History",
                    body: "Track recently terminated ports, process names, timestamps, and termination results to easily audit what ran on your system."
                ),
                KillXHelpSection(
                    title: "Terminal & Restart Command",
                    body: "Copy the original startup command for any listener or launch a new Terminal window directly at the process working directory."
                ),
                KillXHelpSection(
                    title: "Redacted Diagnostics",
                    body: "Export sanitized diagnostic reports containing port bindings, platform versions, and scan metrics without exposing private tokens or environment variables."
                )
            ]
        ),
        KillXHelpTopic(
            id: "network-exposure",
            category: .features,
            title: "Network Exposure & UDP",
            symbol: "shield.lefthalf.filled",
            summary: "Inspect bind-address scope, Docker bridges, and discover UDP listeners.",
            sections: [
                KillXHelpSection(
                    title: "Bind Address Exposure",
                    body: "KillX labels network interface exposure for every port:",
                    bullets: [
                        "Localhost (127.0.0.1 / ::1) - private to your Mac",
                        "LAN (192.168.x.x / 10.x.x.x) - accessible on local network",
                        "All Interfaces (* / 0.0.0.0) - exposed publicly on all adapters"
                    ]
                ),
                KillXHelpSection(
                    title: "UDP Port Discovery",
                    body: "Toggle UDP listener discovery in Settings > Monitoring to monitor UDP services alongside standard TCP listeners."
                ),
                KillXHelpSection(
                    title: "Docker Container Mapping",
                    body: "KillX maps Docker container port bindings to their host endpoints and issues graceful docker stop commands when killing containerized services."
                )
            ]
        ),
        KillXHelpTopic(
            id: "exclude",
            category: .features,
            title: "Exclude & Safety Guardrails",
            symbol: "nosign",
            summary: "Protect databases, development servers, and system daemons from accidental termination.",
            sections: [
                KillXHelpSection(
                    title: "Adding Exclusions",
                    body: "Add port numbers to your Exclude List from any port row menu or in Settings > Exclude to ensure they are omitted from batch selection and kill commands."
                ),
                KillXHelpSection(
                    title: "System & IDE Protections",
                    body: "Critical macOS system daemons (mDNSResponder, rapportd, launchd, /System) and IDE processes (VS Code, Xcode, Cursor) are automatically protected and prevented from accidental termination."
                ),
                KillXHelpSection(
                    title: "Confirmation Prompts",
                    body: "When safety confirmations are enabled, KillX presents a confirmation summary before executing termination commands."
                )
            ]
        ),
        KillXHelpTopic(
            id: "shortcuts",
            category: .preferences,
            title: "Keyboard Shortcuts",
            symbol: "command",
            summary: "Configure global hotkeys and speed up port management.",
            sections: [
                KillXHelpSection(
                    title: "Global Hotkeys",
                    body: "In Settings > Shortcuts, customize global hotkeys for Toggle Popover, Kill Selected Ports, and Force Kill Selected Ports."
                ),
                KillXHelpSection(
                    title: "In-App Key Commands",
                    body: "Within the popover:",
                    bullets: [
                        "⌘A - Select or deselect all visible ports",
                        "⌘, - Open Settings",
                        "⌘H - Open Help documentation",
                        "⌥ (Option key) - Hold to switch to Force Kill mode",
                        "Esc - Cancel confirmation or close popover",
                        "Return - Confirm pending kill action"
                    ]
                )
            ]
        ),
        KillXHelpTopic(
            id: "appearance",
            category: .preferences,
            title: "Appearance & Themes",
            symbol: "paintbrush",
            summary: "Customize window styling with Classic solid or Liquid Glass translucent modes.",
            sections: [
                KillXHelpSection(
                    title: "Signature Sky Blue Theme",
                    body: "KillX features high-contrast dark accents, refined typography, and the signature sky blue accent theme."
                ),
                KillXHelpSection(
                    title: "Liquid Glass Mode",
                    body: "On macOS 26+, choose Liquid Glass in Settings > General for translucent blur depth and floating window aesthetics."
                )
            ]
        ),
        KillXHelpTopic(
            id: "settings-updates",
            category: .preferences,
            title: "Settings & Updates",
            symbol: "gearshape.2",
            summary: "Overview of General, Monitoring, Exclude, Shortcuts, About tabs, and version updates.",
            sections: [
                KillXHelpSection(
                    title: "Preferences Tabs",
                    body: "Settings is divided into 5 focused tabs:",
                    bullets: [
                        "General - Startup, sounds, safety confirmation, appearance, sort order, and reset",
                        "Monitoring - TCP/UDP discovery, menu bar count, grouping, and default signal",
                        "Exclude - Manage protected port list",
                        "Shortcuts - Global keyboard hotkey recorder",
                        "About - Version information, update checking, and contact"
                    ]
                ),
                KillXHelpSection(
                    title: "Checking for Updates",
                    body: "Click Check Updates in Settings > About to verify your installed version against the latest GitHub release. Release disk images and archives are linked directly."
                )
            ]
        ),
        KillXHelpTopic(
            id: "troubleshooting",
            category: .support,
            title: "Troubleshooting & FAQ",
            symbol: "wrench.and.screwdriver",
            summary: "Resolve permission errors, stubborn listeners, and Docker conflicts.",
            sections: [
                KillXHelpSection(
                    title: "Root or System Ports",
                    body: "Ports owned by root or macOS system processes may require administrator permissions. If termination fails, run with elevated privileges or inspect the process owner in Port Details."
                ),
                KillXHelpSection(
                    title: "Port Re-binding by Watchers",
                    body: "If a port immediately reopens after being killed, hold Option and click Force Kill. This terminates the supervising watcher (npm, nodemon, cargo) together with all child processes."
                ),
                KillXHelpSection(
                    title: "Homebrew Services",
                    body: "When terminating services managed by Homebrew (such as PostgreSQL, MySQL, or MongoDB), KillX matches the canonical formula and safely instructs Homebrew to stop the background service."
                )
            ]
        ),
        KillXHelpTopic(
            id: "privacy-support",
            category: .support,
            title: "Privacy & Support",
            symbol: "hand.raised.fill",
            summary: "100% local operation, zero tracking, and direct developer support.",
            sections: [
                KillXHelpSection(
                    title: "100% Local Privacy",
                    body: "KillX operates entirely on your Mac. No network telemetry, analytics, tracking, or process data is ever collected or transmitted."
                ),
                KillXHelpSection(
                    title: "Direct Support & Issues",
                    body: "Report bugs or suggest features directly on GitHub Issues, or click Contact Support in Settings > About to reach the developer directly."
                )
            ]
        )
    ]

    static let byCategory: [(category: KillXHelpCategory, topics: [KillXHelpTopic])] = {
        KillXHelpCategory.allCases.compactMap { cat in
            let matching = all.filter { $0.category == cat }
            return matching.isEmpty ? nil : (category: cat, topics: matching)
        }
    }()
}

@MainActor
final class HelpViewState: ObservableObject {
    @Published var selection: String? = KillXHelpTopic.all.first?.id
    @Published var searchText = ""
    @Published var hoveredTopicId: String?
}

struct HelpView: View {
    @StateObject private var state = HelpViewState()
    @ObservedObject private var configStore: ConfigStore = ConfigStore.shared

    private var filteredTopics: [KillXHelpTopic] {
        KillXHelpTopic.all.filter { $0.matches(state.searchText) }
    }

    private var selectedTopic: KillXHelpTopic? {
        guard let selection = state.selection else { return filteredTopics.first }
        return KillXHelpTopic.all.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            detail
        }
        .frame(minWidth: 740, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                KillXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onChange(of: state.searchText) {
            guard !filteredTopics.contains(where: { $0.id == state.selection }) else { return }
            state.selection = filteredTopics.first?.id
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            stickySearchHeader

            topicList
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(KillXTheme.cardBackground)
    }

    private var stickySearchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(state.searchText.isEmpty ? Color.secondary.opacity(0.85) : KillXTheme.accent)

                TextField("Search help…", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .disableInitialFocus()

                if !state.searchText.isEmpty {
                    Button {
                        state.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        state.searchText.isEmpty
                            ? Color.primary.opacity(0.09)
                            : KillXTheme.accent.opacity(0.55),
                        lineWidth: 1
                    )
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 40)
        .padding(.bottom, 8)
    }

    private var topicList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !state.searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredTopics) { topic in
                            topicRow(topic)
                        }
                    }
                } else {
                    ForEach(KillXHelpTopic.byCategory, id: \.category) { pair in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pair.category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.secondary.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.bottom, 2)

                            ForEach(pair.topics) { topic in
                                topicRow(topic)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func topicRow(_ topic: KillXHelpTopic) -> some View {
        let isSelected = state.selection == topic.id
        return Button {
            state.selection = topic.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: topic.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? KillXTheme.accent : Color.secondary)
                    .frame(width: 18)

                Text(topic.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? KillXTheme.accent.opacity(0.18) : (state.hoveredTopicId == topic.id ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                state.hoveredTopicId = topic.id
            } else if state.hoveredTopicId == topic.id {
                state.hoveredTopicId = nil
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let topic = selectedTopic {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        contentHeader(for: topic)

                        ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                            sectionCard(section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footerLinks(for: topic)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(KillXTheme.paneBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(topic.id)
            .background(KillXTheme.paneBackground)
        } else {
            VStack(spacing: 9) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.secondary)
                Text("Select a Help Topic")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KillXTheme.paneBackground)
        }
    }

    private func contentHeader(for topic: KillXHelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(topic.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)

            Text(topic.summary)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func sectionCard(_ section: KillXHelpSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text(section.body)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.88))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !section.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(section.bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•")
                                    .foregroundStyle(Color.secondary)
                                Text(bullet)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.88))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(KillXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func footerLinks(for topic: KillXHelpTopic) -> some View {
        HStack(spacing: 8) {
            switch topic.id {
            case "quick-start", "port-list", "appearance":
                Button("General Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }

            case "kill-modes", "port-watching", "network-exposure":
                Button("Monitoring Settings") {
                    SettingsWindowController.shared.show(tab: .monitoring)
                }

            case "exclude":
                Button("Exclude Settings") {
                    SettingsWindowController.shared.show(tab: .exclude)
                }

            case "shortcuts":
                Button("Shortcuts Settings") {
                    SettingsWindowController.shared.show(tab: .shortcuts)
                }

            case "settings-updates":
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }

            case "privacy-support":
                Button("Contact Support") {
                    if let url = KillXConstants.contactURL() {
                        NSWorkspace.shared.open(url)
                    }
                }

            default:
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }
            }

            Spacer()

            Button("GitHub Issues") {
                if let url = URL(string: "https://github.com/kiron0/killx-app/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .controlSize(.small)
    }
}
