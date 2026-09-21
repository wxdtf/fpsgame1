//
//  SpriteAtlas.swift
//  fpsgame1
//
//  Packs every procedurally generated sprite frame into one flat pixel array so the
//  GPU sprite kernel can sample any enemy, item, projectile, explosion or weapon
//  frame from a single buffer.
//

import Foundation

/// One of the sprite sheets in SpriteAssets
enum SpriteSheetID: Int, CaseIterable {
    case imp = 0
    case demon
    case soldier
    case baron
    case fist
    case pistol
    case shotgun
    case chaingun
    case rocketLauncher
    case items
    case projectiles
    case explosions
    case hitSplashes

    static func enemy(_ type: EnemyType) -> SpriteSheetID {
        switch type {
        case .imp: return .imp
        case .demon: return .demon
        case .soldier: return .soldier
        case .baron: return .baron
        }
    }

    static func weapon(_ type: WeaponType) -> SpriteSheetID {
        switch type {
        case .fist: return .fist
        case .pistol: return .pistol
        case .shotgun: return .shotgun
        case .chaingun: return .chaingun
        case .rocketLauncher: return .rocketLauncher
        }
    }
}

extension SpriteAssets {
    func sheet(_ id: SpriteSheetID) -> SpriteSheet {
        switch id {
        case .imp: return impSprites
        case .demon: return demonSprites
        case .soldier: return soldierSprites
        case .baron: return baronSprites
        case .fist: return fistSprites
        case .pistol: return pistolSprites
        case .shotgun: return shotgunSprites
        case .chaingun: return chaingunSprites
        case .rocketLauncher: return rocketLauncherSprites
        case .items: return itemSprites
        case .projectiles: return projectileSprites
        case .explosions: return explosionSprites
        case .hitSplashes: return hitSplashSprites
        }
    }
}

final class SpriteAtlas {
    /// Where one frame lives inside `pixels`
    struct FrameLocation {
        let offset: Int
        let width: Int
        let height: Int
    }

    /// All frames back to back, 0xAARRGGBB, row-major within each frame
    let pixels: [UInt32]
    /// Indexed by SpriteSheetID.rawValue, then frame index
    private let locations: [[FrameLocation]]

    init(assets: SpriteAssets = .shared) {
        var pixels: [UInt32] = []
        var locations: [[FrameLocation]] = []
        var total = 0
        for id in SpriteSheetID.allCases {
            let sheet = assets.sheet(id)
            total += sheet.frameCount * sheet.width * sheet.height
        }
        pixels.reserveCapacity(total)

        for id in SpriteSheetID.allCases {
            let sheet = assets.sheet(id)
            var frameLocations: [FrameLocation] = []
            frameLocations.reserveCapacity(sheet.frameCount)
            for frame in sheet.frames {
                precondition(frame.count == sheet.width * sheet.height,
                             "sprite frame size does not match its sheet")
                frameLocations.append(FrameLocation(offset: pixels.count, width: sheet.width, height: sheet.height))
                pixels.append(contentsOf: frame)
            }
            locations.append(frameLocations)
        }
        self.pixels = pixels
        self.locations = locations
    }

    var pixelCount: Int { pixels.count }

    func frameCount(_ id: SpriteSheetID) -> Int {
        locations[id.rawValue].count
    }

    /// Location of a frame; out-of-range frame indices clamp to the sheet's last frame
    func location(_ id: SpriteSheetID, frame: Int) -> FrameLocation {
        let frames = locations[id.rawValue]
        return frames[min(max(0, frame), frames.count - 1)]
    }
}
