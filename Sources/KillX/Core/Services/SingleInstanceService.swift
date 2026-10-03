import AppKit
import Foundation

enum KillXIdentity {
    static let supportedBundleIdentifiers: Set<String> = ["io.coreify.killx"]
}

@MainActor
final class SingleInstanceService {
    static let shared = SingleInstanceService()

    private var launchObserver: NSObjectProtocol?

    private init() {}

    deinit {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
    }

    func prepareForLaunch() async -> Bool {
        let current = NSRunningApplication.current
        let candidates = matchingApplications()
        guard candidates.count > 1 else { return true }

        let winner = candidates.reduce(current) { preferred($1, over: $0) ? $1 : $0 }
        guard winner.processIdentifier == current.processIdentifier else {
            notifyAndActivate(winner)
            return false
        }

        await terminate(candidates.filter { $0.processIdentifier != current.processIdentifier })
        return true
    }

    func startMonitoring() {
        guard launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                await self?.handleNewInstance(application)
            }
        }
    }

    func stopMonitoring() {
        guard let launchObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        self.launchObserver = nil
    }

    private func handleNewInstance(_ application: NSRunningApplication) async {
        let current = NSRunningApplication.current
        guard application.processIdentifier != current.processIdentifier,
              Self.isKillX(application) else { return }

        if preferred(application, over: current) {
            notifyAndActivate(application)
            NSApp.terminate(nil)
        } else {
            await terminate([application])
        }
    }

    private func matchingApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter(Self.isKillX)
    }

    private static func isKillX(_ application: NSRunningApplication) -> Bool {
        guard let bundleIdentifier = application.bundleIdentifier else { return false }
        return KillXIdentity.supportedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func preferred(_ lhs: NSRunningApplication, over rhs: NSRunningApplication) -> Bool {
        Self.isPreferred(
            version: version(of: lhs),
            pid: lhs.processIdentifier,
            over: version(of: rhs),
            pid: rhs.processIdentifier
        )
    }

    static func isPreferred(version lhsVersion: String, pid lhsPid: pid_t, over rhsVersion: String, pid rhsPid: pid_t) -> Bool {
        let comparison = compareVersions(lhsVersion, rhsVersion)
        if comparison != 0 { return comparison > 0 }
        return lhsPid < rhsPid
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let lhsParts = versionComponents(lhs)
        let rhsParts = versionComponents(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsPart = index < lhsParts.count ? lhsParts[index] : 0
            let rhsPart = index < rhsParts.count ? rhsParts[index] : 0
            if lhsPart != rhsPart { return lhsPart < rhsPart ? -1 : 1 }
        }
        return 0
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { component in
                Int(component.prefix(while: { $0.isNumber })) ?? 0
            }
    }

    private func version(of application: NSRunningApplication) -> String {
        guard let bundleURL = application.bundleURL,
              let bundle = Bundle(url: bundleURL) else { return "0" }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private func terminate(_ applications: [NSRunningApplication]) async {
        guard !applications.isEmpty else { return }

        for application in applications where !application.isTerminated {
            _ = application.terminate()
        }

        await waitForTermination(applications, timeout: 3)

        let remaining = applications.filter { !$0.isTerminated }
        for application in remaining {
            _ = application.forceTerminate()
        }

        await waitForTermination(remaining, timeout: 2)

        for application in remaining where !application.isTerminated {
            NSLog("Could not terminate older KillX instance with PID %d", application.processIdentifier)
        }
    }

    private func waitForTermination(_ applications: [NSRunningApplication], timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while applications.contains(where: { !$0.isTerminated }), Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func notifyAndActivate(_ application: NSRunningApplication) {
        DistributedNotificationCenter.default().post(
            name: Notification.Name("io.coreify.killx.showPopover"),
            object: nil
        )
        application.activate(options: [])
    }
}
