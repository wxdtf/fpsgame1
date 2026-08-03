import Foundation
import Observation

enum GameDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "MARINE"
        case .normal: return "VETERAN"
        case .hard: return "NIGHTMARE"
        }
    }

    var enemyHealthMultiplier: Double {
        switch self {
        case .easy: return 0.8
        case .normal: return 1.0
        case .hard: return 1.25
        }
    }

    var enemyDamageMultiplier: Double {
        switch self {
        case .easy: return 0.7
        case .normal: return 1.0
        case .hard: return 1.3
        }
    }

    var enemySpeedMultiplier: Double {
        switch self {
        case .easy: return 0.9
        case .normal: return 1.0
        case .hard: return 1.1
        }
    }
}

struct CampaignCheckpoint: Codable, Equatable {
    let level: Int
    let health: Int
    let armor: Int
    let weapons: [WeaponType]
    let bullets: Int
    let shells: Int
    let currentWeapon: WeaponType
    let difficulty: GameDifficulty
}

@Observable
final class GameSettingsStore {
    private enum Key {
        static let difficulty = "settings.difficulty"
        static let mouseSensitivity = "settings.mouseSensitivity"
        static let masterVolume = "settings.masterVolume"
        static let showMinimap = "settings.showMinimap"
    }

    private let defaults: UserDefaults

    var difficulty: GameDifficulty { didSet { persist() } }
    var mouseSensitivity: Double {
        didSet {
            let clamped = min(2.0, max(0.5, mouseSensitivity))
            guard clamped == mouseSensitivity else {
                mouseSensitivity = clamped
                return
            }
            persist()
        }
    }
    var masterVolume: Double {
        didSet {
            let clamped = min(1.0, max(0.0, masterVolume))
            guard clamped == masterVolume else {
                masterVolume = clamped
                return
            }
            persist()
        }
    }
    var showMinimap: Bool { didSet { persist() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        difficulty = GameDifficulty(rawValue: defaults.string(forKey: Key.difficulty) ?? "") ?? .normal
        let savedSensitivity = defaults.object(forKey: Key.mouseSensitivity) as? Double
        mouseSensitivity = min(2.0, max(0.5, savedSensitivity ?? 1.0))
        let savedVolume = defaults.object(forKey: Key.masterVolume) as? Double
        masterVolume = min(1.0, max(0.0, savedVolume ?? 0.8))
        showMinimap = defaults.object(forKey: Key.showMinimap) as? Bool ?? true
    }

    private func persist() {
        defaults.set(difficulty.rawValue, forKey: Key.difficulty)
        defaults.set(mouseSensitivity, forKey: Key.mouseSensitivity)
        defaults.set(masterVolume, forKey: Key.masterVolume)
        defaults.set(showMinimap, forKey: Key.showMinimap)
    }
}

final class CampaignProgressStore {
    private static let checkpointKey = "campaign.checkpoint.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCheckpoint: Bool { load() != nil }

    func save(_ checkpoint: CampaignCheckpoint) {
        guard let data = try? encoder.encode(checkpoint) else { return }
        defaults.set(data, forKey: Self.checkpointKey)
    }

    func load() -> CampaignCheckpoint? {
        guard let data = defaults.data(forKey: Self.checkpointKey),
              let checkpoint = try? decoder.decode(CampaignCheckpoint.self, from: data),
              (1...GameWorld.maxLevel).contains(checkpoint.level) else {
            return nil
        }
        return checkpoint
    }

    func clear() {
        defaults.removeObject(forKey: Self.checkpointKey)
    }
}
