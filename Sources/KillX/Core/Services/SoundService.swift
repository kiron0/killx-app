import AppKit

enum SoundService {
    static var isAudioDisabledForTesting: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.processName.contains("Tests")
            || ProcessInfo.processInfo.processName.contains("runner")
            || NSClassFromString("XCTest") != nil
    }()

    static func playQuitSingle() {
        guard !isAudioDisabledForTesting else { return }
        guard ConfigStore.shared.config.playSounds else { return }
        playSound(named: "quit-single")
    }

    static func playQuitAll() {
        guard !isAudioDisabledForTesting else { return }
        guard ConfigStore.shared.config.playSounds else { return }
        playSound(named: "quit-all")
    }

    private static func playSound(named name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
            return
        }

        let localPath = "Support/Sounds/\(name).aiff"
        if FileManager.default.fileExists(atPath: localPath),
           let sound = NSSound(contentsOfFile: localPath, byReference: true) {
            sound.play()
        }
    }
}
