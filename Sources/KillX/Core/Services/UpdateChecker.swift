import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private let repoOwner = "kiron0"
    private let repoName = "killx"

    var releasesWebURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
    }

    private var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }

    @Published var isChecking = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkForUpdates(isUserInitiated: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("KillX-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                showErrorAlert(isUserInitiated: isUserInitiated)
                return
            }

            if httpResponse.statusCode == 404 {

                showUpToDateAlert(isUserInitiated: isUserInitiated)
                return
            }

            guard httpResponse.statusCode == 200 else {
                showErrorAlert(isUserInitiated: isUserInitiated)
                return
            }

            struct GitHubRelease: Decodable {
                let tag_name: String
                let html_url: String?
                let name: String?
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersionRaw = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let releaseURL = release.html_url.flatMap { URL(string: $0) } ?? releasesWebURL

            if isVersion(latestVersionRaw, greaterThan: currentVersion) {
                showUpdateAvailableAlert(latestVersion: latestVersionRaw, releaseURL: releaseURL)
            } else {
                showUpToDateAlert(isUserInitiated: isUserInitiated)
            }
        } catch {
            showErrorAlert(isUserInitiated: isUserInitiated)
        }
    }

    func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0.prefix(while: { $0.isNumber })) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0.prefix(while: { $0.isNumber })) }

        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }

    private func configureAlertIcon(_ alert: NSAlert) {
        if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
            alert.icon = appIcon
        }
    }

    private func showUpdateAvailableAlert(latestVersion: String, releaseURL: URL) {
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of KillX (v\(latestVersion)) is available. You currently have v\(currentVersion).\n\nWould you like to open GitHub to download the update?"
        alert.addButton(withTitle: "Download on GitHub")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func showUpToDateAlert(isUserInitiated: Bool) {
        guard isUserInitiated else { return }
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "You're Up to Date!"
        alert.informativeText = "KillX v\(currentVersion) is currently the newest version available."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "View Releases on GitHub")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(releasesWebURL)
        }
    }

    private func showErrorAlert(isUserInitiated: Bool) {
        guard isUserInitiated else { return }
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = "Could not connect to GitHub to check for updates. Would you like to check the releases page directly?"
        alert.addButton(withTitle: "Open GitHub")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releasesWebURL)
        }
    }
}
