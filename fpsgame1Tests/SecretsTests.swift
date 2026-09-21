//
//  SecretsTests.swift
//  fpsgame1Tests
//
//  Secret doors, secret areas, the items-collected tally and per-level par times.
//

import XCTest
@testable import fpsgame1

final class SecretsTests: XCTestCase {

    func testSecretDoorsBehaveLikeDoorsButLookLikeWalls() {
        for tile in [TileType.secretBrick, .secretMetal, .secretTech] {
            XCTAssertTrue(tile.isDoor)
            XCTAssertTrue(tile.isSecretDoor)
            XCTAssertFalse(tile.isWall)
        }
        XCTAssertEqual(TileType.secretBrick.textureIndex, TileType.brickWall.textureIndex)
        XCTAssertEqual(TileType.secretMetal.textureIndex, TileType.metalWall.textureIndex)
        XCTAssertEqual(TileType.secretTech.textureIndex, TileType.techWall.textureIndex)
        XCTAssertFalse(TileType.door.isSecretDoor)
    }

    func testEveryLevelHasSecretsBehindSecretDoorsAndAParTime() {
        for level in 1...GameWorld.maxLevel {
            let data = GameWorld.levelData(for: level)
            let world = GameWorld.createLevel(level)
            XCTAssertGreaterThan(data.parTime, 0, "level \(level) has no par time")
            XCTAssertFalse(data.secrets.isEmpty, "level \(level) has no secrets")
            let secretDoors = world.tiles1D.filter { $0.isSecretDoor }.count
            XCTAssertGreaterThanOrEqual(secretDoors, data.secrets.count, "level \(level) has more secrets than secret doors")
            for (x, y) in data.secrets {
                let tile = world.tileAt(x: x, y: y)
                XCTAssertFalse(tile.isWall || tile.isDoor, "level \(level) secret trigger (\(x), \(y)) is not open floor")
                // Every trigger tile sits next to a secret door
                let neighbours = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                XCTAssertTrue(neighbours.contains { world.tileAt(x: $0.0, y: $0.1).isSecretDoor },
                              "level \(level) secret trigger (\(x), \(y)) is not behind a secret door")
            }
            // Secret doors are registered as doors so they animate and block until opened
            for (i, door) in world.doors.enumerated() where world.tileAt(x: door.tileX, y: door.tileY).isSecretDoor {
                XCTAssertEqual(world.doorAt(x: door.tileX, y: door.tileY), i)
                XCTAssertTrue(world.isSolid(x: door.tileX, y: door.tileY), "a closed secret door must block")
            }
        }
    }

    func testEnemiesCannotPathThroughClosedSecretDoors() {
        var world = GameWorld.createLevel(1)
        guard let doorIndex = world.doors.firstIndex(where: { world.tileAt(x: $0.tileX, y: $0.tileY).isSecretDoor }) else {
            return XCTFail("level 1 has no secret door")
        }
        let door = world.doors[doorIndex]
        XCTAssertFalse(NavigationField.isTraversable(world: world, x: door.tileX, y: door.tileY))
        world.doors[doorIndex].openAmount = 1.0
        XCTAssertTrue(NavigationField.isTraversable(world: world, x: door.tileX, y: door.tileY))
    }

    func testSteppingIntoASecretCountsItOnce() {
        let engine = GameEngine()
        engine.state = .playing
        let (sx, sy) = GameWorld.levelData(for: 1).secrets[0]
        XCTAssertEqual(engine.secretsFound.count, 0)
        engine.player.x = Double(sx) + 0.5
        engine.player.y = Double(sy) + 0.5
        engine.update(deltaTime: 1.0 / 60.0, input: InputManager.InputState())
        XCTAssertEqual(engine.secretsFound.count, 1)
        XCTAssertTrue(engine.secretFoundThisFrame)
        XCTAssertEqual(engine.statusMessage, "A SECRET IS REVEALED!")
        engine.update(deltaTime: 1.0 / 60.0, input: InputManager.InputState())
        XCTAssertEqual(engine.secretsFound.count, 1, "the same secret is not found twice")
        XCTAssertFalse(engine.secretFoundThisFrame)
        XCTAssertEqual(engine.totalSecrets, GameWorld.levelData(for: 1).secrets.count)
    }

    func testItemsCollectedIgnoresEnemyDrops() {
        let engine = GameEngine()
        let placed = engine.items.count
        XCTAssertEqual(engine.placedItemCount, placed)
        XCTAssertEqual(engine.itemsCollected, 0)
        engine.items[0].isCollected = true
        engine.items.append(Item(type: .healthPack(amount: 10), x: 1, y: 1))
        engine.items[placed].isCollected = true
        XCTAssertEqual(engine.itemsCollected, 1, "a collected enemy drop does not count")
        engine.restartLevel()
        XCTAssertEqual(engine.itemsCollected, 0)
        XCTAssertEqual(engine.placedItemCount, placed)
    }

    func testLevelResultPercentages() {
        var result = LevelResult(level: 1, title: "E1M1", kills: 3, totalEnemies: 4, time: 100)
        XCTAssertEqual(result.killPercent, 75)
        XCTAssertEqual(result.itemPercent, 100, "a level with no items counts as fully collected")
        result.itemsCollected = 1
        result.totalItems = 3
        XCTAssertEqual(result.itemPercent, 33)
        XCTAssertEqual(result.parTime, 120)
    }

    func testParTimesGrowWithTheLevels() {
        var last = 0.0
        for level in 1...GameWorld.maxLevel {
            let par = GameWorld.levelData(for: level).parTime
            XCTAssertGreaterThan(par, last, "level \(level) par is not longer than the previous one")
            last = par
        }
        // The rating honours the level's par, not a flat two minutes
        let fast = performanceRating(kills: 10, totalEnemies: 10, time: 200, parTime: 240)
        let slow = performanceRating(kills: 10, totalEnemies: 10, time: 200, parTime: 120)
        XCTAssertNotEqual(fast, slow)
    }
}
