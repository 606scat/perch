import AVFoundation
import PerchCore

/// One looping local player and optional system speech. No audio runs until a
/// session is explicitly started; stopping or quitting releases both.
@MainActor final class RelaxAudio {
    private var player: AVAudioPlayer?
    private var speech: AVSpeechSynthesizer?
    private var volume: Double?
    private var selectedSound: AmbientSound?
    private var phaseKey: String?
    private var startedAt: Date?
    var errorHandler: ((String) -> Void)?

    func update(session: BreathingSession, settings: RelaxPreferences, at date: Date) {
        if startedAt != session.startedAt { stop(); startedAt = session.startedAt }
        if settings.soundEnabled {
            if selectedSound != settings.sound {
                player?.stop(); player = nil; selectedSound = settings.sound
                do {
                    guard let url = Bundle.main.url(forResource: settings.sound.rawValue, withExtension: "wav", subdirectory: "Ambient") else { throw CocoaError(.fileNoSuchFile) }
                    let next = try AVAudioPlayer(contentsOf: url); next.numberOfLoops = -1; next.volume = 0
                    guard next.prepareToPlay(), next.play() else { throw CocoaError(.fileReadUnknown) }
                    next.setVolume(Float(settings.volume), fadeDuration: 1); player = next; volume = settings.volume
                } catch { errorHandler?("The ambient sound couldn’t play. Choose another sound or restart the session. \(error.localizedDescription)") }
            } else if volume != settings.volume { player?.setVolume(Float(settings.volume), fadeDuration: 0.2); volume = settings.volume }
        } else { fadeOut(); selectedSound = nil }

        guard settings.voiceEnabled else { if speech?.isSpeaking == true { speech?.stopSpeaking(at: .immediate) }; phaseKey = nil; return }
        let elapsed = max(0, date.timeIntervalSince(session.startedAt))
        let key = session.mode == .relax ? "relax" : "\(Int(elapsed / 10)):\(session.inhale(at: date))"
        guard phaseKey != key else { return }; phaseKey = key
        let phrase = session.mode == .relax ? "Get comfortable. Let your shoulders settle. There is nothing you need to do right now." : session.inhale(at: date) ? "Breathe in." : "Breathe out."
        say(phrase)
    }
    func finish(withVoice: Bool) {
        stop()
        if withVoice { say("Your session is complete. Take your time returning.") }
    }
    func stop() { fadeOut(); selectedSound = nil; phaseKey = nil; startedAt = nil; speech?.stopSpeaking(at: .immediate) }
    private func say(_ phrase: String) {
        if speech == nil { speech = AVSpeechSynthesizer() }
        speech?.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.40; utterance.volume = 0.65; speech?.speak(utterance)
    }
    private func fadeOut() {
        guard let previous = player else { return }; player = nil; volume = nil
        previous.setVolume(0, fadeDuration: 0.7)
        Task { try? await Task.sleep(for: .milliseconds(750)); previous.stop() }
    }
    deinit { player?.stop(); speech?.stopSpeaking(at: .immediate) }
}
