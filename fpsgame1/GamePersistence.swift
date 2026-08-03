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

struct PlayerSnapshot: Codable, Equatable {
    let x: Double
    let y: Double
    let angle: Double
    let health: Int
    let armor: Int
    let weapons: [WeaponType]
    let bullets: Int
    let shells: Int
    let currentWeapon: WeaponType
    let keys: [KeyColor]
    let berserkTimer: Double
    let bobPhase: Double
    let bobAmount: Double
    let weaponFrame: Int
    let weaponFrameTimer: Double
    let weaponCooldownTimer: Double
    let weaponIsFiring: Bool
    let weaponIsSwitching: Bool
    let weaponSwitchProgress: Double

    nonisolated init(player: Player) {
        x = player.x
        y = player.y
        angle = player.angle
        health = player.health
        armor = player.armor
        weapons = player.weapons.sorted { $0.rawValue < $1.rawValue }
        bullets = player.ammo[.bullets] ?? 0
        shells = player.ammo[.shells] ?? 0
        currentWeapon = player.currentWeapon
        keys = player.keys.sorted { $0.rawValue < $1.rawValue }
        berserkTimer = player.berserkTimer
        bobPhase = player.bobPhase
        bobAmount = player.bobAmount
        weaponFrame = player.weaponState.currentFrame
        weaponFrameTimer = player.weaponState.frameTimer
        weaponCooldownTimer = player.weaponState.cooldownTimer
        weaponIsFiring = player.weaponState.isFiring
        weaponIsSwitching = player.weaponState.isSwitching
        weaponSwitchProgress = player.weaponState.switchProgress
    }
}

struct EnemySnapshot: Codable, Equatable {
    enum Behavior: String, Codable {
        case idle, patrolling, chasing, attacking, hurt, dying, dead
    }

    let type: EnemyType
    let x: Double
    let y: Double
    let angle: Double
    let health: Int
    let behavior: Behavior
    let behaviorTimer: Double
    let animationFrame: Int
    let animationTimer: Double
    let attackCooldown: Double
    let alertTimer: Double
    let patrolTargetX: Double?
    let patrolTargetY: Double?
    let hasDealtDamageThisAttack: Bool
    let stuckTimer: Double
    let wallAvoidAngle: Double
    let navigationPath: [Int]
    let navigationTargetTile: Int?
    let navigationRepathTimer: Double

    nonisolated init(enemy: Enemy) {
        type = enemy.type
        x = enemy.x
        y = enemy.y
        angle = enemy.angle
        health = enemy.health
        switch enemy.state {
        case .idle: behavior = .idle; behaviorTimer = 0
        case .patrolling: behavior = .patrolling; behaviorTimer = 0
        case .chasing: behavior = .chasing; behaviorTimer = 0
        case .attacking: behavior = .attacking; behaviorTimer = 0
        case .hurt(let timer): behavior = .hurt; behaviorTimer = timer
        case .dying(let timer): behavior = .dying; behaviorTimer = timer
        case .dead: behavior = .dead; behaviorTimer = 0
        }
        animationFrame = enemy.animationFrame
        animationTimer = enemy.animationTimer
        attackCooldown = enemy.attackCooldown
        alertTimer = enemy.alertTimer
        patrolTargetX = enemy.patrolTarget?.0
        patrolTargetY = enemy.patrolTarget?.1
        hasDealtDamageThisAttack = enemy.hasDealtDamageThisAttack
        stuckTimer = enemy.stuckTimer
        wallAvoidAngle = enemy.wallAvoidAngle
        navigationPath = enemy.navigationPath
        navigationTargetTile = enemy.navigationTargetTile
        navigationRepathTimer = enemy.navigationRepathTimer
    }
}

struct ItemSnapshot: Codable, Equatable {
    let type: ItemType
    let x: Double
    let y: Double
    let isCollected: Bool
    let bobPhase: Double

    nonisolated init(item: Item) {
        type = item.type
        x = item.x
        y = item.y
        isCollected = item.isCollected
        bobPhase = item.bobPhase
    }
}

struct DoorSnapshot: Codable, Equatable {
    let tileX: Int
    let tileY: Int
    let openAmount: Double
    let isOpening: Bool
    let isClosing: Bool
    let stayOpenTimer: Double

    nonisolated init(door: DoorState) {
        tileX = door.tileX
        tileY = door.tileY
        openAmount = door.openAmount
        isOpening = door.isOpening
        isClosing = door.isClosing
        stayOpenTimer = door.stayOpenTimer
    }
}

struct ProjectileSnapshot: Codable, Equatable {
    let x: Double
    let y: Double
    let dirX: Double
    let dirY: Double
    let speed: Double
    let damage: Int
    let isEnemy: Bool
    let lifetime: Double
    let type: ProjectileType

    nonisolated init(projectile: Projectile) {
        x = projectile.x
        y = projectile.y
        dirX = projectile.dirX
        dirY = projectile.dirY
        speed = projectile.speed
        damage = projectile.damage
        isEnemy = projectile.isEnemy
        lifetime = projectile.lifetime
        type = projectile.type
    }
}

/// Versioned, exact mid-level state. Transient audiovisual effects are intentionally omitted.
struct CampaignSession: Codable, Equatable {
    let level: Int
    let difficulty: GameDifficulty
    let player: PlayerSnapshot
    let enemies: [EnemySnapshot]
    let items: [ItemSnapshot]
    let doors: [DoorSnapshot]
    let projectiles: [ProjectileSnapshot]
    let killCount: Int
    let totalEnemies: Int
    let elapsedTime: Double
    let exploredTiles: [Int]
    let damageFloorAccumulator: Double
    let completedCampaignTime: Double
    let completedCampaignKills: Int
    let completedCampaignEnemies: Int

    var checkpoint: CampaignCheckpoint {
        CampaignCheckpoint(
            level: level,
            health: player.health,
            armor: player.armor,
            weapons: player.weapons,
            bullets: player.bullets,
            shells: player.shells,
            currentWeapon: player.currentWeapon,
            difficulty: difficulty
        )
    }
}

struct LevelPerformance: Codable, Equatable, Identifiable {
    var id: String { "\(difficulty.rawValue)-\(level)" }
    let level: Int
    let difficulty: GameDifficulty
    var bestTime: Double
    var maxKills: Int
    var totalEnemies: Int
    var completionCount: Int
}

struct CampaignPerformance: Codable, Equatable, Identifiable {
    var id: String { difficulty.rawValue }
    let difficulty: GameDifficulty
    var bestTime: Double
    var maxKills: Int
    var totalEnemies: Int
    var completionCount: Int
}

struct CompletionRecordUpdate: Equatable {
    let bestTime: Double
    let maxKills: Int
    let completionCount: Int
    let isNewBestTime: Bool
    let isNewKillRecord: Bool
}

final class GameStatsStore {
    private struct Archive: Codable {
        var levels: [LevelPerformance] = []
        var campaigns: [CampaignPerformance] = []
        var lifetimeKills: Int = 0
        var completedLevels: Int = 0
        var completedCampaigns: Int = 0
    }

    private static let statsKey = "game.stats.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var archive: Archive

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.statsKey),
           let saved = try? decoder.decode(Archive.self, from: data) {
            archive = saved
        } else {
            archive = Archive()
        }
    }

    var lifetimeKills: Int { archive.lifetimeKills }
    var completedCampaigns: Int { archive.completedCampaigns }

    func performance(level: Int, difficulty: GameDifficulty) -> LevelPerformance? {
        archive.levels.first { $0.level == level && $0.difficulty == difficulty }
    }

    @discardableResult
    func recordLevel(
        level: Int,
        difficulty: GameDifficulty,
        time: Double,
        kills: Int,
        totalEnemies: Int
    ) -> CompletionRecordUpdate {
        let safeTime = max(0, time)
        let safeKills = min(max(0, kills), max(0, totalEnemies))
        let index = archive.levels.firstIndex { $0.level == level && $0.difficulty == difficulty }
        let previous = index.map { archive.levels[$0] }
        let isNewBestTime = previous == nil || safeTime < previous!.bestTime
        let isNewKillRecord = previous == nil || safeKills > previous!.maxKills

        let updated = LevelPerformance(
            level: level,
            difficulty: difficulty,
            bestTime: isNewBestTime ? safeTime : previous!.bestTime,
            maxKills: isNewKillRecord ? safeKills : previous!.maxKills,
            totalEnemies: max(totalEnemies, previous?.totalEnemies ?? 0),
            completionCount: (previous?.completionCount ?? 0) + 1
        )
        if let index { archive.levels[index] = updated } else { archive.levels.append(updated) }
        archive.lifetimeKills += safeKills
        archive.completedLevels += 1
        persist()
        return CompletionRecordUpdate(
            bestTime: updated.bestTime,
            maxKills: updated.maxKills,
            completionCount: updated.completionCount,
            isNewBestTime: isNewBestTime,
            isNewKillRecord: isNewKillRecord
        )
    }

    @discardableResult
    func recordCampaign(
        difficulty: GameDifficulty,
        time: Double,
        kills: Int,
        totalEnemies: Int
    ) -> CompletionRecordUpdate {
        let safeTime = max(0, time)
        let safeKills = min(max(0, kills), max(0, totalEnemies))
        let index = archive.campaigns.firstIndex { $0.difficulty == difficulty }
        let previous = index.map { archive.campaigns[$0] }
        let isNewBestTime = previous == nil || safeTime < previous!.bestTime
        let isNewKillRecord = previous == nil || safeKills > previous!.maxKills

        let updated = CampaignPerformance(
            difficulty: difficulty,
            bestTime: isNewBestTime ? safeTime : previous!.bestTime,
            maxKills: isNewKillRecord ? safeKills : previous!.maxKills,
            totalEnemies: max(totalEnemies, previous?.totalEnemies ?? 0),
            completionCount: (previous?.completionCount ?? 0) + 1
        )
        if let index { archive.campaigns[index] = updated } else { archive.campaigns.append(updated) }
        archive.completedCampaigns += 1
        persist()
        return CompletionRecordUpdate(
            bestTime: updated.bestTime,
            maxKills: updated.maxKills,
            completionCount: updated.completionCount,
            isNewBestTime: isNewBestTime,
            isNewKillRecord: isNewKillRecord
        )
    }

    private func persist() {
        guard let data = try? encoder.encode(archive) else { return }
        defaults.set(data, forKey: Self.statsKey)
    }
}

private struct CampaignSaveRecord: Codable {
    let version: Int
    let savedAt: Date
    let checkpoint: CampaignCheckpoint
    let session: CampaignSession?
}

struct CampaignSaveSummary: Equatable {
    let level: Int
    let difficulty: GameDifficulty
    let elapsedTime: Double?
    let isMidLevel: Bool
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
    private static let saveKey = "campaign.save.v2"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCheckpoint: Bool { load() != nil }

    var summary: CampaignSaveSummary? {
        if let record = loadRecord() {
            return CampaignSaveSummary(
                level: record.checkpoint.level,
                difficulty: record.checkpoint.difficulty,
                elapsedTime: record.session?.elapsedTime,
                isMidLevel: record.session != nil
            )
        }
        guard let checkpoint = loadLegacyCheckpoint() else { return nil }
        return CampaignSaveSummary(
            level: checkpoint.level,
            difficulty: checkpoint.difficulty,
            elapsedTime: nil,
            isMidLevel: false
        )
    }

    func save(_ checkpoint: CampaignCheckpoint) {
        persist(CampaignSaveRecord(version: 2, savedAt: Date(), checkpoint: checkpoint, session: nil))
    }

    func save(_ session: CampaignSession) {
        persist(CampaignSaveRecord(version: 2, savedAt: Date(), checkpoint: session.checkpoint, session: session))
    }

    func load() -> CampaignCheckpoint? {
        if let record = loadRecord() {
            return record.checkpoint
        }

        guard let checkpoint = loadLegacyCheckpoint() else { return nil }
        // Migrate lazily so existing players keep their progress after the 9.5 update.
        save(checkpoint)
        return checkpoint
    }

    func loadSession() -> CampaignSession? {
        guard let record = loadRecord(), let session = record.session,
              session.level == record.checkpoint.level,
              session.difficulty == record.checkpoint.difficulty else { return nil }
        return session
    }

    func clear() {
        defaults.removeObject(forKey: Self.saveKey)
        defaults.removeObject(forKey: Self.checkpointKey)
    }

    private func persist(_ record: CampaignSaveRecord) {
        guard let data = try? encoder.encode(record) else { return }
        defaults.set(data, forKey: Self.saveKey)
        defaults.removeObject(forKey: Self.checkpointKey)
    }

    private func loadRecord() -> CampaignSaveRecord? {
        guard let data = defaults.data(forKey: Self.saveKey),
              let record = try? decoder.decode(CampaignSaveRecord.self, from: data),
              record.version == 2,
              (1...GameWorld.maxLevel).contains(record.checkpoint.level) else { return nil }
        return record
    }

    private func loadLegacyCheckpoint() -> CampaignCheckpoint? {
        guard let data = defaults.data(forKey: Self.checkpointKey),
              let checkpoint = try? decoder.decode(CampaignCheckpoint.self, from: data),
              (1...GameWorld.maxLevel).contains(checkpoint.level) else { return nil }
        return checkpoint
    }
}
