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

    public static let criticalIDEBundleIds: Set<String> = [
        "com.google.antigravity-ide",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf",
        "dev.zed.Zed",
        "com.apple.dt.Xcode",
        "com.sublimetext.4",
        "com.sublimetext.3"
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
        "powerd",
        "antigravity",
        "antigravity-ide",
        "antigravity helper",
        "code helper",
        "language_server_macos_arm",
        "language_server",
        "ptyhost"
    ]

    public static let supportedKillXBundleIds: Set<String> = [
        "io.coreify.killx",
        "com.killx.app",
        "com.coreify.killx"
    ]

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
            if supportedKillXBundleIds.contains(bid) {
                return true
            }
            if criticalAppleBundleIds.contains(bid) {
                return true
            }
            if criticalIDEBundleIds.contains(bid) ||
               bid.contains("antigravity") ||
               bid.contains("vscode") ||
               bid.hasPrefix("com.jetbrains.") {
                return true
            }
        }

        let lowerName = processName.lowercased()
        if !lowerName.isEmpty {
            if lowerName == "killx" { return true }
            if criticalSystemProcesses.contains(lowerName) {
                return true
            }
            if lowerName.hasPrefix("antigravity") || lowerName.hasPrefix("code helper") {
                return true
            }
        }

        let path = (executablePath ?? "").isEmpty ? resolvedPath(for: pid) : (executablePath ?? "")
        if !path.isEmpty {
            let lowerPath = path.lowercased()
            if path.hasPrefix("/System/Library/PrivateFrameworks/")
                || path.hasPrefix("/System/Library/CoreServices/")
                || path.hasPrefix("/System/Library/")
                || path.hasPrefix("/System/Volumes/Preboot/")
                || path.hasPrefix("/Library/Apple/System/")
                || path.hasPrefix("/usr/libexec/")
                || path.hasPrefix("/usr/sbin/") {
                return true
            }
            if lowerPath.contains("antigravity ide.app") ||
               lowerPath.contains("antigravity.app") ||
               lowerPath.contains("/extensions/antigravity/") ||
               lowerPath.contains("visual studio code.app") ||
               lowerPath.contains("cursor.app") ||
               lowerPath.contains("windsurf.app") ||
               lowerPath.contains("xcode.app") ||
               lowerPath.contains("language_server_macos_arm") {
                return true
            }
        }

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
