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

    let pistolSprites: SpriteSheet
    let shotgunSprites: SpriteSheet
    let fistSprites: SpriteSheet
    let chaingunSprites: SpriteSheet

    let itemSprites: SpriteSheet
    let projectileSprites: SpriteSheet

    private init() {
        impSprites = Self.generateImpSprites()
        demonSprites = Self.generateDemonSprites()
        soldierSprites = Self.generateSoldierSprites()
        pistolSprites = Self.generatePistolSprites()
        shotgunSprites = Self.generateShotgunSprites()
        fistSprites = Self.generateFistSprites()
        chaingunSprites = Self.generateChaingunSprites()
        itemSprites = Self.generateItemSprites()
        projectileSprites = Self.generateProjectileSprites()
    }

    func enemySprites(for type: EnemyType) -> SpriteSheet {
        switch type {
        case .imp: return impSprites
        case .demon: return demonSprites
        case .soldier: return soldierSprites
        }
    }

    func weaponSprites(for type: WeaponType) -> SpriteSheet {
        switch type {
        case .fist: return fistSprites
        case .pistol: return pistolSprites
        case .shotgun: return shotgunSprites
        case .chaingun: return chaingunSprites
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

    // MARK: - Imp Sprites (horned demon monster, throws fireballs)

    private static func generateImpSprites() -> SpriteSheet {
        let w = 48, h = 64
        var frames: [[UInt32]] = []

        for frame in 0..<10 {
            var px = [UInt32](repeating: T, count: w * h)
            let body = c(160, 55, 30)
            let bodyDark = c(110, 35, 20)
            let bodyLight = c(190, 75, 45)
            let eye = c(255, 220, 0)
            let horn = c(80, 40, 25)
            let blood = c(160, 10, 10)

            let yOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? -1 : 1) : 0

            if frame <= 6 {
                // Legs
                let legSpread = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? 3 : -2) : 0
                fillRect(&px, w: w, h: h, x: 14 - legSpread, y: 48 + yOff, rw: 7, rh: 14, color: bodyDark)
                fillRect(&px, w: w, h: h, x: 27 + legSpread, y: 48 + yOff, rw: 7, rh: 14, color: bodyDark)
                // Feet (clawed)
                fillRect(&px, w: w, h: h, x: 13 - legSpread, y: 59 + yOff, rw: 9, rh: 3, color: horn)
                fillRect(&px, w: w, h: h, x: 26 + legSpread, y: 59 + yOff, rw: 9, rh: 3, color: horn)

                // Torso
                fillOval(&px, w: w, h: h, cx: 24, cy: 38 + yOff, rx: 11, ry: 13, color: body)
                fillOval(&px, w: w, h: h, cx: 22, cy: 34 + yOff, rx: 6, ry: 5, color: bodyLight)

                // Head
                fillOval(&px, w: w, h: h, cx: 24, cy: 14 + yOff, rx: 10, ry: 9, color: body)
                fillRect(&px, w: w, h: h, x: 15, y: 10 + yOff, rw: 18, rh: 3, color: bodyDark)
                // Glowing eyes
                fillCircle(&px, w: w, h: h, cx: 19, cy: 13 + yOff, r: 2, color: eye)
                fillCircle(&px, w: w, h: h, cx: 29, cy: 13 + yOff, r: 2, color: eye)
                // Fanged mouth
                fillRect(&px, w: w, h: h, x: 20, y: 18 + yOff, rw: 8, rh: 3, color: c(60, 10, 5))
                for tx in stride(from: 21, to: 28, by: 2) {
                    let ty = 21 + yOff
                    if ty >= 0 && ty < h { px[ty * w + tx] = c(240, 235, 220) }
                }

                // Horns
                for i in 0..<6 {
                    let hx1 = 13 - i / 2
                    let hx2 = 35 + i / 2
                    let hy = 6 + yOff - i
                    if hy >= 0 && hy < h {
                        px[hy * w + hx1] = horn
                        if hx1 + 1 < w { px[hy * w + hx1 + 1] = horn }
                        px[hy * w + hx2] = horn
                        if hx2 - 1 >= 0 { px[hy * w + hx2 - 1] = horn }
                    }
                }

                if frame == 4 || frame == 5 {
                    // Attack: arm extended, fireball forming/thrown
                    fillRect(&px, w: w, h: h, x: 34, y: 28 + yOff, rw: 12, rh: 5, color: body)
                    // Clawed hand
                    fillRect(&px, w: w, h: h, x: 44, y: 27 + yOff, rw: 3, rh: 7, color: bodyDark)
                    if frame == 5 {
                        // Fireball in hand — bright glowing orb
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 28 + yOff, r: 5, color: c(220, 80, 0))
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 28 + yOff, r: 3, color: c(255, 180, 30))
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 28 + yOff, r: 1, color: c(255, 255, 200))
                    }
                    // Left arm at side
                    fillRect(&px, w: w, h: h, x: 7, y: 28 + yOff, rw: 6, rh: 14, color: body)
                } else {
                    // Arms at sides with claws
                    fillRect(&px, w: w, h: h, x: 7, y: 28 + yOff, rw: 6, rh: 14, color: body)
                    fillRect(&px, w: w, h: h, x: 35, y: 28 + yOff, rw: 6, rh: 14, color: body)
                    for cx in [8, 10, 36, 38] {
                        let cy = 42 + yOff
                        if cy >= 0 && cy < h { px[cy * w + cx] = horn }
                        if cy + 1 < h { px[(cy + 1) * w + cx] = horn }
                    }
                }

                if frame == 6 {
                    for i in 0..<px.count where px[i] != T {
                        px[i] = brighten(px[i], 90)
                    }
                }

                addOutline(&px, w: w, h: h, color: c(40, 15, 8))
            } else {
                // Death: falling backward with blood
                let progress = frame - 7  // 0, 1, 2
                if progress == 0 {
                    // Recoil — leaning back, blood spray from chest
                    fillRect(&px, w: w, h: h, x: 14, y: 48, rw: 7, rh: 14, color: bodyDark)
                    fillRect(&px, w: w, h: h, x: 27, y: 48, rw: 7, rh: 14, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 38, rx: 11, ry: 13, color: body)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 16, rx: 10, ry: 9, color: body)
                    fillCircle(&px, w: w, h: h, cx: 19, cy: 15, r: 2, color: eye)
                    fillCircle(&px, w: w, h: h, cx: 29, cy: 15, r: 2, color: eye)
                    // Blood spray
                    fillCircle(&px, w: w, h: h, cx: 24, cy: 32, r: 4, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 20, cy: 28, r: 2, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 28, cy: 30, r: 2, color: blood)
                    addOutline(&px, w: w, h: h, color: c(40, 15, 8))
                } else if progress == 1 {
                    // Falling — body tilting, legs buckling
                    fillRect(&px, w: w, h: h, x: 12, y: 52, rw: 8, rh: 10, color: bodyDark)
                    fillRect(&px, w: w, h: h, x: 28, y: 50, rw: 8, rh: 10, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 28, cy: 42, rx: 12, ry: 10, color: body)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 28, rx: 8, ry: 7, color: body)
                    // Blood
                    fillCircle(&px, w: w, h: h, cx: 26, cy: 38, r: 5, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 22, cy: 34, r: 3, color: blood)
                    addOutline(&px, w: w, h: h, color: c(40, 15, 8))
                } else {
                    // Corpse on ground — flat body with blood pool
                    fillOval(&px, w: w, h: h, cx: 24, cy: 56, rx: 18, ry: 4, color: c(100, 0, 0))
                    fillOval(&px, w: w, h: h, cx: 24, cy: 55, rx: 16, ry: 5, color: body)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 54, rx: 14, ry: 3, color: bodyDark)
                    // Head
                    fillCircle(&px, w: w, h: h, cx: 36, cy: 54, r: 4, color: body)
                    // Blood pool
                    fillOval(&px, w: w, h: h, cx: 24, cy: 58, rx: 14, ry: 3, color: c(120, 5, 5))
                    addOutline(&px, w: w, h: h, color: c(40, 15, 8))
                }
            }
            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Demon Sprites (big pink/brown beast, melee)

    private static func generateDemonSprites() -> SpriteSheet {
        let w = 64, h = 64
        var frames: [[UInt32]] = []

        for frame in 0..<10 {
            var px = [UInt32](repeating: T, count: w * h)
            let body = c(170, 90, 110)
            let bodyDark = c(120, 55, 70)
            let bodyLight = c(200, 120, 140)
            let eye = c(255, 20, 0)
            let tooth = c(240, 235, 220)
            let blood = c(160, 10, 10)

            let yOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? -2 : 2) : 0

            if frame <= 6 {
                // Main body (large, hunched)
                fillOval(&px, w: w, h: h, cx: 32, cy: 32 + yOff, rx: 22, ry: 18, color: body)
                fillOval(&px, w: w, h: h, cx: 32, cy: 24 + yOff, rx: 18, ry: 12, color: bodyLight)
                fillOval(&px, w: w, h: h, cx: 32, cy: 40 + yOff, rx: 16, ry: 8, color: bodyDark)

                // Head
                fillOval(&px, w: w, h: h, cx: 32, cy: 12 + yOff, rx: 13, ry: 10, color: body)
                fillRect(&px, w: w, h: h, x: 22, y: 16 + yOff, rw: 20, rh: 6, color: bodyDark)

                // Eyes
                fillCircle(&px, w: w, h: h, cx: 25, cy: 10 + yOff, r: 3, color: eye)
                fillCircle(&px, w: w, h: h, cx: 39, cy: 10 + yOff, r: 3, color: eye)
                fillCircle(&px, w: w, h: h, cx: 25, cy: 9 + yOff, r: 1, color: c(255, 100, 50))
                fillCircle(&px, w: w, h: h, cx: 39, cy: 9 + yOff, r: 1, color: c(255, 100, 50))

                // Teeth
                for tx in stride(from: 24, to: 40, by: 3) {
                    fillRect(&px, w: w, h: h, x: tx, y: 17 + yOff, rw: 2, rh: 3, color: tooth)
                }

                // Legs
                let legOff = (frame >= 1 && frame <= 3) ? (frame % 2) * 3 : 0
                fillRect(&px, w: w, h: h, x: 12 + legOff, y: 48 + yOff, rw: 8, rh: 14, color: bodyDark)
                fillRect(&px, w: w, h: h, x: 24, y: 48 + yOff, rw: 7, rh: 14, color: bodyDark)
                fillRect(&px, w: w, h: h, x: 33, y: 48 + yOff, rw: 7, rh: 14, color: bodyDark)
                fillRect(&px, w: w, h: h, x: 44 - legOff, y: 48 + yOff, rw: 8, rh: 14, color: bodyDark)

                // Hooves
                for lx in [12 + legOff, 24, 33, 44 - legOff] {
                    fillRect(&px, w: w, h: h, x: lx - 1, y: 60 + yOff, rw: 9, rh: 3, color: c(60, 30, 20))
                }

                if frame == 4 || frame == 5 {
                    // Attack: jaws open wide with lunging motion
                    fillRect(&px, w: w, h: h, x: 20, y: 16 + yOff, rw: 24, rh: 10, color: c(80, 10, 10))
                    for tx in stride(from: 22, to: 42, by: 3) {
                        fillRect(&px, w: w, h: h, x: tx, y: 16 + yOff, rw: 2, rh: 4, color: tooth)
                    }
                    for tx in stride(from: 23, to: 41, by: 3) {
                        fillRect(&px, w: w, h: h, x: tx, y: 23 + yOff, rw: 2, rh: 3, color: tooth)
                    }
                    if frame == 5 {
                        // Blood/saliva drip
                        fillRect(&px, w: w, h: h, x: 30, y: 26 + yOff, rw: 2, rh: 4, color: blood)
                        fillRect(&px, w: w, h: h, x: 34, y: 25 + yOff, rw: 1, rh: 3, color: blood)
                    }
                }

                if frame == 6 {
                    for i in 0..<px.count where px[i] != T {
                        px[i] = brighten(px[i], 90)
                    }
                }

                addOutline(&px, w: w, h: h, color: c(50, 20, 30))
            } else {
                // Death: falling backward with blood
                let progress = frame - 7  // 0, 1, 2
                if progress == 0 {
                    // Recoil — still upright but staggering back
                    fillOval(&px, w: w, h: h, cx: 34, cy: 32, rx: 22, ry: 18, color: body)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 14, rx: 12, ry: 9, color: body)
                    fillCircle(&px, w: w, h: h, cx: 27, cy: 12, r: 3, color: eye)
                    fillCircle(&px, w: w, h: h, cx: 41, cy: 12, r: 3, color: eye)
                    fillRect(&px, w: w, h: h, x: 14, y: 48, rw: 8, rh: 14, color: bodyDark)
                    fillRect(&px, w: w, h: h, x: 42, y: 48, rw: 8, rh: 14, color: bodyDark)
                    // Blood spray from chest
                    fillCircle(&px, w: w, h: h, cx: 32, cy: 30, r: 5, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 28, cy: 26, r: 3, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 36, cy: 28, r: 2, color: blood)
                    addOutline(&px, w: w, h: h, color: c(50, 20, 30))
                } else if progress == 1 {
                    // Collapsing sideways
                    fillOval(&px, w: w, h: h, cx: 36, cy: 44, rx: 22, ry: 12, color: body)
                    fillOval(&px, w: w, h: h, cx: 42, cy: 36, rx: 10, ry: 8, color: body)
                    fillRect(&px, w: w, h: h, x: 10, y: 54, rw: 10, rh: 8, color: bodyDark)
                    fillRect(&px, w: w, h: h, x: 44, y: 52, rw: 10, rh: 8, color: bodyDark)
                    // Blood
                    fillCircle(&px, w: w, h: h, cx: 32, cy: 42, r: 6, color: blood)
                    addOutline(&px, w: w, h: h, color: c(50, 20, 30))
                } else {
                    // Corpse — flat on ground with blood pool
                    fillOval(&px, w: w, h: h, cx: 32, cy: 57, rx: 22, ry: 4, color: c(100, 0, 0))
                    fillOval(&px, w: w, h: h, cx: 32, cy: 56, rx: 20, ry: 5, color: body)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 55, rx: 18, ry: 3, color: bodyDark)
                    fillCircle(&px, w: w, h: h, cx: 48, cy: 55, r: 5, color: body)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 59, rx: 18, ry: 3, color: c(120, 5, 5))
                    addOutline(&px, w: w, h: h, color: c(50, 20, 30))
                }
            }
            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Soldier Sprites (WW2 soldier with rifle, muzzle flash)

    private static func generateSoldierSprites() -> SpriteSheet {
        let w = 48, h = 64
        var frames: [[UInt32]] = []

        for frame in 0..<10 {
            var px = [UInt32](repeating: T, count: w * h)
            let uniform = c(75, 80, 55)        // Olive drab uniform
            let uniformDark = c(50, 55, 35)
            let uniformLight = c(95, 100, 70)
            let skin = c(195, 155, 125)
            let skinDark = c(165, 130, 100)
            let gun = c(60, 55, 50)             // Dark wood/metal rifle
            let gunMetal = c(70, 70, 75)
            let helmet = c(65, 70, 50)          // Steel helmet
            let helmetDark = c(45, 50, 35)
            let boot = c(45, 35, 25)
            let blood = c(160, 10, 10)

            let yOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? -1 : 1) : 0

            if frame <= 6 {
                // Boots
                let legOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? 2 : -1) : 0
                fillRect(&px, w: w, h: h, x: 14 - legOff, y: 50 + yOff, rw: 8, rh: 12, color: uniformDark)
                fillRect(&px, w: w, h: h, x: 26 + legOff, y: 50 + yOff, rw: 8, rh: 12, color: uniformDark)
                fillRect(&px, w: w, h: h, x: 13 - legOff, y: 59 + yOff, rw: 10, rh: 4, color: boot)
                fillRect(&px, w: w, h: h, x: 25 + legOff, y: 59 + yOff, rw: 10, rh: 4, color: boot)

                // Torso (uniform jacket)
                fillOval(&px, w: w, h: h, cx: 24, cy: 36 + yOff, rx: 12, ry: 16, color: uniform)
                fillOval(&px, w: w, h: h, cx: 22, cy: 32 + yOff, rx: 7, ry: 8, color: uniformLight)
                // Collar
                fillRect(&px, w: w, h: h, x: 19, y: 20 + yOff, rw: 10, rh: 3, color: uniformDark)
                // Belt
                fillRect(&px, w: w, h: h, x: 13, y: 46 + yOff, rw: 22, rh: 3, color: c(60, 45, 25))
                fillRect(&px, w: w, h: h, x: 22, y: 46 + yOff, rw: 4, rh: 3, color: c(150, 130, 40))
                // Ammo pouches on belt
                fillRect(&px, w: w, h: h, x: 14, y: 44 + yOff, rw: 5, rh: 4, color: c(70, 55, 30))
                fillRect(&px, w: w, h: h, x: 29, y: 44 + yOff, rw: 5, rh: 4, color: c(70, 55, 30))

                // Head (M1 style helmet)
                fillOval(&px, w: w, h: h, cx: 24, cy: 11 + yOff, rx: 9, ry: 8, color: helmet)
                // Helmet rim
                fillRect(&px, w: w, h: h, x: 14, y: 14 + yOff, rw: 20, rh: 2, color: helmetDark)
                // Chinstrap
                fillRect(&px, w: w, h: h, x: 16, y: 16 + yOff, rw: 1, rh: 3, color: c(80, 65, 40))
                fillRect(&px, w: w, h: h, x: 31, y: 16 + yOff, rw: 1, rh: 3, color: c(80, 65, 40))
                // Face
                fillOval(&px, w: w, h: h, cx: 24, cy: 16 + yOff, rx: 6, ry: 4, color: skin)
                // Eyes
                fillRect(&px, w: w, h: h, x: 20, y: 14 + yOff, rw: 2, rh: 2, color: c(40, 30, 20))
                fillRect(&px, w: w, h: h, x: 26, y: 14 + yOff, rw: 2, rh: 2, color: c(40, 30, 20))

                if frame == 4 || frame == 5 {
                    // Shooting stance: rifle aimed forward
                    // Left arm forward supporting rifle
                    fillRect(&px, w: w, h: h, x: 8, y: 26 + yOff, rw: 8, rh: 4, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 6, y: 26 + yOff, rw: 4, rh: 4, color: skinDark)
                    // Right arm holding rifle
                    fillRect(&px, w: w, h: h, x: 32, y: 28 + yOff, rw: 6, rh: 4, color: uniformDark)
                    // Rifle extended
                    fillRect(&px, w: w, h: h, x: 4, y: 24 + yOff, rw: 34, rh: 3, color: gun)
                    fillRect(&px, w: w, h: h, x: 4, y: 23 + yOff, rw: 6, rh: 2, color: gunMetal) // Barrel
                    // Stock
                    fillRect(&px, w: w, h: h, x: 34, y: 22 + yOff, rw: 6, rh: 8, color: c(90, 60, 30))
                    if frame == 5 {
                        // Muzzle flash at barrel tip
                        fillCircle(&px, w: w, h: h, cx: 3, cy: 24 + yOff, r: 5, color: c(255, 200, 40))
                        fillCircle(&px, w: w, h: h, cx: 3, cy: 24 + yOff, r: 3, color: c(255, 240, 120))
                        fillCircle(&px, w: w, h: h, cx: 3, cy: 24 + yOff, r: 1, color: c(255, 255, 220))
                    }
                } else {
                    // Arms at sides
                    fillRect(&px, w: w, h: h, x: 6, y: 26 + yOff, rw: 6, rh: 14, color: uniform)
                    fillRect(&px, w: w, h: h, x: 6, y: 38 + yOff, rw: 6, rh: 4, color: skin)
                    fillRect(&px, w: w, h: h, x: 36, y: 26 + yOff, rw: 6, rh: 14, color: uniform)
                    fillRect(&px, w: w, h: h, x: 36, y: 38 + yOff, rw: 6, rh: 4, color: skin)
                    // Rifle slung on right side
                    fillRect(&px, w: w, h: h, x: 38, y: 20 + yOff, rw: 3, rh: 24, color: gun)
                }

                if frame == 6 {
                    for i in 0..<px.count where px[i] != T {
                        px[i] = brighten(px[i], 90)
                    }
                }

                addOutline(&px, w: w, h: h, color: c(25, 30, 15))
            } else {
                // Death: falling backward with blood
                let progress = frame - 7  // 0, 1, 2
                if progress == 0 {
                    // Hit — staggering back, helmet flying off
                    fillRect(&px, w: w, h: h, x: 14, y: 50, rw: 8, rh: 12, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 26, y: 50, rw: 8, rh: 12, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 38, rx: 12, ry: 16, color: uniform)
                    // Head tilted back
                    fillOval(&px, w: w, h: h, cx: 28, cy: 14, rx: 7, ry: 6, color: skin)
                    // Helmet flying off
                    fillOval(&px, w: w, h: h, cx: 38, cy: 6, rx: 7, ry: 5, color: helmet)
                    // Blood from chest
                    fillCircle(&px, w: w, h: h, cx: 24, cy: 32, r: 4, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 20, cy: 28, r: 3, color: blood)
                    // Arms flailing
                    fillRect(&px, w: w, h: h, x: 6, y: 22, rw: 5, rh: 10, color: uniform)
                    fillRect(&px, w: w, h: h, x: 38, y: 20, rw: 5, rh: 12, color: uniform)
                    // Dropped rifle
                    fillRect(&px, w: w, h: h, x: 40, y: 32, rw: 3, rh: 16, color: gun)
                    addOutline(&px, w: w, h: h, color: c(25, 30, 15))
                } else if progress == 1 {
                    // Falling — body crumpling
                    fillRect(&px, w: w, h: h, x: 12, y: 54, rw: 8, rh: 8, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 28, y: 52, rw: 8, rh: 8, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 28, cy: 46, rx: 12, ry: 10, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 34, rx: 6, ry: 5, color: skin)
                    fillCircle(&px, w: w, h: h, cx: 26, cy: 42, r: 5, color: blood)
                    addOutline(&px, w: w, h: h, color: c(25, 30, 15))
                } else {
                    // Corpse on ground — flat body with blood pool
                    fillOval(&px, w: w, h: h, cx: 24, cy: 57, rx: 16, ry: 4, color: c(100, 0, 0))
                    fillOval(&px, w: w, h: h, cx: 24, cy: 56, rx: 14, ry: 5, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 55, rx: 12, ry: 3, color: uniformDark)
                    // Head
                    fillCircle(&px, w: w, h: h, cx: 36, cy: 55, r: 4, color: skin)
                    // Dropped rifle nearby
                    fillRect(&px, w: w, h: h, x: 6, y: 56, rw: 12, rh: 2, color: gun)
                    // Blood pool
                    fillOval(&px, w: w, h: h, cx: 24, cy: 59, rx: 12, ry: 3, color: c(120, 5, 5))
                    addOutline(&px, w: w, h: h, color: c(25, 30, 15))
                }
            }
            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Pistol Weapon Sprites (first person view)

    private static func generatePistolSprites() -> SpriteSheet {
        let w = 192, h = 192
        var frames: [[UInt32]] = []

        for frame in 0..<4 {
            var px = [UInt32](repeating: T, count: w * h)
            let metal = c(75, 75, 80)
            let metalDark = c(50, 50, 55)
            let metalLight = c(100, 100, 108)
            let grip = c(90, 55, 25)
            let gripDark = c(65, 40, 18)
            let skin = c(195, 155, 125)
            let skinDark = c(165, 130, 100)

            let recoil = frame == 1 ? -14 : (frame == 2 ? -6 : 0)

            // Hand
            fillOval(&px, w: w, h: h, cx: 96, cy: 138 + recoil, rx: 30, ry: 16, color: skin)
            fillOval(&px, w: w, h: h, cx: 96, cy: 142 + recoil, rx: 28, ry: 14, color: skinDark)
            // Thumb
            fillOval(&px, w: w, h: h, cx: 74, cy: 128 + recoil, rx: 8, ry: 6, color: skin)

            // Grip
            fillRect(&px, w: w, h: h, x: 78, y: 110 + recoil, rw: 36, rh: 45, color: grip)
            fillRect(&px, w: w, h: h, x: 80, y: 112 + recoil, rw: 3, rh: 38, color: gripDark) // Grip texture lines
            fillRect(&px, w: w, h: h, x: 86, y: 112 + recoil, rw: 3, rh: 38, color: gripDark)
            fillRect(&px, w: w, h: h, x: 92, y: 112 + recoil, rw: 3, rh: 38, color: gripDark)
            fillRect(&px, w: w, h: h, x: 98, y: 112 + recoil, rw: 3, rh: 38, color: gripDark)
            fillRect(&px, w: w, h: h, x: 104, y: 112 + recoil, rw: 3, rh: 38, color: gripDark)

            // Trigger guard
            fillRect(&px, w: w, h: h, x: 78, y: 108 + recoil, rw: 2, rh: 12, color: metalDark)
            fillRect(&px, w: w, h: h, x: 74, y: 116 + recoil, rw: 6, rh: 2, color: metalDark)

            // Slide
            fillRect(&px, w: w, h: h, x: 80, y: 52 + recoil, rw: 32, rh: 60, color: metal)
            // Slide left edge highlight
            fillRect(&px, w: w, h: h, x: 80, y: 52 + recoil, rw: 3, rh: 58, color: metalLight)
            // Slide top
            fillRect(&px, w: w, h: h, x: 82, y: 50 + recoil, rw: 28, rh: 4, color: metalDark)
            // Ejection port
            fillRect(&px, w: w, h: h, x: 100, y: 60 + recoil, rw: 8, rh: 14, color: metalDark)
            // Serrations at back of slide
            for sy in stride(from: 56 + recoil, to: 70 + recoil, by: 3) {
                fillRect(&px, w: w, h: h, x: 106, y: sy, rw: 4, rh: 1, color: metalDark)
            }

            // Front sight
            fillRect(&px, w: w, h: h, x: 92, y: 44 + recoil, rw: 6, rh: 8, color: metalDark)
            // Rear sight
            fillRect(&px, w: w, h: h, x: 84, y: 48 + recoil, rw: 4, rh: 4, color: metalDark)
            fillRect(&px, w: w, h: h, x: 104, y: 48 + recoil, rw: 4, rh: 4, color: metalDark)

            // Barrel
            fillRect(&px, w: w, h: h, x: 86, y: 42 + recoil, rw: 20, rh: 10, color: metalDark)

            // Muzzle flash
            if frame == 1 {
                for r in stride(from: 22, to: 0, by: -2) {
                    let intensity = Double(22 - r) / 22.0
                    let fr = Int(255.0 * intensity)
                    let fg = Int(200.0 * intensity * intensity)
                    let fb = Int(50.0 * intensity * intensity * intensity)
                    fillCircle(&px, w: w, h: h, cx: 96, cy: 30, r: r, color: c(fr, fg, fb))
                }
            }

            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Shotgun Weapon Sprites

    private static func generateShotgunSprites() -> SpriteSheet {
        let w = 220, h = 192
        var frames: [[UInt32]] = []

        for frame in 0..<5 {
            var px = [UInt32](repeating: T, count: w * h)
            let metal = c(65, 65, 70)
            let metalDark = c(40, 40, 45)
            let wood = c(110, 65, 28)
            let woodDark = c(75, 45, 18)
            let woodLight = c(140, 85, 40)
            let skin = c(195, 155, 125)

            let recoil = frame == 1 ? -18 : (frame == 2 ? -8 : (frame == 3 ? -4 : 0))
            let pumpOff = frame == 3 ? 14 : (frame == 4 ? 6 : 0)

            // Supporting hand (left)
            fillOval(&px, w: w, h: h, cx: 80, cy: 108 + recoil + pumpOff, rx: 14, ry: 10, color: skin)

            // Pump / forend
            fillRect(&px, w: w, h: h, x: 65, y: 100 + recoil + pumpOff, rw: 90, rh: 16, color: wood)
            fillRect(&px, w: w, h: h, x: 67, y: 102 + recoil + pumpOff, rw: 86, rh: 2, color: woodLight)
            fillRect(&px, w: w, h: h, x: 67, y: 112 + recoil + pumpOff, rw: 86, rh: 2, color: woodDark)

            // Stock
            fillRect(&px, w: w, h: h, x: 82, y: 120 + recoil, rw: 56, rh: 72, color: wood)
            fillRect(&px, w: w, h: h, x: 84, y: 122 + recoil, rw: 4, rh: 65, color: woodDark) // Wood grain
            fillRect(&px, w: w, h: h, x: 92, y: 122 + recoil, rw: 3, rh: 65, color: woodDark)
            fillRect(&px, w: w, h: h, x: 100, y: 122 + recoil, rw: 4, rh: 65, color: woodDark)
            fillRect(&px, w: w, h: h, x: 110, y: 122 + recoil, rw: 3, rh: 65, color: woodDark)
            fillRect(&px, w: w, h: h, x: 120, y: 122 + recoil, rw: 4, rh: 65, color: woodLight)

            // Trigger hand
            fillOval(&px, w: w, h: h, cx: 110, cy: 134 + recoil, rx: 16, ry: 12, color: skin)

            // Receiver (main body)
            fillRect(&px, w: w, h: h, x: 82, y: 70 + recoil, rw: 56, rh: 32, color: metal)
            fillRect(&px, w: w, h: h, x: 82, y: 70 + recoil, rw: 3, rh: 30, color: c(85, 85, 92)) // Highlight

            // Trigger guard
            fillRect(&px, w: w, h: h, x: 92, y: 100 + recoil, rw: 2, rh: 10, color: metalDark)

            // Double barrels
            fillRect(&px, w: w, h: h, x: 86, y: 30 + recoil, rw: 22, rh: 42, color: metal)
            fillRect(&px, w: w, h: h, x: 110, y: 30 + recoil, rw: 22, rh: 42, color: metalDark)
            // Barrel separation line
            fillRect(&px, w: w, h: h, x: 108, y: 30 + recoil, rw: 2, rh: 40, color: c(30, 30, 32))
            // Barrel openings
            fillCircle(&px, w: w, h: h, cx: 97, cy: 28 + recoil, r: 7, color: c(15, 15, 15))
            fillCircle(&px, w: w, h: h, cx: 121, cy: 28 + recoil, r: 7, color: c(15, 15, 15))
            // Barrel inner rim
            fillCircle(&px, w: w, h: h, cx: 97, cy: 28 + recoil, r: 5, color: c(25, 25, 28))
            fillCircle(&px, w: w, h: h, cx: 121, cy: 28 + recoil, r: 5, color: c(25, 25, 28))

            // Front sight
            fillRect(&px, w: w, h: h, x: 107, y: 24 + recoil, rw: 4, rh: 6, color: metalDark)

            // Muzzle flash
            if frame == 1 {
                for r in stride(from: 28, to: 0, by: -2) {
                    let intensity = Double(28 - r) / 28.0
                    let fr = Int(255.0 * intensity)
                    let fg = Int(210.0 * intensity * intensity)
                    let fb = Int(60.0 * intensity * intensity * intensity)
                    fillCircle(&px, w: w, h: h, cx: 109, cy: 12, r: r, color: c(fr, fg, fb))
                }
            }

            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Fist Weapon Sprites

    private static func generateFistSprites() -> SpriteSheet {
        let w = 192, h = 192
        var frames: [[UInt32]] = []

        for frame in 0..<4 {
            var px = [UInt32](repeating: T, count: w * h)
            let skin = c(195, 155, 125)
            let skinDark = c(165, 130, 100)
            let skinLight = c(215, 175, 145)

            let punch = frame == 1 ? -45 : (frame == 2 ? -25 : 0)
            let xShift = frame == 1 ? -8 : 0

            // Arm
            fillRect(&px, w: w, h: h, x: 68 + xShift, y: 120 + punch, rw: 56, rh: 72, color: skin)
            fillRect(&px, w: w, h: h, x: 70 + xShift, y: 122 + punch, rw: 4, rh: 68, color: skinDark)

            // Fist
            fillOval(&px, w: w, h: h, cx: 96 + xShift, cy: 105 + punch, rx: 30, ry: 18, color: skin)
            // Knuckles (top ridge)
            fillRect(&px, w: w, h: h, x: 68 + xShift, y: 88 + punch, rw: 56, rh: 6, color: skinLight)
            // Knuckle bumps
            for kx in stride(from: 72, to: 120, by: 14) {
                fillCircle(&px, w: w, h: h, cx: kx + xShift, cy: 90 + punch, r: 4, color: skinLight)
            }
            // Finger creases
            for fx in stride(from: 78, to: 116, by: 14) {
                fillRect(&px, w: w, h: h, x: fx + xShift, y: 94 + punch, rw: 2, rh: 20, color: skinDark)
            }
            // Thumb
            fillOval(&px, w: w, h: h, cx: 65 + xShift, cy: 100 + punch, rx: 8, ry: 12, color: skin)

            addOutline(&px, w: w, h: h, color: c(100, 75, 55))

            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Chaingun Sprites

    private static func generateChaingunSprites() -> SpriteSheet {
        let w = 192, h = 192
        var frames: [[UInt32]] = []

        // 3 frames: idle, fire-left, fire-right (alternating barrel flash)
        for frame in 0..<3 {
            var px = [UInt32](repeating: T, count: w * h)

            let gunMetal = c(80, 80, 85)
            let gunDark = c(55, 55, 60)
            let gunLight = c(100, 100, 105)
            let wood = c(100, 60, 25)
            let woodDark = c(80, 50, 20)

            // Dual barrels
            fillRect(&px, w: w, h: h, x: 82, y: 40, rw: 8, rh: 80, color: gunDark)
            fillRect(&px, w: w, h: h, x: 83, y: 42, rw: 6, rh: 76, color: gunMetal)
            fillRect(&px, w: w, h: h, x: 100, y: 40, rw: 8, rh: 80, color: gunDark)
            fillRect(&px, w: w, h: h, x: 101, y: 42, rw: 6, rh: 76, color: gunMetal)

            // Barrel clamp
            fillRect(&px, w: w, h: h, x: 80, y: 70, rw: 32, rh: 6, color: gunDark)
            fillRect(&px, w: w, h: h, x: 80, y: 100, rw: 32, rh: 6, color: gunDark)

            // Body/receiver
            fillRect(&px, w: w, h: h, x: 75, y: 115, rw: 42, rh: 20, color: gunMetal)
            fillRect(&px, w: w, h: h, x: 77, y: 117, rw: 38, rh: 16, color: gunLight)

            // Handle/grip
            fillRect(&px, w: w, h: h, x: 88, y: 135, rw: 16, rh: 45, color: wood)
            fillRect(&px, w: w, h: h, x: 90, y: 137, rw: 12, rh: 41, color: woodDark)

            // Muzzle flash on fire frames
            if frame == 1 {
                fillCircle(&px, w: w, h: h, cx: 86, cy: 35, r: 8, color: c(255, 200, 50))
                fillCircle(&px, w: w, h: h, cx: 86, cy: 35, r: 5, color: c(255, 255, 150))
            } else if frame == 2 {
                fillCircle(&px, w: w, h: h, cx: 104, cy: 35, r: 8, color: c(255, 200, 50))
                fillCircle(&px, w: w, h: h, cx: 104, cy: 35, r: 5, color: c(255, 255, 150))
            }

            addOutline(&px, w: w, h: h, color: c(30, 30, 32))
            frames.append(px)
        }
        return SpriteSheet(frames: frames, width: w, height: h)
    }

    // MARK: - Item Sprites

    private static func generateItemSprites() -> SpriteSheet {
        let w = 20, h = 20
        var frames: [[UInt32]] = []

        // Health pack
        var hp = [UInt32](repeating: T, count: w * h)
        fillRect(&hp, w: w, h: h, x: 2, y: 3, rw: 16, rh: 14, color: c(220, 220, 215))
        fillRect(&hp, w: w, h: h, x: 3, y: 4, rw: 14, rh: 12, color: c(240, 240, 235))
        fillRect(&hp, w: w, h: h, x: 9, y: 5, rw: 2, rh: 10, color: c(220, 30, 30))
        fillRect(&hp, w: w, h: h, x: 5, y: 9, rw: 10, rh: 2, color: c(220, 30, 30))
        addOutline(&hp, w: w, h: h, color: c(60, 60, 60))
        frames.append(hp)

        // Armor vest
        var av = [UInt32](repeating: T, count: w * h)
        fillOval(&av, w: w, h: h, cx: 10, cy: 9, rx: 8, ry: 8, color: c(40, 80, 190))
        fillOval(&av, w: w, h: h, cx: 10, cy: 8, rx: 6, ry: 6, color: c(60, 110, 220))
        fillRect(&av, w: w, h: h, x: 9, y: 5, rw: 2, rh: 7, color: c(100, 150, 255))
        fillRect(&av, w: w, h: h, x: 6, y: 9, rw: 8, rh: 2, color: c(100, 150, 255))
        addOutline(&av, w: w, h: h, color: c(20, 40, 100))
        frames.append(av)

        // Bullets
        var bl = [UInt32](repeating: T, count: w * h)
        fillRect(&bl, w: w, h: h, x: 3, y: 7, rw: 14, rh: 9, color: c(170, 150, 40))
        fillRect(&bl, w: w, h: h, x: 4, y: 8, rw: 12, rh: 7, color: c(190, 170, 50))
        for bx in stride(from: 5, to: 15, by: 3) {
            fillRect(&bl, w: w, h: h, x: bx, y: 4, rw: 2, rh: 4, color: c(200, 175, 55))
            fillRect(&bl, w: w, h: h, x: bx, y: 3, rw: 2, rh: 2, color: c(160, 100, 40))
        }
        addOutline(&bl, w: w, h: h, color: c(80, 70, 20))
        frames.append(bl)

        // Shells
        var sh = [UInt32](repeating: T, count: w * h)
        fillRect(&sh, w: w, h: h, x: 3, y: 7, rw: 14, rh: 9, color: c(150, 40, 35))
        fillRect(&sh, w: w, h: h, x: 4, y: 8, rw: 12, rh: 7, color: c(180, 55, 45))
        fillOval(&sh, w: w, h: h, cx: 7, cy: 5, rx: 3, ry: 3, color: c(195, 60, 50))
        fillOval(&sh, w: w, h: h, cx: 13, cy: 5, rx: 3, ry: 3, color: c(195, 60, 50))
        fillRect(&sh, w: w, h: h, x: 5, y: 3, rw: 4, rh: 1, color: c(160, 140, 40))
        fillRect(&sh, w: w, h: h, x: 11, y: 3, rw: 4, rh: 1, color: c(160, 140, 40))
        addOutline(&sh, w: w, h: h, color: c(80, 20, 15))
        frames.append(sh)

        // Shotgun pickup
        var sg = [UInt32](repeating: T, count: w * h)
        fillRect(&sg, w: w, h: h, x: 1, y: 8, rw: 18, rh: 3, color: c(70, 70, 75))
        fillRect(&sg, w: w, h: h, x: 1, y: 9, rw: 18, rh: 1, color: c(85, 85, 90))
        fillRect(&sg, w: w, h: h, x: 12, y: 8, rw: 7, rh: 5, color: c(110, 65, 28))
        fillRect(&sg, w: w, h: h, x: 13, y: 9, rw: 5, rh: 3, color: c(90, 55, 22))
        addOutline(&sg, w: w, h: h, color: c(30, 30, 32))
        frames.append(sg)

        // Chaingun pickup
        var cg = [UInt32](repeating: T, count: w * h)
        fillRect(&cg, w: w, h: h, x: 1, y: 7, rw: 18, rh: 3, color: c(60, 60, 65))
        fillRect(&cg, w: w, h: h, x: 1, y: 10, rw: 18, rh: 3, color: c(60, 60, 65))
        fillRect(&cg, w: w, h: h, x: 1, y: 8, rw: 18, rh: 1, color: c(90, 90, 95))
        fillRect(&cg, w: w, h: h, x: 1, y: 11, rw: 18, rh: 1, color: c(90, 90, 95))
        fillRect(&cg, w: w, h: h, x: 14, y: 7, rw: 5, rh: 6, color: c(100, 60, 25))
        addOutline(&cg, w: w, h: h, color: c(25, 25, 28))
        frames.append(cg)

        // Key card - Red
        var kr = [UInt32](repeating: T, count: w * h)
        fillRect(&kr, w: w, h: h, x: 4, y: 4, rw: 12, rh: 12, color: c(200, 30, 30))
        fillRect(&kr, w: w, h: h, x: 5, y: 5, rw: 10, rh: 10, color: c(240, 50, 50))
        fillCircle(&kr, w: w, h: h, cx: 10, cy: 8, r: 2, color: c(255, 180, 180))
        fillRect(&kr, w: w, h: h, x: 8, y: 10, rw: 5, rh: 2, color: c(255, 180, 180))
        addOutline(&kr, w: w, h: h, color: c(100, 15, 15))
        frames.append(kr)

        // Key card - Blue
        var kb = [UInt32](repeating: T, count: w * h)
        fillRect(&kb, w: w, h: h, x: 4, y: 4, rw: 12, rh: 12, color: c(30, 60, 200))
        fillRect(&kb, w: w, h: h, x: 5, y: 5, rw: 10, rh: 10, color: c(50, 80, 240))
        fillCircle(&kb, w: w, h: h, cx: 10, cy: 8, r: 2, color: c(180, 200, 255))
        fillRect(&kb, w: w, h: h, x: 8, y: 10, rw: 5, rh: 2, color: c(180, 200, 255))
        addOutline(&kb, w: w, h: h, color: c(15, 30, 100))
        frames.append(kb)

        // Key card - Yellow
        var ky = [UInt32](repeating: T, count: w * h)
        fillRect(&ky, w: w, h: h, x: 4, y: 4, rw: 12, rh: 12, color: c(200, 180, 30))
        fillRect(&ky, w: w, h: h, x: 5, y: 5, rw: 10, rh: 10, color: c(240, 220, 50))
        fillCircle(&ky, w: w, h: h, cx: 10, cy: 8, r: 2, color: c(255, 255, 180))
        fillRect(&ky, w: w, h: h, x: 8, y: 10, rw: 5, rh: 2, color: c(255, 255, 180))
        addOutline(&ky, w: w, h: h, color: c(100, 90, 15))
        frames.append(ky)

        // Berserk pack
        var bp = [UInt32](repeating: T, count: w * h)
        fillRect(&bp, w: w, h: h, x: 3, y: 4, rw: 14, rh: 12, color: c(60, 60, 60))
        fillRect(&bp, w: w, h: h, x: 4, y: 5, rw: 12, rh: 10, color: c(80, 10, 10))
        // Skull symbol
        fillCircle(&bp, w: w, h: h, cx: 10, cy: 9, r: 3, color: c(200, 200, 200))
        fillRect(&bp, w: w, h: h, x: 8, y: 11, rw: 4, rh: 2, color: c(200, 200, 200))
        addOutline(&bp, w: w, h: h, color: c(30, 5, 5))
        frames.append(bp)

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

        return SpriteSheet(frames: frames, width: w, height: h)
    }
}
