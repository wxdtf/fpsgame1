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

    private init() {
        impSprites = EnemySpriteData.imp.decode()
        demonSprites = EnemySpriteData.demon.decode()
        soldierSprites = EnemySpriteData.soldier.decode()
        baronSprites = EnemySpriteData.baron.decode()
        pistolSprites = Self.generatePistolSprites()
        shotgunSprites = Self.generateShotgunSprites()
        fistSprites = Self.generateFistSprites()
        chaingunSprites = Self.generateChaingunSprites()
        rocketLauncherSprites = Self.generateRocketLauncherSprites()
        itemSprites = Self.generateItemSprites()
        projectileSprites = Self.generateProjectileSprites()
        explosionSprites = Self.generateExplosionSprites()
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
    // The enemy sheets are pixel art authored in tools/enemy_art/*.py and baked
    // into EnemySpriteData.swift by tools/enemy_art/build.py.

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

    // MARK: - Rocket Launcher Sprites (first person view)

    private static func generateRocketLauncherSprites() -> SpriteSheet {
        let w = 192, h = 192
        var frames: [[UInt32]] = []

        for frame in 0..<4 {
            var px = [UInt32](repeating: T, count: w * h)
            let tube = c(70, 72, 68)
            let tubeDark = c(45, 47, 44)
            let tubeLight = c(105, 108, 102)
            let olive = c(85, 95, 60)
            let oliveDark = c(60, 68, 42)
            let steel = c(120, 122, 128)
            let rocketRed = c(190, 40, 30)
            let rocketBody = c(150, 150, 140)
            let skin = c(195, 155, 125)
            let skinDark = c(165, 130, 100)

            // Frames: 0 idle, 1 launch, 2 smoke, 3 reloaded
            let recoil = frame == 1 ? 12 : (frame == 2 ? 6 : 0)

            // Shoulder rest / rear body
            fillRect(&px, w: w, h: h, x: 62, y: 120 + recoil, rw: 68, rh: 60, color: olive)
            fillRect(&px, w: w, h: h, x: 66, y: 124 + recoil, rw: 60, rh: 52, color: oliveDark)
            // Main tube
            fillRect(&px, w: w, h: h, x: 70, y: 28 + recoil, rw: 52, rh: 100, color: tube)
            fillRect(&px, w: w, h: h, x: 70, y: 28 + recoil, rw: 6, rh: 100, color: tubeLight)
            fillRect(&px, w: w, h: h, x: 116, y: 28 + recoil, rw: 6, rh: 100, color: tubeDark)
            // Reinforcing bands
            for by in [44, 78, 112] {
                fillRect(&px, w: w, h: h, x: 68, y: by + recoil, rw: 56, rh: 6, color: steel)
                fillRect(&px, w: w, h: h, x: 68, y: by + 6 + recoil, rw: 56, rh: 2, color: tubeDark)
            }
            // Muzzle opening
            fillOval(&px, w: w, h: h, cx: 96, cy: 30 + recoil, rx: 26, ry: 10, color: tubeDark)
            fillOval(&px, w: w, h: h, cx: 96, cy: 30 + recoil, rx: 20, ry: 7, color: c(20, 20, 22))
            // Loaded rocket visible in the muzzle (not on the launch/smoke frames)
            if frame == 0 || frame == 3 {
                fillOval(&px, w: w, h: h, cx: 96, cy: 30 + recoil, rx: 10, ry: 4, color: rocketBody)
                fillOval(&px, w: w, h: h, cx: 96, cy: 29 + recoil, rx: 5, ry: 2, color: rocketRed)
            }
            // Grip and hand
            fillRect(&px, w: w, h: h, x: 124, y: 96 + recoil, rw: 14, rh: 40, color: oliveDark)
            fillOval(&px, w: w, h: h, cx: 138, cy: 122 + recoil, rx: 22, ry: 14, color: skin)
            fillOval(&px, w: w, h: h, cx: 140, cy: 126 + recoil, rx: 20, ry: 12, color: skinDark)
            // Sight
            fillRect(&px, w: w, h: h, x: 60, y: 60 + recoil, rw: 8, rh: 30, color: steel)
            fillRect(&px, w: w, h: h, x: 58, y: 58 + recoil, rw: 12, rh: 4, color: tubeDark)

            if frame == 1 {
                // Launch flash
                for r in stride(from: 30, to: 0, by: -3) {
                    let t = Double(30 - r) / 30.0
                    fillCircle(&px, w: w, h: h, cx: 96, cy: 22, r: r,
                               color: c(Int(255.0 * t), Int(210.0 * t * t), Int(60.0 * t * t * t)))
                }
            } else if frame == 2 {
                // Smoke puff
                fillCircle(&px, w: w, h: h, cx: 92, cy: 22, r: 14, color: c(110, 110, 110))
                fillCircle(&px, w: w, h: h, cx: 104, cy: 14, r: 10, color: c(140, 140, 140))
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

        // Rocket launcher pickup (tube with a loaded rocket)
        var rl = [UInt32](repeating: T, count: w * h)
        fillRect(&rl, w: w, h: h, x: 1, y: 7, rw: 15, rh: 6, color: c(70, 72, 68))
        fillRect(&rl, w: w, h: h, x: 1, y: 8, rw: 15, rh: 2, color: c(105, 108, 102))
        fillRect(&rl, w: w, h: h, x: 5, y: 13, rw: 6, rh: 4, color: c(85, 95, 60))
        fillOval(&rl, w: w, h: h, cx: 17, cy: 10, rx: 2, ry: 3, color: c(20, 20, 22))
        fillRect(&rl, w: w, h: h, x: 16, y: 9, rw: 3, rh: 2, color: c(190, 40, 30))
        addOutline(&rl, w: w, h: h, color: c(25, 25, 28))
        frames.append(rl)

        // Rocket box (crate with three rockets)
        var rb = [UInt32](repeating: T, count: w * h)
        fillRect(&rb, w: w, h: h, x: 2, y: 8, rw: 16, rh: 8, color: c(80, 90, 55))
        fillRect(&rb, w: w, h: h, x: 3, y: 9, rw: 14, rh: 6, color: c(100, 110, 70))
        for rx in stride(from: 4, to: 16, by: 4) {
            fillRect(&rb, w: w, h: h, x: rx, y: 4, rw: 2, rh: 5, color: c(150, 150, 140))
            fillRect(&rb, w: w, h: h, x: rx, y: 3, rw: 2, rh: 2, color: c(190, 40, 30))
        }
        addOutline(&rb, w: w, h: h, color: c(30, 35, 20))
        frames.append(rb)

        return SpriteSheet(frames: frames, width: w, height: h)
    }

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
