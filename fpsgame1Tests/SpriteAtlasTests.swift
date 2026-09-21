//
//  SpriteAtlasTests.swift
//  fpsgame1Tests
//
//  The packed sprite atlas the GPU compositor samples from, and the screen-effect
//  parameters both renderers share.
//

import XCTest
@testable import fpsgame1

final class SpriteAtlasTests: XCTestCase {

    func testEveryFrameIsPackedAtItsRecordedLocation() {
        let assets = SpriteAssets.shared
        let atlas = SpriteAtlas(assets: assets)

        var expectedTotal = 0
        for id in SpriteSheetID.allCases {
            let sheet = assets.sheet(id)
            XCTAssertEqual(atlas.frameCount(id), sheet.frameCount)
            for (frameIndex, frame) in sheet.frames.enumerated() {
                let loc = atlas.location(id, frame: frameIndex)
                XCTAssertEqual(loc.width, sheet.width)
                XCTAssertEqual(loc.height, sheet.height)
                XCTAssertGreaterThanOrEqual(loc.offset, 0)
                XCTAssertLessThanOrEqual(loc.offset + loc.width * loc.height, atlas.pixelCount)
                // Spot-check a few pixels through the atlas against the source frame
                for sample in [0, frame.count / 3, frame.count - 1] {
                    XCTAssertEqual(atlas.pixels[loc.offset + sample], frame[sample],
                                   "\(id) frame \(frameIndex) pixel \(sample) differs in the atlas")
                }
                expectedTotal += frame.count
            }
        }
        XCTAssertEqual(atlas.pixelCount, expectedTotal, "no gaps or overlaps between frames")
    }

    func testFrameLookupClampsOutOfRangeIndices() {
        let atlas = SpriteAtlas()
        let last = atlas.frameCount(.imp) - 1
        XCTAssertEqual(atlas.location(.imp, frame: 999).offset, atlas.location(.imp, frame: last).offset)
        XCTAssertEqual(atlas.location(.imp, frame: -5).offset, atlas.location(.imp, frame: 0).offset)
    }

    func testSheetIDsMatchTheAssetAccessors() {
        let assets = SpriteAssets.shared
        for type in [EnemyType.imp, .demon, .soldier, .baron] {
            let viaID = assets.sheet(SpriteSheetID.enemy(type))
            let direct = assets.enemySprites(for: type)
            XCTAssertEqual(viaID.width, direct.width)
            XCTAssertEqual(viaID.height, direct.height)
            XCTAssertEqual(viaID.frameCount, direct.frameCount)
        }
        for type in WeaponType.allCases {
            let viaID = assets.sheet(SpriteSheetID.weapon(type))
            let direct = assets.weaponSprites(for: type)
            XCTAssertEqual(viaID.width, direct.width)
            XCTAssertEqual(viaID.frameCount, direct.frameCount)
        }
    }

    func testSpriteFrameIndicesStayInsideTheirSheets() {
        let atlas = SpriteAtlas()
        // Enemy animation frames used by Enemy.spriteFrameOffset go up to frontFrameCount - 1
        for type in [EnemyType.imp, .demon, .soldier, .baron] {
            XCTAssertGreaterThanOrEqual(atlas.frameCount(SpriteSheetID.enemy(type)), Enemy.frontFrameCount, "\(type) sheet is short")
        }
        // HitSplash frames: two variants of four
        XCTAssertGreaterThanOrEqual(atlas.frameCount(.hitSplashes), 8)
        // Item.spriteIndex goes up to 13
        XCTAssertGreaterThanOrEqual(atlas.frameCount(.items), 14)
        // ProjectileType.spriteFrame goes up to 3
        XCTAssertGreaterThanOrEqual(atlas.frameCount(.projectiles), 4)
        XCTAssertGreaterThan(atlas.frameCount(.explosions), 0)
    }

    // MARK: - Post effects

    func testDamageAngleIsNormalisedRelativeToTheView() {
        // A hit from straight ahead (source in the facing direction) maps to π
        let front = PostEffects.normalizedDamageAngle(direction: 1.0, playerAngle: 1.0)
        XCTAssertEqual(front, .pi, accuracy: 1e-12)
        // From directly behind maps to 0 (or 2π wrapped to 0)
        let behind = PostEffects.normalizedDamageAngle(direction: 1.0 + .pi, playerAngle: 1.0)
        XCTAssertEqual(behind, 0, accuracy: 1e-12)
        // Always inside [0, 2π)
        for direction in stride(from: -20.0, through: 20.0, by: 0.7) {
            let a = PostEffects.normalizedDamageAngle(direction: direction, playerAngle: 2.5)
            XCTAssertGreaterThanOrEqual(a, 0)
            XCTAssertLessThan(a, 2 * .pi)
        }
    }

    func testEffectsApplyToAPixelBufferWithoutCrashing() {
        let buffer = PixelBuffer(width: GameConstants.renderWidth, height: GameConstants.renderHeight)
        buffer.fill(color: PixelBuffer.makeColor(r: 100, g: 100, b: 100))
        var effects = PostEffects()
        effects.muzzleFlash = 0.3
        effects.damageIntensity = 0.5
        effects.damageDirection = 0.3
        effects.playerAngle = 1.2
        effects.pickupFlash = 0.2
        effects.berserkTint = 0.08
        effects.deathProgress = 0.7
        effects.hitMarkerAlpha = 1.0
        effects.fadeToBlack = 0.4
        effects.apply(to: buffer)

        // The fade darkens everything: no pixel keeps the original grey
        let untouched = PixelBuffer.makeColor(r: 100, g: 100, b: 100)
        XCTAssertNotEqual(buffer.rawPixels[0], untouched)
        XCTAssertNotEqual(buffer.rawPixels[buffer.count - 1], untouched)
    }
}
