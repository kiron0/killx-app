import AppKit
import Foundation
import Security

enum UpdateState: Equatable {
    case idle
    case downloading(progress: Double, bytesDownloaded: Int64, totalBytes: Int64, speed: String)
    case extracting
    case ready(stagedURL: URL, version: String)
    case failed(message: String)
}

enum UpdateError: LocalizedError, Equatable {
    case invalidDownloadURL
    case downloadFailed(String)
    case mountFailed
    case copyFailed
    case extractFailed
    case appNotFoundInArchive
    case invalidBundle
    case versionMismatch
    case destinationNotWritable(String)
    case scriptExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL:
            return "Invalid update download URL."
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .mountFailed:
            return "Failed to mount update disk image."
        case .copyFailed:
            return "Failed to extract application from disk image."
        case .extractFailed:
            return "Failed to extract update archive."
        case .appNotFoundInArchive:
            return "KillX.app not found inside update package."
        case .invalidBundle:
            return "Invalid application bundle signature or identifier."
        case .versionMismatch:
            return "Update application version does not match the expected version."
        case .destinationNotWritable(let path):
            return "Cannot write to destination: \(path)"
        case .scriptExecutionFailed(let reason):
            return "Failed to run update script: \(reason)"
        }
    }
}

@MainActor
final class UpdateDownloadService: NSObject, ObservableObject {
    static let shared = UpdateDownloadService()

    nonisolated static let supportedBundleIdentifiers: Set<String> = [
        "io.coreify.killx",
        "com.killx.app"
    ]

    @Published private(set) var state: UpdateState = .idle
    @Published private(set) var targetVersion: String = ""
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var bytesDownloaded: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var downloadSpeed: String = ""

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var lastSpeedTime: Date?
    private var lastSpeedBytes: Int64 = 0
    private var lastPublishedProgress: Double = -1
    private var stagedDirURL: URL?
    private(set) var currentDownloadURL: URL?

    override init() {
        super.init()
    }

    func startDownload(from url: URL, version: String) {
        cancelDownload()

        currentDownloadURL = url
        targetVersion = version
        downloadProgress = 0.0
        bytesDownloaded = 0
        totalBytes = 0
        downloadSpeed = ""
        lastSpeedTime = nil
        lastSpeedBytes = 0
        lastPublishedProgress = -1
        state = .downloading(progress: 0.0, bytesDownloaded: 0, totalBytes: 0, speed: "")

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)

        let task = session?.downloadTask(with: url)
        downloadTask = task
        task?.resume()
    }

    func retryLastDownload() {
        guard let url = currentDownloadURL, !targetVersion.isEmpty else { return }
        startDownload(from: url, version: targetVersion)
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        clearStagedDirectory()
        state = .idle
        downloadProgress = 0.0
        bytesDownloaded = 0
        totalBytes = 0
        downloadSpeed = ""
    }

    func reset() {
        cancelDownload()
        targetVersion = ""
        currentDownloadURL = nil
    }

    private func isActive(session: URLSession, task: URLSessionTask) -> Bool {
        self.session === session && self.downloadTask === task
    }

    private func finishSession(_ completedSession: URLSession, task: URLSessionTask) {
        guard isActive(session: completedSession, task: task) else { return }
        completedSession.finishTasksAndInvalidate()
        session = nil
        downloadTask = nil
    }

    private func clearStagedDirectory() {
        if let stagedDirURL {
            try? FileManager.default.removeItem(at: stagedDirURL)
            self.stagedDirURL = nil
        }
    }

    nonisolated func extractApp(from fileURL: URL, originalFileName: String?) async throws -> URL {
        let ext = ((originalFileName as NSString?)?.pathExtension ?? fileURL.pathExtension).lowercased()
        if ext == "dmg" {
            return try await extractAppFromDMG(dmgURL: fileURL)
        }
        return try await extractAppFromZIP(zipURL: fileURL)
    }

    nonisolated func extractAppFromZIP(zipURL: URL) async throws -> URL {
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KillXStaged-\(UUID().uuidString)")
        let extractDir = stagingDir.appendingPathComponent("extract")

        defer {
            try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent())
        }

        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-xk", zipURL.path, extractDir.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.extractFailed
        }

        guard let appURL = findApp(in: extractDir, appName: "KillX.app") else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.appNotFoundInArchive
        }

        let stagedAppURL = stagingDir.appendingPathComponent("KillX.app")
        if appURL != stagedAppURL {
            try? FileManager.default.removeItem(at: stagedAppURL)
            do {
                try FileManager.default.moveItem(at: appURL, to: stagedAppURL)
            } catch {
                let copy = Process()
                copy.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                copy.arguments = [appURL.path, stagedAppURL.path]
                try copy.run()
                copy.waitUntilExit()
                guard copy.terminationStatus == 0 else {
                    try? FileManager.default.removeItem(at: stagingDir)
                    throw UpdateError.copyFailed
                }
            }
        }
        try? FileManager.default.removeItem(at: extractDir)
        return stagedAppURL
    }

    nonisolated func extractAppFromDMG(dmgURL: URL) async throws -> URL {
        let mountPoint = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KillXMount-\(UUID().uuidString)")
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KillXStaged-\(UUID().uuidString)")
        let stagedAppURL = stagingDir.appendingPathComponent("KillX.app")

        var isMounted = false
        defer {
            if isMounted {
                let detachProcess = Process()
                detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProcess.arguments = ["detach", mountPoint.path, "-force", "-quiet"]
                try? detachProcess.run()
                detachProcess.waitUntilExit()
            }
            try? FileManager.default.removeItem(at: mountPoint)
            try? FileManager.default.removeItem(at: dmgURL.deletingLastPathComponent())
        }

        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let attachProcess = Process()
        attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attachProcess.arguments = [
            "attach", dmgURL.path,
            "-mountpoint", mountPoint.path,
            "-nobrowse", "-readonly", "-quiet"
        ]
        try attachProcess.run()
        attachProcess.waitUntilExit()
        guard attachProcess.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.mountFailed
        }
        isMounted = true

        let defaultAppURL = mountPoint.appendingPathComponent("KillX.app")
        let sourceAppURL: URL
        if FileManager.default.fileExists(atPath: defaultAppURL.path) {
            sourceAppURL = defaultAppURL
        } else {
            let contents = (try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
            guard let foundApp = contents.first(where: { $0.pathExtension == "app" }) else {
                try? FileManager.default.removeItem(at: stagingDir)
                throw UpdateError.appNotFoundInArchive
            }
            sourceAppURL = foundApp
        }

        let copyProcess = Process()
        copyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        copyProcess.arguments = [sourceAppURL.path, stagedAppURL.path]
        try copyProcess.run()
        copyProcess.waitUntilExit()
        guard copyProcess.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw UpdateError.copyFailed
        }

        return stagedAppURL
    }

    nonisolated private func findApp(in dir: URL, appName: String) -> URL? {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent(appName).path) {
            return dir.appendingPathComponent(appName)
        }
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent == appName {
                return url
            }
            if url.pathComponents.count > dir.pathComponents.count + 4 {
                enumerator.skipDescendants()
            }
        }
        return nil
    }

    nonisolated static func validateUpdateBundle(at appURL: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: appURL),
              let bundleId = bundle.bundleIdentifier,
              supportedBundleIdentifiers.contains(bundleId)
        else {
            throw UpdateError.invalidBundle
        }

        guard let executableURL = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw UpdateError.invalidBundle
        }

        if !expectedVersion.isEmpty {
            let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            guard bundleVersion == expectedVersion else {
                throw UpdateError.versionMismatch
            }
        }
    }

    nonisolated static func resolveDestinationAppURL() -> URL {
        let mainBundle = Bundle.main.bundleURL
        if mainBundle.pathExtension == "app" {
            return mainBundle
        }
        let systemApp = URL(fileURLWithPath: "/Applications/KillX.app")
        if FileManager.default.fileExists(atPath: systemApp.path) {
            return systemApp
        }
        let userApp = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/KillX.app")
        if FileManager.default.fileExists(atPath: userApp.path) {
            return userApp
        }
        return systemApp
    }

    nonisolated static func generateRelaunchScript() -> String {
        return """
        #!/bin/bash
        set -euo pipefail

        TARGET_PID="$1"
        SRC_APP="$2"
        DEST_APP="$3"

        COUNT=0
        while kill -0 "$TARGET_PID" 2>/dev/null; do
            sleep 0.1
            COUNT=$((COUNT + 1))
            if [ "$COUNT" -ge 50 ]; then
                break
            fi
        done

        DEST_DIR="$(dirname "$DEST_APP")"
        NEW_APP="$DEST_DIR/.KillX.new.$$"
        OLD_APP="$DEST_DIR/.KillX.old.$$"

        rm -rf "$NEW_APP" "$OLD_APP"

        ditto "$SRC_APP" "$NEW_APP"

        if [ -e "$DEST_APP" ]; then
            mv "$DEST_APP" "$OLD_APP"
        fi

        if mv "$NEW_APP" "$DEST_APP"; then
            rm -rf "$OLD_APP"
        else
            rm -rf "$NEW_APP"

            if [ -e "$OLD_APP" ]; then
                mv "$OLD_APP" "$DEST_APP"
            fi

            exit 1
        fi

        xattr -rd com.apple.quarantine "$DEST_APP" 2>/dev/null || true
        rm -rf "$(dirname "$SRC_APP")"

        open "$DEST_APP"

        rm -- "$0"
        """
    }

    func installAndRelaunch(stagedURL: URL) {
        stagedDirURL = nil

        var destURL = Self.resolveDestinationAppURL()
        let parentDir = destURL.deletingLastPathComponent()

        if !FileManager.default.isWritableFile(atPath: parentDir.path) {
            let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            try? FileManager.default.createDirectory(at: userApps, withIntermediateDirectories: true)
            destURL = userApps.appendingPathComponent("KillX.app")
        }

        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("killx_relaunch_\(UUID().uuidString).sh")

        do {
            try Self.generateRelaunchScript().write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                "-c",
                "nohup \"$@\" >/dev/null 2>&1 &",
                "updater",
                scriptURL.path,
                String(ProcessInfo.processInfo.processIdentifier),
                stagedURL.path,
                destURL.path
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()

            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: scriptURL)
            state = .failed(message: "Failed to launch updater: \(error.localizedDescription)")
        }
    }

    private static let bytesFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter
    }()

    private static let speedFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    static func formatBytes(_ bytes: Int64) -> String {
        bytesFormatter.string(fromByteCount: bytes)
    }

    static func formatSpeed(bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "" }
        return "\(speedFormatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    fileprivate func handleProgress(bytesWritten: Int64, totalWritten: Int64, expectedToWrite: Int64) {
        bytesDownloaded = totalWritten
        totalBytes = expectedToWrite

        if expectedToWrite > 0 {
            downloadProgress = min(1.0, max(0.0, Double(totalWritten) / Double(expectedToWrite)))
        } else {
            downloadProgress = 0.0
        }

        let now = Date()
        if let lastTime = lastSpeedTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed >= 0.3 {
                let delta = totalWritten - lastSpeedBytes
                if delta >= 0 {
                    let speed = Double(delta) / elapsed
                    downloadSpeed = Self.formatSpeed(bytesPerSecond: speed)
                }
                lastSpeedTime = now
                lastSpeedBytes = totalWritten
            }
        } else {
            lastSpeedTime = now
            lastSpeedBytes = totalWritten
            downloadSpeed = ""
        }

        let delta = abs(downloadProgress - lastPublishedProgress)
        let reachedEnd = downloadProgress >= 1.0 && lastPublishedProgress < 1.0
        guard delta >= 0.005 || reachedEnd else { return }
        lastPublishedProgress = downloadProgress
        state = .downloading(
            progress: downloadProgress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            speed: downloadSpeed
        )
    }

    fileprivate func handleDownloadFinished(
        persistentFile: URL,
        fileName: String?,
        session completedSession: URLSession,
        task completedTask: URLSessionTask
    ) async {
        guard isActive(session: completedSession, task: completedTask) else {
            try? FileManager.default.removeItem(at: persistentFile.deletingLastPathComponent())
            return
        }
        let version = targetVersion
        defer { finishSession(completedSession, task: completedTask) }

        do {
            state = .extracting
            let stagedURL = try await extractApp(from: persistentFile, originalFileName: fileName)
            stagedDirURL = stagedURL.deletingLastPathComponent()

            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: stagedURL.deletingLastPathComponent())
                return
            }

            let expectedVersion = version
            try await Task.detached {
                try Self.validateUpdateBundle(at: stagedURL, expectedVersion: expectedVersion)
            }.value

            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: stagedURL.deletingLastPathComponent())
                return
            }

            state = .ready(stagedURL: stagedURL, version: version)
        } catch {
            guard isActive(session: completedSession, task: completedTask) else {
                try? FileManager.default.removeItem(at: persistentFile.deletingLastPathComponent())
                return
            }
            clearStagedDirectory()
            try? FileManager.default.removeItem(at: persistentFile.deletingLastPathComponent())
            state = .failed(message: error.localizedDescription)
        }
    }

    fileprivate func handleDownloadFailed(error: Error, session failedSession: URLSession, task failedTask: URLSessionTask) {
        guard isActive(session: failedSession, task: failedTask) else { return }
        finishSession(failedSession, task: failedTask)
        if let urlError = error as? URLError, urlError.code == .cancelled {
            state = .idle
            return
        }
        state = .failed(message: error.localizedDescription)
    }
}

extension UpdateDownloadService: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard self.isActive(session: session, task: downloadTask) else { return }
            self.handleProgress(
                bytesWritten: bytesWritten,
                totalWritten: totalBytesWritten,
                expectedToWrite: totalBytesExpectedToWrite
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let resolvedName: String = downloadTask.response?.suggestedFilename
            ?? downloadTask.originalRequest?.url?.lastPathComponent
            ?? "KillX-update.zip"
        let updateDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KillXUpdate-\(UUID().uuidString)")
        let persistentFile = updateDir.appendingPathComponent(resolvedName)

        do {
            try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: persistentFile)

            Task { @MainActor in
                await self.handleDownloadFinished(
                    persistentFile: persistentFile,
                    fileName: resolvedName,
                    session: session,
                    task: downloadTask
                )
            }
        } catch {
            Task { @MainActor in
                guard self.isActive(session: session, task: downloadTask) else { return }
                self.finishSession(session, task: downloadTask)
                self.state = .failed(message: "Failed to process downloaded file: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.handleDownloadFailed(error: error, session: session, task: task)
            }
        }
    }
}
