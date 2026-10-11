import AppKit

enum SoundService {
    static var isAudioDisabledForTesting: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.processName.contains("Tests")
            || ProcessInfo.processInfo.processName.contains("runner")
            || NSClassFromString("XCTest") != nil
    }()

    static func playKillSingle() {
        guard !isAudioDisabledForTesting else { return }
        guard ConfigStore.shared.config.playSounds else { return }
        playSound(named: "kill-single")
    }

    static func playKillAll() {
        guard !isAudioDisabledForTesting else { return }
        guard ConfigStore.shared.config.playSounds else { return }
        playSound(named: "kill-all")
    }

    static func playQuitSingle() {
        playKillSingle()
    }

    static func playQuitAll() {
        playKillAll()
    }

    private static func playSound(named name: String) {
        let soundName = name.replacingOccurrences(of: "quit-", with: "kill-")
        if let url = Bundle.main.url(forResource: soundName, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
            return
        }

        let localPath = "Support/Sounds/\(soundName).aiff"
        if FileManager.default.fileExists(atPath: localPath),
           let sound = NSSound(contentsOfFile: localPath, byReference: true) {
            sound.play()
        }
    }
}
