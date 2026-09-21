//
//  WeaponItemSpriteTests.swift
//  fpsgame1Tests
//
//  The baked first-person weapon and pickup sheets match what the engine indexes.
//

import XCTest
@testable import fpsgame1

final class WeaponItemSpriteTests: XCTestCase {

    func testWeaponSheetsHaveOneFrameForEveryAnimationFrame() {
        let assets = SpriteAssets.shared
        for type in WeaponType.allCases {
            let sheet = assets.weaponSprites(for: type)
            let def = WeaponDefinition.forType(type)
            XCTAssertEqual(sheet.frameCount, def.animationFrames,
                           "\(type) sheet must have exactly animationFrames frames (frame 0 idle)")
            XCTAssertEqual(sheet.width * 5, sheet.height * 8, "\(type) sheet is not 1.6:1 like the on-screen overlay")
            for (i, frame) in sheet.frames.enumerated() {
                XCTAssertEqual(frame.count, sheet.width * sheet.height)
                let opaque = frame.filter { ($0 >> 24) != 0 }.count
                XCTAssertGreaterThan(opaque, frame.count / 10, "\(type) frame \(i) is nearly empty")
                XCTAssertLessThan(opaque, frame.count, "\(type) frame \(i) has no transparency")
            }
        }
    }

    func testWeaponsSitAtTheBottomOfTheOverlay() {
        // The hands/sleeves run off the bottom edge, so the bottom row is never empty
        let assets = SpriteAssets.shared
        for type in WeaponType.allCases {
            let sheet = assets.weaponSprites(for: type)
            let bottom = (sheet.height - 1) * sheet.width
            let opaqueBottom = (0..<sheet.width).filter { (sheet.frames[0][bottom + $0] >> 24) != 0 }.count
            XCTAssertGreaterThan(opaqueBottom, 0, "\(type) idle frame floats above the bottom edge")
        }
    }

    func testItemSheetCoversEverySpriteIndex() {
        let sheet = SpriteAssets.shared.itemSprites
        let types: [ItemType] = [
            .healthPack(amount: 10), .armorVest(amount: 10), .ammoBullets(amount: 10), .ammoShells(amount: 4),
            .shotgunPickup, .chaingunPickup, .keyCard(color: .red), .keyCard(color: .blue), .keyCard(color: .yellow),
            .berserkPack, .intelData, .demonicArtifact, .rocketLauncherPickup, .ammoRockets(amount: 2),
        ]
        var seen = Set<Int>()
        for type in types {
            let index = Item(type: type, x: 0, y: 0).spriteIndex
            XCTAssertLessThan(index, sheet.frameCount, "\(type) indexes past the item sheet")
            seen.insert(index)
        }
        XCTAssertEqual(seen.count, types.count, "two item types share a sprite index")
        XCTAssertEqual(sheet.frameCount, types.count, "item sheet has frames nothing uses")
        XCTAssertEqual(sheet.width, sheet.height, "pickups are square")
        for (i, frame) in sheet.frames.enumerated() {
            let opaque = frame.filter { ($0 >> 24) != 0 }.count
            XCTAssertGreaterThan(opaque, frame.count / 8, "item \(i) is nearly empty")
            XCTAssertLessThan(opaque, frame.count, "item \(i) has no transparency")
        }
    }

    func testKeycardsAreTheirOwnColour() {
        let sheet = SpriteAssets.shared.itemSprites
        func dominant(_ frame: [UInt32]) -> (r: Int, g: Int, b: Int) {
            var r = 0, g = 0, b = 0, n = 0
            for p in frame where (p >> 24) != 0 {
                r += Int((p >> 16) & 0xFF); g += Int((p >> 8) & 0xFF); b += Int(p & 0xFF); n += 1
            }
            return (r / max(1, n), g / max(1, n), b / max(1, n))
        }
        let red = dominant(sheet.frames[Item(type: .keyCard(color: .red), x: 0, y: 0).spriteIndex])
        let blue = dominant(sheet.frames[Item(type: .keyCard(color: .blue), x: 0, y: 0).spriteIndex])
        let yellow = dominant(sheet.frames[Item(type: .keyCard(color: .yellow), x: 0, y: 0).spriteIndex])
        XCTAssertGreaterThan(red.r, red.b)
        XCTAssertGreaterThan(blue.b, blue.r)
        XCTAssertGreaterThan(yellow.r + yellow.g, 2 * yellow.b)
    }

    func testExitPortalAnimationLoopsAndStaysInsideTheFrame() {
        let atlas = TextureAtlas()
        let a = atlas.exitPortalFramePixels(0)
        let b = atlas.exitPortalFramePixels(TextureAtlas.exitPortalFrameCount / 2)
        XCTAssertEqual(a.count, GameConstants.textureSize * GameConstants.textureSize)
        XCTAssertNotEqual(a, b, "the portal animates")
        // every texel is opaque (it is a wall texture)
        XCTAssertTrue(a.allSatisfy { ($0 >> 24) == 0xFF })
        // the frame rows are dark iron, the EXIT lettering over the vortex is bright
        // (top-left texel of the "E", see the letter layout in tools/sprite_art/portal.py)
        let size = GameConstants.textureSize
        let corner = a[0]
        let letter = a[(size / 2 - 3) * size + size / 2 - 9]
        XCTAssertLessThan(Int((corner >> 8) & 0xFF), 90)
        XCTAssertGreaterThan(Int((letter >> 8) & 0xFF), 150)
        // and the vortex as a whole glows green: mean green over the inner disc beats the frame
        var vortexGreen = 0, vortexCount = 0
        for y in 8..<(size - 8) {
            for x in 8..<(size - 8) {
                vortexGreen += Int((a[y * size + x] >> 8) & 0xFF); vortexCount += 1
            }
        }
        XCTAssertGreaterThan(vortexGreen / vortexCount, 60)
    }
}
