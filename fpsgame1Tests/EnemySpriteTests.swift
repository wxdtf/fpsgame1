//
//  EnemySpriteTests.swift
//  fpsgame1Tests
//
//  The baked enemy sprite sheets (tools/enemy_art) decode into complete frames.
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

    func testEveryEnemySheetDecodesTenFullFrames() {
        for (name, baked) in sheets {
            let sheet = baked.decode()
            XCTAssertEqual(sheet.frameCount, 10, "\(name) needs idle, 3 walk, 2 attack, hurt, recoil, falling, corpse")
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
        // Frames 0-6 stand; the lowest opaque row must sit within a few pixels of the sheet bottom
        for (name, baked) in sheets {
            let sheet = baked.decode()
            for i in 0...6 {
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

    func testSpriteAssetsUseTheBakedSheets() {
        let assets = SpriteAssets.shared
        XCTAssertEqual(assets.impSprites.width, EnemySpriteData.imp.width)
        XCTAssertEqual(assets.demonSprites.height, EnemySpriteData.demon.height)
        XCTAssertEqual(assets.soldierSprites.frameCount, 10)
        XCTAssertEqual(assets.baronSprites.width, EnemySpriteData.baron.width)
    }
}
