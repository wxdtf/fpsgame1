import XCTest
@testable import fpsgame1

@MainActor
final class GameRegressionTests: XCTestCase {
    func testDiagonalMovementMatchesStraightSpeed() {
        var world = openWorld()
        world.rebuildDoorIndex()

        var straight = Player(x: 4.5, y: 4.5, angle: 0)
        straight.move(forward: 1, strafe: 0, deltaTime: 0.1, world: world)
        let straightDistance = hypot(straight.x - 4.5, straight.y - 4.5)

        var diagonal = Player(x: 4.5, y: 4.5, angle: 0)
        diagonal.move(forward: 1, strafe: 1, deltaTime: 0.1, world: world)
        let diagonalDistance = hypot(diagonal.x - 4.5, diagonal.y - 4.5)

        XCTAssertEqual(diagonalDistance, straightDistance, accuracy: 0.000_001)
    }

    func testRestartKeepsCurrentLevel() {
        let engine = GameEngine()
        engine.nextLevel()
        engine.restart()
        XCTAssertEqual(engine.currentLevel, 2)
        XCTAssertEqual(engine.totalEnemies, GameWorld.levelData(for: 2).enemies.count)
    }

    func testFinalLevelCompletesCampaign() {
        let engine = GameEngine()
        engine.nextLevel()
        engine.nextLevel()
        engine.nextLevel()
        XCTAssertEqual(engine.currentLevel, GameWorld.maxLevel)
        XCTAssertEqual(engine.state, .campaignComplete)
    }

    func testDamageFloorAppliesFiveDamagePerSecond() {
        let engine = GameEngine()
        engine.enemies = []
        engine.state = .playing
        let tileIndex = Int(engine.player.y) * engine.world.width + Int(engine.player.x)
        engine.world.tiles1D[tileIndex] = .damageFloor

        for _ in 0..<120 {
            engine.update(deltaTime: 1.0 / 60.0, input: InputManager.InputState())
        }
        XCTAssertEqual(engine.player.health, 90)
    }

    func testAllBuiltInLevelsAreValid() {
        for level in 1...GameWorld.maxLevel {
            let issues = GameWorld.validationIssues(for: GameWorld.levelData(for: level))
            XCTAssertTrue(issues.isEmpty, "Level \(level): \(issues.joined(separator: ", "))")
        }
    }

    func testCheckpointRoundTripRestoresLoadout() {
        let defaults = isolatedDefaults()
        let store = CampaignProgressStore(defaults: defaults)
        let checkpoint = CampaignCheckpoint(
            level: 2, health: 63, armor: 42,
            weapons: [.fist, .pistol, .shotgun, .chaingun],
            bullets: 117, shells: 21, currentWeapon: .chaingun, difficulty: .hard
        )

        store.save(checkpoint)
        XCTAssertEqual(store.load(), checkpoint)

        let engine = GameEngine(difficulty: .hard)
        engine.restoreCheckpoint(checkpoint)
        XCTAssertEqual(engine.currentLevel, 2)
        XCTAssertEqual(engine.player.health, 63)
        XCTAssertEqual(engine.player.armor, 42)
        XCTAssertEqual(engine.player.currentWeapon, .chaingun)
        XCTAssertEqual(engine.player.ammo[.bullets], 117)
    }

    func testMidLevelSessionRoundTripRestoresWorldState() {
        let defaults = isolatedDefaults()
        let store = CampaignProgressStore(defaults: defaults)
        let engine = GameEngine(difficulty: .hard)
        engine.state = .playing
        engine.player.health = 71
        engine.player.armor = 33
        engine.player.keys = [.red]
        engine.player.berserkTimer = 8.5
        engine.enemies[0].health = 17
        engine.enemies[0].state = .hurt(timer: 0.12)
        engine.enemies[0].attackCooldown = 0.7
        engine.items[0].isCollected = true
        engine.items.append(Item(type: .ammoBullets(amount: 10), x: 2.5, y: 2.5))
        if !engine.world.doors.isEmpty {
            engine.world.doors[0].openAmount = 0.65
            engine.world.doors[0].isOpening = true
        }
        engine.projectiles = [Projectile(
            x: 3.5, y: 3.5, dirX: 1, dirY: 0,
            speed: 5, damage: 10, isEnemy: true, lifetime: 1.25, type: .fireball
        )]
        engine.killCount = 1
        engine.elapsedTime = 42.75
        engine.exploredTiles = [21, 22, 23]

        let snapshot = engine.makeSessionSnapshot()
        store.save(snapshot)
        XCTAssertEqual(store.loadSession(), snapshot)

        let restored = GameEngine(difficulty: .hard)
        XCTAssertTrue(restored.restoreSessionSnapshot(snapshot))
        XCTAssertEqual(restored.makeSessionSnapshot(), snapshot)
        XCTAssertEqual(restored.state, .paused)
    }

    func testLegacyCheckpointMigratesWithoutLosingProgress() throws {
        let defaults = isolatedDefaults()
        let checkpoint = CampaignCheckpoint(
            level: 3, health: 54, armor: 12,
            weapons: [.fist, .pistol, .shotgun],
            bullets: 88, shells: 9, currentWeapon: .shotgun, difficulty: .normal
        )
        defaults.set(try JSONEncoder().encode(checkpoint), forKey: "campaign.checkpoint.v1")

        let store = CampaignProgressStore(defaults: defaults)
        XCTAssertEqual(store.load(), checkpoint)
        XCTAssertNil(store.loadSession())
        XCTAssertNil(defaults.data(forKey: "campaign.checkpoint.v1"))
        XCTAssertNotNil(defaults.data(forKey: "campaign.save.v2"))
    }

    func testPerformanceStatsKeepBestRecordsPerDifficulty() {
        let defaults = isolatedDefaults()
        let store = GameStatsStore(defaults: defaults)

        let first = store.recordLevel(
            level: 1, difficulty: .hard, time: 120, kills: 5, totalEnemies: 8
        )
        XCTAssertTrue(first.isNewBestTime)
        XCTAssertTrue(first.isNewKillRecord)

        let second = store.recordLevel(
            level: 1, difficulty: .hard, time: 130, kills: 8, totalEnemies: 8
        )
        XCTAssertFalse(second.isNewBestTime)
        XCTAssertTrue(second.isNewKillRecord)
        XCTAssertEqual(second.bestTime, 120)

        let third = store.recordLevel(
            level: 1, difficulty: .hard, time: 95, kills: 7, totalEnemies: 8
        )
        XCTAssertTrue(third.isNewBestTime)
        XCTAssertFalse(third.isNewKillRecord)
        XCTAssertEqual(third.maxKills, 8)
        XCTAssertEqual(third.completionCount, 3)

        let restored = GameStatsStore(defaults: defaults)
        XCTAssertEqual(restored.performance(level: 1, difficulty: .hard)?.bestTime, 95)
        XCTAssertNil(restored.performance(level: 1, difficulty: .easy))
        XCTAssertEqual(restored.lifetimeKills, 20)
    }

    func testEnemyNavigatesAroundBlockingWall() {
        var tiles = (0..<81).map { index -> TileType in
            let x = index % 9
            let y = index / 9
            if x == 0 || x == 8 || y == 0 || y == 8 { return .brickWall }
            if x == 4 && y <= 6 { return .brickWall }
            return .empty
        }
        // Keep the enemy's starting side and the gap explicitly walkable.
        tiles[2 * 9 + 2] = .empty
        tiles[7 * 9 + 4] = .empty
        var world = GameWorld(width: 9, height: 9, tiles1D: tiles, doors: [])
        world.rebuildDoorIndex()

        var enemy = Enemy(type: .demon, x: 2.5, y: 2.5)
        enemy.state = .chasing
        let initialDistance = hypot(6.5 - enemy.x, 2.5 - enemy.y)
        for _ in 0..<720 {
            enemy.update(
                deltaTime: 1.0 / 60.0,
                playerX: 6.5,
                playerY: 2.5,
                world: world
            )
        }

        XCTAssertLessThan(hypot(6.5 - enemy.x, 2.5 - enemy.y), initialDistance)
        XCTAssertGreaterThan(enemy.x, 4.0, "Enemy should route through the gap instead of sticking to the wall")
    }

    func testAllLevelsRemainStableDuringLongSimulation() {
        let noInput = InputManager.InputState()
        for targetLevel in 1...GameWorld.maxLevel {
            let engine = GameEngine(difficulty: .hard)
            if targetLevel > 1 {
                for _ in 2...targetLevel { engine.nextLevel() }
            }
            engine.player.health = 1_000_000
            engine.state = .playing

            // Thirty seconds per level at 60 Hz exercises AI, projectiles, doors and timers.
            for _ in 0..<1_800 {
                engine.update(deltaTime: 1.0 / 60.0, input: noInput)
            }

            XCTAssertTrue(engine.player.x.isFinite && engine.player.y.isFinite)
            XCTAssertTrue(engine.enemies.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            XCTAssertTrue(engine.projectiles.allSatisfy {
                $0.x.isFinite && $0.y.isFinite && $0.lifetime.isFinite
            })
            XCTAssertLessThan(engine.projectiles.count, 100)
        }
    }

    func testSettingsPersistAndClampValues() {
        let defaults = isolatedDefaults()
        let settings = GameSettingsStore(defaults: defaults)
        settings.difficulty = .hard
        settings.mouseSensitivity = 1.7
        settings.masterVolume = 0.35
        settings.showMinimap = false

        let restored = GameSettingsStore(defaults: defaults)
        XCTAssertEqual(restored.difficulty, .hard)
        XCTAssertEqual(restored.mouseSensitivity, 1.7, accuracy: 0.001)
        XCTAssertEqual(restored.masterVolume, 0.35, accuracy: 0.001)
        XCTAssertFalse(restored.showMinimap)

        restored.mouseSensitivity = 9
        restored.masterVolume = -1
        XCTAssertEqual(restored.mouseSensitivity, 2.0)
        XCTAssertEqual(restored.masterVolume, 0.0)
    }

    func testHealthAndArmorCarryBetweenLevels() {
        let engine = GameEngine()
        engine.player.health = 30
        engine.player.armor = 45
        engine.nextLevel()
        XCTAssertEqual(engine.player.health, 55)
        XCTAssertEqual(engine.player.armor, 45)
    }

    func testDifficultyScalesEnemyHealth() {
        let easy = GameEngine(difficulty: .easy)
        let hard = GameEngine(difficulty: .hard)
        XCTAssertLessThan(easy.enemies[0].health, hard.enemies[0].health)
    }

    func testMouseSensitivityScalesTurnInput() {
        let input = InputManager()
        input.mouseSensitivity = 2.0
        input.mouseMoved(deltaX: 10, deltaY: 0)
        XCTAssertEqual(input.getInputState().turn, 0.06, accuracy: 0.000_001)
    }

    private func openWorld() -> GameWorld {
        GameWorld(
            width: 9,
            height: 9,
            tiles1D: (0..<81).map { index in
                let x = index % 9
                let y = index / 9
                return (x == 0 || x == 8 || y == 0 || y == 8) ? .brickWall : .empty
            },
            doors: []
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "fpsgame1.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
