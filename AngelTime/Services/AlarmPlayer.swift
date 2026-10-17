import AppKit

/// Plays the end-of-session alarm using the built-in macOS system sounds.
@MainActor
final class AlarmPlayer {
    static let systemSounds = [
        "Glass", "Hero", "Ping", "Submarine", "Funk", "Purr", "Blow",
        "Bottle", "Frog", "Morse", "Pop", "Sosumi", "Tink", "Basso",
    ]

    private var playback: Task<Void, Never>?
    private var playing: [NSSound] = []

    func play(_ name: String, volume: Double, repeats: Int) {
        stop()
        guard name != AppSettings.noSound, let base = NSSound(named: NSSound.Name(name)) else { return }
        let gap = max(base.duration, 0.4) + 0.2

        playback = Task { [weak self] in
            for round in 0..<max(1, repeats) {
                if round > 0 {
                    try? await Task.sleep(for: .seconds(gap))
                }
                guard !Task.isCancelled, let self, let sound = base.copy() as? NSSound else { return }
                sound.volume = Float(volume)
                playing.append(sound)
                sound.play()
            }
        }
    }

    func stop() {
        playback?.cancel()
        playback = nil
        playing.forEach { $0.stop() }
        playing.removeAll()
    }
}
