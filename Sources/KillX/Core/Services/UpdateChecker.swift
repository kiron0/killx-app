import AppKit
import Foundation

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case available(version: String, downloadURL: URL?, releaseURL: URL)
    case upToDate(version: String)
    case failed(message: String)
}

struct GitHubAsset: Decodable {
    let name: String
    let browser_download_url: String?
}

struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String?
    let name: String?
    let assets: [GitHubAsset]?
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private let repoOwner = "kiron0"
    private let repoName = "killx-app"

    var releasesWebURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
    }

    private var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }

    @Published var isChecking = false
    @Published var checkState: UpdateCheckState = .idle

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? KillXConstants.appVersion
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
                handleError(message: "No published release was found.", isUserInitiated: isUserInitiated)
                return
            }

            guard httpResponse.statusCode == 200 else {
                handleError(message: "GitHub returned status code \(httpResponse.statusCode)", isUserInitiated: isUserInitiated)
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersionRaw = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let releaseURL = release.html_url.flatMap { URL(string: $0) } ?? releasesWebURL
            let downloadURL = Self.selectAssetURL(from: release.assets)

            if isVersion(latestVersionRaw, greaterThan: currentVersion) {
                handleUpdateAvailable(latestVersion: latestVersionRaw, downloadURL: downloadURL, releaseURL: releaseURL, isUserInitiated: isUserInitiated)
            } else {
                handleUpToDate(isUserInitiated: isUserInitiated)
            }
        } catch {
            handleError(message: "Could not connect to GitHub. Please check your connection and try again.", isUserInitiated: isUserInitiated)
        }
    }

    nonisolated static func selectAssetURL(from assets: [GitHubAsset]?) -> URL? {
        guard let assets, !assets.isEmpty else { return nil }
        func secure(_ s: String?) -> URL? {
            guard let s, let url = URL(string: s),
                  url.scheme?.lowercased() == "https",
                  url.host != nil else { return nil }
            return url
        }
        if let zip = assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }),
           let url = secure(zip.browser_download_url) {
            return url
        }
        if let dmg = assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
           let url = secure(dmg.browser_download_url) {
            return url
        }
        return nil
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

    private func handleUpdateAvailable(latestVersion: String, downloadURL: URL?, releaseURL: URL, isUserInitiated: Bool) {
        checkState = .available(version: latestVersion, downloadURL: downloadURL, releaseURL: releaseURL)
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
