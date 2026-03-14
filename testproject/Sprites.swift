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

    // MARK: - Imp Sprites (horned demon monster, throws fireballs)

    private static func generateImpSprites() -> SpriteSheet {
        let w = 48, h = 64
        var frames: [[UInt32]] = []

        // Rich color palette for depth
        let skin = c(160, 55, 30)
        let skinDark = c(110, 35, 20)
        let skinDeep = c(80, 25, 15)
        let skinLight = c(190, 75, 45)
        let skinHi = c(215, 105, 60)
        let belly = c(175, 100, 65)
        let bellyDark = c(145, 75, 45)
        let eyeOuter = c(200, 160, 0)
        let eyeMid = c(255, 220, 0)
        let eyeCore = c(255, 255, 180)
        let hornBase = c(90, 50, 30)
        let hornMid = c(70, 35, 22)
        let hornTip = c(50, 25, 15)
        let mouth = c(60, 10, 5)
        let teeth = c(240, 235, 220)
        let claw = c(55, 28, 18)
        let blood = c(160, 10, 10)
        let bloodDark = c(110, 5, 5)
        let outline = c(40, 15, 8)

        for frame in 0..<10 {
            var px = [UInt32](repeating: T, count: w * h)
            let yOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? -1 : 1) : 0

            if frame <= 6 {
                let legSpread = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? 3 : -2) : 0

                // --- Legs with muscle shading ---
                // Left thigh + calf
                fillOval(&px, w: w, h: h, cx: 17 - legSpread, cy: 50 + yOff, rx: 5, ry: 5, color: skin)
                fillOval(&px, w: w, h: h, cx: 16 - legSpread, cy: 49 + yOff, rx: 3, ry: 3, color: skinLight)
                fillOval(&px, w: w, h: h, cx: 17 - legSpread, cy: 55 + yOff, rx: 4, ry: 5, color: skinDark)
                fillOval(&px, w: w, h: h, cx: 16 - legSpread, cy: 54 + yOff, rx: 2, ry: 3, color: skin)
                // Knee highlight
                fillRect(&px, w: w, h: h, x: 15 - legSpread, y: 52 + yOff, rw: 4, rh: 1, color: skinHi)
                // Right thigh + calf
                fillOval(&px, w: w, h: h, cx: 31 + legSpread, cy: 50 + yOff, rx: 5, ry: 5, color: skin)
                fillOval(&px, w: w, h: h, cx: 32 + legSpread, cy: 49 + yOff, rx: 3, ry: 3, color: skinLight)
                fillOval(&px, w: w, h: h, cx: 31 + legSpread, cy: 55 + yOff, rx: 4, ry: 5, color: skinDark)
                fillOval(&px, w: w, h: h, cx: 32 + legSpread, cy: 54 + yOff, rx: 2, ry: 3, color: skin)
                fillRect(&px, w: w, h: h, x: 29 + legSpread, y: 52 + yOff, rw: 4, rh: 1, color: skinHi)

                // Feet with individual toe claws
                fillOval(&px, w: w, h: h, cx: 16 - legSpread, cy: 60 + yOff, rx: 5, ry: 2, color: skinDark)
                fillOval(&px, w: w, h: h, cx: 32 + legSpread, cy: 60 + yOff, rx: 5, ry: 2, color: skinDark)
                for t in 0..<3 {
                    let lx = 13 - legSpread + t * 3
                    let rx = 29 + legSpread + t * 3
                    let fy = 61 + yOff
                    fillTriangle(&px, w: w, h: h, x0: lx, y0: fy, x1: lx + 2, y1: fy, x2: lx + 1, y2: min(63, fy + 2), color: claw)
                    fillTriangle(&px, w: w, h: h, x0: rx, y0: fy, x1: rx + 2, y1: fy, x2: rx + 1, y2: min(63, fy + 2), color: claw)
                }

                // --- Torso with musculature ---
                fillOval(&px, w: w, h: h, cx: 24, cy: 37 + yOff, rx: 12, ry: 14, color: skin)
                // Pectoral muscles
                fillOval(&px, w: w, h: h, cx: 20, cy: 30 + yOff, rx: 5, ry: 4, color: skinLight)
                fillOval(&px, w: w, h: h, cx: 28, cy: 30 + yOff, rx: 5, ry: 4, color: skinLight)
                fillOval(&px, w: w, h: h, cx: 20, cy: 31 + yOff, rx: 4, ry: 3, color: skinHi)
                fillOval(&px, w: w, h: h, cx: 28, cy: 31 + yOff, rx: 4, ry: 3, color: skinHi)
                // Center chest line
                drawLine(&px, w: w, h: h, x0: 24, y0: 26 + yOff, x1: 24, y1: 44 + yOff, color: skinDark)
                // Belly area
                fillOval(&px, w: w, h: h, cx: 24, cy: 40 + yOff, rx: 7, ry: 5, color: belly)
                fillOval(&px, w: w, h: h, cx: 24, cy: 42 + yOff, rx: 5, ry: 3, color: bellyDark)
                // Navel
                fillCircle(&px, w: w, h: h, cx: 24, cy: 42 + yOff, r: 1, color: skinDark)
                // Rib lines on sides
                for ribY in stride(from: 30, through: 38, by: 3) {
                    drawLine(&px, w: w, h: h, x0: 13, y0: ribY + yOff, x1: 18, y1: ribY + 1 + yOff, color: skinDark)
                    drawLine(&px, w: w, h: h, x0: 35, y0: ribY + yOff, x1: 30, y1: ribY + 1 + yOff, color: skinDark)
                }
                // Shoulder muscles
                fillOval(&px, w: w, h: h, cx: 13, cy: 27 + yOff, rx: 4, ry: 3, color: skin)
                fillOval(&px, w: w, h: h, cx: 12, cy: 26 + yOff, rx: 2, ry: 2, color: skinLight)
                fillOval(&px, w: w, h: h, cx: 35, cy: 27 + yOff, rx: 4, ry: 3, color: skin)
                fillOval(&px, w: w, h: h, cx: 36, cy: 26 + yOff, rx: 2, ry: 2, color: skinLight)

                // --- Head ---
                fillOval(&px, w: w, h: h, cx: 24, cy: 14 + yOff, rx: 10, ry: 9, color: skin)
                // Brow ridge — heavy, overhanging
                fillOval(&px, w: w, h: h, cx: 24, cy: 10 + yOff, rx: 9, ry: 2, color: skinDeep)
                fillOval(&px, w: w, h: h, cx: 24, cy: 9 + yOff, rx: 7, ry: 1, color: skinDark)
                // Cheekbones
                fillOval(&px, w: w, h: h, cx: 17, cy: 16 + yOff, rx: 3, ry: 2, color: skinLight)
                fillOval(&px, w: w, h: h, cx: 31, cy: 16 + yOff, rx: 3, ry: 2, color: skinLight)
                // Jaw line
                drawLine(&px, w: w, h: h, x0: 16, y0: 19 + yOff, x1: 24, y1: 21 + yOff, color: skinDark)
                drawLine(&px, w: w, h: h, x0: 32, y0: 19 + yOff, x1: 24, y1: 21 + yOff, color: skinDark)

                // Eyes — 3-layer glow
                fillCircle(&px, w: w, h: h, cx: 19, cy: 13 + yOff, r: 3, color: eyeOuter)
                fillCircle(&px, w: w, h: h, cx: 29, cy: 13 + yOff, r: 3, color: eyeOuter)
                fillCircle(&px, w: w, h: h, cx: 19, cy: 13 + yOff, r: 2, color: eyeMid)
                fillCircle(&px, w: w, h: h, cx: 29, cy: 13 + yOff, r: 2, color: eyeMid)
                fillCircle(&px, w: w, h: h, cx: 20, cy: 12 + yOff, r: 1, color: eyeCore)
                fillCircle(&px, w: w, h: h, cx: 30, cy: 12 + yOff, r: 1, color: eyeCore)

                // Mouth with prominent fangs
                fillOval(&px, w: w, h: h, cx: 24, cy: 19 + yOff, rx: 5, ry: 2, color: mouth)
                // Two large upper fangs
                fillTriangle(&px, w: w, h: h, x0: 20, y0: 18 + yOff, x1: 22, y1: 18 + yOff, x2: 21, y2: 22 + yOff, color: teeth)
                fillTriangle(&px, w: w, h: h, x0: 26, y0: 18 + yOff, x1: 28, y1: 18 + yOff, x2: 27, y2: 22 + yOff, color: teeth)
                // Small teeth between fangs
                for tx in [23, 25] {
                    let ty = 18 + yOff
                    if ty >= 0 && ty < h && tx < w { px[ty * w + tx] = teeth }
                    if ty + 1 >= 0 && ty + 1 < h && tx < w { px[(ty + 1) * w + tx] = teeth }
                }

                // Horns — curved triangular shapes
                // Left horn (curves outward-left)
                fillTriangle(&px, w: w, h: h, x0: 15, y0: 8 + yOff, x1: 17, y1: 7 + yOff, x2: 9, y2: 0, color: hornBase)
                drawLine(&px, w: w, h: h, x0: 15, y0: 7 + yOff, x1: 10, y1: 1, color: hornMid)
                drawLine(&px, w: w, h: h, x0: 9, y0: 0, x1: 7, y1: 1, color: hornTip)
                // Right horn (curves outward-right)
                fillTriangle(&px, w: w, h: h, x0: 31, y0: 8 + yOff, x1: 33, y1: 7 + yOff, x2: 39, y2: 0, color: hornBase)
                drawLine(&px, w: w, h: h, x0: 33, y0: 7 + yOff, x1: 38, y1: 1, color: hornMid)
                drawLine(&px, w: w, h: h, x0: 39, y0: 0, x1: 41, y1: 1, color: hornTip)

                // --- Arms ---
                if frame == 4 || frame == 5 {
                    // Attack: right arm extended with fireball
                    fillOval(&px, w: w, h: h, cx: 37, cy: 30 + yOff, rx: 4, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 42, cy: 28 + yOff, rx: 4, ry: 3, color: skinDark)
                    // Clawed fingers spread
                    for f in 0..<3 {
                        let fy = 26 + yOff + f * 2
                        fillRect(&px, w: w, h: h, x: 44, y: fy, rw: 3, rh: 2, color: skinDark)
                        if fy >= 0 && fy < h { px[fy * w + min(47, w - 1)] = claw }
                    }
                    if frame == 5 {
                        // Fireball — layered glow with energy wisps
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 27 + yOff, r: 6, color: c(180, 50, 0))
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 27 + yOff, r: 4, color: c(220, 100, 0))
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 27 + yOff, r: 3, color: c(255, 180, 30))
                        fillCircle(&px, w: w, h: h, cx: 46, cy: 27 + yOff, r: 1, color: c(255, 255, 200))
                        drawLine(&px, w: w, h: h, x0: 42, y0: 24 + yOff, x1: 44, y1: 22 + yOff, color: c(255, 150, 30))
                        drawLine(&px, w: w, h: h, x0: 47, y0: 22 + yOff, x1: 46, y1: 24 + yOff, color: c(255, 150, 30))
                    }
                    // Left arm at side
                    fillOval(&px, w: w, h: h, cx: 9, cy: 33 + yOff, rx: 3, ry: 7, color: skin)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 39 + yOff, rx: 3, ry: 3, color: skinDark)
                    for f in 0..<3 { let fy = 41 + yOff + f; if fy >= 0 && fy < h && 6 + f < w { px[fy * w + 7] = claw } }
                } else {
                    // Arms at sides with detailed claws
                    fillOval(&px, w: w, h: h, cx: 9, cy: 33 + yOff, rx: 3, ry: 7, color: skin)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 32 + yOff, rx: 2, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 39 + yOff, rx: 3, ry: 3, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 39, cy: 33 + yOff, rx: 3, ry: 7, color: skin)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 32 + yOff, rx: 2, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 39 + yOff, rx: 3, ry: 3, color: skinDark)
                    // Individual claws
                    for clx in [6, 8, 10] {
                        let cy = 42 + yOff
                        if cy >= 0 && cy < h && clx < w { px[cy * w + clx] = claw }
                        if cy + 1 < h && clx < w { px[(cy + 1) * w + clx] = claw }
                    }
                    for clx in [38, 40, 42] {
                        let cy = 42 + yOff
                        if cy >= 0 && cy < h && clx < w { px[cy * w + clx] = claw }
                        if cy + 1 < h && clx < w { px[(cy + 1) * w + clx] = claw }
                    }
                }

                if frame == 6 {
                    for i in 0..<px.count where px[i] != T { px[i] = brighten(px[i], 90) }
                }

                addNoise(&px, w: w, h: h, intensity: 8, seed: frame)
                addOutline(&px, w: w, h: h, color: outline)
            } else {
                // Death sequence
                let progress = frame - 7
                if progress == 0 {
                    // Recoil — staggering back, fully detailed imp leaning back
                    // Legs buckling
                    fillOval(&px, w: w, h: h, cx: 17, cy: 52, rx: 5, ry: 7, color: skin)
                    fillOval(&px, w: w, h: h, cx: 16, cy: 51, rx: 3, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 17, cy: 57, rx: 4, ry: 5, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 31, cy: 52, rx: 5, ry: 7, color: skin)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 51, rx: 3, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 31, cy: 57, rx: 4, ry: 5, color: skinDark)
                    // Feet with claws
                    fillOval(&px, w: w, h: h, cx: 16, cy: 61, rx: 5, ry: 2, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 61, rx: 5, ry: 2, color: skinDark)
                    for t in 0..<3 {
                        fillTriangle(&px, w: w, h: h, x0: 13 + t * 3, y0: 62, x1: 15 + t * 3, y1: 62, x2: 14 + t * 3, y2: 63, color: claw)
                        fillTriangle(&px, w: w, h: h, x0: 29 + t * 3, y0: 62, x1: 31 + t * 3, y1: 62, x2: 30 + t * 3, y2: 63, color: claw)
                    }
                    // Torso leaning back (shifted right)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 38, rx: 12, ry: 13, color: skin)
                    fillOval(&px, w: w, h: h, cx: 22, cy: 32, rx: 5, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 32, rx: 5, ry: 4, color: skinLight)
                    drawLine(&px, w: w, h: h, x0: 26, y0: 28, x1: 26, y1: 44, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 42, rx: 7, ry: 5, color: belly)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 44, rx: 5, ry: 3, color: bellyDark)
                    fillCircle(&px, w: w, h: h, cx: 26, cy: 43, r: 1, color: skinDark)
                    // Rib lines
                    for ribY in stride(from: 32, through: 40, by: 3) {
                        drawLine(&px, w: w, h: h, x0: 15, y0: ribY, x1: 20, y1: ribY + 1, color: skinDark)
                        drawLine(&px, w: w, h: h, x0: 37, y0: ribY, x1: 32, y1: ribY + 1, color: skinDark)
                    }
                    // Shoulders
                    fillOval(&px, w: w, h: h, cx: 15, cy: 29, rx: 4, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 37, cy: 29, rx: 4, ry: 3, color: skin)
                    // Arms flung out
                    fillOval(&px, w: w, h: h, cx: 9, cy: 35, rx: 3, ry: 7, color: skin)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 34, rx: 2, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 41, rx: 3, ry: 3, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 41, cy: 33, rx: 3, ry: 6, color: skin)
                    fillOval(&px, w: w, h: h, cx: 42, cy: 32, rx: 2, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 42, cy: 39, rx: 3, ry: 3, color: skinDark)
                    // Claws on hands
                    for clx in [6, 8, 10] { let cy2 = 44; if cy2 < h && clx < w { px[cy2 * w + clx] = claw } }
                    for clx in [40, 42, 44] { let cy2 = 42; if cy2 < h && clx < w { px[cy2 * w + clx] = claw } }
                    // Head tilted back
                    fillOval(&px, w: w, h: h, cx: 26, cy: 16, rx: 10, ry: 9, color: skin)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 12, rx: 9, ry: 2, color: skinDeep)
                    fillOval(&px, w: w, h: h, cx: 19, cy: 18, rx: 3, ry: 2, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 33, cy: 18, rx: 3, ry: 2, color: skinLight)
                    drawLine(&px, w: w, h: h, x0: 18, y0: 21, x1: 26, y1: 23, color: skinDark)
                    drawLine(&px, w: w, h: h, x0: 34, y0: 21, x1: 26, y1: 23, color: skinDark)
                    // Eyes — wide open in pain
                    fillCircle(&px, w: w, h: h, cx: 21, cy: 15, r: 3, color: eyeOuter)
                    fillCircle(&px, w: w, h: h, cx: 31, cy: 15, r: 3, color: eyeOuter)
                    fillCircle(&px, w: w, h: h, cx: 21, cy: 15, r: 2, color: eyeMid)
                    fillCircle(&px, w: w, h: h, cx: 31, cy: 15, r: 2, color: eyeMid)
                    // Mouth open in agony
                    fillOval(&px, w: w, h: h, cx: 26, cy: 20, rx: 5, ry: 3, color: mouth)
                    fillTriangle(&px, w: w, h: h, x0: 22, y0: 19, x1: 24, y1: 19, x2: 23, y2: 23, color: teeth)
                    fillTriangle(&px, w: w, h: h, x0: 28, y0: 19, x1: 30, y1: 19, x2: 29, y2: 23, color: teeth)
                    // Horns
                    fillTriangle(&px, w: w, h: h, x0: 17, y0: 10, x1: 19, y1: 9, x2: 11, y2: 2, color: hornBase)
                    drawLine(&px, w: w, h: h, x0: 17, y0: 9, x1: 12, y1: 3, color: hornMid)
                    fillTriangle(&px, w: w, h: h, x0: 33, y0: 10, x1: 35, y1: 9, x2: 41, y2: 2, color: hornBase)
                    drawLine(&px, w: w, h: h, x0: 35, y0: 9, x1: 40, y1: 3, color: hornMid)
                    // Blood eruption from chest wound
                    fillCircle(&px, w: w, h: h, cx: 24, cy: 34, r: 5, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 20, cy: 30, r: 3, color: blood)
                    drawLine(&px, w: w, h: h, x0: 22, y0: 28, x1: 18, y1: 22, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 28, cy: 32, r: 2, color: bloodDark)
                    addNoise(&px, w: w, h: h, intensity: 8, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
                } else if progress == 1 {
                    // Falling — toppling to the right, detailed body
                    // Legs crumpling left
                    fillOval(&px, w: w, h: h, cx: 12, cy: 56, rx: 5, ry: 4, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 11, cy: 55, rx: 3, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 14, cy: 52, rx: 4, ry: 5, color: skin)
                    fillOval(&px, w: w, h: h, cx: 13, cy: 51, rx: 2, ry: 3, color: skinLight)
                    // Foot/claws
                    fillOval(&px, w: w, h: h, cx: 10, cy: 60, rx: 4, ry: 2, color: skinDark)
                    for t in 0..<3 { fillTriangle(&px, w: w, h: h, x0: 7 + t * 3, y0: 61, x1: 9 + t * 3, y1: 61, x2: 8 + t * 3, y2: 63, color: claw) }
                    // Torso tilting right with muscle detail
                    fillOval(&px, w: w, h: h, cx: 26, cy: 44, rx: 11, ry: 10, color: skin)
                    fillOval(&px, w: w, h: h, cx: 22, cy: 40, rx: 5, ry: 4, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 40, rx: 5, ry: 4, color: skinLight)
                    drawLine(&px, w: w, h: h, x0: 26, y0: 36, x1: 26, y1: 50, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 48, rx: 6, ry: 4, color: belly)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 49, rx: 4, ry: 2, color: bellyDark)
                    // Rib lines
                    for ribY in stride(from: 38, through: 46, by: 3) {
                        drawLine(&px, w: w, h: h, x0: 16, y0: ribY, x1: 20, y1: ribY + 1, color: skinDark)
                    }
                    // Arm trailing
                    fillOval(&px, w: w, h: h, cx: 16, cy: 48, rx: 3, ry: 4, color: skin)
                    fillOval(&px, w: w, h: h, cx: 15, cy: 52, rx: 2, ry: 2, color: skinDark)
                    // Head falling right
                    fillOval(&px, w: w, h: h, cx: 36, cy: 34, rx: 7, ry: 6, color: skin)
                    fillOval(&px, w: w, h: h, cx: 36, cy: 31, rx: 6, ry: 2, color: skinDeep)
                    fillOval(&px, w: w, h: h, cx: 33, cy: 36, rx: 2, ry: 2, color: skinLight)
                    // Eye dimming
                    fillCircle(&px, w: w, h: h, cx: 38, cy: 33, r: 2, color: eyeOuter)
                    fillCircle(&px, w: w, h: h, cx: 38, cy: 33, r: 1, color: eyeMid)
                    // Mouth slack
                    fillOval(&px, w: w, h: h, cx: 37, cy: 38, rx: 3, ry: 2, color: mouth)
                    fillTriangle(&px, w: w, h: h, x0: 35, y0: 37, x1: 37, y1: 37, x2: 36, y2: 40, color: teeth)
                    // Horns
                    fillTriangle(&px, w: w, h: h, x0: 40, y0: 30, x1: 42, y1: 30, x2: 44, y2: 25, color: hornBase)
                    drawLine(&px, w: w, h: h, x0: 41, y0: 29, x1: 43, y1: 26, color: hornMid)
                    fillTriangle(&px, w: w, h: h, x0: 30, y0: 30, x1: 32, y1: 29, x2: 28, y2: 25, color: hornBase)
                    // Blood from wound
                    fillCircle(&px, w: w, h: h, cx: 24, cy: 42, r: 4, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 22, cy: 46, r: 3, color: bloodDark)
                    drawLine(&px, w: w, h: h, x0: 24, y0: 46, x1: 22, y1: 52, color: blood)
                    addNoise(&px, w: w, h: h, intensity: 8, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
                } else {
                    // Corpse — lying on side, recognizable as imp
                    // Blood pool under body
                    fillOval(&px, w: w, h: h, cx: 24, cy: 58, rx: 16, ry: 3, color: c(120, 5, 5))
                    // Legs (left side, bent)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 52, rx: 4, ry: 5, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 9, cy: 51, rx: 2, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 10, cy: 48, rx: 3, ry: 4, color: skin)
                    fillOval(&px, w: w, h: h, cx: 9, cy: 47, rx: 2, ry: 2, color: skinLight)
                    // Foot with claws
                    fillOval(&px, w: w, h: h, cx: 6, cy: 56, rx: 3, ry: 2, color: skinDark)
                    for t in 0..<2 { fillTriangle(&px, w: w, h: h, x0: 4 + t * 3, y0: 57, x1: 6 + t * 3, y1: 57, x2: 5 + t * 3, y2: 59, color: claw) }
                    // Torso lying on side with muscle detail
                    fillOval(&px, w: w, h: h, cx: 24, cy: 50, rx: 12, ry: 8, color: skin)
                    fillOval(&px, w: w, h: h, cx: 22, cy: 47, rx: 5, ry: 3, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 28, cy: 47, rx: 5, ry: 3, color: skinLight)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 48, rx: 8, ry: 4, color: belly)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 54, rx: 10, ry: 3, color: skinDark)
                    drawLine(&px, w: w, h: h, x0: 24, y0: 44, x1: 24, y1: 56, color: skinDark)
                    // Rib lines visible on side
                    for ribY in stride(from: 46, through: 52, by: 3) {
                        drawLine(&px, w: w, h: h, x0: 13, y0: ribY, x1: 17, y1: ribY, color: skinDark)
                    }
                    // Arm draped forward with claws
                    fillOval(&px, w: w, h: h, cx: 30, cy: 54, rx: 4, ry: 2, color: skin)
                    fillOval(&px, w: w, h: h, cx: 33, cy: 55, rx: 2, ry: 2, color: skinDark)
                    for clx in [32, 34, 36] { let cy2 = 57; if cy2 < h && clx < w { px[cy2 * w + clx] = claw } }
                    // Head on right side
                    fillOval(&px, w: w, h: h, cx: 38, cy: 48, rx: 5, ry: 5, color: skin)
                    fillOval(&px, w: w, h: h, cx: 38, cy: 45, rx: 4, ry: 2, color: skinDeep)
                    fillOval(&px, w: w, h: h, cx: 38, cy: 50, rx: 4, ry: 2, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 35, cy: 49, rx: 2, ry: 1, color: skinLight)
                    // Closed eye (line)
                    drawLine(&px, w: w, h: h, x0: 39, y0: 47, x1: 42, y1: 47, color: skinDeep)
                    // Slack mouth with fang
                    fillOval(&px, w: w, h: h, cx: 40, cy: 51, rx: 2, ry: 1, color: mouth)
                    fillTriangle(&px, w: w, h: h, x0: 40, y0: 50, x1: 41, y1: 50, x2: 41, y2: 53, color: teeth)
                    // Horn sticking up
                    fillTriangle(&px, w: w, h: h, x0: 39, y0: 44, x1: 41, y1: 44, x2: 43, y2: 38, color: hornBase)
                    fillTriangle(&px, w: w, h: h, x0: 40, y0: 43, x1: 41, y1: 43, x2: 43, y2: 39, color: hornMid)
                    drawLine(&px, w: w, h: h, x0: 42, y0: 39, x1: 43, y1: 38, color: hornTip)
                    // Other horn flat on ground
                    drawLine(&px, w: w, h: h, x0: 36, y0: 44, x1: 32, y1: 43, color: hornBase)
                    // Blood stain on torso
                    fillCircle(&px, w: w, h: h, cx: 22, cy: 49, r: 3, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 20, cy: 51, r: 2, color: bloodDark)
                    addNoise(&px, w: w, h: h, intensity: 8, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
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

        // Rich palette for a hulking pink/brown beast
        let body = c(170, 90, 110)
        let bodyDark = c(120, 55, 70)
        let bodyDeep = c(85, 35, 50)
        let bodyLight = c(200, 120, 140)
        let bodyHi = c(220, 145, 160)
        let underside = c(190, 130, 130)
        let eyeOuter = c(180, 10, 0)
        let eyeMid = c(255, 30, 0)
        let eyeCore = c(255, 120, 60)
        let tooth = c(240, 235, 220)
        let toothDark = c(200, 195, 180)
        let gum = c(100, 20, 30)
        let hoof = c(55, 30, 20)
        let hoofLight = c(75, 45, 30)
        let spineColor = c(140, 65, 80)
        let blood = c(160, 10, 10)
        let bloodDark = c(110, 5, 5)
        let drool = c(180, 170, 150)
        let outline = c(50, 20, 30)

        for frame in 0..<10 {
            var px = [UInt32](repeating: T, count: w * h)
            let yOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? -2 : 2) : 0

            if frame <= 6 {
                // --- Massive hunched body ---
                fillOval(&px, w: w, h: h, cx: 32, cy: 34 + yOff, rx: 22, ry: 18, color: body)
                // Upper back/shoulders — lighter highlight
                fillOval(&px, w: w, h: h, cx: 32, cy: 26 + yOff, rx: 18, ry: 10, color: bodyLight)
                fillOval(&px, w: w, h: h, cx: 30, cy: 24 + yOff, rx: 12, ry: 6, color: bodyHi)
                // Belly — darker underside
                fillOval(&px, w: w, h: h, cx: 32, cy: 42 + yOff, rx: 14, ry: 7, color: bodyDark)
                fillOval(&px, w: w, h: h, cx: 32, cy: 44 + yOff, rx: 10, ry: 4, color: underside)
                // Muscle definition on chest
                drawLine(&px, w: w, h: h, x0: 32, y0: 22 + yOff, x1: 32, y1: 42 + yOff, color: bodyDark)
                fillOval(&px, w: w, h: h, cx: 26, cy: 28 + yOff, rx: 5, ry: 4, color: bodyHi)
                fillOval(&px, w: w, h: h, cx: 38, cy: 28 + yOff, rx: 5, ry: 4, color: bodyHi)
                // Spine ridges along back (visible bumps)
                for sy in stride(from: 20, through: 36, by: 4) {
                    fillOval(&px, w: w, h: h, cx: 32, cy: sy + yOff, rx: 3, ry: 2, color: spineColor)
                    fillRect(&px, w: w, h: h, x: 31, y: sy - 1 + yOff, rw: 2, rh: 1, color: bodyHi)
                }

                // --- Head with snout/jaw ---
                fillOval(&px, w: w, h: h, cx: 32, cy: 12 + yOff, rx: 13, ry: 10, color: body)
                // Brow ridge — heavy overhanging
                fillOval(&px, w: w, h: h, cx: 32, cy: 7 + yOff, rx: 11, ry: 3, color: bodyDark)
                fillOval(&px, w: w, h: h, cx: 32, cy: 6 + yOff, rx: 9, ry: 2, color: bodyDeep)
                // Snout/muzzle area
                fillOval(&px, w: w, h: h, cx: 32, cy: 16 + yOff, rx: 8, ry: 4, color: bodyDark)
                // Cheek muscles
                fillOval(&px, w: w, h: h, cx: 22, cy: 13 + yOff, rx: 4, ry: 3, color: bodyLight)
                fillOval(&px, w: w, h: h, cx: 42, cy: 13 + yOff, rx: 4, ry: 3, color: bodyLight)

                // Eyes — deep set, glowing red
                fillCircle(&px, w: w, h: h, cx: 25, cy: 10 + yOff, r: 3, color: eyeOuter)
                fillCircle(&px, w: w, h: h, cx: 39, cy: 10 + yOff, r: 3, color: eyeOuter)
                fillCircle(&px, w: w, h: h, cx: 25, cy: 10 + yOff, r: 2, color: eyeMid)
                fillCircle(&px, w: w, h: h, cx: 39, cy: 10 + yOff, r: 2, color: eyeMid)
                fillCircle(&px, w: w, h: h, cx: 26, cy: 9 + yOff, r: 1, color: eyeCore)
                fillCircle(&px, w: w, h: h, cx: 40, cy: 9 + yOff, r: 1, color: eyeCore)

                // Mouth — closed jaw with visible fangs
                fillOval(&px, w: w, h: h, cx: 32, cy: 18 + yOff, rx: 7, ry: 2, color: gum)
                // Large upper fangs
                fillTriangle(&px, w: w, h: h, x0: 24, y0: 17 + yOff, x1: 26, y1: 17 + yOff, x2: 25, y2: 22 + yOff, color: tooth)
                fillTriangle(&px, w: w, h: h, x0: 38, y0: 17 + yOff, x1: 40, y1: 17 + yOff, x2: 39, y2: 22 + yOff, color: tooth)
                // Smaller teeth
                for tx in stride(from: 28, to: 37, by: 3) {
                    fillTriangle(&px, w: w, h: h, x0: tx, y0: 17 + yOff, x1: tx + 2, y1: 17 + yOff, x2: tx + 1, y2: 20 + yOff, color: toothDark)
                }

                // --- Powerful legs ---
                let legOff = (frame >= 1 && frame <= 3) ? (frame % 2) * 3 : 0
                // Front-left
                fillOval(&px, w: w, h: h, cx: 16 + legOff, cy: 50 + yOff, rx: 5, ry: 6, color: body)
                fillOval(&px, w: w, h: h, cx: 15 + legOff, cy: 49 + yOff, rx: 3, ry: 3, color: bodyLight)
                fillOval(&px, w: w, h: h, cx: 16 + legOff, cy: 55 + yOff, rx: 4, ry: 5, color: bodyDark)
                // Front-right
                fillOval(&px, w: w, h: h, cx: 48 - legOff, cy: 50 + yOff, rx: 5, ry: 6, color: body)
                fillOval(&px, w: w, h: h, cx: 49 - legOff, cy: 49 + yOff, rx: 3, ry: 3, color: bodyLight)
                fillOval(&px, w: w, h: h, cx: 48 - legOff, cy: 55 + yOff, rx: 4, ry: 5, color: bodyDark)
                // Inner legs (partially hidden)
                fillOval(&px, w: w, h: h, cx: 27, cy: 51 + yOff, rx: 4, ry: 6, color: bodyDark)
                fillOval(&px, w: w, h: h, cx: 37, cy: 51 + yOff, rx: 4, ry: 6, color: bodyDark)

                // Hooves with claws
                for lx in [16 + legOff, 27, 37, 48 - legOff] {
                    fillOval(&px, w: w, h: h, cx: lx, cy: 60 + yOff, rx: 5, ry: 2, color: hoof)
                    fillRect(&px, w: w, h: h, x: lx - 3, y: 59 + yOff, rw: 6, rh: 1, color: hoofLight)
                    // Toe claws
                    for t in 0..<2 {
                        let tx = lx - 2 + t * 4
                        fillTriangle(&px, w: w, h: h, x0: tx, y0: 61 + yOff, x1: tx + 2, y1: 61 + yOff, x2: tx + 1, y2: min(63, 63 + yOff), color: hoof)
                    }
                }

                // --- Attack frames ---
                if frame == 4 || frame == 5 {
                    // Jaws gaping wide — upper and lower jaw separated
                    fillOval(&px, w: w, h: h, cx: 32, cy: 15 + yOff, rx: 9, ry: 3, color: gum)
                    fillRect(&px, w: w, h: h, x: 23, y: 16 + yOff, rw: 18, rh: 8, color: c(80, 10, 10))
                    // Upper fangs row
                    for tx in stride(from: 24, to: 40, by: 4) {
                        fillTriangle(&px, w: w, h: h, x0: tx, y0: 16 + yOff, x1: tx + 2, y1: 16 + yOff, x2: tx + 1, y2: 20 + yOff, color: tooth)
                    }
                    // Lower fangs row
                    for tx in stride(from: 26, to: 38, by: 4) {
                        fillTriangle(&px, w: w, h: h, x0: tx, y0: 24 + yOff, x1: tx + 2, y1: 24 + yOff, x2: tx + 1, y2: 21 + yOff, color: toothDark)
                    }
                    if frame == 5 {
                        // Drool/saliva strings
                        drawLine(&px, w: w, h: h, x0: 28, y0: 20 + yOff, x1: 29, y1: 28 + yOff, color: drool)
                        drawLine(&px, w: w, h: h, x0: 35, y0: 20 + yOff, x1: 34, y1: 26 + yOff, color: drool)
                        // Blood splatter
                        fillCircle(&px, w: w, h: h, cx: 32, cy: 26 + yOff, r: 2, color: blood)
                    }
                }

                if frame == 6 {
                    for i in 0..<px.count where px[i] != T { px[i] = brighten(px[i], 90) }
                }

                addNoise(&px, w: w, h: h, intensity: 10, seed: frame)
                addOutline(&px, w: w, h: h, color: outline)
            } else {
                // Death sequence
                let progress = frame - 7
                if progress == 0 {
                    // Recoil — staggering back, fully detailed demon
                    // Legs buckling with muscle detail
                    fillOval(&px, w: w, h: h, cx: 18, cy: 52, rx: 5, ry: 6, color: body)
                    fillOval(&px, w: w, h: h, cx: 17, cy: 51, rx: 3, ry: 3, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 18, cy: 57, rx: 4, ry: 5, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 48, cy: 52, rx: 5, ry: 6, color: body)
                    fillOval(&px, w: w, h: h, cx: 49, cy: 51, rx: 3, ry: 3, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 48, cy: 57, rx: 4, ry: 5, color: bodyDark)
                    // Inner legs
                    fillOval(&px, w: w, h: h, cx: 27, cy: 53, rx: 4, ry: 6, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 37, cy: 53, rx: 4, ry: 6, color: bodyDark)
                    // Hooves
                    for lx in [18, 27, 37, 48] {
                        fillOval(&px, w: w, h: h, cx: lx, cy: 61, rx: 5, ry: 2, color: hoof)
                        fillRect(&px, w: w, h: h, x: lx - 3, y: 60, rw: 6, rh: 1, color: hoofLight)
                    }
                    // Massive body leaning back
                    fillOval(&px, w: w, h: h, cx: 34, cy: 34, rx: 22, ry: 18, color: body)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 26, rx: 18, ry: 10, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 24, rx: 12, ry: 6, color: bodyHi)
                    // Belly
                    fillOval(&px, w: w, h: h, cx: 34, cy: 42, rx: 14, ry: 7, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 44, rx: 10, ry: 4, color: underside)
                    // Muscle definition
                    drawLine(&px, w: w, h: h, x0: 34, y0: 22, x1: 34, y1: 42, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 28, cy: 28, rx: 5, ry: 4, color: bodyHi)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 28, rx: 5, ry: 4, color: bodyHi)
                    // Spine ridges
                    for sy in stride(from: 20, through: 36, by: 4) {
                        fillOval(&px, w: w, h: h, cx: 34, cy: sy, rx: 3, ry: 2, color: spineColor)
                    }
                    // Head with full detail
                    fillOval(&px, w: w, h: h, cx: 34, cy: 12, rx: 13, ry: 10, color: body)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 7, rx: 11, ry: 3, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 6, rx: 9, ry: 2, color: bodyDeep)
                    // Cheekbones
                    fillOval(&px, w: w, h: h, cx: 24, cy: 13, rx: 4, ry: 3, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 44, cy: 13, rx: 4, ry: 3, color: bodyLight)
                    // Eyes wide in agony
                    fillCircle(&px, w: w, h: h, cx: 27, cy: 10, r: 3, color: eyeOuter)
                    fillCircle(&px, w: w, h: h, cx: 41, cy: 10, r: 3, color: eyeOuter)
                    fillCircle(&px, w: w, h: h, cx: 27, cy: 10, r: 2, color: eyeMid)
                    fillCircle(&px, w: w, h: h, cx: 41, cy: 10, r: 2, color: eyeMid)
                    // Mouth gaping in pain with fangs
                    fillOval(&px, w: w, h: h, cx: 34, cy: 17, rx: 8, ry: 4, color: gum)
                    fillRect(&px, w: w, h: h, x: 26, y: 16, rw: 16, rh: 6, color: c(80, 10, 10))
                    for tx in stride(from: 27, to: 42, by: 4) {
                        fillTriangle(&px, w: w, h: h, x0: tx, y0: 16, x1: tx + 2, y1: 16, x2: tx + 1, y2: 19, color: tooth)
                    }
                    // Blood eruption from chest
                    fillCircle(&px, w: w, h: h, cx: 32, cy: 30, r: 6, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 28, cy: 26, r: 3, color: bloodDark)
                    drawLine(&px, w: w, h: h, x0: 30, y0: 24, x1: 26, y1: 18, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 36, cy: 28, r: 2, color: bloodDark)
                    addNoise(&px, w: w, h: h, intensity: 10, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
                } else if progress == 1 {
                    // Collapsing — toppling to the right, detailed
                    // Hind legs buckling left
                    fillOval(&px, w: w, h: h, cx: 12, cy: 56, rx: 6, ry: 5, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 11, cy: 55, rx: 3, ry: 3, color: body)
                    fillOval(&px, w: w, h: h, cx: 16, cy: 52, rx: 5, ry: 6, color: body)
                    fillOval(&px, w: w, h: h, cx: 15, cy: 51, rx: 3, ry: 3, color: bodyLight)
                    // Hooves
                    fillOval(&px, w: w, h: h, cx: 10, cy: 60, rx: 4, ry: 2, color: hoof)
                    fillOval(&px, w: w, h: h, cx: 18, cy: 58, rx: 3, ry: 2, color: hoof)
                    // Massive body tilting with detail
                    fillOval(&px, w: w, h: h, cx: 34, cy: 44, rx: 20, ry: 12, color: body)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 40, rx: 14, ry: 8, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 38, rx: 8, ry: 4, color: bodyHi)
                    // Belly underside
                    fillOval(&px, w: w, h: h, cx: 34, cy: 50, rx: 12, ry: 5, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 51, rx: 8, ry: 3, color: underside)
                    // Muscle/chest line
                    drawLine(&px, w: w, h: h, x0: 34, y0: 34, x1: 34, y1: 50, color: bodyDark)
                    // Spine ridges visible
                    for sx in stride(from: 26, through: 42, by: 4) {
                        fillOval(&px, w: w, h: h, cx: sx, cy: 35, rx: 2, ry: 1, color: spineColor)
                    }
                    // Head dropping right with detail
                    fillOval(&px, w: w, h: h, cx: 52, cy: 38, rx: 9, ry: 8, color: body)
                    fillOval(&px, w: w, h: h, cx: 52, cy: 34, rx: 8, ry: 3, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 48, cy: 39, rx: 3, ry: 2, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 56, cy: 39, rx: 3, ry: 2, color: bodyLight)
                    // Eye dimming
                    fillCircle(&px, w: w, h: h, cx: 55, cy: 36, r: 2, color: eyeOuter)
                    fillCircle(&px, w: w, h: h, cx: 55, cy: 36, r: 1, color: eyeMid)
                    // Jaw slack with fang
                    fillOval(&px, w: w, h: h, cx: 54, cy: 43, rx: 5, ry: 2, color: gum)
                    fillTriangle(&px, w: w, h: h, x0: 51, y0: 42, x1: 53, y1: 42, x2: 52, y2: 46, color: tooth)
                    fillTriangle(&px, w: w, h: h, x0: 55, y0: 42, x1: 57, y1: 42, x2: 56, y2: 45, color: toothDark)
                    // Drool
                    drawLine(&px, w: w, h: h, x0: 54, y0: 44, x1: 55, y1: 48, color: drool)
                    // Blood wound
                    fillCircle(&px, w: w, h: h, cx: 32, cy: 42, r: 6, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 28, cy: 46, r: 3, color: bloodDark)
                    drawLine(&px, w: w, h: h, x0: 30, y0: 46, x1: 28, y1: 52, color: blood)
                    addNoise(&px, w: w, h: h, intensity: 10, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
                } else {
                    // Corpse — massive body on its side, recognizable as demon
                    // Blood pool under body
                    fillOval(&px, w: w, h: h, cx: 32, cy: 58, rx: 22, ry: 3, color: c(120, 5, 5))
                    // Hind legs (left side) with detail
                    fillOval(&px, w: w, h: h, cx: 8, cy: 52, rx: 5, ry: 5, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 7, cy: 51, rx: 3, ry: 3, color: body)
                    fillOval(&px, w: w, h: h, cx: 10, cy: 48, rx: 4, ry: 4, color: body)
                    fillOval(&px, w: w, h: h, cx: 9, cy: 47, rx: 2, ry: 2, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 6, cy: 56, rx: 3, ry: 2, color: hoof)
                    fillOval(&px, w: w, h: h, cx: 12, cy: 54, rx: 3, ry: 2, color: hoof)
                    // Body lying on side (tall, bulky)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 50, rx: 18, ry: 10, color: body)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 46, rx: 12, ry: 6, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 28, cy: 44, rx: 8, ry: 4, color: bodyHi)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 54, rx: 14, ry: 4, color: bodyDark)
                    // Muscle definition
                    drawLine(&px, w: w, h: h, x0: 30, y0: 42, x1: 30, y1: 56, color: bodyDark)
                    // Spine ridges along the back (top edge of body)
                    for sx in stride(from: 20, through: 40, by: 4) {
                        fillOval(&px, w: w, h: h, cx: sx, cy: 41, rx: 2, ry: 1, color: spineColor)
                        fillRect(&px, w: w, h: h, x: sx, y: 40, rw: 2, rh: 1, color: bodyHi)
                    }
                    // Belly visible (underside)
                    fillOval(&px, w: w, h: h, cx: 30, cy: 55, rx: 10, ry: 3, color: underside)
                    // Head on right side, jaw slack
                    fillOval(&px, w: w, h: h, cx: 52, cy: 48, rx: 7, ry: 6, color: body)
                    fillOval(&px, w: w, h: h, cx: 52, cy: 45, rx: 6, ry: 3, color: bodyDark)
                    fillOval(&px, w: w, h: h, cx: 52, cy: 46, rx: 5, ry: 3, color: bodyLight)
                    fillOval(&px, w: w, h: h, cx: 48, cy: 49, rx: 3, ry: 2, color: bodyLight)
                    // Closed eye
                    drawLine(&px, w: w, h: h, x0: 54, y0: 46, x1: 57, y1: 46, color: bodyDeep)
                    // Fang hanging from open jaw
                    fillOval(&px, w: w, h: h, cx: 54, cy: 52, rx: 4, ry: 2, color: gum)
                    fillTriangle(&px, w: w, h: h, x0: 53, y0: 52, x1: 55, y1: 52, x2: 54, y2: 56, color: tooth)
                    fillTriangle(&px, w: w, h: h, x0: 56, y0: 52, x1: 58, y1: 52, x2: 57, y2: 55, color: toothDark)
                    // Drool on ground
                    drawLine(&px, w: w, h: h, x0: 55, y0: 54, x1: 56, y1: 57, color: drool)
                    // Blood stain on body
                    fillCircle(&px, w: w, h: h, cx: 28, cy: 49, r: 4, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 32, cy: 52, r: 3, color: bloodDark)
                    addNoise(&px, w: w, h: h, intensity: 10, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
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

        // Rich palette
        let uniform = c(75, 80, 55)
        let uniformDark = c(50, 55, 35)
        let uniformDeep = c(35, 40, 25)
        let uniformLight = c(95, 100, 70)
        let uniformHi = c(110, 115, 80)
        let skin = c(195, 155, 125)
        let skinDark = c(165, 130, 100)
        let skinShadow = c(140, 110, 85)
        let gun = c(55, 50, 45)
        let gunDark = c(40, 38, 35)
        let gunMetal = c(75, 75, 80)
        let gunMetalHi = c(95, 95, 100)
        let wood = c(90, 60, 30)
        let woodDark = c(70, 45, 20)
        let helmet = c(65, 70, 50)
        let helmetDark = c(45, 50, 35)
        let helmetHi = c(85, 90, 65)
        let boot = c(45, 35, 25)
        let bootDark = c(30, 22, 16)
        let belt = c(60, 45, 25)
        let buckle = c(150, 130, 40)
        let pouch = c(70, 55, 30)
        let pouchDark = c(55, 42, 22)
        let strap = c(65, 50, 28)
        let blood = c(160, 10, 10)
        let bloodDark = c(110, 5, 5)
        let eyeColor = c(40, 30, 20)
        let outline = c(25, 30, 15)

        for frame in 0..<10 {
            var px = [UInt32](repeating: T, count: w * h)
            let yOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? -1 : 1) : 0

            if frame <= 6 {
                let legOff = (frame >= 1 && frame <= 3) ? (frame % 2 == 0 ? 2 : -1) : 0

                // --- Legs with trouser detail ---
                // Left leg
                fillOval(&px, w: w, h: h, cx: 18 - legOff, cy: 52 + yOff, rx: 4, ry: 6, color: uniformDark)
                fillOval(&px, w: w, h: h, cx: 17 - legOff, cy: 51 + yOff, rx: 3, ry: 4, color: uniform)
                drawLine(&px, w: w, h: h, x0: 16 - legOff, y0: 48 + yOff, x1: 17 - legOff, y1: 58 + yOff, color: uniformDeep)
                // Right leg
                fillOval(&px, w: w, h: h, cx: 30 + legOff, cy: 52 + yOff, rx: 4, ry: 6, color: uniformDark)
                fillOval(&px, w: w, h: h, cx: 31 + legOff, cy: 51 + yOff, rx: 3, ry: 4, color: uniform)
                drawLine(&px, w: w, h: h, x0: 32 + legOff, y0: 48 + yOff, x1: 31 + legOff, y1: 58 + yOff, color: uniformDeep)

                // Boots with lace detail
                fillRect(&px, w: w, h: h, x: 14 - legOff, y: 58 + yOff, rw: 9, rh: 5, color: boot)
                fillRect(&px, w: w, h: h, x: 26 + legOff, y: 58 + yOff, rw: 9, rh: 5, color: boot)
                // Boot tops
                fillRect(&px, w: w, h: h, x: 14 - legOff, y: 57 + yOff, rw: 9, rh: 2, color: bootDark)
                fillRect(&px, w: w, h: h, x: 26 + legOff, y: 57 + yOff, rw: 9, rh: 2, color: bootDark)
                // Lace cross pattern
                for ly in stride(from: 58, through: 61, by: 2) {
                    let ly2 = ly + yOff
                    if ly2 >= 0 && ly2 < h {
                        let lx1 = 18 - legOff
                        let lx2 = 30 + legOff
                        if lx1 >= 0 && lx1 < w { px[ly2 * w + lx1] = bootDark }
                        if lx2 >= 0 && lx2 < w { px[ly2 * w + lx2] = bootDark }
                    }
                }
                // Sole highlight
                fillRect(&px, w: w, h: h, x: 13 - legOff, y: 62 + yOff, rw: 11, rh: 1, color: c(35, 28, 18))
                fillRect(&px, w: w, h: h, x: 25 + legOff, y: 62 + yOff, rw: 11, rh: 1, color: c(35, 28, 18))

                // --- Torso with uniform detail ---
                fillOval(&px, w: w, h: h, cx: 24, cy: 36 + yOff, rx: 12, ry: 14, color: uniform)
                // Chest highlight
                fillOval(&px, w: w, h: h, cx: 22, cy: 32 + yOff, rx: 6, ry: 6, color: uniformLight)
                fillOval(&px, w: w, h: h, cx: 21, cy: 31 + yOff, rx: 4, ry: 4, color: uniformHi)
                // Collar
                fillRect(&px, w: w, h: h, x: 19, y: 21 + yOff, rw: 10, rh: 3, color: uniformDark)
                fillRect(&px, w: w, h: h, x: 23, y: 21 + yOff, rw: 2, rh: 3, color: uniformDeep)
                // Chest pockets
                fillRect(&px, w: w, h: h, x: 15, y: 28 + yOff, rw: 6, rh: 5, color: uniformDark)
                fillRect(&px, w: w, h: h, x: 27, y: 28 + yOff, rw: 6, rh: 5, color: uniformDark)
                // Pocket flaps
                fillRect(&px, w: w, h: h, x: 15, y: 28 + yOff, rw: 6, rh: 1, color: uniformDeep)
                fillRect(&px, w: w, h: h, x: 27, y: 28 + yOff, rw: 6, rh: 1, color: uniformDeep)
                // Pocket buttons
                fillRect(&px, w: w, h: h, x: 17, y: 29 + yOff, rw: 1, rh: 1, color: uniformDeep)
                fillRect(&px, w: w, h: h, x: 29, y: 29 + yOff, rw: 1, rh: 1, color: uniformDeep)
                // Shirt buttons down center
                for by in stride(from: 24, through: 42, by: 4) {
                    let by2 = by + yOff
                    if by2 >= 0 && by2 < h { px[by2 * w + 24] = uniformDeep }
                }
                // Cross-body webbing/suspender straps
                drawLine(&px, w: w, h: h, x0: 18, y0: 22 + yOff, x1: 28, y1: 44 + yOff, color: strap)
                drawLine(&px, w: w, h: h, x0: 30, y0: 22 + yOff, x1: 20, y1: 44 + yOff, color: strap)
                // Belt with buckle and pouches
                fillRect(&px, w: w, h: h, x: 13, y: 46 + yOff, rw: 22, rh: 3, color: belt)
                fillRect(&px, w: w, h: h, x: 22, y: 46 + yOff, rw: 4, rh: 3, color: buckle)
                // Pouches with detail
                fillRect(&px, w: w, h: h, x: 14, y: 44 + yOff, rw: 5, rh: 4, color: pouch)
                fillRect(&px, w: w, h: h, x: 14, y: 44 + yOff, rw: 5, rh: 1, color: pouchDark)
                fillRect(&px, w: w, h: h, x: 29, y: 44 + yOff, rw: 5, rh: 4, color: pouch)
                fillRect(&px, w: w, h: h, x: 29, y: 44 + yOff, rw: 5, rh: 1, color: pouchDark)

                // --- Head with detailed helmet ---
                fillOval(&px, w: w, h: h, cx: 24, cy: 11 + yOff, rx: 9, ry: 8, color: helmet)
                // Helmet dome highlight
                fillOval(&px, w: w, h: h, cx: 22, cy: 8 + yOff, rx: 5, ry: 4, color: helmetHi)
                // Helmet netting texture (cross-hatch lines)
                for ny in stride(from: 5, through: 13, by: 3) {
                    drawLine(&px, w: w, h: h, x0: 17, y0: ny + yOff, x1: 31, y1: ny + yOff, color: helmetDark)
                }
                for nx in stride(from: 18, through: 30, by: 4) {
                    drawLine(&px, w: w, h: h, x0: nx, y0: 5 + yOff, x1: nx, y1: 14 + yOff, color: helmetDark)
                }
                // Helmet rim
                fillRect(&px, w: w, h: h, x: 14, y: 14 + yOff, rw: 20, rh: 2, color: helmetDark)
                // Chinstrap
                drawLine(&px, w: w, h: h, x0: 16, y0: 16 + yOff, x1: 16, y1: 18 + yOff, color: c(80, 65, 40))
                drawLine(&px, w: w, h: h, x0: 31, y0: 16 + yOff, x1: 31, y1: 18 + yOff, color: c(80, 65, 40))

                // Face with more detail
                fillOval(&px, w: w, h: h, cx: 24, cy: 16 + yOff, rx: 7, ry: 5, color: skin)
                // Forehead shadow under helmet
                fillRect(&px, w: w, h: h, x: 18, y: 14 + yOff, rw: 12, rh: 1, color: skinShadow)
                // Nose bridge
                fillRect(&px, w: w, h: h, x: 23, y: 15 + yOff, rw: 2, rh: 3, color: skinDark)
                fillRect(&px, w: w, h: h, x: 24, y: 15 + yOff, rw: 1, rh: 3, color: skin)
                // Eyes with eyebrows
                fillRect(&px, w: w, h: h, x: 19, y: 14 + yOff, rw: 3, rh: 1, color: skinDark)
                fillRect(&px, w: w, h: h, x: 26, y: 14 + yOff, rw: 3, rh: 1, color: skinDark)
                fillRect(&px, w: w, h: h, x: 20, y: 15 + yOff, rw: 2, rh: 2, color: c(245, 245, 240))
                fillRect(&px, w: w, h: h, x: 26, y: 15 + yOff, rw: 2, rh: 2, color: c(245, 245, 240))
                fillRect(&px, w: w, h: h, x: 20, y: 15 + yOff, rw: 1, rh: 1, color: eyeColor)
                fillRect(&px, w: w, h: h, x: 27, y: 15 + yOff, rw: 1, rh: 1, color: eyeColor)
                // Jaw/chin
                fillOval(&px, w: w, h: h, cx: 24, cy: 19 + yOff, rx: 4, ry: 2, color: skinDark)
                fillOval(&px, w: w, h: h, cx: 24, cy: 19 + yOff, rx: 3, ry: 1, color: skin)

                // --- Arms ---
                if frame == 4 || frame == 5 {
                    // Shooting stance: body leaning, rifle aimed
                    // Left arm forward supporting
                    fillOval(&px, w: w, h: h, cx: 10, cy: 28 + yOff, rx: 4, ry: 3, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 7, cy: 27 + yOff, rx: 3, ry: 2, color: skinDark)
                    // Right arm holding stock
                    fillOval(&px, w: w, h: h, cx: 34, cy: 30 + yOff, rx: 3, ry: 3, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 35, cy: 28 + yOff, rx: 2, ry: 2, color: skinDark)
                    // Rifle — barrel, receiver, stock
                    fillRect(&px, w: w, h: h, x: 2, y: 24 + yOff, rw: 6, rh: 2, color: gunMetal)
                    fillRect(&px, w: w, h: h, x: 2, y: 23 + yOff, rw: 3, rh: 1, color: gunMetalHi)
                    fillRect(&px, w: w, h: h, x: 8, y: 24 + yOff, rw: 26, rh: 3, color: gun)
                    fillRect(&px, w: w, h: h, x: 8, y: 24 + yOff, rw: 26, rh: 1, color: gunDark)
                    // Trigger guard
                    fillRect(&px, w: w, h: h, x: 22, y: 27 + yOff, rw: 3, rh: 2, color: gunMetal)
                    // Stock
                    fillRect(&px, w: w, h: h, x: 34, y: 23 + yOff, rw: 6, rh: 7, color: wood)
                    fillRect(&px, w: w, h: h, x: 35, y: 24 + yOff, rw: 1, rh: 5, color: woodDark)
                    fillRect(&px, w: w, h: h, x: 38, y: 24 + yOff, rw: 1, rh: 5, color: woodDark)

                    if frame == 5 {
                        // Muzzle flash — multi-layered
                        fillCircle(&px, w: w, h: h, cx: 2, cy: 24 + yOff, r: 6, color: c(255, 180, 30))
                        fillCircle(&px, w: w, h: h, cx: 2, cy: 24 + yOff, r: 4, color: c(255, 220, 80))
                        fillCircle(&px, w: w, h: h, cx: 2, cy: 24 + yOff, r: 2, color: c(255, 250, 180))
                        // Flash spikes
                        drawLine(&px, w: w, h: h, x0: 0, y0: 20 + yOff, x1: 2, y1: 22 + yOff, color: c(255, 240, 120))
                        drawLine(&px, w: w, h: h, x0: 0, y0: 28 + yOff, x1: 2, y1: 26 + yOff, color: c(255, 240, 120))
                    }
                } else {
                    // Arms at sides with forearm skin visible (rolled sleeves)
                    // Left arm
                    fillOval(&px, w: w, h: h, cx: 9, cy: 30 + yOff, rx: 3, ry: 6, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 29 + yOff, rx: 2, ry: 3, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 9, cy: 37 + yOff, rx: 3, ry: 4, color: skin)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 40 + yOff, rx: 2, ry: 2, color: skinDark)
                    // Right arm
                    fillOval(&px, w: w, h: h, cx: 39, cy: 30 + yOff, rx: 3, ry: 6, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 29 + yOff, rx: 2, ry: 3, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 39, cy: 37 + yOff, rx: 3, ry: 4, color: skin)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 40 + yOff, rx: 2, ry: 2, color: skinDark)
                    // Rifle slung diagonal
                    drawLine(&px, w: w, h: h, x0: 40, y0: 18 + yOff, x1: 38, y1: 42 + yOff, color: gun)
                    drawLine(&px, w: w, h: h, x0: 41, y0: 18 + yOff, x1: 39, y1: 42 + yOff, color: gunDark)
                    drawLine(&px, w: w, h: h, x0: 42, y0: 18 + yOff, x1: 40, y1: 42 + yOff, color: gun)
                }

                if frame == 6 {
                    for i in 0..<px.count where px[i] != T { px[i] = brighten(px[i], 90) }
                }

                addNoise(&px, w: w, h: h, intensity: 5, seed: frame)
                addOutline(&px, w: w, h: h, color: outline)
            } else {
                // Death sequence
                let progress = frame - 7
                if progress == 0 {
                    // Hit — staggering backward, helmet flying off

                    // --- Legs staggering apart ---
                    // Left leg
                    fillOval(&px, w: w, h: h, cx: 16, cy: 52, rx: 4, ry: 6, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 15, cy: 51, rx: 3, ry: 4, color: uniform)
                    drawLine(&px, w: w, h: h, x0: 14, y0: 48, x1: 15, y1: 58, color: uniformDeep)
                    // Right leg (shifted from stagger)
                    fillOval(&px, w: w, h: h, cx: 32, cy: 53, rx: 4, ry: 6, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 33, cy: 52, rx: 3, ry: 4, color: uniform)
                    drawLine(&px, w: w, h: h, x0: 34, y0: 49, x1: 33, y1: 58, color: uniformDeep)

                    // Boots with lace detail
                    fillRect(&px, w: w, h: h, x: 12, y: 58, rw: 9, rh: 5, color: boot)
                    fillRect(&px, w: w, h: h, x: 28, y: 58, rw: 9, rh: 5, color: boot)
                    fillRect(&px, w: w, h: h, x: 12, y: 57, rw: 9, rh: 2, color: bootDark)
                    fillRect(&px, w: w, h: h, x: 28, y: 57, rw: 9, rh: 2, color: bootDark)
                    // Lace dots
                    for ly in stride(from: 58, through: 61, by: 2) {
                        if ly < h { px[ly * w + 16] = bootDark }
                        if ly < h { px[ly * w + 32] = bootDark }
                    }
                    // Soles
                    fillRect(&px, w: w, h: h, x: 11, y: 62, rw: 11, rh: 1, color: c(35, 28, 18))
                    fillRect(&px, w: w, h: h, x: 27, y: 62, rw: 11, rh: 1, color: c(35, 28, 18))

                    // --- Torso reeling back ---
                    fillOval(&px, w: w, h: h, cx: 26, cy: 36, rx: 12, ry: 14, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 32, rx: 6, ry: 6, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 23, cy: 31, rx: 4, ry: 4, color: uniformHi)
                    // Collar
                    fillRect(&px, w: w, h: h, x: 21, y: 21, rw: 10, rh: 3, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 25, y: 21, rw: 2, rh: 3, color: uniformDeep)
                    // Chest pockets
                    fillRect(&px, w: w, h: h, x: 17, y: 28, rw: 6, rh: 5, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 29, y: 28, rw: 6, rh: 5, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 17, y: 28, rw: 6, rh: 1, color: uniformDeep)
                    fillRect(&px, w: w, h: h, x: 29, y: 28, rw: 6, rh: 1, color: uniformDeep)
                    fillRect(&px, w: w, h: h, x: 19, y: 29, rw: 1, rh: 1, color: uniformDeep)
                    fillRect(&px, w: w, h: h, x: 31, y: 29, rw: 1, rh: 1, color: uniformDeep)
                    // Shirt buttons
                    for by in stride(from: 24, through: 42, by: 4) {
                        if by < h { px[by * w + 26] = uniformDeep }
                    }
                    // Cross-body webbing straps
                    drawLine(&px, w: w, h: h, x0: 20, y0: 22, x1: 30, y1: 44, color: strap)
                    drawLine(&px, w: w, h: h, x0: 32, y0: 22, x1: 22, y1: 44, color: strap)
                    // Belt with buckle and pouches
                    fillRect(&px, w: w, h: h, x: 15, y: 46, rw: 22, rh: 3, color: belt)
                    fillRect(&px, w: w, h: h, x: 24, y: 46, rw: 4, rh: 3, color: buckle)
                    fillRect(&px, w: w, h: h, x: 16, y: 44, rw: 5, rh: 4, color: pouch)
                    fillRect(&px, w: w, h: h, x: 16, y: 44, rw: 5, rh: 1, color: pouchDark)
                    fillRect(&px, w: w, h: h, x: 31, y: 44, rw: 5, rh: 4, color: pouch)
                    fillRect(&px, w: w, h: h, x: 31, y: 44, rw: 5, rh: 1, color: pouchDark)

                    // Blood from chest wound (over uniform)
                    fillCircle(&px, w: w, h: h, cx: 24, cy: 32, r: 5, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 20, cy: 28, r: 3, color: bloodDark)
                    drawLine(&px, w: w, h: h, x0: 22, y0: 26, x1: 18, y1: 20, color: blood)

                    // --- Head tilted back ---
                    fillOval(&px, w: w, h: h, cx: 28, cy: 14, rx: 7, ry: 5, color: skin)
                    // Forehead shadow
                    fillRect(&px, w: w, h: h, x: 22, y: 12, rw: 12, rh: 1, color: skinShadow)
                    // Nose bridge
                    fillRect(&px, w: w, h: h, x: 27, y: 13, rw: 2, rh: 3, color: skinDark)
                    // Eyes wide (shock)
                    fillRect(&px, w: w, h: h, x: 24, y: 13, rw: 2, rh: 2, color: c(245, 245, 240))
                    fillRect(&px, w: w, h: h, x: 30, y: 13, rw: 2, rh: 2, color: c(245, 245, 240))
                    fillRect(&px, w: w, h: h, x: 24, y: 13, rw: 1, rh: 1, color: eyeColor)
                    fillRect(&px, w: w, h: h, x: 31, y: 13, rw: 1, rh: 1, color: eyeColor)
                    // Mouth open in pain
                    fillRect(&px, w: w, h: h, x: 26, y: 17, rw: 4, rh: 2, color: c(80, 30, 30))
                    // Jaw
                    fillOval(&px, w: w, h: h, cx: 28, cy: 18, rx: 4, ry: 2, color: skinDark)

                    // Helmet flying off (with netting detail)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 6, rx: 7, ry: 5, color: helmet)
                    fillOval(&px, w: w, h: h, cx: 38, cy: 4, rx: 5, ry: 3, color: helmetHi)
                    // Netting on flying helmet
                    for ny in stride(from: 3, through: 8, by: 3) {
                        drawLine(&px, w: w, h: h, x0: 35, y0: ny, x1: 45, y1: ny, color: helmetDark)
                    }
                    for nx in stride(from: 36, through: 44, by: 4) {
                        drawLine(&px, w: w, h: h, x0: nx, y0: 2, x1: nx, y1: 9, color: helmetDark)
                    }
                    // Helmet rim
                    fillRect(&px, w: w, h: h, x: 34, y: 9, rw: 12, rh: 1, color: helmetDark)

                    // Arms flung out (with rolled sleeves showing skin)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 28, rx: 3, ry: 6, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 7, cy: 27, rx: 2, ry: 3, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 8, cy: 35, rx: 3, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 7, cy: 37, rx: 2, ry: 2, color: skinDark)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 26, rx: 3, ry: 6, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 41, cy: 25, rx: 2, ry: 3, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 33, rx: 3, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 41, cy: 35, rx: 2, ry: 2, color: skinDark)

                    // Dropped rifle
                    drawLine(&px, w: w, h: h, x0: 42, y0: 30, x1: 44, y1: 48, color: gun)
                    drawLine(&px, w: w, h: h, x0: 43, y0: 30, x1: 45, y1: 48, color: gunDark)
                    drawLine(&px, w: w, h: h, x0: 44, y0: 30, x1: 46, y1: 48, color: gun)
                    fillRect(&px, w: w, h: h, x: 43, y: 44, rw: 4, rh: 5, color: wood)
                    fillRect(&px, w: w, h: h, x: 44, y: 45, rw: 1, rh: 3, color: woodDark)

                    addNoise(&px, w: w, h: h, intensity: 5, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
                } else if progress == 1 {
                    // Falling — toppling forward/right

                    // --- Left leg buckling ---
                    fillOval(&px, w: w, h: h, cx: 12, cy: 54, rx: 4, ry: 6, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 11, cy: 53, rx: 3, ry: 4, color: uniform)
                    drawLine(&px, w: w, h: h, x0: 10, y0: 50, x1: 11, y1: 58, color: uniformDeep)
                    // Right leg trailing
                    fillOval(&px, w: w, h: h, cx: 20, cy: 56, rx: 4, ry: 5, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 21, cy: 55, rx: 3, ry: 3, color: uniform)
                    drawLine(&px, w: w, h: h, x0: 22, y0: 52, x1: 21, y1: 58, color: uniformDeep)
                    // Boots
                    fillRect(&px, w: w, h: h, x: 8, y: 58, rw: 9, rh: 5, color: boot)
                    fillRect(&px, w: w, h: h, x: 16, y: 59, rw: 9, rh: 4, color: boot)
                    fillRect(&px, w: w, h: h, x: 8, y: 57, rw: 9, rh: 2, color: bootDark)
                    fillRect(&px, w: w, h: h, x: 16, y: 58, rw: 9, rh: 2, color: bootDark)
                    // Soles
                    fillRect(&px, w: w, h: h, x: 7, y: 62, rw: 11, rh: 1, color: c(35, 28, 18))

                    // --- Torso tilting forward ---
                    fillOval(&px, w: w, h: h, cx: 28, cy: 44, rx: 11, ry: 10, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 26, cy: 40, rx: 6, ry: 4, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 25, cy: 39, rx: 4, ry: 3, color: uniformHi)
                    // Collar
                    fillRect(&px, w: w, h: h, x: 28, y: 34, rw: 8, rh: 2, color: uniformDark)
                    // Chest pockets (visible at angle)
                    fillRect(&px, w: w, h: h, x: 21, y: 40, rw: 5, rh: 4, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 32, y: 40, rw: 5, rh: 4, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 21, y: 40, rw: 5, rh: 1, color: uniformDeep)
                    fillRect(&px, w: w, h: h, x: 32, y: 40, rw: 5, rh: 1, color: uniformDeep)
                    // Webbing straps
                    drawLine(&px, w: w, h: h, x0: 24, y0: 35, x1: 32, y1: 50, color: strap)
                    drawLine(&px, w: w, h: h, x0: 34, y0: 35, x1: 26, y1: 50, color: strap)
                    // Belt with buckle
                    fillRect(&px, w: w, h: h, x: 18, y: 49, rw: 20, rh: 3, color: belt)
                    fillRect(&px, w: w, h: h, x: 26, y: 49, rw: 4, rh: 3, color: buckle)
                    // Pouches
                    fillRect(&px, w: w, h: h, x: 19, y: 47, rw: 4, rh: 3, color: pouch)
                    fillRect(&px, w: w, h: h, x: 19, y: 47, rw: 4, rh: 1, color: pouchDark)
                    fillRect(&px, w: w, h: h, x: 35, y: 47, rw: 4, rh: 3, color: pouch)
                    fillRect(&px, w: w, h: h, x: 35, y: 47, rw: 4, rh: 1, color: pouchDark)

                    // Blood from wound
                    fillCircle(&px, w: w, h: h, cx: 26, cy: 42, r: 4, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 22, cy: 38, r: 3, color: bloodDark)
                    drawLine(&px, w: w, h: h, x0: 24, y0: 40, x1: 20, y1: 34, color: blood)

                    // --- Head falling forward ---
                    fillOval(&px, w: w, h: h, cx: 38, cy: 36, rx: 6, ry: 5, color: skin)
                    // Forehead shadow
                    fillRect(&px, w: w, h: h, x: 33, y: 33, rw: 10, rh: 1, color: skinShadow)
                    // Nose
                    fillRect(&px, w: w, h: h, x: 37, y: 35, rw: 2, rh: 2, color: skinDark)
                    // Eyes closing
                    drawLine(&px, w: w, h: h, x0: 34, y0: 35, x1: 36, y1: 35, color: skinShadow)
                    drawLine(&px, w: w, h: h, x0: 40, y0: 35, x1: 42, y1: 35, color: skinShadow)
                    // Jaw
                    fillOval(&px, w: w, h: h, cx: 38, cy: 39, rx: 4, ry: 2, color: skinDark)

                    // Arms going limp
                    fillOval(&px, w: w, h: h, cx: 14, cy: 44, rx: 3, ry: 5, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 13, cy: 43, rx: 2, ry: 3, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 14, cy: 50, rx: 2, ry: 3, color: skin)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 42, rx: 3, ry: 5, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 41, cy: 41, rx: 2, ry: 3, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 40, cy: 48, rx: 2, ry: 3, color: skin)

                    addNoise(&px, w: w, h: h, intensity: 5, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
                } else {
                    // Corpse — soldier lying on side, recognizable

                    // Blood pool under body
                    fillOval(&px, w: w, h: h, cx: 24, cy: 58, rx: 16, ry: 4, color: c(120, 5, 5))
                    fillOval(&px, w: w, h: h, cx: 22, cy: 59, rx: 12, ry: 2, color: c(90, 3, 3))

                    // Boots (left side)
                    fillRect(&px, w: w, h: h, x: 2, y: 54, rw: 6, rh: 4, color: boot)
                    fillRect(&px, w: w, h: h, x: 2, y: 53, rw: 5, rh: 2, color: bootDark)
                    fillRect(&px, w: w, h: h, x: 1, y: 57, rw: 8, rh: 1, color: c(35, 28, 18))
                    // Second boot behind
                    fillRect(&px, w: w, h: h, x: 5, y: 56, rw: 5, rh: 3, color: boot)
                    fillRect(&px, w: w, h: h, x: 5, y: 55, rw: 4, rh: 2, color: bootDark)

                    // Legs in uniform with trouser crease
                    fillOval(&px, w: w, h: h, cx: 10, cy: 52, rx: 4, ry: 5, color: uniformDark)
                    fillOval(&px, w: w, h: h, cx: 10, cy: 50, rx: 3, ry: 3, color: uniform)
                    drawLine(&px, w: w, h: h, x0: 8, y0: 48, x1: 9, y1: 56, color: uniformDeep)

                    // Torso lying on side
                    fillOval(&px, w: w, h: h, cx: 24, cy: 50, rx: 11, ry: 8, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 48, rx: 7, ry: 4, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 24, cy: 54, rx: 9, ry: 3, color: uniformDark)
                    // Chest pocket visible
                    fillRect(&px, w: w, h: h, x: 18, y: 47, rw: 5, rh: 4, color: uniformDark)
                    fillRect(&px, w: w, h: h, x: 18, y: 47, rw: 5, rh: 1, color: uniformDeep)
                    // Webbing strap across torso
                    drawLine(&px, w: w, h: h, x0: 16, y0: 46, x1: 32, y1: 52, color: strap)
                    // Belt visible across torso
                    drawLine(&px, w: w, h: h, x0: 16, y0: 52, x1: 33, y1: 52, color: belt)
                    fillRect(&px, w: w, h: h, x: 22, y: 51, rw: 3, rh: 3, color: buckle)
                    // Pouch on belt
                    fillRect(&px, w: w, h: h, x: 28, y: 50, rw: 4, rh: 3, color: pouch)
                    fillRect(&px, w: w, h: h, x: 28, y: 50, rw: 4, rh: 1, color: pouchDark)

                    // Arm draped forward (rolled sleeve showing skin)
                    fillOval(&px, w: w, h: h, cx: 31, cy: 54, rx: 3, ry: 2, color: uniform)
                    fillOval(&px, w: w, h: h, cx: 31, cy: 53, rx: 2, ry: 1, color: uniformLight)
                    fillOval(&px, w: w, h: h, cx: 34, cy: 55, rx: 2, ry: 2, color: skin)
                    fillCircle(&px, w: w, h: h, cx: 36, cy: 55, r: 2, color: skinDark)

                    // Head (no helmet — lost in frame 7)
                    fillOval(&px, w: w, h: h, cx: 38, cy: 48, rx: 5, ry: 5, color: skin)
                    fillOval(&px, w: w, h: h, cx: 38, cy: 50, rx: 4, ry: 2, color: skinDark)
                    // Forehead
                    fillRect(&px, w: w, h: h, x: 34, y: 44, rw: 8, rh: 1, color: skinShadow)
                    // Closed eyes
                    drawLine(&px, w: w, h: h, x0: 36, y0: 47, x1: 38, y1: 47, color: skinShadow)
                    drawLine(&px, w: w, h: h, x0: 40, y0: 47, x1: 42, y1: 47, color: skinShadow)
                    // Nose
                    fillRect(&px, w: w, h: h, x: 39, y: 48, rw: 1, rh: 2, color: skinDark)
                    // Jaw
                    fillOval(&px, w: w, h: h, cx: 38, cy: 51, rx: 3, ry: 1, color: skinDark)

                    // Dropped rifle nearby
                    fillRect(&px, w: w, h: h, x: 12, y: 58, rw: 18, rh: 2, color: gun)
                    fillRect(&px, w: w, h: h, x: 12, y: 57, rw: 5, rh: 1, color: gunMetal)
                    fillRect(&px, w: w, h: h, x: 13, y: 56, rw: 2, rh: 1, color: gunMetalHi)
                    fillRect(&px, w: w, h: h, x: 27, y: 57, rw: 5, rh: 2, color: wood)
                    fillRect(&px, w: w, h: h, x: 28, y: 58, rw: 1, rh: 1, color: woodDark)
                    fillRect(&px, w: w, h: h, x: 31, y: 58, rw: 1, rh: 1, color: woodDark)

                    // Helmet on ground nearby (with netting)
                    fillOval(&px, w: w, h: h, cx: 44, cy: 56, rx: 5, ry: 3, color: helmet)
                    fillOval(&px, w: w, h: h, cx: 43, cy: 55, rx: 3, ry: 2, color: helmetHi)
                    // Netting texture on helmet
                    drawLine(&px, w: w, h: h, x0: 41, y0: 55, x1: 47, y1: 55, color: helmetDark)
                    drawLine(&px, w: w, h: h, x0: 42, y0: 54, x1: 42, y1: 57, color: helmetDark)
                    drawLine(&px, w: w, h: h, x0: 46, y0: 54, x1: 46, y1: 57, color: helmetDark)

                    // Blood stain on torso
                    fillCircle(&px, w: w, h: h, cx: 22, cy: 49, r: 3, color: blood)
                    fillCircle(&px, w: w, h: h, cx: 24, cy: 52, r: 2, color: bloodDark)
                    drawLine(&px, w: w, h: h, x0: 20, y0: 48, x1: 18, y1: 44, color: blood)

                    addNoise(&px, w: w, h: h, intensity: 5, seed: frame)
                    addOutline(&px, w: w, h: h, color: outline)
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

        // Intel Data (glowing green datapad — mission item)
        var id = [UInt32](repeating: T, count: w * h)
        fillRect(&id, w: w, h: h, x: 4, y: 3, rw: 12, rh: 14, color: c(40, 50, 45))
        fillRect(&id, w: w, h: h, x: 5, y: 4, rw: 10, rh: 12, color: c(20, 80, 30))
        // Screen glow
        fillRect(&id, w: w, h: h, x: 6, y: 5, rw: 8, rh: 7, color: c(60, 200, 80))
        fillRect(&id, w: w, h: h, x: 7, y: 6, rw: 6, rh: 5, color: c(120, 255, 140))
        // Data lines on screen
        fillRect(&id, w: w, h: h, x: 7, y: 7, rw: 5, rh: 1, color: c(40, 160, 60))
        fillRect(&id, w: w, h: h, x: 7, y: 9, rw: 4, rh: 1, color: c(40, 160, 60))
        // Antenna
        fillRect(&id, w: w, h: h, x: 14, y: 2, rw: 1, rh: 4, color: c(60, 60, 55))
        fillRect(&id, w: w, h: h, x: 14, y: 1, rw: 1, rh: 1, color: c(60, 255, 80))
        addOutline(&id, w: w, h: h, color: c(20, 40, 25))
        frames.append(id)

        // Demonic Artifact (glowing purple orb — mission item)
        var da = [UInt32](repeating: T, count: w * h)
        fillCircle(&da, w: w, h: h, cx: 10, cy: 10, r: 7, color: c(80, 20, 100))
        fillCircle(&da, w: w, h: h, cx: 10, cy: 10, r: 6, color: c(120, 40, 160))
        fillCircle(&da, w: w, h: h, cx: 10, cy: 10, r: 4, color: c(170, 70, 220))
        fillCircle(&da, w: w, h: h, cx: 10, cy: 10, r: 2, color: c(220, 150, 255))
        fillCircle(&da, w: w, h: h, cx: 9, cy: 9, r: 1, color: c(255, 220, 255))
        // Rune marks around orb
        fillRect(&da, w: w, h: h, x: 3, y: 9, rw: 1, rh: 2, color: c(200, 80, 255))
        fillRect(&da, w: w, h: h, x: 16, y: 9, rw: 1, rh: 2, color: c(200, 80, 255))
        fillRect(&da, w: w, h: h, x: 9, y: 2, rw: 2, rh: 1, color: c(200, 80, 255))
        fillRect(&da, w: w, h: h, x: 9, y: 17, rw: 2, rh: 1, color: c(200, 80, 255))
        addOutline(&da, w: w, h: h, color: c(40, 10, 50))
        frames.append(da)

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
