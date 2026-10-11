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
                    body: "Click the KillX menu bar icon or press the configured global shortcut. Type in the search box to filter ports by number, process name, or directory."
                ),
                KillXHelpSection(
                    title: "Choose ports",
                    body: "Select individual port checkboxes, or click the master checkbox beside the search box to select or deselect all visible ports."
                ),
                KillXHelpSection(
                    title: "Kill ports",
                    body: "Click the primary button to terminate selected ports, or click the power icon on any port row to kill that specific process immediately."
                )
            ]
        ),
        KillXHelpTopic(
            id: "port-list",
            category: .essentials,
            title: "Port List & Row Actions",
            symbol: "network",
            summary: "Understand port numbers, dev server badges, Docker tags, and row options.",
            sections: [
                KillXHelpSection(
                    title: "Port numbers & Process info",
                    body: "Each row displays the port number (e.g. :3000) and app name. Dev servers feature a highlighted dev badge, while Docker-bound ports show a docker tag."
                ),
                KillXHelpSection(
                    title: "Row options menu",
                    body: "Click the three-dot button on any row for quick actions: view Port Details, Trace Process Tree, Copy Port Number, Copy PID, or Open in Browser (http://localhost:port)."
                ),
                KillXHelpSection(
                    title: "Tree Kill",
                    body: "Use Tree Kill from the row options menu to terminate the root supervisor (npm, vite, cargo) and all child worker processes cleanly."
                )
            ]
        ),
        KillXHelpTopic(
            id: "kill-modes",
            category: .features,
            title: "Kill Signals & Modes",
            symbol: "power",
            summary: "Choose graceful SIGTERM shutdown or immediate SIGKILL force termination.",
            sections: [
                KillXHelpSection(
                    title: "Graceful kill (SIGTERM)",
                    body: "SIGTERM asks the process to exit cleanly, close database connections, and release ports. This is the default safe mode."
                ),
                KillXHelpSection(
                    title: "Force kill (SIGKILL)",
                    body: "Hold ⌥ Option while clicking any kill button to force terminate immediately with SIGKILL. You can also change the default signal in Settings."
                ),
                KillXHelpSection(
                    title: "Confirmation alerts",
                    body: "When safety confirmations are enabled in Settings, KillX displays a clean in-popover confirmation card before terminating processes."
                )
            ]
        ),
        KillXHelpTopic(
            id: "dev-sweeper",
            category: .features,
            title: "Dev Server Sweeper",
            symbol: "arrow.triangle.branch",
            summary: "Detect and sweep all active web frameworks and development servers in one click.",
            sections: [
                KillXHelpSection(
                    title: "Dev server filter",
                    body: "Switch to the Dev Servers filter at the top of the popover to see only web development servers such as Vite, Next.js, Webpack, Astro, Remix, and Cargo."
                ),
                KillXHelpSection(
                    title: "Sweep Dev Servers",
                    body: "Click Sweep Dev Servers to terminate all development listeners and their complete process trees at once, freeing up ports instantly."
                )
            ]
        ),
        KillXHelpTopic(
            id: "exclude",
            category: .features,
            title: "Exclude Ports",
            symbol: "nosign",
            summary: "Protect critical services and databases from accidental termination.",
            sections: [
                KillXHelpSection(
                    title: "Adding exclusions",
                    body: "Choose Add to Exclude List from any port row menu, or configure excluded port numbers in Settings to protect background services."
                ),
                KillXHelpSection(
                    title: "Protected operations",
                    body: "Excluded ports are never killed during batch kills or dev server sweeps, preventing accidental disruption of your environment."
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
                    title: "Global hotkeys",
                    body: "Settings > Shortcuts allows recording custom global hotkeys for Toggle Popover, Sweep Dev Servers, and Force Kill Selected Ports."
                ),
                KillXHelpSection(
                    title: "In-popover shortcuts",
                    body: "Press ⌘A to select all, ⌘, for Settings, ⌘H for Help, Esc to cancel confirmation or close, and Return to confirm an action."
                )
            ]
        ),
        KillXHelpTopic(
            id: "appearance",
            category: .preferences,
            title: "Appearance & Themes",
            symbol: "paintbrush",
            summary: "Customize window themes, Classic retro styling, and Liquid Glass translucency.",
            sections: [
                KillXHelpSection(
                    title: "Signature Sky Blue Theme",
                    body: "KillX features the signature sky blue aesthetic, high-contrast dark accents, and adaptive window backgrounds."
                ),
                KillXHelpSection(
                    title: "Liquid Glass Mode",
                    body: "On macOS 26+, choose Liquid Glass in Settings > General for translucent blur effects and modern glass depth."
                )
            ]
        ),
        KillXHelpTopic(
            id: "troubleshooting",
            category: .support,
            title: "Troubleshooting & FAQ",
            symbol: "wrench.and.screwdriver",
            summary: "Resolve permission issues, stubborn system ports, and hung listeners.",
            sections: [
                KillXHelpSection(
                    title: "Root or system ports",
                    body: "Ports owned by root or system daemons (such as Apache or mDNSResponder) may require administrator privileges to terminate."
                ),
                KillXHelpSection(
                    title: "Docker container ports",
                    body: "Killing a Docker-bound port will issue a graceful docker stop command to shut down the container cleanly."
                ),
                KillXHelpSection(
                    title: "Port still bound after kill",
                    body: "If a port remains bound, hold Option and click Force Kill, or use Tree Kill to terminate supervisor processes holding open sockets."
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
            case "quick-start":
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }

            case "port-list":
                Button("General Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }

            case "shortcuts":
                Button("Shortcuts Settings") {
                    SettingsWindowController.shared.show(tab: .shortcuts)
                }

            case "appearance":
                Button("Open Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }

            default:
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }
            }

            Spacer()

            Button("GitHub Issues") {
                if let url = URL(string: "https://github.com/kiron0/killx/issues") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("KillX Website") {
                if let url = URL(string: "https://killx.js.org") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .controlSize(.small)
    }
}
