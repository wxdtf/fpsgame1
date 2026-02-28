//
//  AudioManager.swift
//  testproject
//

import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private var audioEngine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var ambientNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var isSetup = false
    private let poolSize = 8
    private var nextNodeIndex = 0

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        let engine = AVAudioEngine()

        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }

        // Create pool of player nodes for simultaneous sounds
        var nodes: [AVAudioPlayerNode] = []
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: fmt)
            nodes.append(node)
        }

        // Separate ambient node for looping background
        let ambient = AVAudioPlayerNode()
        engine.attach(ambient)
        engine.connect(ambient, to: engine.mainMixerNode, format: fmt)

        do {
            try engine.start()
            audioEngine = engine
            playerNodes = nodes
            ambientNode = ambient
            format = fmt
            isSetup = true
            for node in nodes { node.play() }
            ambient.play()
        } catch {
            // Audio not available - game still works
        }
    }

    // MARK: - Public Sound Methods

    func playGunshot() {
        playSound(generateGunshot())
    }

    func playShotgun() {
        playSound(generateShotgunBlast())
    }

    func playPunch() {
        playSound(generatePunch())
    }

    func playPickup() {
        playSound(generatePickup())
    }

    func playHurt() {
        playSound(generateHurt())
    }

    func playEnemyDeath() {
        playSound(generateEnemyDeath())
    }

    func playDoorOpen() {
        playSound(generateDoorOpen())
    }

    func playFootstep() {
        playSound(generateFootstep())
    }

    func playWeaponSwitch() {
        playSound(generateWeaponSwitch())
    }

    func playEnemyAlert() {
        playSound(generateEnemyAlert())
    }

    func playEnemyPain() {
        playSound(generateEnemyPain())
    }

    func playLevelComplete() {
        playSound(generateLevelComplete())
    }

    func playAmbientDrone() {
        guard isSetup, let ambient = ambientNode, let buffer = generateAmbientDrone() else { return }
        ambient.stop()
        ambient.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        ambient.play()
    }

    func stopAmbientDrone() {
        ambientNode?.stop()
        ambientNode?.play() // Keep node ready
    }

    // MARK: - Sound Pool

    private func playSound(_ buffer: AVAudioPCMBuffer?) {
        guard isSetup, let buffer = buffer else { return }
        let node = playerNodes[nextNodeIndex]
        nextNodeIndex = (nextNodeIndex + 1) % poolSize
        node.scheduleBuffer(buffer, completionHandler: nil)
    }

    // MARK: - Procedural Sound Generators

    private func generateGunshot() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.15) { t in
            let noise = Float.random(in: -1...1)
            let decay = max(0, 1.0 - t / 0.15)
            let pop = sin(t * 800 * pitch) * max(0, 1.0 - t / 0.02)
            return (noise * 0.5 + pop) * decay * 0.6
        }
    }

    private func generateShotgunBlast() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.25) { t in
            let noise = Float.random(in: -1...1)
            let decay = max(0, 1.0 - t / 0.25)
            let lowBoom = sin(t * 200 * pitch) * max(0, 1.0 - t / 0.05)
            return (noise * 0.6 + lowBoom * 0.8) * decay * 0.7
        }
    }

    private func generatePunch() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.1) { t in
            let thud = sin(t * 300 * pitch) * max(0, 1.0 - t / 0.1)
            return thud * 0.5
        }
    }

    private func generatePickup() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.2) { t in
            let freq: Float = 600 + t * 3000
            let tone = sin(t * freq * 2 * .pi)
            let decay = max(0, 1.0 - t / 0.2)
            return tone * decay * 0.3
        }
    }

    private func generateHurt() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.2) { t in
            let freq: Float = (200 - t * 400) * pitch
            let tone = sin(t * max(50, freq) * 2 * .pi)
            let noise = Float.random(in: -0.3...0.3)
            let decay = max(0, 1.0 - t / 0.2)
            return (tone * 0.5 + noise) * decay * 0.4
        }
    }

    private func generateEnemyDeath() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.3) { t in
            let freq: Float = (300 - t * 600) * pitch
            let tone = sin(t * max(40, freq) * 2 * .pi)
            let noise = Float.random(in: -0.2...0.2)
            let decay = max(0, 1.0 - t / 0.3)
            return (tone * 0.4 + noise) * decay * 0.5
        }
    }

    private func generateDoorOpen() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.4) { t in
            let freq: Float = (100 + t * 50) * pitch
            let tone = sin(t * freq * 2 * .pi) * 0.2
            let noise = Float.random(in: -0.1...0.1)
            let grind = sin(t * 45 * pitch) * 0.15 * max(0, 1.0 - t / 0.4)
            let decay = max(0, 1.0 - t / 0.4)
            return (tone + noise + grind) * decay * 0.35
        }
    }

    private func generateFootstep() -> AVAudioPCMBuffer? {
        let pitch = Float.random(in: 0.85...1.15)
        return generateBuffer(duration: 0.06) { t in
            let thud = sin(t * 150 * pitch) * max(0, 1.0 - t / 0.04)
            let click = sin(t * 2500 * pitch) * max(0, 1.0 - t / 0.01) * 0.2
            return (thud + click) * 0.25
        }
    }

    private func generateWeaponSwitch() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.1) { t in
            let click1 = sin(t * 2000 * 2 * Float.pi) * max(0, 1.0 - t / 0.03)
            let click2: Float = t > 0.04 ? sin((t - 0.04) * 3000 * 2 * Float.pi) * max(0, 1.0 - (t - 0.04) / 0.03) : 0
            return (click1 + click2) * 0.3
        }
    }

    private func generateEnemyAlert() -> AVAudioPCMBuffer? {
        let pitch = Float.random(in: 0.85...1.15)
        return generateBuffer(duration: 0.35) { t in
            let freq: Float = 90 * pitch
            // Sawtooth-like growl via harmonics
            let fundamental = sin(t * freq * 2 * Float.pi)
            let harmonic2 = sin(t * freq * 2 * 2 * Float.pi) * 0.5
            let harmonic3 = sin(t * freq * 3 * 2 * Float.pi) * 0.25
            let noise = Float.random(in: -0.2...0.2)
            let decay = max(0, 1.0 - t / 0.35)
            let wobble: Float = 1.0 + sin(t * 12) * 0.2
            return (fundamental + harmonic2 + harmonic3 + noise) * decay * wobble * 0.2
        }
    }

    private func generateEnemyPain() -> AVAudioPCMBuffer? {
        let pitch = Float.random(in: 0.85...1.15)
        return generateBuffer(duration: 0.15) { t in
            let freq: Float = (300 - t * 1200) * pitch
            let tone = sin(t * max(80, freq) * 2 * Float.pi)
            let noise = Float.random(in: -0.3...0.3)
            let decay = max(0, 1.0 - t / 0.15)
            return (tone * 0.4 + noise * 0.3) * decay * 0.35
        }
    }

    private func generateLevelComplete() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.7) { t in
            // Three ascending tones: C-E-G
            let tone: Float
            if t < 0.22 {
                tone = sin(t * 262 * 2 * Float.pi) // C4
            } else if t < 0.44 {
                tone = sin(t * 330 * 2 * Float.pi) // E4
            } else {
                tone = sin(t * 392 * 2 * Float.pi) // G4
            }
            let harmonic = sin(t * 524 * 2 * Float.pi) * 0.15 // Octave shimmer
            let envelope: Float
            let phase = t.truncatingRemainder(dividingBy: 0.22)
            envelope = min(1.0, phase / 0.02) * max(0, 1.0 - phase / 0.22)
            return (tone + harmonic) * envelope * 0.35
        }
    }

    private func generateAmbientDrone() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 2.0) { t in
            let s1 = sin(t * 30 * 2 * Float.pi)
            let s2 = sin(t * 45 * 2 * Float.pi) * 0.7
            let s3 = sin(t * 60 * 2 * Float.pi) * 0.4
            // Smooth envelope to avoid click on loop boundary
            let loopEnv: Float = min(1.0, t / 0.05) * min(1.0, (2.0 - t) / 0.05)
            return (s1 + s2 + s3) * 0.03 * loopEnv
        }
    }

    // MARK: - Helpers

    private func randomPitch() -> Float {
        Float.random(in: 0.95...1.05)
    }

    private func generateBuffer(duration: Float, generator: (Float) -> Float) -> AVAudioPCMBuffer? {
        guard let fmt = format else { return nil }
        let sampleRate = Float(fmt.sampleRate)
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            data[i] = generator(t)
        }

        return buffer
    }
}
