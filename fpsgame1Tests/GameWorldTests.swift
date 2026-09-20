//
//  GameWorldTests.swift
//  fpsgame1Tests
//

import XCTest
@testable import fpsgame1

final class GameWorldTests: XCTestCase {

    func testTileAtOutsideTheMapIsWall() {
        let world = TestWorld.make([
            "###",
            "#.#",
            "###",
        ])
        XCTAssertEqual(world.tileAt(x: 1, y: 1), .empty)
        XCTAssertEqual(world.tileAt(x: -1, y: 1), .brickWall)
        XCTAssertEqual(world.tileAt(x: 3, y: 1), .brickWall)
        XCTAssertEqual(world.tileAt(x: 1, y: -1), .brickWall)
        XCTAssertEqual(world.tileAt(x: 1, y: 3), .brickWall)
    }

    func testDoorsAreSolidUntilMostlyOpen() {
        var world = TestWorld.make([
            "#####",
            "#.+.#",
            "#####",
        ])
        let idx = try! XCTUnwrap(world.doorAt(x: 2, y: 1))
        XCTAssertTrue(world.isSolid(x: 2, y: 1), "a closed door blocks movement")

        world.doors[idx].openAmount = 0.5
        XCTAssertTrue(world.isSolid(x: 2, y: 1), "a half-open door still blocks")

        world.doors[idx].openAmount = 0.8
        XCTAssertFalse(world.isSolid(x: 2, y: 1), "an 80% open door lets things through")
    }

    func testDamageFloorAndPortalSolidity() {
        let world = TestWorld.make([
            "#####",
            "#~X.#",
            "#####",
        ])
        XCTAssertFalse(world.isSolid(x: 1, y: 1), "nukage is walkable")
        XCTAssertTrue(world.isSolid(x: 2, y: 1), "the exit portal is a wall you interact with")
    }

    /// isPassable was unrolled for speed; it must still agree with the original
    /// four-corner definition everywhere, including on tile boundaries.
    func testIsPassableMatchesFourCornerReference() {
        var world = TestWorld.make([
            "########",
            "#..#...#",
            "#..+...#",
            "#..#.~.#",
            "#......#",
            "########",
        ])
        let doorIdx = try! XCTUnwrap(world.doorAt(x: 3, y: 2))

        func reference(_ x: Double, _ y: Double, _ r: Double) -> Bool {
            let corners = [(x - r, y - r), (x + r, y - r), (x - r, y + r), (x + r, y + r)]
            for (cx, cy) in corners where world.isSolid(x: Int(cx), y: Int(cy)) {
                return false
            }
            return true
        }

        var rng = SystemRandomNumberGenerator()
        for openAmount in [0.0, 0.85] {
            world.doors[doorIdx].openAmount = openAmount
            for _ in 0..<2000 {
                let x = Double.random(in: 0.3..<7.7, using: &rng)
                let y = Double.random(in: 0.3..<5.7, using: &rng)
                let r = Double.random(in: 0.05...0.3, using: &rng)
                XCTAssertEqual(world.isPassable(x: x, y: y, radius: r), reference(x, y, r),
                               "mismatch at (\(x), \(y)) r=\(r) door=\(openAmount)")
            }
            // Exact tile boundaries
            for tx in 1...6 {
                for ty in 1...4 {
                    let x = Double(tx), y = Double(ty)
                    XCTAssertEqual(world.isPassable(x: x, y: y, radius: 0.25), reference(x, y, 0.25))
                    XCTAssertEqual(world.isPassable(x: x + 0.5, y: y + 0.5, radius: 0.25),
                                   reference(x + 0.5, y + 0.5, 0.25))
                }
            }
        }
    }

    // MARK: - Shipped level data

    func testEveryLevelLoadsWithEntitiesOnWalkableTiles() {
        for level in 1...GameWorld.maxLevel {
            let data = GameWorld.levelData(for: level)
            let world = GameWorld.createLevel(level)

            XCTAssertEqual(world.width, data.layout[0].count)
            XCTAssertEqual(world.height, data.layout.count)
            for row in data.layout {
                XCTAssertEqual(row.count, world.width, "level \(level) layout is not rectangular")
            }

            let startTile = world.tileAt(x: Int(data.playerStartX), y: Int(data.playerStartY))
            XCTAssertFalse(startTile.isWall || startTile.isDoor, "level \(level) start is inside a wall")

            for (type, x, y) in data.enemies {
                let tile = world.tileAt(x: Int(x), y: Int(y))
                XCTAssertFalse(tile.isWall || tile.isDoor, "level \(level) \(type) at (\(x), \(y)) is inside a wall")
            }
            for (type, x, y) in data.items {
                let tile = world.tileAt(x: Int(x), y: Int(y))
                XCTAssertFalse(tile.isWall || tile.isDoor, "level \(level) item \(type) at (\(x), \(y)) is inside a wall")
            }

            let hasExit = world.tiles1D.contains(.exitPortal)
            XCTAssertTrue(hasExit, "level \(level) has no exit portal")

            let doorTiles = world.tiles1D.filter { $0.isDoor }.count
            XCTAssertEqual(doorTiles, world.doors.count, "level \(level) door index out of sync")
            for (i, door) in world.doors.enumerated() {
                XCTAssertEqual(world.doorAt(x: door.tileX, y: door.tileY), i)
            }
        }
    }

    func testObjectiveTargetsExistInEachLevel() {
        for level in 1...GameWorld.maxLevel {
            let data = GameWorld.levelData(for: level)
            switch data.objective {
            case .retrieveIntel:
                XCTAssertTrue(data.items.contains { if case .intelData = $0.0 { return true } else { return false } },
                              "level \(level) asks for intel that is not placed")
            case .retrieveArtifact:
                XCTAssertTrue(data.items.contains { if case .demonicArtifact = $0.0 { return true } else { return false } },
                              "level \(level) asks for an artifact that is not placed")
            case .exterminate(let type):
                XCTAssertTrue(data.enemies.contains { $0.0 == type },
                              "level \(level) asks to exterminate \(type) but spawns none")
            case .exterminateAll:
                XCTAssertFalse(data.enemies.isEmpty, "level \(level) has nothing to exterminate")
            case .reachExit:
                break
            }
        }
    }

    func testBriefingExistsForEveryLevel() {
        for level in 1...GameWorld.maxLevel {
            let briefing = GameWorld.briefingText(for: level)
            XCTAssertFalse(briefing.title.isEmpty)
            XCTAssertFalse(briefing.lines.isEmpty)
        }
    }
}
