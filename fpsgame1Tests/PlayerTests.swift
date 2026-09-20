//
//  PlayerTests.swift
//  fpsgame1Tests
//

import XCTest
@testable import fpsgame1

final class PlayerTests: XCTestCase {

    func testCameraVectorsFollowTheAngle() {
        var player = Player(x: 2, y: 2, angle: 0)
        let planeScale = tan(GameConstants.fov / 2)

        for angle in stride(from: -1.0, through: 7.0, by: 0.37) {
            player.angle = angle
            XCTAssertEqual(player.dirX, cos(angle), accuracy: 1e-12)
            XCTAssertEqual(player.dirY, sin(angle), accuracy: 1e-12)
            XCTAssertEqual(player.planeX, -sin(angle) * planeScale, accuracy: 1e-12)
            XCTAssertEqual(player.planeY, cos(angle) * planeScale, accuracy: 1e-12)
        }
    }

    func testInitialCameraVectorsAreSetWithoutRotating() {
        let player = Player(x: 0, y: 0, angle: .pi / 2)
        XCTAssertEqual(player.dirX, 0, accuracy: 1e-12)
        XCTAssertEqual(player.dirY, 1, accuracy: 1e-12)
    }

    func testRotateWrapsInto0To2Pi() {
        var player = Player(x: 0, y: 0, angle: 0.1)
        player.rotate(by: -0.2)
        XCTAssertGreaterThanOrEqual(player.angle, 0)
        XCTAssertLessThan(player.angle, 2 * .pi)
        XCTAssertEqual(player.angle, 2 * .pi - 0.1, accuracy: 1e-12)

        player.rotate(by: 0.2)
        XCTAssertEqual(player.angle, 0.1, accuracy: 1e-12)
        XCTAssertEqual(player.dirX, cos(0.1), accuracy: 1e-12)
    }

    func testArmorAbsorbsHalfTheDamage() {
        var player = Player(x: 0, y: 0, angle: 0)
        player.armor = 50
        player.takeDamage(40)
        XCTAssertEqual(player.armor, 30)
        XCTAssertEqual(player.health, 80)

        player.armor = 5
        player.takeDamage(40)
        XCTAssertEqual(player.armor, 0, "armor absorbs at most what it has")
        XCTAssertEqual(player.health, 45)

        player.takeDamage(1000)
        XCTAssertEqual(player.health, 0, "health never goes negative")
        XCTAssertTrue(player.isDead)
    }

    func testHealAndArmorAreCapped() {
        var player = Player(x: 0, y: 0, angle: 0)
        player.health = 90
        player.heal(50)
        XCTAssertEqual(player.health, GameConstants.maxHealth)
        player.addArmor(500)
        XCTAssertEqual(player.armor, GameConstants.maxArmor)
    }

    func testMovementSlidesAlongWalls() {
        let world = TestWorld.make([
            "#####",
            "#...#",
            "#...#",
            "#####",
        ])
        var player = Player(x: 1.5, y: 1.5, angle: 0)  // facing +x
        // Walk into the wall at x = 4 for a long time: must stop before it, never inside it
        for _ in 0..<120 {
            player.move(forward: 1, strafe: 0, deltaTime: 1.0 / 60.0, world: world)
        }
        XCTAssertLessThan(player.x, 4.0 - GameConstants.playerRadius + 1e-9)
        XCTAssertTrue(world.isPassable(x: player.x, y: player.y, radius: GameConstants.playerRadius))
        XCTAssertEqual(player.y, 1.5, accuracy: 1e-9, "no sideways drift")
    }

    func testApplyCharacterSetsLoadout() {
        var player = Player(x: 0, y: 0, angle: 0)
        for character in PlayerCharacter.all {
            player.applyCharacter(character)
            XCTAssertEqual(player.currentWeapon, character.startingWeapon)
            XCTAssertTrue(player.weapons.contains(.fist))
            XCTAssertTrue(player.weapons.contains(.pistol))
            XCTAssertTrue(player.weapons.contains(character.startingWeapon))
            XCTAssertEqual(player.armor, min(GameConstants.maxArmor, character.startingArmor))
            XCTAssertEqual(player.moveSpeedMultiplier, character.moveSpeedMultiplier)
        }
    }
}
