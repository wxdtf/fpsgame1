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
