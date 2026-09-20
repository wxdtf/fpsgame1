//
//  NavigationTests.swift
//  fpsgame1Tests
//

import XCTest
@testable import fpsgame1

final class NavigationTests: XCTestCase {

    func testDistanceFieldCountsStepsAroundWalls() {
        let world = TestWorld.make([
            "#######",
            "#.....#",
            "#.###.#",
            "#.#...#",
            "#######",
        ])
        var nav = NavigationField(width: world.width, height: world.height)
        nav.rebuild(world: world, goalX: 1, goalY: 1)

        XCTAssertEqual(nav.distance(x: 1, y: 1), 0)
        XCTAssertEqual(nav.distance(x: 5, y: 1), 4)
        XCTAssertEqual(nav.distance(x: 5, y: 3), 6, "must go around the wall block")
        XCTAssertEqual(nav.distance(x: 3, y: 3), 8)
        XCTAssertEqual(nav.distance(x: 2, y: 2), NavigationField.unreachable, "walls are not reachable")
        XCTAssertEqual(nav.distance(x: -1, y: 0), NavigationField.unreachable, "out of bounds is unreachable")
        XCTAssertEqual(nav.distance(x: 1, y: 3), 2)
    }

    func testNextStepMovesTowardTheGoal() {
        let world = TestWorld.make([
            "#######",
            "#.....#",
            "#.###.#",
            "#.#...#",
            "#######",
        ])
        var nav = NavigationField(width: world.width, height: world.height)
        nav.rebuild(world: world, goalX: 1, goalY: 1)

        // From the far end of the dead-end corridor, follow the field to the goal
        var x = 3, y = 3
        var steps = 0
        while let next = nav.nextStep(fromX: x, fromY: y) {
            XCTAssertEqual(nav.distance(x: next.x, y: next.y), nav.distance(x: x, y: y) - 1,
                           "each step must reduce the distance by exactly one")
            x = next.x; y = next.y
            steps += 1
            XCTAssertLessThan(steps, 50, "walked in circles")
        }
        XCTAssertEqual(x, 1)
        XCTAssertEqual(y, 1)
        XCTAssertEqual(steps, 8)
        XCTAssertNil(nav.nextStep(fromX: 1, fromY: 1), "no step from the goal itself")
        XCTAssertNil(nav.nextStep(fromX: 2, fromY: 2), "no step from inside a wall")
    }

    func testUnlockedDoorsArePassableButLockedDoorsAreNotUntilOpen() {
        var world = TestWorld.make([
            "#######",
            "#.+.R.#",
            "#######",
        ])
        var nav = NavigationField(width: world.width, height: world.height)

        nav.rebuild(world: world, goalX: 1, goalY: 1)
        XCTAssertEqual(nav.distance(x: 3, y: 1), 2, "enemies can path through closed unlocked doors")
        XCTAssertEqual(nav.distance(x: 5, y: 1), NavigationField.unreachable,
                       "a closed locked door blocks the path")

        let redIdx = try! XCTUnwrap(world.doorAt(x: 4, y: 1))
        world.doors[redIdx].openAmount = 1.0
        nav.rebuild(world: world, goalX: 1, goalY: 1)
        XCTAssertEqual(nav.distance(x: 5, y: 1), 4, "an open locked door is traversable")
    }

    func testGoalOutsideTheMapLeavesEverythingUnreachable() {
        let world = TestWorld.make([
            "###",
            "#.#",
            "###",
        ])
        var nav = NavigationField(width: world.width, height: world.height)
        nav.rebuild(world: world, goalX: 10, goalY: 10)
        XCTAssertEqual(nav.distance(x: 1, y: 1), NavigationField.unreachable)
    }
}
