import SwiftUI
import AppKit

@MainActor
final class ShortcutsViewState: ObservableObject {
    @Published var recordingRow: String? = nil
    var localMonitor: Any? = nil

    func startMonitor(sm: ShortcutManager) {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return event }
            guard event.window == NSApp.keyWindow else { return event }
            if self.processEvent(event, row: row, sm: sm) {
                return nil
            }
            return event
        }
    }

    func stopMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func processEvent(_ event: NSEvent, row: String, sm: ShortcutManager) -> Bool {
        if event.keyCode == 53 {
            DispatchQueue.main.async { self.recordingRow = nil }
            return true
        }
        if event.keyCode == 51 {
            DispatchQueue.main.async {
                self.applyKeys([], for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }

        let keys = ShortcutManager.eventToKeys(event)
        if !keys.isEmpty {
            DispatchQueue.main.async {
                self.applyKeys(keys, for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }
        return false
    }

    func applyKeys(_ keys: [String], for row: String, sm: ShortcutManager) {
        let slot: ShortcutManager.Slot?
        switch row {
        case "activate": slot = .activateMenu
        case "quit": slot = .quitAll
        case "force": slot = .forceQuitAll
        default: slot = nil
        }
        if let slot {
            sm.setKeys(keys, for: slot)
        }
    }
}

struct ShortcutsTabCloneView: View {
    @ObservedObject private var sm = ShortcutManager.shared
    @StateObject private var viewState = ShortcutsViewState()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 11) {
                shortcutRow(
                    id: "activate",
                    title: "Activate menu",
                    isEnabled: $sm.activateMenuEnabled,
                    keys: $sm.activateMenuKeys
                )
                shortcutRow(
                    id: "quit",
                    title: "Kill selected ports",
                    isEnabled: $sm.quitAllEnabled,
                    keys: $sm.quitAllKeys
                )
                shortcutRow(
                    id: "force",
                    title: "Force kill all",
                    isEnabled: $sm.forceQuitAllEnabled,
                    keys: $sm.forceQuitAllKeys
                )
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)

            if let error = sm.shortcutError ?? sm.registrationError {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 32, height: 32)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.red)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text((sm.shortcutError?.contains("already assigned") == true) ? "Shortcut Conflict" : "Shortcut Invalid")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.red)

                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                )
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KillXTheme.accent.opacity(0.12))
                            .frame(width: 32, height: 32)

                        Text("⌥")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(KillXTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Option Key Pro-Tip")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.primary)

                        Text("Hold down Option (⌥) in the menu bar to toggle between Kill and Force Kill.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(KillXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: 480, height: 221, alignment: .topLeading)
        .background(KillXTheme.paneBackground)
        .onAppear {
            viewState.startMonitor(sm: sm)
        }
        .onDisappear {
            viewState.stopMonitor()
        }
    }

    private func shortcutRow(id: String, title: String, isEnabled: Binding<Bool>, keys: Binding<[String]>) -> some View {
        let active = isEnabled.wrappedValue
        let isRecording = (viewState.recordingRow == id)
        let keyList = keys.wrappedValue

        return HStack(spacing: 8) {
            Button {
                isEnabled.wrappedValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    KillXSelectionCheckbox(isSelected: active)
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if isRecording {
                Button {
                    viewState.recordingRow = nil
                } label: {
                    HStack(spacing: 5) {
                        Text("Press keys…")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KillXTheme.accent)
                        Text("(esc to cancel)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KillXTheme.accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(KillXTheme.accent, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            } else if keyList.isEmpty {
                Button {
                    if !active { isEnabled.wrappedValue = true }
                    viewState.recordingRow = id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Record Shortcut")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(KillXTheme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KillXTheme.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(KillXTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Button {
                        if !active { isEnabled.wrappedValue = true }
                        viewState.recordingRow = id
                    } label: {
                        HStack(spacing: 3) {
                            ForEach(keyList, id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(active ? Color.primary : Color.secondary)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .padding(.horizontal, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .fill(active ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .stroke(active ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(active ? 0.06 : 0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Click to change shortcut")

                    Button {
                        viewState.applyKeys([], for: id, sm: sm)
                        if viewState.recordingRow == id { viewState.recordingRow = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary.opacity(active ? 0.65 : 0.3))
                    }
                    .buttonStyle(.plain)
                    .help("Remove shortcut")
                }
            }
        }
        .frame(height: 28)
    }
}
