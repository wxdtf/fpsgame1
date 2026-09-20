//
//  GameEngineTests.swift
//  fpsgame1Tests
//

import XCTest
@testable import fpsgame1

final class GameEngineTests: XCTestCase {

    func testNewEngineStartsOnLevelOneWithSpawns() {
        let engine = GameEngine()
        XCTAssertEqual(engine.currentLevel, 1)
        XCTAssertEqual(engine.enemies.count, GameWorld.levelData(for: 1).enemies.count)
        XCTAssertEqual(engine.items.count, GameWorld.levelData(for: 1).items.count)
        XCTAssertEqual(engine.totalEnemies, engine.enemies.count)
        XCTAssertEqual(engine.killCount, 0)
        XCTAssertFalse(engine.isFinalLevel)
    }

    func testNextLevelCarriesHealthOverAndRestoresSome() {
        let engine = GameEngine()
        engine.player.health = 40
        engine.player.armor = 30
        engine.player.weapons.insert(.chaingun)
        engine.player.ammo[.bullets] = 123

        engine.nextLevel()

        XCTAssertEqual(engine.currentLevel, 2)
        XCTAssertEqual(engine.player.health, 65, "health carries over plus 25")
        XCTAssertEqual(engine.player.armor, 30)
        XCTAssertTrue(engine.player.weapons.contains(.chaingun))
        XCTAssertEqual(engine.player.ammo[.bullets], 123)
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(engine.killCount, 0)
        XCTAssertEqual(engine.elapsedTime, 0)
    }

    func testNextLevelHealthIsCappedAtMax() {
        let engine = GameEngine()
        engine.player.health = 95
        engine.nextLevel()
        XCTAssertEqual(engine.player.health, GameConstants.maxHealth)
    }

    func testNextLevelStopsAtTheFinalLevel() {
        let engine = GameEngine()
        for _ in 0..<(GameWorld.maxLevel + 3) {
            engine.nextLevel()
        }
        XCTAssertEqual(engine.currentLevel, GameWorld.maxLevel)
        XCTAssertTrue(engine.isFinalLevel)
    }

    func testRestartLevelIsAPistolStart() {
        let engine = GameEngine()
        engine.nextLevel()
        engine.player.health = 5
        engine.player.weapons.insert(.rocketLauncher)
        engine.killCount = 3

        engine.restartLevel()

        XCTAssertEqual(engine.currentLevel, 2, "death restarts the current level, not the campaign")
        XCTAssertEqual(engine.player.health, GameConstants.maxHealth)
        XCTAssertFalse(engine.player.weapons.contains(.rocketLauncher))
        XCTAssertEqual(engine.killCount, 0)
        XCTAssertEqual(engine.state, .playing)
    }

    func testResetToMenuGoesBackToLevelOne() {
        let engine = GameEngine()
        engine.nextLevel()
        engine.nextLevel()
        engine.resetToMenu()
        XCTAssertEqual(engine.currentLevel, 1)
        XCTAssertEqual(engine.state, .menu)
        XCTAssertTrue(engine.levelResults.isEmpty)
    }

    func testCharacterLoadoutSurvivesLevelLoad() {
        let engine = GameEngine()
        let grimm = try! XCTUnwrap(PlayerCharacter.all.first { $0.startingWeapon != .pistol })
        engine.selectCharacter(grimm)
        XCTAssertEqual(engine.player.currentWeapon, grimm.startingWeapon)
        engine.restartLevel()
        XCTAssertEqual(engine.player.currentWeapon, grimm.startingWeapon,
                       "a restart keeps the chosen marine's loadout")
    }

    func testObjectiveIsIncompleteAtLevelStart() {
        for level in 1...GameWorld.maxLevel {
            let engine = GameEngine()
            for _ in 1..<level { engine.nextLevel() }
            if case .reachExit = engine.objective { continue }
            XCTAssertFalse(engine.missionObjectiveComplete, "level \(level) objective completes too early")
            XCTAssertFalse(engine.objectiveText.isEmpty)
        }
    }

    /// Ten seconds of standing still must not crash, kill the player at spawn or
    /// let the level end on its own.
    func testIdleSimulationIsStable() {
        let engine = GameEngine()
        engine.state = .playing
        let input = InputManager.InputState()
        for _ in 0..<600 {
            engine.update(deltaTime: 1.0 / 60.0, input: input)
        }
        XCTAssertTrue(engine.state == .playing || engine.state == .dead)
        XCTAssertEqual(engine.elapsedTime, 10.0, accuracy: 1e-6)
        XCTAssertEqual(engine.killCount, 0)
        XCTAssertFalse(engine.exploredTiles.isEmpty, "the start area gets explored")
        for enemy in engine.enemies {
            XCTAssertTrue(engine.world.isPassable(x: enemy.x, y: enemy.y, radius: 0.2),
                          "\(enemy.type) wandered into a wall at (\(enemy.x), \(enemy.y))")
        }
    }

    func testUpdateDoesNothingWhenNotPlaying() {
        let engine = GameEngine()
        engine.state = .paused
        engine.update(deltaTime: 1, input: InputManager.InputState())
        XCTAssertEqual(engine.elapsedTime, 0)
    }
}
