//
//  SettingsTests.swift
//  fpsgame1Tests
//
//  Difficulty scaling, the options menu's persistence, per-level records and the
//  input manager's sensitivity / weapon cycling.
//

import XCTest
@testable import fpsgame1

final class SettingsTests: XCTestCase {

    private func freshDefaults(_ name: String) -> UserDefaults {
        let suite = "fpsgame1.tests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Difficulty

    func testDifficultyScalesUpMonotonically() {
        var lastHealth = 0.0, lastDamage = 0.0, lastSpeed = 0.0
        for difficulty in Difficulty.allCases {
            XCTAssertGreaterThan(difficulty.enemyHealthMultiplier, lastHealth)
            XCTAssertGreaterThan(difficulty.playerDamageMultiplier, lastDamage)
            XCTAssertGreaterThan(difficulty.enemySpeedMultiplier, lastSpeed)
            lastHealth = difficulty.enemyHealthMultiplier
            lastDamage = difficulty.playerDamageMultiplier
            lastSpeed = difficulty.enemySpeedMultiplier
        }
        XCTAssertEqual(Difficulty.normal.enemyHealthMultiplier, 1.0)
        XCTAssertEqual(Difficulty.normal.playerDamageMultiplier, 1.0)
        XCTAssertEqual(Difficulty.easy.next, .normal)
        XCTAssertEqual(Difficulty.nightmare.next, .easy, "wraps round")
        XCTAssertEqual(Difficulty.easy.previous, .nightmare)
    }

    func testDifficultyScalesSpawnedEnemyHealth() {
        let normal = GameEngine()
        let nightmare = GameEngine()
        nightmare.difficulty = .nightmare
        nightmare.selectCharacter(.sarge)
        XCTAssertEqual(normal.enemies.count, nightmare.enemies.count)
        for (a, b) in zip(normal.enemies, nightmare.enemies) {
            XCTAssertEqual(b.maxHealth, Int(Double(a.maxHealth) * Difficulty.nightmare.enemyHealthMultiplier))
            XCTAssertEqual(b.health, b.maxHealth)
        }
        let easy = GameEngine()
        easy.difficulty = .easy
        easy.restartLevel()
        XCTAssertLessThan(easy.enemies[0].maxHealth, normal.enemies[0].maxHealth)
    }

    // MARK: - Settings persistence

    func testSettingsRoundTripThroughDefaults() {
        let defaults = freshDefaults("settings")
        let first = GameSettings(defaults: defaults)
        XCTAssertEqual(first.mouseSensitivity, 1.0)
        XCTAssertEqual(first.masterVolume, 1.0)
        XCTAssertTrue(first.minimapDefault)
        XCTAssertEqual(first.difficulty, .normal)

        first.adjustSensitivity(by: 5)
        first.adjustMasterVolume(by: -3)
        first.adjustMusicVolume(by: 20)
        first.setMinimapDefault(false)
        first.setDifficulty(.hard)

        let second = GameSettings(defaults: defaults)
        XCTAssertEqual(second.mouseSensitivity, 1.5, accuracy: 1e-9)
        XCTAssertEqual(second.masterVolume, 0.7, accuracy: 1e-9)
        XCTAssertEqual(second.musicVolume, 1.0, accuracy: 1e-9, "clamped at 100%")
        XCTAssertFalse(second.minimapDefault)
        XCTAssertEqual(second.difficulty, .hard)

        second.resetToDefaults()
        XCTAssertEqual(second.mouseSensitivity, 1.0)
        XCTAssertTrue(second.minimapDefault)
        XCTAssertEqual(second.difficulty, .hard, "resetting options keeps the chosen skill")
    }

    func testSensitivityStaysInsideItsRange() {
        let settings = GameSettings(defaults: freshDefaults("range"))
        settings.adjustSensitivity(by: -100)
        XCTAssertEqual(settings.mouseSensitivity, GameSettings.sensitivityRange.lowerBound, accuracy: 1e-9)
        settings.adjustSensitivity(by: 100)
        XCTAssertEqual(settings.mouseSensitivity, GameSettings.sensitivityRange.upperBound, accuracy: 1e-9)
        settings.adjustSfxVolume(by: -100)
        XCTAssertEqual(settings.sfxVolume, 0)
    }

    // MARK: - Records

    func testRecordsKeepTheBestTimeAndKills() {
        let store = RecordStore(defaults: freshDefaults("records"))
        XCTAssertEqual(store.record(level: 1, difficulty: .normal), LevelRecord())

        let slow = LevelResult(level: 1, title: "E1M1", kills: 6, totalEnemies: 12, time: 200)
        let first = store.submit(slow, difficulty: .normal)
        XCTAssertTrue(first.newBestTime)
        XCTAssertTrue(first.newBestKills)
        XCTAssertEqual(first.record.bestTime, 200)
        XCTAssertEqual(first.record.bestKillPercent, 50)

        let fastButSloppy = LevelResult(level: 1, title: "E1M1", kills: 3, totalEnemies: 12, time: 90)
        let second = store.submit(fastButSloppy, difficulty: .normal)
        XCTAssertTrue(second.newBestTime)
        XCTAssertFalse(second.newBestKills)
        XCTAssertEqual(second.record.bestTime, 90)
        XCTAssertEqual(second.record.bestKillPercent, 50, "a worse kill count never lowers the record")

        let clean = LevelResult(level: 1, title: "E1M1", kills: 12, totalEnemies: 12, time: 150)
        let third = store.submit(clean, difficulty: .normal)
        XCTAssertFalse(third.newBestTime)
        XCTAssertTrue(third.newBestKills)
        XCTAssertEqual(store.record(level: 1, difficulty: .normal), LevelRecord(bestTime: 90, bestKillPercent: 100))

        // Other skills and levels are separate
        XCTAssertEqual(store.record(level: 1, difficulty: .hard), LevelRecord())
        XCTAssertEqual(store.record(level: 2, difficulty: .normal), LevelRecord())
        store.clear()
        XCTAssertEqual(store.record(level: 1, difficulty: .normal), LevelRecord())
    }

    func testKillPercentHandlesEmptyLevels() {
        XCTAssertEqual(RecordStore.killPercent(kills: 0, totalEnemies: 0), 100)
        XCTAssertEqual(RecordStore.killPercent(kills: 1, totalEnemies: 3), 33)
    }

    // MARK: - Input

    func testMouseSensitivityScalesTurning() {
        let input = InputManager()
        input.mouseMoved(deltaX: 10, deltaY: 0)
        let base = input.getInputState().turn
        input.mouseSensitivity = 2.0
        input.mouseMoved(deltaX: 10, deltaY: 0)
        XCTAssertEqual(input.getInputState().turn, base * 2, accuracy: 1e-9)
    }

    func testStickDeadzoneIsContinuous() {
        XCTAssertEqual(InputManager.deadzoned(0.1), 0)
        XCTAssertEqual(InputManager.deadzoned(-0.1), 0)
        XCTAssertEqual(InputManager.deadzoned(1.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(InputManager.deadzoned(-1.0), -1.0, accuracy: 1e-9)
        XCTAssertLessThan(InputManager.deadzoned(InputManager.stickDeadzone + 0.01), 0.05, "no jump at the edge")
    }

    func testWeaponCyclingWrapsThroughOwnedWeaponsOnly() {
        let engine = GameEngine()
        engine.player.weapons = [.fist, .pistol, .rocketLauncher]
        engine.player.currentWeapon = .pistol
        XCTAssertEqual(engine.cycledWeapon(by: 1), .rocketLauncher, "skips the shotgun and chaingun it lacks")
        XCTAssertEqual(engine.cycledWeapon(by: -1), .fist)
        engine.player.currentWeapon = .rocketLauncher
        XCTAssertEqual(engine.cycledWeapon(by: 1), .fist, "wraps round")
        engine.player.weapons = [.pistol]
        engine.player.currentWeapon = .pistol
        XCTAssertNil(engine.cycledWeapon(by: 1), "nothing to cycle to")

        engine.state = .playing
        engine.player.weapons = [.fist, .pistol, .shotgun]
        var input = InputManager.InputState()
        input.weaponCycle = 1
        engine.update(deltaTime: 1.0 / 60.0, input: input)
        XCTAssertEqual(engine.player.currentWeapon, .shotgun)
    }
}
