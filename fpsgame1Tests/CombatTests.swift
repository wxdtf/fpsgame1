//
//  CombatTests.swift
//  fpsgame1Tests
//
//  Weapons, enemies and the texture animation clock.
//

import XCTest
@testable import fpsgame1

final class CombatTests: XCTestCase {

    // MARK: - Weapons

    func testWeaponFireRespectsCooldownAndAnimation() {
        var state = WeaponState(type: .pistol)
        let def = WeaponDefinition.pistol

        XCTAssertTrue(state.canFire)
        XCTAssertTrue(state.fire())
        XCTAssertFalse(state.canFire, "busy right after firing")
        XCTAssertFalse(state.fire())

        // Play out the whole animation and cooldown
        var elapsed = 0.0
        while !state.canFire && elapsed < 5 {
            state.update(deltaTime: 0.01)
            elapsed += 0.01
        }
        XCTAssertTrue(state.canFire)
        XCTAssertGreaterThanOrEqual(elapsed, def.fireRate - 0.011)
        XCTAssertEqual(state.currentFrame, 0)
    }

    func testWeaponSwitchBlocksFiringUntilDone() {
        var state = WeaponState(type: .pistol)
        state.beginSwitch(to: .shotgun)
        XCTAssertEqual(state.type, .shotgun)
        XCTAssertTrue(state.isSwitching)
        XCTAssertFalse(state.canFire)

        for _ in 0..<30 { state.update(deltaTime: 0.01) }
        XCTAssertFalse(state.isSwitching)
        XCTAssertTrue(state.canFire)
    }

    func testEveryWeaponHasADefinition() {
        for type in WeaponType.allCases {
            let def = WeaponDefinition.forType(type)
            XCTAssertEqual(def.type, type)
            XCTAssertGreaterThan(def.damage, 0)
            XCTAssertGreaterThan(def.animationFrames, 0)
            if def.ammoType != nil {
                XCTAssertGreaterThan(def.ammoPerShot, 0)
            }
        }
    }

    // MARK: - Enemies

    func testLethalDamageStartsDyingAndStopsCountingAsAlive() {
        var enemy = Enemy(type: .imp, x: 1, y: 1)
        XCTAssertTrue(enemy.isAlive)
        enemy.takeDamage(enemy.health + 50)
        XCTAssertEqual(enemy.health, 0, "health floors at zero")
        XCTAssertTrue(enemy.isDying)
        XCTAssertFalse(enemy.isAlive)
        XCTAssertFalse(enemy.isDead)

        // Damage to a corpse-to-be is ignored
        enemy.takeDamage(10)
        XCTAssertTrue(enemy.isDying)
    }

    func testDyingEnemyBecomesDeadAfterTheAnimation() {
        var enemy = Enemy(type: .soldier, x: 1.5, y: 1.5)
        enemy.takeDamage(1000)
        let world = TestWorld.make(["###", "#.#", "###"])
        var nav = NavigationField(width: 3, height: 3)
        nav.rebuild(world: world, goalX: 1, goalY: 1)
        for _ in 0..<70 {
            enemy.update(deltaTime: 1.0 / 60.0, playerX: 1.5, playerY: 1.5, world: world, nav: nav)
        }
        XCTAssertTrue(enemy.isDead)
        XCTAssertEqual(enemy.spriteFrameOffset, 9, "corpse frame")
    }

    func testNonLethalHitAlwaysWakesADormantEnemy() {
        for _ in 0..<50 {
            var enemy = Enemy(type: .baron, x: 1, y: 1)  // lowest pain chance
            enemy.takeDamage(1)
            switch enemy.state {
            case .chasing, .hurt:
                break
            default:
                XCTFail("enemy stayed dormant after being shot: \(enemy.state)")
            }
        }
    }

    func testDifficultyScalingIsMonotonic() {
        var lastHealth = 0.0, lastDamage = 0.0, lastSpeed = 0.0
        for level in 1...GameWorld.maxLevel {
            let h = GameConstants.difficultyHealthMultiplier(for: level)
            let d = GameConstants.difficultyDamageMultiplier(for: level)
            let s = GameConstants.difficultySpeedMultiplier(for: level)
            XCTAssertGreaterThan(h, lastHealth)
            XCTAssertGreaterThan(d, lastDamage)
            XCTAssertGreaterThan(s, lastSpeed)
            lastHealth = h; lastDamage = d; lastSpeed = s
        }
    }

    // MARK: - Exit portal animation clock

    func testExitPortalFrameIndexWrapsAndStaysInRange() {
        let count = TextureAtlas.exitPortalFrameCount
        XCTAssertGreaterThan(count, 1)
        XCTAssertEqual(TextureAtlas.exitPortalFrame(at: 0), 0)
        XCTAssertEqual(TextureAtlas.exitPortalFrame(at: TextureAtlas.exitPortalPeriod), 0, "loops after one period")
        XCTAssertEqual(TextureAtlas.exitPortalFrame(at: TextureAtlas.exitPortalPeriod - 1e-9), count - 1)
        for t in stride(from: 0.0, through: 100.0, by: 0.013) {
            let index = TextureAtlas.exitPortalFrame(at: t)
            XCTAssertTrue(index >= 0 && index < count, "index \(index) out of range at t=\(t)")
        }
    }

    func testExitPortalUpdatesOnlyWhenTheFrameChanges() {
        let atlas = TextureAtlas()
        XCTAssertTrue(atlas.updateExitPortal(time: 0.0), "first call uploads a frame")
        XCTAssertFalse(atlas.updateExitPortal(time: 0.001), "same sampled frame, no change")
        XCTAssertTrue(atlas.updateExitPortal(time: 1.0 / TextureAtlas.exitPortalFrameRate + 1e-6))
        XCTAssertTrue(atlas.updateExitPortal(time: 0.0), "going back to a cached frame still swaps it in")
    }
}
