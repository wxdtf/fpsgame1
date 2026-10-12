//
//  LineOfSightTests.swift
//  fpsgame1Tests
//
//  A look that clips a wall has to stop there. The old quarter-tile sampler
//  stepped over that clip, so an enemy around the corner woke up and fired.
//

import XCTest
@testable import fpsgame1

final class LineOfSightTests: XCTestCase {

    // The wall at (3, 2) sits on the straight line from (1.2, 3.2) to (4.2, 1.2).
    // Samples every quarter tile miss that cell; the grid walk does not.
    private let cornerClip = [
        "#######",
        "#.....#",
        "#..#..#",
        "#.....#",
        "#######",
    ]

    func testALookThatClipsAWallCornerIsBlocked() {
        let world = TestWorld.make(cornerClip)
        XCTAssertTrue(world.blocksSight(fromX: 1.2, fromY: 3.2, toX: 4.2, toY: 1.2))
        XCTAssertTrue(world.blocksSight(fromX: 4.2, fromY: 1.2, toX: 1.2, toY: 3.2), "the same wall blocks the way back")
    }

    func testAWallOffToTheSideLeavesTheLookClear() {
        let world = TestWorld.make(cornerClip)
        XCTAssertFalse(world.blocksSight(fromX: 1.5, fromY: 1.5, toX: 5.5, toY: 1.5))
    }

    func testAnOpenHallAndANukagePuddleDoNotBlock() {
        let hall = TestWorld.make([
            "#######",
            "#.....#",
            "#######",
        ])
        XCTAssertFalse(hall.blocksSight(fromX: 1.5, fromY: 1.5, toX: 5.5, toY: 1.5))

        let nukage = TestWorld.make([
            "#######",
            "#..~..#",
            "#######",
        ])
        XCTAssertFalse(nukage.blocksSight(fromX: 1.5, fromY: 1.5, toX: 5.5, toY: 1.5))
    }

    func testAClosedDoorBlocksAndAnOpenDoorDoesNot() throws {
        var world = TestWorld.make([
            "#######",
            "#..+..#",
            "#######",
        ])
        XCTAssertTrue(world.blocksSight(fromX: 1.5, fromY: 1.5, toX: 5.5, toY: 1.5))

        let door = try XCTUnwrap(world.doorAt(x: 3, y: 1))
        world.doors[door].openAmount = 0.8
        XCTAssertFalse(world.blocksSight(fromX: 1.5, fromY: 1.5, toX: 5.5, toY: 1.5))
    }

    func testTheCellSomeoneIsStandingInDoesNotHideThem() {
        let world = TestWorld.make(cornerClip)
        XCTAssertFalse(world.blocksSight(fromX: 1.2, fromY: 1.2, toX: 1.8, toY: 1.6), "same cell")

        // The look ends inside the closed door: that cell is where the target is.
        // The same door, one cell further on, is a wall between the two of them.
        let door = TestWorld.make([
            "#####",
            "#.+.#",
            "#####",
        ])
        XCTAssertFalse(door.blocksSight(fromX: 1.5, fromY: 1.5, toX: 2.5, toY: 1.5))
        XCTAssertTrue(door.blocksSight(fromX: 1.5, fromY: 1.5, toX: 3.5, toY: 1.5))
    }

    func testAnEnemyDoesNotWakeUpThroughAWallCorner() {
        let world = TestWorld.make(cornerClip)
        let enemy = enemyAfterOneTick(at: 1.2, 3.2, seeing: 4.2, 1.2, in: world)
        XCTAssertFalse(isChasing(enemy), "the corner of the wall is enough to hide the player")
    }

    func testAnEnemyDoesWakeUpDownAnOpenHall() {
        let world = TestWorld.make([
            "#######",
            "#.....#",
            "#######",
        ])
        let enemy = enemyAfterOneTick(at: 1.5, 1.5, seeing: 5.5, 1.5, in: world)
        XCTAssertTrue(isChasing(enemy))
    }

    func testAnEnemyWakesThroughAnOpenDoorButNotAClosedOne() throws {
        var world = TestWorld.make([
            "#######",
            "#..+..#",
            "#######",
        ])
        XCTAssertFalse(isChasing(enemyAfterOneTick(at: 1.5, 1.5, seeing: 5.5, 1.5, in: world)))

        let door = try XCTUnwrap(world.doorAt(x: 3, y: 1))
        world.doors[door].openAmount = 0.8
        XCTAssertTrue(isChasing(enemyAfterOneTick(at: 1.5, 1.5, seeing: 5.5, 1.5, in: world)))
    }

    private func enemyAfterOneTick(at x: Double, _ y: Double, seeing playerX: Double, _ playerY: Double, in world: GameWorld) -> Enemy {
        var enemy = Enemy(type: .imp, x: x, y: y)
        var nav = NavigationField(width: world.width, height: world.height)
        nav.rebuild(world: world, goalX: Int(playerX), goalY: Int(playerY))
        enemy.update(deltaTime: 1.0 / 60.0, playerX: playerX, playerY: playerY, world: world, nav: nav)
        return enemy
    }

    private func isChasing(_ enemy: Enemy) -> Bool {
        if case .chasing = enemy.state { return true }
        return false
    }
}
