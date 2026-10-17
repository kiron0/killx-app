import Foundation

enum KillXConstants {
    static let primaryBundleId = "io.coreify.killx"
    static let appName = "KillX"
    static let author = "Toufiq Hasan Kiron"
    static let supportEmail = "hello@kiron.dev"

    enum Notifications {
        static let dismissSettingsTooltips = Notification.Name("\(KillXConstants.primaryBundleId).dismissSettingsTooltips")
    }

    static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    static var copyright: String {
        "Copyright © \(currentYear) \(author)"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.4"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static func sayHiURL() -> URL? {
        let subject = "Saying hi from KillX!"
        let body = """
        Hi Toufiq,

        I wanted to say hi and drop a quick note about KillX!

        """
        return makeMailtoURL(to: supportEmail, subject: subject, body: body)
    }

    static func contactURL() -> URL? {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let subject = "KillX Feedback & Support (v\(appVersion))"
        let body = """
        Hi Toufiq,

        Feedback Type: [Bug Report / Feature Request / Other]

        Details:
        [Please describe your issue, feedback, or suggestion here]

        Steps to reproduce (if bug):
        1.
        2.

        Expected behavior:

        System Info:
        - KillX Version: v\(appVersion) (\(buildNumber))
        - macOS Version: \(osVersion)
        """
        return makeMailtoURL(to: supportEmail, subject: subject, body: body)
    }

    private static func makeMailtoURL(to: String, subject: String, body: String) -> URL? {
        let allowed = CharacterSet.urlQueryAllowed
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return URL(string: "mailto:\(to)")
        }
        return URL(string: "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
}

