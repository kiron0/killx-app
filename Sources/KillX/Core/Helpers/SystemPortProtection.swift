import Foundation
import AppKit
import Darwin

public enum SystemPortProtection {
    public static let criticalAppleBundleIds: Set<String> = [
        "com.apple.dock",
        "com.apple.spotlight",
        "com.apple.systemuiserver",
        "com.apple.windowmanager",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.loginwindow",
        "com.apple.screensaver.engine",
        "com.apple.finder",
        "com.apple.airplayxpcservice",
        "com.apple.airplayxpchelper",
        "com.apple.rapportd",
        "com.apple.mdnsresponder",
        "com.apple.identityservicesd"
    ]

    public static let criticalSystemProcesses: Set<String> = [
        "launchd",
        "kernel_task",
        "mdnsresponder",
        "rapportd",
        "identityservicesd",
        "airplayxpchelper",
        "controlcenter",
        "remoted",
        "symptomsd",
        "configd",
        "cupsd",
        "systemuiserver",
        "sharingd",
        "timed",
        "locationd",
        "bluetoothd",
        "loginwindow",
        "windowserver",
        "syslogd",
        "diskarbitrationd",
        "powerd"
    ]

    public static let protectedPathPrefixes: [String] = [
        "/System/Library/PrivateFrameworks/",
        "/System/Library/CoreServices/",
        "/System/Library/",
        "/System/Volumes/Preboot/",
        "/Library/Apple/System/",
        "/usr/libexec/",
        "/usr/sbin/"
    ]

    public static let supportedKillXBundleIds: Set<String> = [
        "io.coreify.killx",
        "com.killx.app",
        "com.coreify.killx"
    ]

    public static func isEditorHelperProcess(name: String, command: String = "") -> Bool {
        let n = name.lowercased()
        let c = command.lowercased()
        let haystack = n + " " + c
        if haystack.contains("language_server") || haystack.contains("languageserver") { return true }
        if haystack.contains("extensionhost") || haystack.contains("extension_host") { return true }
        if haystack.contains("ptyhost") || haystack.contains("pty_host") { return true }
        if n.contains("helper") && c.contains(".app/") { return true }
        return false
    }

    public static func isAppBundleExecutable(_ command: String) -> Bool {
        guard let first = command.split(separator: " ").first else { return false }
        return first.lowercased().contains(".app/")
    }

    public static func isUserInterfaceApp(pid: pid_t) -> Bool {
        guard pid > 1 else { return false }
        return NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
    }

    public static func isSystemProtected(
        pid: pid_t,
        processName: String = "",
        bundleIdentifier: String? = nil,
        executablePath: String? = nil
    ) -> Bool {
        if pid <= 1 || pid == ProcessInfo.processInfo.processIdentifier {
            return true
        }

        let bid = (bundleIdentifier ?? "").lowercased()
        if !bid.isEmpty {
            if supportedKillXBundleIds.contains(bid) { return true }
            if criticalAppleBundleIds.contains(bid) { return true }
        }

        let lowerName = processName.lowercased()
        if !lowerName.isEmpty {
            if lowerName == "killx" { return true }
            if criticalSystemProcesses.contains(lowerName) { return true }
        }

        let path = (executablePath ?? "").isEmpty ? resolvedPath(for: pid) : (executablePath ?? "")
        if !path.isEmpty {
            for prefix in protectedPathPrefixes where path.hasPrefix(prefix) {
                return true
            }
        }

        if isUserInterfaceApp(pid: pid) { return true }
        if isEditorHelperProcess(name: processName, command: path) { return true }

        return false
    }

    public static func isSystemProtected(port: PortInfo) -> Bool {
        return isSystemProtected(
            pid: port.pid,
            processName: port.processName,
            bundleIdentifier: port.appBundleId,
            executablePath: nil
        )
    }

    private static func resolvedPath(for pid: pid_t) -> String {
        guard pid > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: 4096)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard ret > 0 else { return "" }
        return String(cString: buffer)
    }
}

public typealias SystemAppProtection = SystemPortProtection
