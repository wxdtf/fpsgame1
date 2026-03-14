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

    func playEnemyAttack(type: EnemyType) {
        switch type {
        case .imp:
            playSound(generateImpFireball())
        case .demon:
            playSound(generateDemonBite())
        case .soldier:
            playSound(generateSoldierShot())
        }
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

    func playBGM(level: Int) {
        guard isSetup, let ambient = ambientNode, let buffer = generateBGM(level: level) else { return }
        ambient.stop()
        ambient.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        ambient.play()
    }

    func stopBGM() {
        ambientNode?.stop()
        ambientNode?.play()
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
        let pitch = Float.random(in: 0.8...1.2)
        return generateBuffer(duration: 0.5) { t in
            let twoPi = Float.pi * 2
            // Guttural death groan: descending multi-harmonic with gurgle
            let freq = max(35, (200 - t * 350) * pitch)
            let h1 = sin(t * freq * twoPi)
            let h2 = sin(t * freq * 2 * twoPi) * 0.4
            let h3 = sin(t * freq * 3 * twoPi) * 0.2
            // Gurgling noise (modulated random)
            let gurgleRate: Float = 15 + t * 20  // speeds up as creature falls
            let gurgleMod = (1.0 + sin(t * gurgleRate * twoPi)) * 0.5
            let gurgle = Float.random(in: -0.3...0.3) * gurgleMod
            // Body thud at the end
            let thudT = max(0, t - 0.3)
            let thud = sin(thudT * 40 * twoPi) * max(0, 1.0 - thudT / 0.15) * 0.3
            // Envelope: quick attack, long decay
            let env = min(1.0, t / 0.02) * max(0, 1.0 - t / 0.5)
            return (h1 + h2 + h3 + gurgle) * env * 0.35 + thud
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
        let pitch = Float.random(in: 0.8...1.2)
        return generateBuffer(duration: 0.45) { t in
            let twoPi = Float.pi * 2
            let baseFreq: Float = 85 * pitch
            // Two-phase growl: rising snarl then bark
            let phase1End: Float = 0.25
            let freq: Float
            if t < phase1End {
                // Rising snarl
                freq = baseFreq * (1.0 + t / phase1End * 0.4)
            } else {
                // Sharp bark that decays
                freq = baseFreq * 1.6 * max(0.7, 1.0 - (t - phase1End) / 0.2)
            }
            // Rich growl harmonics (sawtooth-ish)
            let h1 = sin(t * freq * twoPi)
            let h2 = sin(t * freq * 2 * twoPi) * 0.5
            let h3 = sin(t * freq * 3 * twoPi) * 0.3
            let h4 = sin(t * freq * 4 * twoPi) * 0.15
            // Guttural noise modulation (throat rattle)
            let rattle = Float.random(in: -0.25...0.25) * (1.0 + sin(t * 25 * twoPi) * 0.5)
            // Amplitude: swell up, hold, then decay
            let attack = min(1.0, t / 0.04)
            let hold: Float = t < phase1End ? 1.0 : max(0, 1.0 - (t - phase1End) / 0.2)
            return (h1 + h2 + h3 + h4 + rattle) * attack * hold * 0.22
        }
    }

    private func generateEnemyPain() -> AVAudioPCMBuffer? {
        let pitch = Float.random(in: 0.8...1.2)
        return generateBuffer(duration: 0.25) { t in
            let twoPi = Float.pi * 2
            // Sharp yelp: quick upward pitch then descending moan
            let freq: Float
            if t < 0.04 {
                freq = (150 + t / 0.04 * 250) * pitch  // Quick rise
            } else {
                freq = (400 - (t - 0.04) * 900) * pitch  // Descending moan
            }
            let clampedFreq = max(60, freq)
            let tone = sin(t * clampedFreq * twoPi)
            let h2 = sin(t * clampedFreq * 2 * twoPi) * 0.3
            // Breathy noise layer
            let breath = Float.random(in: -0.2...0.2) * min(1.0, t / 0.02)
            // Quick attack, moderate decay
            let env = min(1.0, t / 0.01) * max(0, 1.0 - t / 0.25)
            return (tone * 0.45 + h2 + breath) * env * 0.4
        }
    }

    private func generateImpFireball() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.4) { t in
            let twoPi = Float.pi * 2
            // Layered fire whoosh: filtered noise shaped over time
            let n1 = Float.random(in: -1...1)
            let n2 = Float.random(in: -1...1)
            // Band-pass effect: mix noise with resonant tones that sweep up
            let sweepFreq: Float = (120 + t * 400) * pitch
            let resonance = sin(t * sweepFreq * twoPi) * 0.3
            let resonance2 = sin(t * sweepFreq * 1.5 * twoPi) * 0.15
            // Fire crackle: rapid random pops
            let crackle = n2 * (sin(t * 8000 * twoPi) > 0.7 ? 1.0 : 0.0) * 0.3
            // Shape: swell up then sustain and fade
            let attack = min(1.0, t / 0.05)
            let sustain: Float = t < 0.15 ? 1.0 : max(0, 1.0 - (t - 0.15) / 0.25)
            let env = attack * sustain
            // Low rumble for body
            let rumble = sin(t * 45 * pitch * twoPi) * 0.25
            return (n1 * 0.35 + resonance + resonance2 + crackle + rumble) * env * 0.4
        }
    }

    private func generateDemonBite() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.25) { t in
            let twoPi = Float.pi * 2
            // Phase 1: jaw opening growl (0-0.08s)
            let growl = sin(t * 70 * pitch * twoPi) * max(0, 1.0 - t / 0.1) * 0.4
            let growlH = sin(t * 140 * pitch * twoPi) * max(0, 1.0 - t / 0.1) * 0.2
            // Phase 2: sharp jaw snap at 0.08s
            let snapT = max(0, t - 0.07)
            let snap = sin(snapT * 900 * pitch * twoPi) * max(0, 1.0 - snapT / 0.02) * 0.7
            // Phase 3: meaty wet impact
            let impactT = max(0, t - 0.08)
            let wetNoise = Float.random(in: -1...1) * max(0, 1.0 - impactT / 0.08)
            let thud = sin(impactT * 55 * pitch * twoPi) * max(0, 1.0 - impactT / 0.12)
            let crunch = Float.random(in: -0.5...0.5) * max(0, 1.0 - impactT / 0.04)
            // Combine
            let overall = max(0, 1.0 - t / 0.25)
            return (growl + growlH + snap + wetNoise * 0.3 + thud * 0.5 + crunch * 0.25) * overall * 0.5
        }
    }

    private func generateSoldierShot() -> AVAudioPCMBuffer? {
        let pitch = randomPitch()
        return generateBuffer(duration: 0.3) { t in
            let twoPi = Float.pi * 2
            // Sharp transient crack (first 10ms)
            let crack = Float.random(in: -1...1) * max(0, 1.0 - t / 0.008) * 0.8
            // Metallic body with harmonics (different from player's pistol)
            let body = sin(t * 420 * pitch * twoPi) * max(0, 1.0 - t / 0.04)
            let bodyH = sin(t * 840 * pitch * twoPi) * max(0, 1.0 - t / 0.03) * 0.3
            // Echo/room reflection (delayed copy, lower volume)
            let echoT = max(0, t - 0.06)
            let echo = Float.random(in: -0.6...0.6) * max(0, 1.0 - echoT / 0.08)
            let echoTone = sin(echoT * 380 * pitch * twoPi) * max(0, 1.0 - echoT / 0.1) * 0.2
            // Low thump
            let thump = sin(t * 100 * pitch * twoPi) * max(0, 1.0 - t / 0.05) * 0.35
            // Tail hiss (shell casing / air)
            let tail = Float.random(in: -0.15...0.15) * max(0, t / 0.1) * max(0, 1.0 - t / 0.3)
            return (crack + body * 0.5 + bodyH + echo * 0.3 + echoTone + thump + tail) * 0.45
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

    // MARK: - BGM Generator

    private func generateBGM(level: Int) -> AVAudioPCMBuffer? {
        guard let fmt = format else { return nil }
        let sampleRate = Float(fmt.sampleRate)
        let twoPi = Float.pi * 2

        // Deterministic noise for drums
        func noise(_ i: Int, _ seed: Int) -> Float {
            var h = UInt32(bitPattern: Int32(truncatingIfNeeded: i &* seed))
            h = (h ^ (h >> 16)) &* 0x45d9f3b
            h = h ^ (h >> 16)
            return Float(Int(h % 20000)) / 10000.0 - 1.0
        }

        switch level {
        case 1:
            return generateBGM_MilitaryBase(fmt: fmt, sr: sampleRate, pi2: twoPi, noise: noise)
        case 2:
            return generateBGM_HellsGateway(fmt: fmt, sr: sampleRate, pi2: twoPi, noise: noise)
        default:
            return generateBGM_ToxinRefinery(fmt: fmt, sr: sampleRate, pi2: twoPi, noise: noise)
        }
    }

    // MARK: Level 1 — "UAC Military Base" (Industrial/Tense)
    // Steady march, metallic percussion, tense synth stabs. Cold, mechanical.
    private func generateBGM_MilitaryBase(
        fmt: AVAudioFormat, sr: Float, pi2: Float,
        noise: (Int, Int) -> Float
    ) -> AVAudioPCMBuffer? {
        let bpm: Float = 120
        let beatDur = 60.0 / bpm
        // E minor: E2=82.4, B1=61.7, G2=98, D2=73.4, A1=55
        // Bass: chugging 8th note pattern (palm-muted power chord feel)
        let bassNotes: [Float] = [82.4, 82.4, 82.4, 82.4, 73.4, 73.4, 98.0, 82.4]
        // Lead: sparse stabs, tension building (0 = rest)
        let leadNotes: [Float] = [0, 0, 0, 0,  0, 0, 164.8, 0,
                                   0, 0, 0, 0,  196.0, 164.8, 0, 0]
        let totalBeats = leadNotes.count
        let duration = Float(totalBeats) * beatDur
        let frameCount = AVAudioFrameCount(duration * sr)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let beatPos = t / beatDur
            let beat = Int(beatPos) % totalBeats
            let beatFrac = beatPos - floor(beatPos)
            let eighthPos = beatPos * 2
            let eighthFrac = eighthPos - floor(eighthPos)
            let beatTime = beatFrac * beatDur
            var s: Float = 0

            // KICK: every beat (march)
            let kEnv = max(0, 1.0 - beatTime / 0.15)
            let kFreq: Float = 50 + 100 * max(0, 1.0 - beatTime / 0.06)
            s += sin(beatTime * kFreq * pi2) * kEnv * kEnv * 0.45

            // SNARE: beats 1 and 3 (march pattern: kick-snare-kick-snare per 4 beats)
            if beat % 4 == 2 {
                let sEnv = max(0, 1.0 - beatTime / 0.1)
                s += (noise(i, 2654435761) * 0.5 + sin(beatTime * 190 * pi2) * 0.3) * sEnv * 0.35
            }

            // INDUSTRIAL HI-HAT: 16th notes, tight and metallic
            let hhPos = beatPos * 4
            let hhFrac = hhPos - floor(hhPos)
            let hhTime = hhFrac * beatDur / 4
            let hhEnv = max(0, 1.0 - hhTime / 0.025)
            let hhAccent: Float = (Int(hhPos) % 4 == 0) ? 1.0 : 0.5
            s += noise(i, 374761393) * hhEnv * 0.08 * hhAccent

            // METALLIC CLANG: on beat 4 of each 4-beat group
            if beat % 4 == 3 {
                let clangEnv = max(0, 1.0 - beatTime / 0.08)
                s += sin(beatTime * 1800 * pi2) * clangEnv * 0.08
                s += sin(beatTime * 2400 * pi2) * clangEnv * 0.05
            }

            // BASS: chugging 8th notes with tight staccato
            let bassIdx = Int(eighthPos) % bassNotes.count
            let bassFreq = bassNotes[bassIdx]
            let bPhase = t * bassFreq * pi2
            // Tight, palm-muted bass (harmonics + fast decay per note)
            let bass = sin(bPhase) + sin(bPhase * 2) * 0.6 + sin(bPhase * 3) * 0.35 + sin(bPhase * 4) * 0.2
            let bassEnv: Float = min(1.0, eighthFrac * 30) * max(0, 1.0 - eighthFrac * 1.8)
            s += bass * bassEnv * 0.15

            // LEAD: sparse, cold synth stabs
            let leadFreq = leadNotes[beat]
            if leadFreq > 0 {
                let lPhase = t * leadFreq * pi2
                // Saw-like stab (bright, metallic)
                let lead = sin(lPhase) + sin(lPhase * 2) * 0.4 + sin(lPhase * 3) * 0.2
                let leadEnv = min(1.0, beatFrac * 20) * max(0, 1.0 - beatFrac * 2.5)
                s += lead * leadEnv * 0.12
            }

            // PAD: low industrial hum
            let pad = sin(t * 41.2 * pi2) * 0.03 + sin(t * 61.7 * pi2) * 0.02
            s += pad

            let loopEnv: Float = min(1.0, t / 0.01) * min(1.0, (duration - t) / 0.01)
            data[i] = max(-1, min(1, s * loopEnv * 0.7))
        }
        return buffer
    }

    // MARK: Level 2 — "Hell's Gateway" (Demonic/Ritual)
    // Slow, heavy doom. Tribal toms, tritone bass, organ-like lead, dark choir pad.
    private func generateBGM_HellsGateway(
        fmt: AVAudioFormat, sr: Float, pi2: Float,
        noise: (Int, Int) -> Float
    ) -> AVAudioPCMBuffer? {
        let bpm: Float = 100
        let beatDur = 60.0 / bpm
        // D minor with tritone (Ab): D2=73.4, A1=55, Bb1=58.3, F2=87.3, Ab2=103.8
        let bassNotes: [Float] = [73.4, 73.4, 0, 73.4,  103.8, 73.4, 0, 58.3]
        // Eerie organ melody with tritone intervals
        let leadNotes: [Float] = [0, 0, 0, 0,  293.7, 277.2, 0, 0,
                                   0, 0, 0, 0,  207.7, 0, 174.6, 0]
        let totalBeats = leadNotes.count
        let duration = Float(totalBeats) * beatDur
        let frameCount = AVAudioFrameCount(duration * sr)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let beatPos = t / beatDur
            let beat = Int(beatPos) % totalBeats
            let beatFrac = beatPos - floor(beatPos)
            let eighthPos = beatPos * 2
            let eighthFrac = eighthPos - floor(eighthPos)
            let beatTime = beatFrac * beatDur
            var s: Float = 0

            // KICK: heavy doom kick, long sustain, every other beat
            if beat % 2 == 0 {
                let kEnv = max(0, 1.0 - beatTime / 0.3)
                let kFreq: Float = 40 + 80 * max(0, 1.0 - beatTime / 0.1)
                s += sin(beatTime * kFreq * pi2) * kEnv * kEnv * 0.55
            }

            // TOMS instead of snare: alternating low/high tom on odd beats
            if beat % 2 == 1 {
                let tomFreq: Float = (beat % 4 == 1) ? 100 : 80
                let tEnv = max(0, 1.0 - beatTime / 0.2)
                s += sin(beatTime * tomFreq * pi2) * tEnv * tEnv * 0.35
            }

            // TRIBAL SHAKER: 8th notes, quiet
            let shakeTime = eighthFrac * beatDur / 2
            let shakeEnv = max(0, 1.0 - shakeTime / 0.03)
            s += noise(i, 874761393) * shakeEnv * 0.06

            // CRASH/GONG: every 8 beats
            if beat % 8 == 0 {
                let gongEnv = max(0, 1.0 - beatTime / beatDur)
                let gongN = noise(i, 123456789)
                s += gongN * gongEnv * 0.1 * max(0, 1.0 - beatFrac * 3)
            }

            // BASS: deep, detuned, with rests for drama
            let bassIdx = Int(eighthPos) % bassNotes.count
            let bassFreq = bassNotes[bassIdx]
            if bassFreq > 0 {
                let bPhase = t * bassFreq * pi2
                // Detuned power: fundamental + slightly sharp octave for hellish dissonance
                let bass = sin(bPhase) + sin(bPhase * 1.02) * 0.4 +
                            sin(bPhase * 2) * 0.5 + sin(bPhase * 2.03) * 0.2 +
                            sin(bPhase * 3) * 0.15
                let bassEnv: Float = min(1.0, eighthFrac * 15) * max(0.4, 1.0 - eighthFrac * 0.5)
                s += bass * bassEnv * 0.16
            }

            // LEAD: organ-like with vibrato (eerie, slow)
            let leadFreq = leadNotes[beat]
            if leadFreq > 0 {
                let vibrato = sin(t * 4.5 * pi2) * 3
                let lPhase = t * (leadFreq + vibrato) * pi2
                // Organ: all harmonics present
                let lead = sin(lPhase) + sin(lPhase * 2) * 0.5 + sin(lPhase * 3) * 0.25 +
                            sin(lPhase * 4) * 0.15 + sin(lPhase * 5) * 0.08
                let leadEnv = min(1.0, beatFrac * 8) * max(0, 1.0 - beatFrac * 0.8)
                s += lead * leadEnv * 0.08
            }

            // PAD: dark "choir" — detuned fifths + slow LFO
            let choirLfo = (1.0 + sin(t * 0.5 * pi2)) * 0.5
            let choir = sin(t * 36.7 * pi2) + sin(t * 36.7 * 1.01 * pi2) * 0.7 +  // Detuned unison
                         sin(t * 55.0 * pi2) * 0.5 + sin(t * 55.2 * pi2) * 0.3     // Detuned fifth
            s += choir * 0.03 * (0.7 + choirLfo * 0.3)

            let loopEnv: Float = min(1.0, t / 0.01) * min(1.0, (duration - t) / 0.01)
            data[i] = max(-1, min(1, s * loopEnv * 0.7))
        }
        return buffer
    }

    // MARK: Level 3 — "Toxin Refinery" (Tech/Aggressive)
    // Fast, driving, electronic. Double-kick, arpeggiated bass, aggressive synth lead.
    private func generateBGM_ToxinRefinery(
        fmt: AVAudioFormat, sr: Float, pi2: Float,
        noise: (Int, Int) -> Float
    ) -> AVAudioPCMBuffer? {
        let bpm: Float = 155
        let beatDur = 60.0 / bpm
        // A minor: A1=55, E2=82.4, C2=65.4, G2=98, D2=73.4, F2=87.3
        // Fast arpeggiated bass
        let bassNotes: [Float] = [55.0, 82.4, 55.0, 65.4,  55.0, 82.4, 73.4, 65.4,
                                   55.0, 82.4, 55.0, 98.0,  87.3, 82.4, 73.4, 65.4]
        // Aggressive lead: fast staccato phrases
        let leadNotes: [Float] = [220.0, 0, 261.6, 220.0,  196.0, 0, 220.0, 0,
                                   261.6, 0, 293.7, 261.6,  220.0, 196.0, 174.6, 0]
        let totalBeats = leadNotes.count
        let duration = Float(totalBeats) * beatDur
        let frameCount = AVAudioFrameCount(duration * sr)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let beatPos = t / beatDur
            let beat = Int(beatPos) % totalBeats
            let beatFrac = beatPos - floor(beatPos)
            let eighthPos = beatPos * 2
            let eighthFrac = eighthPos - floor(eighthPos)
            let beatTime = beatFrac * beatDur
            let sixteenthPos = beatPos * 4
            let sixteenthFrac = sixteenthPos - floor(sixteenthPos)
            let sixteenthTime = sixteenthFrac * beatDur / 4
            var s: Float = 0

            // DOUBLE KICK: 16th notes on kick drum (relentless)
            let dkEnv = max(0, 1.0 - sixteenthTime / 0.06)
            let dkFreq: Float = 50 + 90 * max(0, 1.0 - sixteenthTime / 0.04)
            // Accent pattern: strong on beats, softer in between
            let dkAccent: Float = (Int(sixteenthPos) % 4 == 0) ? 1.0 :
                                   (Int(sixteenthPos) % 2 == 0) ? 0.7 : 0.4
            s += sin(sixteenthTime * dkFreq * pi2) * dkEnv * dkEnv * 0.35 * dkAccent

            // SNARE: every other beat + ghost notes
            if beat % 2 == 1 {
                let sEnv = max(0, 1.0 - beatTime / 0.08)
                s += (noise(i, 2654435761) * 0.6 + sin(beatTime * 210 * pi2) * 0.3) * sEnv * 0.4
            }
            // Ghost snare on 16th before snare beats
            if beat % 2 == 0 && beatFrac > 0.75 {
                let gsTime = (beatFrac - 0.75) * beatDur * 4
                let gsEnv = max(0, 1.0 - gsTime / 0.04)
                s += noise(i, 2654435761) * gsEnv * 0.12
            }

            // RIDE CYMBAL: 8th notes, bright
            let rideTime = eighthFrac * beatDur / 2
            let rideEnv = max(0, 1.0 - rideTime / 0.06)
            let rideN = noise(i, 574761393)
            let rideTone = sin(rideTime * 6000 * pi2) * 0.3
            s += (rideN * 0.5 + rideTone) * rideEnv * 0.07

            // BASS: fast arpeggiated, each 8th note
            let bassIdx = Int(eighthPos) % bassNotes.count
            let bassFreq = bassNotes[bassIdx]
            let bPhase = t * bassFreq * pi2
            // Aggressive distorted bass (many harmonics, clipped)
            var bass = sin(bPhase) + sin(bPhase * 2) * 0.7 + sin(bPhase * 3) * 0.5 +
                        sin(bPhase * 4) * 0.35 + sin(bPhase * 5) * 0.2
            bass = max(-1.5, min(1.5, bass * 1.3)) // Soft clip for grit
            let bassEnv: Float = min(1.0, eighthFrac * 25) * max(0.2, 1.0 - eighthFrac * 1.2)
            s += bass * bassEnv * 0.14

            // LEAD: aggressive staccato synth
            let leadFreq = leadNotes[beat]
            if leadFreq > 0 {
                let lPhase = t * leadFreq * pi2
                // Hard square wave (very aggressive)
                let lead = sin(lPhase) + sin(lPhase * 3) / 3 + sin(lPhase * 5) / 5 +
                            sin(lPhase * 7) / 7
                let leadEnv = min(1.0, beatFrac * 25) * max(0, 1.0 - beatFrac * 3.0)
                s += lead * leadEnv * 0.1
            }

            // PAD: electronic buzz/hum
            let buzz = sin(t * 27.5 * pi2) * 0.025 + sin(t * 55.0 * pi2) * 0.02
            // Add a subtle pulsing effect synced to beat
            let pulse = (1.0 + sin(beatPos * pi2)) * 0.5
            s += buzz * (0.8 + pulse * 0.2)

            let loopEnv: Float = min(1.0, t / 0.01) * min(1.0, (duration - t) / 0.01)
            data[i] = max(-1, min(1, s * loopEnv * 0.7))
        }
        return buffer
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
