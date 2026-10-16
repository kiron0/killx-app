import SwiftUI
import AppKit
import Darwin

public enum AppIconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 150
        return c
    }()

    nonisolated private static func cacheKey(bundleId: String?, pid: pid_t?, url: URL?) -> String {
        if let bundleId, !bundleId.isEmpty {
            return bundleId
        }
        if let url {
            return url.path
        }
        if let pid {
            return "pid-\(pid)"
        }
        return "fallback"
    }

    nonisolated public static func cachedIcon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil) -> NSImage? {
        cache.object(forKey: cacheKey(bundleId: bundleId, pid: pid, url: url) as NSString)
    }

    nonisolated public static func icon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil) -> NSImage? {
        let key = cacheKey(bundleId: bundleId, pid: pid, url: url) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        return resolveAndCache(bundleId: bundleId, pid: pid, url: url, key: key)
    }

    nonisolated private static func resolveAndCache(bundleId: String?, pid: pid_t?, url: URL?, key: NSString) -> NSImage {
        if let existing = cache.object(forKey: key) {
            return existing
        }
        let resolved: NSImage
        if let url, FileManager.default.fileExists(atPath: url.path) {
            resolved = NSWorkspace.shared.icon(forFile: url.path)
        } else if let pid, let running = NSRunningApplication(processIdentifier: pid), let icon = running.icon {
            resolved = icon
        } else if let bid = bundleId, !bid.isEmpty {
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path {
                resolved = NSWorkspace.shared.icon(forFile: path)
            } else if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }),
                      let icon = running.icon {
                resolved = icon
            } else {
                resolved = NSWorkspace.shared.icon(for: .applicationBundle)
            }
        } else if let pid {
            var buffer = [CChar](repeating: 0, count: 4096)
            let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            if ret > 0 {
                let path = String(cString: buffer)
                if let appRange = path.range(of: ".app") {
                    let appBundlePath = String(path[..<appRange.upperBound])
                    resolved = NSWorkspace.shared.icon(forFile: appBundlePath)
                } else {
                    resolved = NSWorkspace.shared.icon(forFile: path)
                }
            } else {
                resolved = NSWorkspace.shared.icon(for: .applicationBundle)
            }
        } else {
            resolved = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        cache.setObject(resolved, forKey: key)
        return resolved
    }

    nonisolated public static func loadIcon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil, completion: @escaping @MainActor (NSImage?) -> Void) {
        if let existing = cachedIcon(for: bundleId, pid: pid, url: url) {
            Task { @MainActor in
                completion(existing)
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = icon(for: bundleId, pid: pid, url: url)
            DispatchQueue.main.async {
                completion(img)
            }
        }
    }
}

@MainActor
public final class AppIconLoader: ObservableObject {
    @Published public var icon: NSImage?
    private var generation = 0

    @discardableResult
    func beginRequest() -> Int {
        generation += 1
        return generation
    }

    func accept(_ loaded: NSImage?, generation requestGeneration: Int) {
        guard generation == requestGeneration else { return }
        icon = loaded
    }

    public func load(bundleId: String?, pid: pid_t? = nil, url: URL? = nil) {
        let requestGeneration = beginRequest()
        if let cached = AppIconCache.cachedIcon(for: bundleId, pid: pid, url: url) {
            self.icon = cached
            return
        }
        icon = nil
        AppIconCache.loadIcon(for: bundleId, pid: pid, url: url) { [weak self] loaded in
            self?.accept(loaded, generation: requestGeneration)
        }
    }
}

public struct AppIconView: View {
    public let bundleId: String?
    public var pid: pid_t? = nil
    public var url: URL? = nil
    public var size: CGFloat = 16
    public var cornerRadius: CGFloat = 3.5

    @StateObject private var loader = AppIconLoader()

    public init(bundleId: String?, pid: pid_t? = nil, url: URL? = nil, size: CGFloat = 16, cornerRadius: CGFloat = 3.5) {
        self.bundleId = bundleId
        self.pid = pid
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Group {
            if let icon = loader.icon ?? AppIconCache.cachedIcon(for: bundleId, pid: pid, url: url) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .cornerRadius(cornerRadius)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            if loader.icon == nil {
                loader.load(bundleId: bundleId, pid: pid, url: url)
            }
        }
        .onChange(of: bundleId) { _, newId in
            loader.load(bundleId: newId, pid: pid, url: url)
        }
        .onChange(of: pid) { _, newPid in
            loader.load(bundleId: bundleId, pid: newPid, url: url)
        }
        .onChange(of: url) { _, newURL in
            loader.load(bundleId: bundleId, pid: pid, url: newURL)
        }
    }
}
