//
//  LevelValidationTests.swift
//  fpsgame1Tests
//
//  The playability checks from tools/validate_levels.py, run against the shipped
//  levels through the real GameWorld: an enclosed border, key-gated reachability
//  of the exit, the objective and every entity, keys that actually gate something,
//  no sealed-off floor, doors set into walls, and nukage that is never the only
//  way through. The Python script stays for the quick Ubuntu CI job and its ASCII
//  maps; this is the copy that runs with ⌘U.
//

import XCTest
@testable import fpsgame1

/// Flood-fill analysis of one level honouring key cards
struct LevelAnalysis {
    let data: GameWorld.LevelData
    let world: GameWorld
    let level: Int

    init(level: Int) {
        self.level = level
        data = GameWorld.levelData(for: level)
        world = GameWorld.createLevel(level)
    }

    var startTile: (Int, Int) { (Int(data.playerStartX), Int(data.playerStartY)) }

    static func lockedColour(_ tile: TileType) -> KeyColor? {
        switch tile {
        case .lockedDoorRed: return .red
        case .lockedDoorBlue: return .blue
        case .lockedDoorYellow: return .yellow
        default: return nil
        }
    }

    /// Whether a tile can be crossed on foot with the given keys (doors count as open,
    /// secret doors too: the player can always use them)
    func passable(_ tile: TileType, keys: Set<KeyColor>, throughNukage: Bool = true) -> Bool {
        if tile.isWall { return false }
        if tile == .damageFloor { return throughNukage }
        if let colour = Self.lockedColour(tile) { return keys.contains(colour) }
        return true
    }

    func key(_ x: Int, _ y: Int) -> Int { y * world.width + x }

    /// Tiles reachable from `start`
    func flood(from start: (Int, Int), keys: Set<KeyColor>, throughNukage: Bool = true) -> Set<Int> {
        var seen: Set<Int> = [key(start.0, start.1)]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let (x, y) = queue[head]
            head += 1
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                guard nx >= 0, nx < world.width, ny >= 0, ny < world.height else { continue }
                let k = key(nx, ny)
                guard !seen.contains(k) else { continue }
                if passable(world.tileAt(x: nx, y: ny), keys: keys, throughNukage: throughNukage) {
                    seen.insert(k)
                    queue.append((nx, ny))
                }
            }
        }
        return seen
    }

    /// Expand reachability as key cards come within reach; returns the final set and
    /// the keys collected in the order their doors opened up
    func reachableWithKeys() -> (reach: Set<Int>, keys: Set<KeyColor>, passes: [[KeyColor]]) {
        var keys: Set<KeyColor> = []
        var passes: [[KeyColor]] = []
        while true {
            let reach = flood(from: startTile, keys: keys)
            var found: [KeyColor] = []
            for (type, x, y) in data.items {
                if case .keyCard(let colour) = type, !keys.contains(colour), reach.contains(key(Int(x), Int(y))) {
                    found.append(colour)
                }
            }
            if found.isEmpty { return (reach, keys, passes) }
            passes.append(found)
            keys.formUnion(found)
        }
    }

    var lockedColoursPresent: Set<KeyColor> {
        Set(world.tiles1D.compactMap(Self.lockedColour))
    }

    var exits: [(Int, Int)] {
        var out: [(Int, Int)] = []
        for y in 0..<world.height {
            for x in 0..<world.width where world.tileAt(x: x, y: y) == .exitPortal {
                out.append((x, y))
            }
        }
        return out
    }

    /// The exit is a wall tile the player uses from an adjacent floor tile
    func exitUsable(_ exit: (Int, Int), from reach: Set<Int>) -> Bool {
        let (x, y) = exit
        return [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)].contains { reach.contains(key($0.0, $0.1)) }
    }

    /// Tiles the objective needs the player to reach
    var objectiveTargets: [(String, Int, Int)] {
        switch data.objective {
        case .retrieveIntel:
            return data.items.compactMap { if case .intelData = $0.0 { return ("intel", Int($0.1), Int($0.2)) } else { return nil } }
        case .retrieveArtifact:
            return data.items.compactMap { if case .demonicArtifact = $0.0 { return ("artifact", Int($0.1), Int($0.2)) } else { return nil } }
        case .exterminate(let type):
            return data.enemies.filter { $0.0 == type }.map { ("\($0.0)", Int($0.1), Int($0.2)) }
        case .exterminateAll:
            return data.enemies.map { ("\($0.0)", Int($0.1), Int($0.2)) }
        case .reachExit:
            return []
        }
    }
}

final class LevelValidationTests: XCTestCase {

    private var levels: [LevelAnalysis] { (1...GameWorld.maxLevel).map(LevelAnalysis.init) }

    func testEveryLevelIsEnclosedByWalls() {
        for a in levels {
            for x in 0..<a.world.width {
                XCTAssertTrue(a.world.tileAt(x: x, y: 0).isWall, "level \(a.level) top border open at x=\(x)")
                XCTAssertTrue(a.world.tileAt(x: x, y: a.world.height - 1).isWall, "level \(a.level) bottom border open at x=\(x)")
            }
            for y in 0..<a.world.height {
                XCTAssertTrue(a.world.tileAt(x: 0, y: y).isWall, "level \(a.level) left border open at y=\(y)")
                XCTAssertTrue(a.world.tileAt(x: a.world.width - 1, y: y).isWall, "level \(a.level) right border open at y=\(y)")
            }
        }
    }

    func testExitObjectiveAndEveryEntityAreReachableWithTheKeysOnTheWay() {
        for a in levels {
            let (reach, keys, passes) = a.reachableWithKeys()
            XCTAssertFalse(a.exits.isEmpty, "level \(a.level) has no exit portal")
            for exit in a.exits {
                XCTAssertTrue(a.exitUsable(exit, from: reach), "level \(a.level) exit at \(exit) is unreachable")
            }
            XCTAssertFalse(a.objectiveTargets.isEmpty, "level \(a.level) objective has nothing to target")
            for (name, x, y) in a.objectiveTargets {
                XCTAssertTrue(reach.contains(a.key(x, y)), "level \(a.level) objective target \(name) at (\(x), \(y)) is unreachable")
            }
            for (type, x, y) in a.data.enemies {
                XCTAssertTrue(reach.contains(a.key(Int(x), Int(y))), "level \(a.level) \(type) at (\(x), \(y)) is unreachable")
            }
            for (type, x, y) in a.data.items {
                XCTAssertTrue(reach.contains(a.key(Int(x), Int(y))), "level \(a.level) item \(type) at (\(x), \(y)) is unreachable")
            }
            // Every locked colour present has a key the player can get to
            for colour in a.lockedColoursPresent {
                XCTAssertTrue(keys.contains(colour), "level \(a.level) has \(colour) doors but no reachable \(colour) key")
            }
            // Keys come one colour at a time in the shipped levels (red, then blue, then yellow)
            XCTAssertEqual(passes.flatMap { $0 }.count, keys.count, "level \(a.level) found a key twice")
        }
    }

    func testEveryKeyCardHasADoorAndEveryColourGatesTheExit() {
        for a in levels {
            let present = a.lockedColoursPresent
            for (type, x, y) in a.data.items {
                if case .keyCard(let colour) = type {
                    XCTAssertTrue(present.contains(colour), "level \(a.level) \(colour) key at (\(x), \(y)) opens nothing")
                }
            }
            // Seal one colour with every other key in hand: the exit must be behind it
            for colour in present {
                let sealed = a.flood(from: a.startTile, keys: Set([KeyColor.red, .blue, .yellow]).subtracting([colour]))
                let exitOpen = a.exits.allSatisfy { a.exitUsable($0, from: sealed) }
                XCTAssertFalse(exitOpen, "level \(a.level) \(colour) key is never required: the exit is reachable with every \(colour) door sealed")
            }
        }
    }

    func testNoFloorIsSealedOffEvenWithEveryKey() {
        for a in levels {
            let reach = a.flood(from: a.startTile, keys: [.red, .blue, .yellow])
            var dead: [(Int, Int)] = []
            for y in 0..<a.world.height {
                for x in 0..<a.world.width {
                    let tile = a.world.tileAt(x: x, y: y)
                    if !tile.isWall && !reach.contains(a.key(x, y)) { dead.append((x, y)) }
                }
            }
            XCTAssertTrue(dead.isEmpty, "level \(a.level) has \(dead.count) walkable tiles sealed off, e.g. \(dead.prefix(4))")
        }
    }

    func testDoorsAreSetIntoWalls() {
        for a in levels {
            for y in 0..<a.world.height {
                for x in 0..<a.world.width {
                    let tile = a.world.tileAt(x: x, y: y)
                    guard tile.isDoor, !tile.isSecretDoor else { continue }
                    let horizontal = a.world.tileAt(x: x - 1, y: y).isWall && a.world.tileAt(x: x + 1, y: y).isWall
                    let vertical = a.world.tileAt(x: x, y: y - 1).isWall && a.world.tileAt(x: x, y: y + 1).isWall
                    XCTAssertTrue(horizontal || vertical, "level \(a.level) door at (\(x), \(y)) is not flanked by walls")
                    XCTAssertFalse(horizontal && vertical, "level \(a.level) door at (\(x), \(y)) is walled in on all sides")
                }
            }
        }
    }

    func testSecretDoorsMatchTheWallTheySitIn() {
        for a in levels {
            for y in 0..<a.world.height {
                for x in 0..<a.world.width {
                    let tile = a.world.tileAt(x: x, y: y)
                    guard tile.isSecretDoor else { continue }
                    let neighbours = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)].map { a.world.tileAt(x: $0.0, y: $0.1) }
                    XCTAssertTrue(neighbours.contains { $0.textureIndex == tile.textureIndex && $0.isWall },
                                  "level \(a.level) secret door at (\(x), \(y)) does not match a neighbouring wall")
                }
            }
        }
    }

    func testNukageIsNeverTheOnlyWayToTheExit() {
        for a in levels where a.world.tiles1D.contains(.damageFloor) {
            let dry = a.flood(from: a.startTile, keys: [.red, .blue, .yellow], throughNukage: false)
            for exit in a.exits {
                XCTAssertTrue(a.exitUsable(exit, from: dry), "level \(a.level) exit at \(exit) can only be reached through nukage")
            }
        }
    }

    func testStartAndEntitiesStandOnOpenFloor() {
        for a in levels {
            let (sx, sy) = (a.data.playerStartX, a.data.playerStartY)
            for (cx, cy) in [(sx - 0.25, sy - 0.25), (sx + 0.25, sy - 0.25), (sx - 0.25, sy + 0.25), (sx + 0.25, sy + 0.25)] {
                let tile = a.world.tileAt(x: Int(cx), y: Int(cy))
                XCTAssertFalse(tile.isWall || tile.isDoor, "level \(a.level) start overlaps (\(Int(cx)), \(Int(cy)))")
            }
            var positions: [String: Int] = [:]
            for (type, x, y) in a.data.enemies {
                XCTAssertFalse(a.world.tileAt(x: Int(x), y: Int(y)).isDoor, "level \(a.level) \(type) stands in a door")
                positions["\(x),\(y)", default: 0] += 1
            }
            for (type, x, y) in a.data.items {
                XCTAssertFalse(a.world.tileAt(x: Int(x), y: Int(y)).isDoor, "level \(a.level) item \(type) sits in a door")
                positions["\(x),\(y)", default: 0] += 1
            }
            for (pos, count) in positions where count > 1 {
                XCTFail("level \(a.level) has \(count) entities stacked at \(pos)")
            }
        }
    }

    // The analysis itself, on a hand-drawn map
    func testAnalysisHonoursLockedDoorsAndKeys() {
        // The red key card lies at (2, 1); the red door at (4, 1) seals off (5, 1)
        let rows = ["#######",
                    "#...R.#",
                    "###.###",
                    "#..X..#",
                    "#######"]
        let world = TestWorld.make(rows)
        let analysis = LevelAnalysis(world: world, level: 0, start: (1, 1), items: [(.keyCard(color: .red), 2.5, 1.5)])
        let without = analysis.flood(from: (1, 1), keys: [])
        XCTAssertFalse(without.contains(analysis.key(5, 1)), "red door blocks without the key")
        let (reach, keys, passes) = analysis.reachableWithKeys()
        XCTAssertEqual(keys, [.red])
        XCTAssertEqual(passes, [[.red]])
        XCTAssertTrue(reach.contains(analysis.key(5, 1)))
        XCTAssertTrue(analysis.exitUsable((3, 3), from: reach))
    }
}

extension LevelAnalysis {
    /// Analysis over a hand-drawn world (tests of the analysis itself)
    init(world: GameWorld, level: Int, start: (Int, Int), items: [(ItemType, Double, Double)],
         enemies: [(EnemyType, Double, Double)] = [], objective: MissionObjective = .reachExit) {
        self.world = world
        self.level = level
        self.data = GameWorld.LevelData(layout: [], playerStartX: Double(start.0) + 0.5, playerStartY: Double(start.1) + 0.5,
                                        playerStartAngle: 0, enemies: enemies, items: items, objective: objective,
                                        parTime: 60, secrets: [])
    }
}
