import AppKit
import PerchCore

@MainActor final class SoundEngine {
    enum Cue: String, CaseIterable { case complete, copy, drop, start, pause, finish, reminder }
    private var players: [NSSound] = []
    private var lastPlayed: [Cue: Date] = [:]
    func play(_ cue: Cue, preferences: Preferences, preview: Bool = false) {
        let alert = cue == .finish || cue == .reminder
        guard preview || (alert ? preferences.alertSounds : preferences.interactionSounds) else { return }
        guard preview || Date().timeIntervalSince(lastPlayed[cue] ?? .distantPast) > (cue == .complete ? 0.03 : 0.07) else { return }
        guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav", subdirectory: "Sounds"),
              let sound = NSSound(contentsOf: url, byReference: false) else { return }
        players.removeAll { !$0.isPlaying }
        sound.volume = Float(alert ? preferences.alertVolume : preferences.interactionVolume)
        if players.count >= 6 { players.removeFirst().stop() }
        players.append(sound); sound.play(); lastPlayed[cue] = Date()
    }
}
