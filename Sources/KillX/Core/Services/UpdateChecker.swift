import AppKit
import Foundation

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case available(version: String, releaseURL: URL)
    case upToDate(version: String)
    case failed(message: String)
}

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
    @Published var checkState: UpdateCheckState = .idle

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func resetState() {
        checkState = .idle
    }

    func checkForUpdates(isUserInitiated: Bool = true) async {
        if isUserInitiated {
            AppUpdateWindowController.shared.showCheckWindow()
        }
        guard !isChecking else { return }
        isChecking = true
        checkState = .checking
        defer { isChecking = false }

        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("KillX-App", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                handleError(message: "Invalid response from server", isUserInitiated: isUserInitiated)
                return
            }

            if httpResponse.statusCode == 404 {
                handleUpToDate(isUserInitiated: isUserInitiated)
                return
            }

            guard httpResponse.statusCode == 200 else {
                handleError(message: "GitHub returned status code \(httpResponse.statusCode)", isUserInitiated: isUserInitiated)
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
                handleUpdateAvailable(latestVersion: latestVersionRaw, releaseURL: releaseURL, isUserInitiated: isUserInitiated)
            } else {
                handleUpToDate(isUserInitiated: isUserInitiated)
            }
        } catch {
            handleError(message: "Could not connect to GitHub. Please check your connection and try again.", isUserInitiated: isUserInitiated)
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

    private func handleUpdateAvailable(latestVersion: String, releaseURL: URL, isUserInitiated: Bool) {
        checkState = .available(version: latestVersion, releaseURL: releaseURL)
        if !isUserInitiated {
            AppUpdateWindowController.shared.showCheckWindow()
        }
    }

    private func handleUpToDate(isUserInitiated: Bool) {
        checkState = .upToDate(version: currentVersion)
    }

    private func handleError(message: String, isUserInitiated: Bool) {
        checkState = .failed(message: message)
    }
}
