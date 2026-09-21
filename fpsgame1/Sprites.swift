//
//  Sprites.swift
//  testproject
//

import Foundation

struct SpriteSheet {
    let frames: [[UInt32]]
    let width: Int
    let height: Int
    var frameCount: Int { frames.count }
}

final class SpriteAssets {
    static let shared = SpriteAssets()

    let impSprites: SpriteSheet
    let demonSprites: SpriteSheet
    let soldierSprites: SpriteSheet
    let baronSprites: SpriteSheet

    let pistolSprites: SpriteSheet
    let shotgunSprites: SpriteSheet
    let fistSprites: SpriteSheet
    let chaingunSprites: SpriteSheet
    let rocketLauncherSprites: SpriteSheet

    let itemSprites: SpriteSheet
    let projectileSprites: SpriteSheet
    let explosionSprites: SpriteSheet
    /// Blood spurts on hit: frames 0-3 red, 4-7 green (tools/sprite_art/effects.py)
    let hitSplashSprites: SpriteSheet

    private init() {
        impSprites = EnemySpriteData.imp.decode()
        demonSprites = EnemySpriteData.demon.decode()
        soldierSprites = EnemySpriteData.soldier.decode()
        baronSprites = EnemySpriteData.baron.decode()
        pistolSprites = WeaponSpriteData.pistol.decode()
        shotgunSprites = WeaponSpriteData.shotgun.decode()
        fistSprites = WeaponSpriteData.fist.decode()
        chaingunSprites = WeaponSpriteData.chaingun.decode()
        rocketLauncherSprites = WeaponSpriteData.rocketLauncher.decode()
        itemSprites = ItemSpriteData.items.decode()
        projectileSprites = Self.generateProjectileSprites()
        explosionSprites = Self.generateExplosionSprites()
        hitSplashSprites = EffectSpriteData.hitSplash.decode()
    }

    func enemySprites(for type: EnemyType) -> SpriteSheet {
        switch type {
        case .imp: return impSprites
        case .demon: return demonSprites
        case .soldier: return soldierSprites
        case .baron: return baronSprites
        }
    }

    func weaponSprites(for type: WeaponType) -> SpriteSheet {
        switch type {
        case .fist: return fistSprites
        case .pistol: return pistolSprites
        case .shotgun: return shotgunSprites
        case .chaingun: return chaingunSprites
        case .rocketLauncher: return rocketLauncherSprites
        }
    }

    // MARK: - Drawing Helpers

    private static let T: UInt32 = 0x00000000

    private static func c(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        PixelBuffer.makeColor(r: UInt8(max(0, min(255, r))), g: UInt8(max(0, min(255, g))), b: UInt8(max(0, min(255, b))))
    }

    private static func fillCircle(_ px: inout [UInt32], w: Int, h: Int, cx: Int, cy: Int, r: Int, color: UInt32) {
        for dy in -r...r {
            for dx in -r...r {
                if dx * dx + dy * dy <= r * r {
                    let px2 = cx + dx, py2 = cy + dy
                    if px2 >= 0 && px2 < w && py2 >= 0 && py2 < h {
                        px[py2 * w + px2] = color
                    }
                }
            }
        }
    }

    private static func fillOval(_ px: inout [UInt32], w: Int, h: Int, cx: Int, cy: Int, rx: Int, ry: Int, color: UInt32) {
        for dy in -ry...ry {
            for dx in -rx...rx {
                let nx = Double(dx) / Double(rx)
                let ny = Double(dy) / Double(ry)
                if nx * nx + ny * ny <= 1.0 {
                    let px2 = cx + dx, py2 = cy + dy
                    if px2 >= 0 && px2 < w && py2 >= 0 && py2 < h {
                        px[py2 * w + px2] = color
                    }
                }
            }
        }
    }

    private static func fillRect(_ px: inout [UInt32], w: Int, h: Int, x: Int, y: Int, rw: Int, rh: Int, color: UInt32) {
        for dy in 0..<rh {
            for dx in 0..<rw {
                let px2 = x + dx, py2 = y + dy
                if px2 >= 0 && px2 < w && py2 >= 0 && py2 < h {
                    px[py2 * w + px2] = color
                }
            }
        }
    }

    private static func drawLine(_ px: inout [UInt32], w: Int, h: Int, x0: Int, y0: Int, x1: Int, y1: Int, color: UInt32) {
        var x = x0, y = y0
        let dx = abs(x1 - x0), dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        while true {
            if x >= 0 && x < w && y >= 0 && y < h { px[y * w + x] = color }
            if x == x1 && y == y1 { break }
            let e2 = err * 2
            if e2 > -dy { err -= dy; x += sx }
            if e2 < dx { err += dx; y += sy }
        }
    }

    private static func fillTriangle(_ px: inout [UInt32], w: Int, h: Int, x0: Int, y0: Int, x1: Int, y1: Int, x2: Int, y2: Int, color: UInt32) {
        let minY = max(0, min(y0, min(y1, y2)))
        let maxY = min(h - 1, max(y0, max(y1, y2)))
        for y in minY...maxY {
            var minX = w, maxX = 0
            let edges = [(x0, y0, x1, y1), (x1, y1, x2, y2), (x2, y2, x0, y0)]
            for (ax, ay, bx, by) in edges {
                guard (ay <= y && by >= y) || (by <= y && ay >= y) else { continue }
                if ay == by { minX = min(minX, min(ax, bx)); maxX = max(maxX, max(ax, bx)); continue }
                let ix = ax + (y - ay) * (bx - ax) / (by - ay)
                minX = min(minX, ix); maxX = max(maxX, ix)
            }
            for x in max(0, minX)...min(w - 1, maxX) {
                px[y * w + x] = color
            }
        }
    }

    /// Add per-pixel noise variation to non-transparent pixels
    private static func addNoise(_ px: inout [UInt32], w: Int, h: Int, intensity: Int, seed: Int = 0) {
        for y in 0..<h {
            for x in 0..<w {
                guard (px[y * w + x] >> 24) != 0 else { continue }
                let p = px[y * w + x]
                // Simple deterministic hash for noise
                var hash = x &* 374761393 &+ y &* 668265263 &+ seed &* 1274126177
                hash = (hash ^ (hash >> 13)) &* 1274126177
                hash = hash ^ (hash >> 16)
                let n = (hash & 0xFF) % (intensity * 2 + 1) - intensity
                let r = max(0, min(255, Int((p >> 16) & 0xFF) + n))
                let g = max(0, min(255, Int((p >> 8) & 0xFF) + n))
                let b = max(0, min(255, Int(p & 0xFF) + n))
                px[y * w + x] = c(r, g, b)
            }
        }
    }

    private static func addOutline(_ px: inout [UInt32], w: Int, h: Int, color: UInt32) {
        let copy = px
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                if (copy[y * w + x] >> 24) == 0 {
                    // Check 4-neighbors for non-transparent
                    let hasNeighbor = (copy[(y - 1) * w + x] >> 24) != 0 ||
                                      (copy[(y + 1) * w + x] >> 24) != 0 ||
                                      (copy[y * w + (x - 1)] >> 24) != 0 ||
                                      (copy[y * w + (x + 1)] >> 24) != 0
                    if hasNeighbor {
                        px[y * w + x] = color
                    }
                }
            }
        }
    }

    private static func brighten(_ color: UInt32, _ amount: Int) -> UInt32 {
        let r = min(255, Int(PixelBuffer.getRed(color)) + amount)
        let g = min(255, Int(PixelBuffer.getGreen(color)) + amount)
        let b = min(255, Int(PixelBuffer.getBlue(color)) + amount)
        return c(r, g, b)
    }

    private static func darken(_ color: UInt32, _ amount: Int) -> UInt32 {
        let r = max(0, Int(PixelBuffer.getRed(color)) - amount)
        let g = max(0, Int(PixelBuffer.getGreen(color)) - amount)
        let b = max(0, Int(PixelBuffer.getBlue(color)) - amount)
        return c(r, g, b)
    }

    // MARK: - Enemy Sprites
    //
    // The enemy sheets are pixel art authored in tools/sprite_art/*.py and baked
    // into BakedSpriteData.swift by tools/sprite_art/build.py.

    // MARK: - Weapon and Item Sprites
    //
    // Also pixel art from tools/sprite_art (weapons.py, items.py), baked into
    // BakedSpriteData.swift.

    // MARK: - Explosion Sprites (rocket blast, 4 frames)

    private static func generateExplosionSprites() -> SpriteSheet {
        let w = 32, h = 32
        var frames: [[UInt32]] = []

        // Frame 0: white-hot flash
        var f0 = [UInt32](repeating: T, count: w * h)
        fillCircle(&f0, w: w, h: h, cx: 16, cy: 16, r: 7, color: c(255, 220, 120))
        fillCircle(&f0, w: w, h: h, cx: 16, cy: 16, r: 4, color: c(255, 255, 230))
        frames.append(f0)

        // Frame 1: expanding fireball
        var f1 = [UInt32](repeating: T, count: w * h)
        fillCircle(&f1, w: w, h: h, cx: 16, cy: 16, r: 12, color: c(200, 60, 10))
        fillCircle(&f1, w: w, h: h, cx: 16, cy: 16, r: 9, color: c(255, 140, 20))
        fillCircle(&f1, w: w, h: h, cx: 15, cy: 15, r: 5, color: c(255, 240, 150))
        frames.append(f1)

        // Frame 2: full blast with a dark rim and hot spots
        var f2 = [UInt32](repeating: T, count: w * h)
        fillCircle(&f2, w: w, h: h, cx: 16, cy: 16, r: 15, color: c(90, 30, 10))
        fillCircle(&f2, w: w, h: h, cx: 16, cy: 16, r: 12, color: c(220, 80, 15))
        fillCircle(&f2, w: w, h: h, cx: 12, cy: 13, r: 5, color: c(255, 200, 80))
        fillCircle(&f2, w: w, h: h, cx: 21, cy: 18, r: 4, color: c(255, 180, 60))
        frames.append(f2)

        // Frame 3: smoke
        var f3 = [UInt32](repeating: T, count: w * h)
        fillCircle(&f3, w: w, h: h, cx: 15, cy: 15, r: 14, color: c(70, 60, 55))
        fillCircle(&f3, w: w, h: h, cx: 19, cy: 12, r: 8, color: c(95, 85, 80))
        fillCircle(&f3, w: w, h: h, cx: 11, cy: 18, r: 6, color: c(55, 45, 42))
        frames.append(f3)

        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Projectile Sprites (fireball + bullet tracer)

    private static func generateProjectileSprites() -> SpriteSheet {
        let w = 16, h = 16
        var frames: [[UInt32]] = []

        // Frame 0: Fireball (clean round glowing sphere)
        var fb = [UInt32](repeating: T, count: w * h)
        fillCircle(&fb, w: w, h: h, cx: 8, cy: 8, r: 7, color: c(160, 40, 0))
        fillCircle(&fb, w: w, h: h, cx: 8, cy: 8, r: 6, color: c(220, 80, 0))
        fillCircle(&fb, w: w, h: h, cx: 8, cy: 8, r: 4, color: c(255, 160, 20))
        fillCircle(&fb, w: w, h: h, cx: 8, cy: 8, r: 2, color: c(255, 230, 100))
        fillCircle(&fb, w: w, h: h, cx: 7, cy: 7, r: 1, color: c(255, 255, 200))
        frames.append(fb)

        // Frame 1: Bullet (small bright symmetric dot)
        var bl = [UInt32](repeating: T, count: w * h)
        fillCircle(&bl, w: w, h: h, cx: 8, cy: 8, r: 3, color: c(200, 180, 100))
        fillCircle(&bl, w: w, h: h, cx: 8, cy: 8, r: 2, color: c(255, 240, 160))
        fillCircle(&bl, w: w, h: h, cx: 8, cy: 8, r: 1, color: c(255, 255, 240))
        frames.append(bl)

        // Frame 2: Plasma ball (baron) — green hellfire with a white-hot core
        var pl = [UInt32](repeating: T, count: w * h)
        fillCircle(&pl, w: w, h: h, cx: 8, cy: 8, r: 7, color: c(20, 120, 50))
        fillCircle(&pl, w: w, h: h, cx: 8, cy: 8, r: 6, color: c(50, 200, 90))
        fillCircle(&pl, w: w, h: h, cx: 8, cy: 8, r: 4, color: c(120, 255, 150))
        fillCircle(&pl, w: w, h: h, cx: 8, cy: 8, r: 2, color: c(220, 255, 230))
        frames.append(pl)

        // Frame 3: Rocket — grey body, red nose, exhaust flame
        var rk = [UInt32](repeating: T, count: w * h)
        fillRect(&rk, w: w, h: h, x: 6, y: 3, rw: 4, rh: 8, color: c(150, 150, 140))
        fillTriangle(&rk, w: w, h: h, x0: 6, y0: 3, x1: 10, y1: 3, x2: 8, y2: 0, color: c(190, 40, 30))
        fillRect(&rk, w: w, h: h, x: 4, y: 9, rw: 2, rh: 3, color: c(90, 90, 85))
        fillRect(&rk, w: w, h: h, x: 10, y: 9, rw: 2, rh: 3, color: c(90, 90, 85))
        fillCircle(&rk, w: w, h: h, cx: 8, cy: 13, r: 3, color: c(255, 160, 30))
        fillCircle(&rk, w: w, h: h, cx: 8, cy: 12, r: 1, color: c(255, 240, 160))
        frames.append(rk)

        return SpriteSheet(frames: frames, width: w, height: h)
    }
}
