//
//  Settings.swift
//  fpsgame1
//
//  Player-facing options and per-level records, both persisted in UserDefaults:
//  the skill level picked on the title screen, the settings menu (mouse
//  sensitivity, volumes, minimap default) and the best time / kill percentage
//  for every level and skill.
//

import Foundation

// MARK: - Difficulty

/// Skill level chosen on the title screen. Scales enemy health, enemy projectile
/// speed and the damage the player takes, on top of the per-level ramp in
/// GameConstants.
enum Difficulty: Int, CaseIterable, Codable {
    case easy = 0
    case normal
    case hard
    case nightmare

    var name: String {
        switch self {
        case .easy: return "I'M TOO YOUNG TO DIE"
        case .normal: return "HURT ME PLENTY"
        case .hard: return "ULTRA-VIOLENCE"
        case .nightmare: return "NIGHTMARE!"
        }
    }

    var blurb: String {
        switch self {
        case .easy: return "Half damage taken, frail demons. A stroll through hell."
        case .normal: return "The way it was meant to be played."
        case .hard: return "Tougher demons that hit half again as hard."
        case .nightmare: return "Double damage, armoured demons, fast plasma. Good luck."
        }
    }

    var enemyHealthMultiplier: Double {
        switch self {
        case .easy: return 0.7
        case .normal: return 1.0
        case .hard: return 1.3
        case .nightmare: return 1.6
        }
    }

    var playerDamageMultiplier: Double {
        switch self {
        case .easy: return 0.5
        case .normal: return 1.0
        case .hard: return 1.5
        case .nightmare: return 2.0
        }
    }

    var enemySpeedMultiplier: Double {
        switch self {
        case .easy: return 0.85
        case .normal: return 1.0
        case .hard: return 1.1
        case .nightmare: return 1.25
        }
    }

    var next: Difficulty { Difficulty(rawValue: (rawValue + 1) % Difficulty.allCases.count) ?? .normal }
    var previous: Difficulty {
        Difficulty(rawValue: (rawValue + Difficulty.allCases.count - 1) % Difficulty.allCases.count) ?? .normal
    }
}

// MARK: - Settings

/// The options menu. Every change goes through a method that writes it straight to
/// UserDefaults and, for the volumes, pushes it to the audio engine.
@Observable
final class GameSettings {
    static let shared = GameSettings()

    static let sensitivityRange: ClosedRange<Double> = 0.3...3.0
    static let sensitivityStep: Double = 0.1
    static let volumeStep: Double = 0.1

    private let defaults: UserDefaults

    private(set) var mouseSensitivity: Double
    private(set) var masterVolume: Double
    private(set) var sfxVolume: Double
    private(set) var musicVolume: Double
    /// Whether the minimap is showing when a level starts (TAB still toggles it)
    private(set) var minimapDefault: Bool
    private(set) var difficulty: Difficulty

    private enum Key {
        static let sensitivity = "settings.mouseSensitivity"
        static let master = "settings.masterVolume"
        static let sfx = "settings.sfxVolume"
        static let music = "settings.musicVolume"
        static let minimap = "settings.minimapDefault"
        static let difficulty = "settings.difficulty"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func number(_ key: String, _ fallback: Double) -> Double {
            defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
        }
        mouseSensitivity = Self.clampSensitivity(number(Key.sensitivity, 1.0))
        masterVolume = Self.clampVolume(number(Key.master, 1.0))
        sfxVolume = Self.clampVolume(number(Key.sfx, 1.0))
        musicVolume = Self.clampVolume(number(Key.music, 0.8))
        minimapDefault = defaults.object(forKey: Key.minimap) == nil ? true : defaults.bool(forKey: Key.minimap)
        // An absent key reads as 0, which would be the easiest skill, so check presence first
        difficulty = defaults.object(forKey: Key.difficulty) == nil
            ? .normal
            : Difficulty(rawValue: defaults.integer(forKey: Key.difficulty)) ?? .normal
        applyVolumes()
    }

    static func clampSensitivity(_ value: Double) -> Double {
        let stepped = (value / sensitivityStep).rounded() * sensitivityStep
        return min(sensitivityRange.upperBound, max(sensitivityRange.lowerBound, stepped))
    }

    static func clampVolume(_ value: Double) -> Double {
        let stepped = (value / volumeStep).rounded() * volumeStep
        return min(1.0, max(0.0, stepped))
    }

    func adjustSensitivity(by steps: Int) {
        mouseSensitivity = Self.clampSensitivity(mouseSensitivity + Double(steps) * Self.sensitivityStep)
        save()
    }

    func adjustMasterVolume(by steps: Int) {
        masterVolume = Self.clampVolume(masterVolume + Double(steps) * Self.volumeStep)
        save()
        applyVolumes()
    }

    func adjustSfxVolume(by steps: Int) {
        sfxVolume = Self.clampVolume(sfxVolume + Double(steps) * Self.volumeStep)
        save()
        applyVolumes()
    }

    func adjustMusicVolume(by steps: Int) {
        musicVolume = Self.clampVolume(musicVolume + Double(steps) * Self.volumeStep)
        save()
        applyVolumes()
    }

    func setMinimapDefault(_ on: Bool) {
        minimapDefault = on
        save()
    }

    func toggleMinimapDefault() { setMinimapDefault(!minimapDefault) }

    func setDifficulty(_ chosen: Difficulty) {
        difficulty = chosen
        save()
    }

    func resetToDefaults() {
        mouseSensitivity = 1.0
        masterVolume = 1.0
        sfxVolume = 1.0
        musicVolume = 0.8
        minimapDefault = true
        save()
        applyVolumes()
    }

    private func save() {
        defaults.set(mouseSensitivity, forKey: Key.sensitivity)
        defaults.set(masterVolume, forKey: Key.master)
        defaults.set(sfxVolume, forKey: Key.sfx)
        defaults.set(musicVolume, forKey: Key.music)
        defaults.set(minimapDefault, forKey: Key.minimap)
        defaults.set(difficulty.rawValue, forKey: Key.difficulty)
    }

    private func applyVolumes() {
        AudioManager.shared.setVolumes(master: Float(masterVolume), sfx: Float(sfxVolume), music: Float(musicVolume))
    }
}

// MARK: - Records

/// Best results for one level at one skill
struct LevelRecord: Codable, Equatable {
    var bestTime: Double?
    var bestKillPercent: Int?
}

/// What submitting a level result changed
struct RecordUpdate: Equatable {
    let record: LevelRecord
    let newBestTime: Bool
    let newBestKills: Bool
}

/// Best time and kill percentage per level and skill, kept in UserDefaults
final class RecordStore {
    static let shared = RecordStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func killPercent(kills: Int, totalEnemies: Int) -> Int {
        guard totalEnemies > 0 else { return 100 }
        return min(100, kills * 100 / totalEnemies)
    }

    private func key(level: Int, difficulty: Difficulty) -> String {
        "record.\(difficulty.rawValue).\(level)"
    }

    func record(level: Int, difficulty: Difficulty) -> LevelRecord {
        guard let data = defaults.data(forKey: key(level: level, difficulty: difficulty)),
              let record = try? JSONDecoder().decode(LevelRecord.self, from: data) else {
            return LevelRecord()
        }
        return record
    }

    /// Merge a finished level into its record; returns what improved
    @discardableResult
    func submit(_ result: LevelResult, difficulty: Difficulty) -> RecordUpdate {
        var record = self.record(level: result.level, difficulty: difficulty)
        let percent = Self.killPercent(kills: result.kills, totalEnemies: result.totalEnemies)
        let newBestTime = record.bestTime.map { result.time < $0 } ?? true
        let newBestKills = record.bestKillPercent.map { percent > $0 } ?? true
        if newBestTime { record.bestTime = result.time }
        if newBestKills { record.bestKillPercent = percent }
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: key(level: result.level, difficulty: difficulty))
        }
        return RecordUpdate(record: record, newBestTime: newBestTime, newBestKills: newBestKills)
    }

    func clear() {
        for difficulty in Difficulty.allCases {
            for level in 1...GameWorld.maxLevel {
                defaults.removeObject(forKey: key(level: level, difficulty: difficulty))
            }
        }
    }
}
