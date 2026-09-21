//
//  EnemySpriteTests.swift
//  fpsgame1Tests
//
//  The baked enemy sprite sheets (tools/sprite_art) decode into complete frames.
//

import XCTest
@testable import fpsgame1

final class EnemySpriteTests: XCTestCase {

    private let sheets: [(String, BakedSpriteSheet)] = [
        ("imp", EnemySpriteData.imp),
        ("demon", EnemySpriteData.demon),
        ("soldier", EnemySpriteData.soldier),
        ("baron", EnemySpriteData.baron),
    ]

    private let expectedFrames = Enemy.frontFrameCount + 4 * Enemy.rotatedFrameCount  // 41

    func testEveryEnemySheetDecodesAllFrames() {
        for (name, baked) in sheets {
            let sheet = baked.decode()
            XCTAssertEqual(sheet.frameCount, expectedFrames,
                           "\(name) needs 13 front frames plus 7 frames for each of 4 rotations")
            XCTAssertEqual(sheet.width, baked.width)
            XCTAssertEqual(sheet.height, baked.height)
            for (i, frame) in sheet.frames.enumerated() {
                XCTAssertEqual(frame.count, baked.width * baked.height, "\(name) frame \(i) has the wrong size")
                let opaque = frame.filter { ($0 >> 24) != 0 }.count
                XCTAssertGreaterThan(opaque, baked.width * baked.height / 12, "\(name) frame \(i) is nearly empty")
                XCTAssertLessThan(opaque, baked.width * baked.height, "\(name) frame \(i) has no transparent pixels")
            }
        }
    }

    func testBakedPalettesAreOpaqueAndWithinTheAlphabet() {
        for (name, baked) in sheets {
            XCTAssertLessThanOrEqual(baked.palette.count, BakedSpriteSheet.maxColors, "\(name) palette too large")
            for color in baked.palette {
                XCTAssertEqual(color >> 24, 0xFF, "\(name) palette entry is not opaque")
            }
        }
    }

    func testStandingFramesKeepTheirFeetOnTheFloor() {
        // Standing frames (0-6 in every rotation): the lowest opaque row must sit within a
        // few pixels of the sheet bottom
        for (name, baked) in sheets {
            let sheet = baked.decode()
            let standing = Array(0...6) + Array(Enemy.frontFrameCount..<expectedFrames)
            for i in standing {
                let frame = sheet.frames[i]
                var lowest = -1
                for y in stride(from: sheet.height - 1, through: 0, by: -1) where lowest < 0 {
                    for x in 0..<sheet.width where (frame[y * sheet.width + x] >> 24) != 0 {
                        lowest = y
                        break
                    }
                }
                XCTAssertGreaterThanOrEqual(lowest, sheet.height - 6, "\(name) frame \(i) floats above the floor")
            }
        }
    }

    // MARK: - Rotation selection

    func testEnemyFacingTheViewerShowsTheFront() {
        var enemy = Enemy(type: .imp, x: 5, y: 5)
        enemy.angle = 0  // facing +x
        XCTAssertEqual(enemy.spriteView(viewerX: 10, viewerY: 5), Enemy.SpriteView(rotation: 0, mirrored: false))
        XCTAssertEqual(enemy.spriteView(viewerX: 0, viewerY: 5), Enemy.SpriteView(rotation: 4, mirrored: false))
    }

    func testSideViewsMirrorForTheOtherSide() {
        var enemy = Enemy(type: .soldier, x: 5, y: 5)
        enemy.angle = 0  // facing +x
        // Viewer at +y: the enemy faces screen-right for them, so the authored (screen-left) side is mirrored
        XCTAssertEqual(enemy.spriteView(viewerX: 5, viewerY: 10), Enemy.SpriteView(rotation: 2, mirrored: true))
        XCTAssertEqual(enemy.spriteView(viewerX: 5, viewerY: 0), Enemy.SpriteView(rotation: 2, mirrored: false))
        // Quarter views
        XCTAssertEqual(enemy.spriteView(viewerX: 10, viewerY: 0).rotation, 1)
        XCTAssertEqual(enemy.spriteView(viewerX: 0, viewerY: 0).rotation, 3)
        XCTAssertTrue(enemy.spriteView(viewerX: 0, viewerY: 10).mirrored)
    }

    func testRotationWrapsAroundTheAngleSeam() {
        var enemy = Enemy(type: .demon, x: 0, y: 0)
        enemy.angle = 2 * .pi - 0.01  // just below the seam, still facing +x
        XCTAssertEqual(enemy.spriteView(viewerX: 10, viewerY: 0).rotation, 0)
        enemy.angle = -.pi + 0.01
        XCTAssertEqual(enemy.spriteView(viewerX: 10, viewerY: 0).rotation, 4)
    }

    func testDeathFramesIgnoreRotation() {
        var enemy = Enemy(type: .baron, x: 5, y: 5)
        enemy.angle = 0
        enemy.takeDamage(10_000)
        let frame = enemy.spriteFrame(viewerX: 5, viewerY: 10)
        XCTAssertEqual(frame.index, enemy.spriteFrameOffset)
        XCTAssertFalse(frame.mirrored)
        XCTAssertGreaterThanOrEqual(frame.index, 7)
    }

    func testRotatedFrameIndicesStayInsideTheSheet() {
        var enemy = Enemy(type: .imp, x: 5, y: 5)
        enemy.state = .chasing
        enemy.animationFrame = 3
        for angle in stride(from: 0.0, to: 2 * .pi, by: 0.2) {
            enemy.angle = angle
            let frame = enemy.spriteFrame(viewerX: 9, viewerY: 2)
            XCTAssertLessThan(frame.index, expectedFrames)
            if frame.index >= Enemy.frontFrameCount {
                XCTAssertEqual((frame.index - Enemy.frontFrameCount) % Enemy.rotatedFrameCount, enemy.spriteFrameOffset)
            }
        }
    }

    func testSpriteAssetsUseTheBakedSheets() {
        let assets = SpriteAssets.shared
        XCTAssertEqual(assets.impSprites.width, EnemySpriteData.imp.width)
        XCTAssertEqual(assets.demonSprites.height, EnemySpriteData.demon.height)
        XCTAssertEqual(assets.soldierSprites.frameCount, expectedFrames)
        XCTAssertEqual(assets.baronSprites.width, EnemySpriteData.baron.width)
    }
}

// MARK: - Death animations

final class EnemyDeathTests: XCTestCase {

    private func runOut(_ enemy: inout Enemy, seconds: Double) -> [Int] {
        // Collect the death frame shown on every tick of a 60 Hz simulation
        let world = TestWorld.make(["###", "#.#", "###"])
        var nav = NavigationField(width: 3, height: 3)
        nav.rebuild(world: world, goalX: 1, goalY: 1)
        var shown: [Int] = []
        for _ in 0..<Int(seconds * 60) {
            if let frame = enemy.deathFrame { shown.append(frame) }
            enemy.update(deltaTime: 1.0 / 60.0, playerX: 1.5, playerY: 1.5, world: world, nav: nav)
        }
        return shown
    }

    func testEveryEnemyPlaysAllSixDeathFramesInOrder() {
        for type in [EnemyType.imp, .demon, .soldier, .baron] {
            XCTAssertEqual(type.deathFrameDurations.count, Enemy.deathFrameCount, "\(type) needs a duration per frame")
            var enemy = Enemy(type: type, x: 1.5, y: 1.5)
            enemy.takeDamage(10_000)
            let shown = runOut(&enemy, seconds: type.deathDuration + 0.5)
            var distinct: [Int] = []
            for f in shown where distinct.last != f { distinct.append(f) }
            XCTAssertEqual(distinct, Array(0..<Enemy.deathFrameCount), "\(type) skipped or reordered a death frame")
            XCTAssertTrue(enemy.isDead)
        }
    }

    func testDeathTimingIsPerEnemy() {
        // The Baron takes visibly longer to go down than the imp
        XCTAssertGreaterThan(EnemyType.baron.deathDuration, EnemyType.imp.deathDuration + 0.4)
        for type in [EnemyType.imp, .demon, .soldier, .baron] {
            for d in type.deathFrameDurations {
                XCTAssertGreaterThanOrEqual(d, 1.0 / 30.0, "\(type) has a death frame shorter than two ticks")
            }
        }
    }

    func testDyingSpriteSinksToTheFloorButNeverRises() {
        var enemy = Enemy(type: .demon, x: 1.5, y: 1.5)
        enemy.takeDamage(10_000)
        let world = TestWorld.make(["###", "#.#", "###"])
        var nav = NavigationField(width: 3, height: 3)
        nav.rebuild(world: world, goalX: 1, goalY: 1)
        var last = -1.0
        for _ in 0..<90 {
            let v = enemy.deathVOffset
            XCTAssertGreaterThanOrEqual(v + 1e-9, last, "sprite rose while dying")
            XCTAssertLessThanOrEqual(v, 0.12 + 1e-9)
            last = v
            enemy.update(deltaTime: 1.0 / 60.0, playerX: 1.5, playerY: 1.5, world: world, nav: nav)
        }
        XCTAssertEqual(enemy.deathVOffset, 0.12, accuracy: 1e-9, "corpse rests at the floor offset")
    }

    func testDeathFramesLandOnTheFloorAndUseTheSheet() {
        // The six front-only death frames sit just above the sheet bottom (feet/body on the floor)
        for (name, baked) in [("imp", EnemySpriteData.imp), ("demon", EnemySpriteData.demon),
                              ("soldier", EnemySpriteData.soldier), ("baron", EnemySpriteData.baron)] {
            let sheet = baked.decode()
            for i in Enemy.rotatedFrameCount..<Enemy.frontFrameCount {
                let frame = sheet.frames[i]
                var lowest = -1
                for y in stride(from: sheet.height - 1, through: 0, by: -1) where lowest < 0 {
                    for x in 0..<sheet.width where (frame[y * sheet.width + x] >> 24) != 0 {
                        lowest = y
                        break
                    }
                }
                XCTAssertGreaterThanOrEqual(lowest, sheet.height - 8, "\(name) death frame \(i) floats above the floor")
            }
            // consecutive death frames differ (the animation actually moves)
            for i in Enemy.rotatedFrameCount..<(Enemy.frontFrameCount - 1) {
                XCTAssertNotEqual(sheet.frames[i], sheet.frames[i + 1], "\(name) repeats death frame \(i)")
            }
        }
    }

    func testHitSplashSheetHasRedAndGreenBursts() {
        let sheet = SpriteAssets.shared.hitSplashSprites
        XCTAssertEqual(sheet.frameCount, 8)
        XCTAssertEqual(sheet.width, sheet.height)
        func mean(_ frame: [UInt32]) -> (r: Int, g: Int) {
            var r = 0, g = 0, n = 0
            for p in frame where (p >> 24) != 0 { r += Int((p >> 16) & 0xFF); g += Int((p >> 8) & 0xFF); n += 1 }
            return (r / max(1, n), g / max(1, n))
        }
        for i in 0..<4 {
            let red = mean(sheet.frames[i]), green = mean(sheet.frames[4 + i])
            XCTAssertGreaterThan(red.r, red.g, "red frame \(i) is not red")
            XCTAssertGreaterThan(green.g, green.r, "green frame \(i) is not green")
            let opaque = sheet.frames[i].filter { ($0 >> 24) != 0 }.count
            XCTAssertGreaterThan(opaque, 6, "frame \(i) is empty")
            XCTAssertLessThan(opaque, sheet.width * sheet.height / 2, "frame \(i) fills the tile")
        }
    }
}
