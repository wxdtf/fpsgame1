//
//  AudioManager.swift
//  testproject
//

import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var isSetup = false

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)

        do {
            try engine.start()
            audioEngine = engine
            playerNode = player
            format = fmt
            isSetup = true
            player.play()
        } catch {
            // Audio not available - game still works
        }
    }

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

    private func playSound(_ buffer: AVAudioPCMBuffer?) {
        guard isSetup, let buffer = buffer, let player = playerNode else { return }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    // MARK: - Procedural Sound Generation

    private func generateGunshot() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.15) { t in
            let noise = Float.random(in: -1...1)
            let decay = max(0, 1.0 - t / 0.15)
            let pop = sin(Float(t) * 800) * max(0, 1.0 - t / 0.02)
            return (noise * 0.5 + pop) * decay * 0.6
        }
    }

    private func generateShotgunBlast() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.25) { t in
            let noise = Float.random(in: -1...1)
            let decay = max(0, 1.0 - t / 0.25)
            let lowBoom = sin(Float(t) * 200) * max(0, 1.0 - t / 0.05)
            return (noise * 0.6 + lowBoom * 0.8) * decay * 0.7
        }
    }

    private func generatePunch() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.1) { t in
            let thud = sin(Float(t) * 300) * max(0, 1.0 - t / 0.1)
            return thud * 0.5
        }
    }

    private func generatePickup() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.2) { t in
            let freq: Float = 600 + t * 3000
            let tone = sin(Float(t) * freq * 2 * .pi)
            let decay = max(0, 1.0 - t / 0.2)
            return tone * decay * 0.3
        }
    }

    private func generateHurt() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.2) { t in
            let freq: Float = 200 - t * 400
            let tone = sin(Float(t) * max(50, freq) * 2 * .pi)
            let noise = Float.random(in: -0.3...0.3)
            let decay = max(0, 1.0 - t / 0.2)
            return (tone * 0.5 + noise) * decay * 0.4
        }
    }

    private func generateEnemyDeath() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.3) { t in
            let freq: Float = 300 - t * 600
            let tone = sin(Float(t) * max(40, freq) * 2 * .pi)
            let noise = Float.random(in: -0.2...0.2)
            let decay = max(0, 1.0 - t / 0.3)
            return (tone * 0.4 + noise) * decay * 0.5
        }
    }

    private func generateDoorOpen() -> AVAudioPCMBuffer? {
        return generateBuffer(duration: 0.4) { t in
            let freq: Float = 100 + t * 50
            let tone = sin(Float(t) * freq * 2 * .pi) * 0.2
            let noise = Float.random(in: -0.1...0.1)
            let decay = max(0, 1.0 - t / 0.4)
            return (tone + noise) * decay * 0.3
        }
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
