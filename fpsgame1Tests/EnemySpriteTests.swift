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

    private let expectedFrames = Enemy.frontFrameCount + 4 * Enemy.rotatedFrameCount  // 38

    func testEveryEnemySheetDecodesAllFrames() {
        for (name, baked) in sheets {
            let sheet = baked.decode()
            XCTAssertEqual(sheet.frameCount, expectedFrames,
                           "\(name) needs 10 front frames plus 7 frames for each of 4 rotations")
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
