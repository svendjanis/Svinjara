import AVFoundation

/// Every sound in the game, synthesised at launch. There are no audio files in the bundle —
/// same principle as the art: a kick is a recipe, not an asset.
final class SFX {

    enum Sound: CaseIterable {
        case kick
        case touch
        case post
        case wall
        case goal
        case whistle
        case eliminated
        case dash
    }

    var isEnabled: Bool

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    /// A small pool per sound, so a rattle of post hits does not cut itself off.
    private var voices: [Sound: [AVAudioPlayerNode]] = [:]
    private var nextVoice: [Sound: Int] = [:]
    private var running = false

    init(enabled: Bool) {
        isEnabled = enabled
        // Ambient: the game should never stop whatever the player is listening to.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for sound in Sound.allCases {
            buffers[sound] = render(sound)
            var pool: [AVAudioPlayerNode] = []
            for _ in 0..<3 {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: format)
                pool.append(node)
            }
            voices[sound] = pool
            nextVoice[sound] = 0
        }

        engine.mainMixerNode.outputVolume = 0.7
        running = (try? engine.start()) != nil
        if running { voices.values.flatMap { $0 }.forEach { $0.play() } }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard isEnabled, running,
              let buffer = buffers[sound],
              let pool = voices[sound], !pool.isEmpty else { return }

        let index = (nextVoice[sound] ?? 0) % pool.count
        nextVoice[sound] = index + 1

        let node = pool[index]
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    func stop() {
        engine.stop()
        running = false
    }

    // MARK: Synthesis

    private func render(_ sound: Sound) -> AVAudioPCMBuffer? {
        switch sound {
        case .kick:
            // A thump with a slap on the front: the slap is what makes it read as contact.
            return make(seconds: 0.11) { t, phase in
                let thump = sin(phase(92)) * exp(-t * 38)
                let slap = phase.noise() * exp(-t * 120) * 0.5
                return Float(thump * 0.85 + slap)
            }

        case .touch:
            return make(seconds: 0.06) { t, phase in
                Float(sin(phase(150)) * exp(-t * 60) * 0.35 + phase.noise() * exp(-t * 150) * 0.15)
            }

        case .post:
            // Two detuned partials ringing on: unmistakably metal, and the moment everybody
            // in the room reacts to.
            return make(seconds: 0.45) { t, phase in
                let a = sin(phase(1_180)) * exp(-t * 9)
                let b = sin(phase(1_790)) * exp(-t * 13) * 0.6
                let c = sin(phase(2_630)) * exp(-t * 20) * 0.25
                return Float((a + b + c) * 0.4)
            }

        case .wall:
            return make(seconds: 0.05) { t, phase in
                Float(sin(phase(210)) * exp(-t * 70) * 0.3 + phase.noise() * exp(-t * 200) * 0.12)
            }

        case .goal:
            // Rising, because a goal is good news for somebody.
            return make(seconds: 0.5) { t, phase in
                let step = t < 0.12 ? 0 : (t < 0.24 ? 1 : 2)
                let frequency = [523.25, 659.25, 783.99][step]
                let local = t - Double(step) * 0.12
                return Float(sin(phase(frequency)) * exp(-local * 7) * 0.42)
            }

        case .whistle:
            return make(seconds: 0.34) { t, phase in
                let warble = sin(phase(2_350) + sin(t * 58) * 1.6)
                let envelope = min(1, t * 30) * exp(-max(0, t - 0.2) * 16)
                return Float(warble * envelope * 0.26)
            }

        case .eliminated:
            // Falling: somebody just walked home.
            return make(seconds: 0.65) { t, phase in
                let frequency = 340 * pow(0.42, t)
                return Float(sin(phase(frequency)) * exp(-t * 4.2) * 0.4)
            }

        case .dash:
            return make(seconds: 0.2) { t, phase in
                Float(phase.noise() * exp(-t * 16) * min(1, t * 40) * 0.22)
            }
        }
    }

    /// Walks a buffer sample by sample, handing the generator the elapsed time and a phase
    /// accumulator. Accumulating phase rather than computing `sin(2πft)` is what allows a
    /// sound to sweep its frequency without clicking.
    private func make(seconds: Double,
                      _ generator: (Double, PhaseClock) -> Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        let clock = PhaseClock(sampleRate: format.sampleRate)
        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            clock.advance()
            samples[frame] = max(-1, min(1, generator(t, clock)))
        }
        return buffer
    }
}

/// Accumulates phase per partial, and carries a seeded noise source so a sound is identical
/// every time it is heard.
final class PhaseClock {
    private let sampleRate: Double
    private var phases: [Double: Double] = [:]
    private var rng = SeededRandom(seed: 1_234_567)
    private var step = 0

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    func advance() { step += 1 }

    func callAsFunction(_ frequency: Double) -> Double {
        let increment = Angles.tau * frequency / sampleRate
        let phase = (phases[frequency] ?? 0) + increment
        phases[frequency] = phase
        return phase
    }

    func noise() -> Double {
        rng.double(in: -1...1)
    }
}
