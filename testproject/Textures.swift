//
//  Textures.swift
//  testproject
//

import Foundation

final class TextureAtlas {
    let size = GameConstants.textureSize
    let texCount = 12
    /// All textures in one flat array: texCount * size * size UInt32s
    /// Layout: texture[i] pixel (x,y) = atlas[i * size * size + y * size + x]
    let atlas: UnsafeMutablePointer<UInt32>
    private let pixelsPerTex: Int

    // Texture indices
    static let brick = 0
    static let metal = 1
    static let tech = 2
    static let door = 3
    static let floor = 4
    static let ceiling = 5
    static let brickTorch = 6
    static let exitPortal = 7
    static let lockedDoorRed = 8
    static let lockedDoorBlue = 9
    static let lockedDoorYellow = 10
    static let damageFloor = 11

    init() {
        pixelsPerTex = GameConstants.textureSize * GameConstants.textureSize
        let total = texCount * pixelsPerTex
        atlas = .allocate(capacity: total)
        atlas.initialize(repeating: 0, count: total)

        copyTexture(generateBrickTexture(), to: Self.brick)
        copyTexture(generateMetalTexture(), to: Self.metal)
        copyTexture(generateTechTexture(), to: Self.tech)
        copyTexture(generateDoorTexture(), to: Self.door)
        copyTexture(generateFloorTexture(), to: Self.floor)
        copyTexture(generateCeilingTexture(), to: Self.ceiling)
        copyTexture(generateBrickTorchTexture(), to: Self.brickTorch)
        copyTexture(generateExitPortalTexture(), to: Self.exitPortal)
        copyTexture(generateLockedDoorTexture(borderR: 200, borderG: 30, borderB: 30), to: Self.lockedDoorRed)
        copyTexture(generateLockedDoorTexture(borderR: 30, borderG: 80, borderB: 200), to: Self.lockedDoorBlue)
        copyTexture(generateLockedDoorTexture(borderR: 220, borderG: 200, borderB: 30), to: Self.lockedDoorYellow)
        copyTexture(generateDamageFloorTexture(), to: Self.damageFloor)
    }

    deinit {
        atlas.deallocate()
    }

    private func copyTexture(_ pixels: [UInt32], to index: Int) {
        let offset = index * pixelsPerTex
        for i in 0..<min(pixels.count, pixelsPerTex) {
            atlas[offset + i] = pixels[i]
        }
    }

    @inline(__always)
    func sample(textureIndex: Int, x: Int, y: Int) -> UInt32 {
        let tx = x & (size - 1)
        let ty = y & (size - 1)
        return atlas[textureIndex * pixelsPerTex + ty * size + tx]
    }

    // Deterministic hash for noise
    private func hash(_ x: Int, _ y: Int, _ seed: Int = 0) -> Int {
        var h = x &* 374761393 &+ y &* 668265263 &+ seed &* 1274126177
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        return h & 0x7FFFFFFF
    }

    private func noise01(_ x: Int, _ y: Int, _ seed: Int = 0) -> Double {
        return Double(hash(x, y, seed) % 1000) / 1000.0
    }

    private func c(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        PixelBuffer.makeColor(r: UInt8(max(0, min(255, r))), g: UInt8(max(0, min(255, g))), b: UInt8(max(0, min(255, b))))
    }

    private func blend(_ c1: UInt32, _ c2: UInt32, _ t: Double) -> UInt32 {
        let r1 = Int(PixelBuffer.getRed(c1)), g1 = Int(PixelBuffer.getGreen(c1)), b1 = Int(PixelBuffer.getBlue(c1))
        let r2 = Int(PixelBuffer.getRed(c2)), g2 = Int(PixelBuffer.getGreen(c2)), b2 = Int(PixelBuffer.getBlue(c2))
        let inv = 1.0 - t
        return c(Int(Double(r1) * inv + Double(r2) * t),
                 Int(Double(g1) * inv + Double(g2) * t),
                 Int(Double(b1) * inv + Double(b2) * t))
    }

    // MARK: - Brick Wall (Doom STARTAN-style reddish-brown bricks)
    private func generateBrickTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)
        let brickH = 8
        let brickW = 16

        for y in 0..<size {
            for x in 0..<size {
                let row = y / brickH
                let offset = (row % 2 == 0) ? 0 : brickW / 2
                let bx = (x + offset) % brickW
                let by = y % brickH

                let isMortarH = by == 0
                let isMortarV = bx == 0

                if isMortarH || isMortarV {
                    // Mortar: dark gray with slight variation
                    let n = noise01(x, y, 100)
                    let v = 35 + Int(n * 15)
                    pixels[y * size + x] = c(v, v - 2, v - 4)
                } else {
                    // Each brick gets a unique color from its grid position
                    let brickID = row * 8 + ((x + offset) / brickW)
                    let brickNoise = noise01(brickID, brickID * 7, 42)

                    // Base brick color with per-brick variation
                    let baseR = 115 + Int(brickNoise * 40)
                    let baseG = 45 + Int(brickNoise * 20)
                    let baseB = 30 + Int(brickNoise * 15)

                    // Per-pixel noise for texture
                    let pn = noise01(x, y, 7)
                    let detail = Int(pn * 18) - 9

                    // Edge darkening for 3D look (shadow on bottom and right of each brick)
                    var edgeDarken = 0
                    if by >= brickH - 2 { edgeDarken = -12 }
                    if bx >= brickW - 2 { edgeDarken = -12 }
                    // Highlight on top and left
                    if by == 1 { edgeDarken = 10 }
                    if bx == 1 { edgeDarken = 8 }

                    // Occasional cracks
                    var crack = 0
                    if hash(x, y, 999) % 200 == 0 { crack = -25 }

                    pixels[y * size + x] = c(baseR + detail + edgeDarken + crack,
                                              baseG + detail / 2 + edgeDarken + crack,
                                              baseB + detail / 3 + edgeDarken + crack)
                }
            }
        }
        return pixels
    }

    // MARK: - Metal Wall (Doom STARG-style industrial gray panels)
    private func generateMetalTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                // Two large panels (top/bottom halves)
                let panelY = y % 32
                let panelX = x

                // Panel border (recessed groove)
                let isBorderH = panelY < 2 || panelY > 29
                let isBorderV = panelX < 2 || panelX > 61

                if isBorderH || isBorderV {
                    // Deep groove
                    let n = noise01(x, y, 200)
                    pixels[y * size + x] = c(35 + Int(n * 10), 38 + Int(n * 10), 42 + Int(n * 10))
                } else {
                    // Brushed metal surface - horizontal streaks
                    let streak = noise01(x, y * 3 + 1, 50)
                    let hStreak = noise01(0, y, 55)
                    let base = 90 + Int(hStreak * 25) + Int(streak * 12) - 6

                    // Vertical gradient within panel (lighter at top = overhead light)
                    let vGrad = 8 - panelY / 4

                    pixels[y * size + x] = c(base + vGrad - 2, base + vGrad, base + vGrad + 3)

                    // Rivet bolts at corners of each panel
                    let ry = panelY
                    let isRivet = ((panelX == 5 || panelX == 58) && (ry == 5 || ry == 26))
                    if isRivet {
                        // Rivet highlight
                        for dy in -1...1 {
                            for dx in -1...1 {
                                let px = x + dx
                                let py = y + dy
                                if px >= 0 && px < size && py >= 0 && py < size {
                                    if dx * dx + dy * dy <= 1 {
                                        let rv = dx == -1 && dy == -1 ? 155 : 95
                                        pixels[py * size + px] = c(rv, rv + 2, rv + 5)
                                    }
                                }
                            }
                        }
                    }

                    // Occasional scratch marks
                    if hash(x * 3, y, 77) % 150 == 0 {
                        pixels[y * size + x] = c(base + 20, base + 22, base + 25)
                    }
                }
            }
        }
        return pixels
    }

    // MARK: - Tech Panel (Doom COMP-style with green/blue screens and circuits)
    private func generateTechTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                // Dark blue-gray base
                let n = noise01(x, y, 300)
                let base = 25 + Int(n * 10)
                pixels[y * size + x] = c(base, base + 3, base + 12)

                // Top frame border
                if y < 3 || y > 60 || x < 3 || x > 60 {
                    pixels[y * size + x] = c(50, 55, 60)
                    if y < 1 || y > 62 || x < 1 || x > 62 {
                        pixels[y * size + x] = c(30, 32, 35)
                    }
                    continue
                }

                // Central screen area (glowing green/amber display)
                if x >= 8 && x <= 55 && y >= 8 && y <= 30 {
                    // Screen background
                    let screenBase = c(5, 20, 10)
                    pixels[y * size + x] = screenBase

                    // Scanlines
                    if y % 2 == 0 {
                        pixels[y * size + x] = c(8, 28, 14)
                    }

                    // Horizontal data bars (like Doom computer screens)
                    let barY = (y - 8) % 6
                    let barWidth = hash(0, y / 6, 321) % 30 + 15
                    if barY >= 1 && barY <= 3 && x >= 10 && x < 10 + barWidth {
                        let intensity = 120 + Int(noise01(x, y / 6, 55) * 80)
                        pixels[y * size + x] = c(0, intensity, intensity / 3)
                    }

                    // Screen edge glow
                    if x == 8 || x == 55 || y == 8 || y == 30 {
                        pixels[y * size + x] = c(20, 60, 30)
                    }
                }

                // Bottom panel: circuit board area
                if y >= 35 && y <= 58 && x >= 6 && x <= 57 {
                    // PCB green base
                    pixels[y * size + x] = c(15, 35 + Int(n * 8), 18)

                    // Circuit traces (horizontal)
                    if (y == 38 || y == 44 || y == 50 || y == 55) && x >= 8 && x <= 55 {
                        pixels[y * size + x] = c(30, 80, 40)
                    }
                    // Circuit traces (vertical)
                    if (x == 16 || x == 32 || x == 48) && y >= 36 && y <= 57 {
                        pixels[y * size + x] = c(30, 80, 40)
                    }

                    // Solder points at intersections
                    for cy in [38, 44, 50, 55] {
                        for cx in [16, 32, 48] {
                            let dx = x - cx
                            let dy = y - cy
                            if dx * dx + dy * dy <= 2 {
                                pixels[y * size + x] = c(60, 180, 80)
                            }
                        }
                    }

                    // Small LEDs
                    if y >= 40 && y <= 42 && (x == 10 || x == 12) {
                        pixels[y * size + x] = c(255, 40, 20)  // Red LED
                    }
                    if y >= 40 && y <= 42 && x == 14 {
                        pixels[y * size + x] = c(40, 255, 40)  // Green LED
                    }
                }
            }
        }
        return pixels
    }

    // MARK: - Door (Doom DOOR-style heavy steel)
    private func generateDoorTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                // Heavy steel frame
                if x < 3 || x > 60 || y < 3 {
                    let n = noise01(x, y, 400)
                    pixels[y * size + x] = c(55 + Int(n * 10), 50 + Int(n * 10), 48 + Int(n * 10))
                    // Inner bevel
                    if x == 3 || x == 60 || y == 3 {
                        pixels[y * size + x] = c(75, 72, 70)
                    }
                    continue
                }

                // Door panel body
                let n = noise01(x, y, 401)
                let base = 72 + Int(n * 12)

                // Vertical ribbing (industrial look)
                let ribPhase = x % 8
                let ribDarken = ribPhase < 2 ? -10 : (ribPhase == 3 ? 8 : 0)

                // Horizontal panel divisions
                let panelY = y % 32
                if panelY < 1 {
                    pixels[y * size + x] = c(45, 45, 48)
                    continue
                }

                // Vertical center bevel
                let vGrad = panelY < 4 ? 10 : (panelY > 28 ? -8 : 0)

                pixels[y * size + x] = c(base + ribDarken + vGrad,
                                          base + ribDarken + vGrad + 2,
                                          base + ribDarken + vGrad + 5)

                // Yellow/black hazard stripe near bottom
                if y >= 52 && y <= 58 {
                    let stripePhase = (x + y) % 8
                    if stripePhase < 4 {
                        pixels[y * size + x] = c(200, 180, 20)
                    } else {
                        pixels[y * size + x] = c(25, 25, 25)
                    }
                }

                // Door handle/lock
                if x >= 28 && x <= 36 && y >= 24 && y <= 40 {
                    pixels[y * size + x] = c(50, 50, 55)
                    if x >= 30 && x <= 34 && y >= 26 && y <= 38 {
                        pixels[y * size + x] = c(160, 130, 20) // Brass handle
                    }
                    if x >= 31 && x <= 33 && y >= 30 && y <= 34 {
                        pixels[y * size + x] = c(200, 170, 40) // Handle highlight
                    }
                }
            }
        }
        return pixels
    }

    // MARK: - Floor (Doom FLAT-style dark stone tiles)
    private func generateFloorTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                let tileX = x % 32
                let tileY = y % 32

                // Tile grout
                if tileX < 1 || tileY < 1 {
                    pixels[y * size + x] = c(22, 20, 18)
                    continue
                }

                // Stone base with per-tile color variation
                let tileID = (y / 32) * 2 + (x / 32)
                let tileNoise = noise01(tileID, tileID * 13, 500)
                let baseV = 50 + Int(tileNoise * 20)

                // Per-pixel detail noise
                let n = noise01(x, y, 501)
                let detail = Int(n * 16) - 8

                // Subtle worn spots (lighter patches)
                let wear = noise01(x / 3, y / 3, 502)
                let wearAdd = wear > 0.85 ? 12 : 0

                // Edge darkening for tile depth
                let edgeD = (tileX < 3 || tileY < 3) ? -5 : ((tileX > 29 || tileY > 29) ? 4 : 0)

                let v = baseV + detail + wearAdd + edgeD
                pixels[y * size + x] = c(v, v - 2, v - 5)
            }
        }
        return pixels
    }

    // MARK: - Ceiling (Doom FLAT-style industrial ceiling panels)
    private func generateCeilingTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                // Industrial panel grid
                let panelX = x % 32
                let panelY = y % 32

                // Panel edges
                if panelX < 1 || panelY < 1 {
                    pixels[y * size + x] = c(28, 26, 22)
                    continue
                }

                let n = noise01(x, y, 600)
                let base = 38 + Int(n * 10)

                // Light fixture in center of each panel
                let cx = panelX - 16
                let cy = panelY - 16
                let dist = cx * cx + cy * cy
                if dist < 25 {
                    // Fluorescent light (dim yellowish)
                    let intensity = max(0, 25 - dist) * 3
                    pixels[y * size + x] = c(base + intensity, base + intensity - 2, base + intensity / 2)
                    continue
                }

                // Slight rust stains
                let rust = noise01(x / 2, y / 2, 601)
                let rustAdd = rust > 0.9 ? 8 : 0

                pixels[y * size + x] = c(base + rustAdd, base - 3 + rustAdd / 2, base - 5)
            }
        }
        return pixels
    }

    // MARK: - Brick with Torch
    private func generateBrickTorchTexture() -> [UInt32] {
        var pixels = generateBrickTexture()

        // Iron torch bracket
        for y in 26..<48 {
            for x in 28..<36 {
                if x >= 30 && x <= 33 {
                    pixels[y * size + x] = c(45, 40, 35)
                    // Bracket highlight on left edge
                    if x == 30 { pixels[y * size + x] = c(65, 60, 55) }
                }
            }
        }
        // Bracket arm
        for x in 26..<38 {
            pixels[26 * size + x] = c(50, 45, 40)
            pixels[27 * size + x] = c(40, 35, 30)
        }

        // Flame (multi-layered for realistic look)
        for y in 8..<27 {
            for x in 26..<38 {
                let cx = 32.0
                let cy = 18.0
                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let dist = sqrt(dx * dx + dy * dy * 0.6)

                // Flame shape: wider at bottom, narrow at top
                let maxR = 5.0 - Double(y - 8) * 0.15
                if dist < maxR {
                    let t = dist / maxR
                    if t < 0.3 {
                        // White hot core
                        pixels[y * size + x] = c(255, 255, 200)
                    } else if t < 0.55 {
                        // Yellow
                        pixels[y * size + x] = c(255, 220, 60)
                    } else if t < 0.8 {
                        // Orange
                        pixels[y * size + x] = c(255, 130, 20)
                    } else {
                        // Red edge
                        pixels[y * size + x] = c(200, 50, 10)
                    }
                }
            }
        }

        // Light cast on surrounding brick from torch
        for y in 10..<45 {
            for x in 20..<44 {
                let dx = Double(x) - 32.0
                let dy = Double(y) - 22.0
                let dist = sqrt(dx * dx + dy * dy)
                if dist < 12 && dist > 5 {
                    let existing = pixels[y * size + x]
                    let warmth = max(0.0, 1.0 - dist / 12.0) * 0.3
                    let r = min(255, Int(Double(PixelBuffer.getRed(existing))) + Int(warmth * 60))
                    let g = min(255, Int(Double(PixelBuffer.getGreen(existing))) + Int(warmth * 30))
                    let b = Int(Double(PixelBuffer.getBlue(existing)))
                    pixels[y * size + x] = c(r, g, b)
                }
            }
        }

        return pixels
    }

    // MARK: - Exit Portal (glowing green energy portal - level exit)
    private func generateExitPortalTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        let cx = Double(size) / 2.0
        let cy = Double(size) / 2.0
        let maxR = Double(size) / 2.0 - 3.0

        for y in 0..<size {
            for x in 0..<size {
                // Dark metal frame border
                if x < 3 || x >= size - 3 || y < 3 || y >= size - 3 {
                    let n = noise01(x, y, 700)
                    let v = 30 + Int(n * 15)
                    pixels[y * size + x] = c(v, v + 5, v)
                    // Inner bevel glow
                    if x == 3 || x == size - 4 || y == 3 || y == size - 4 {
                        pixels[y * size + x] = c(20, 80, 30)
                    }
                    continue
                }

                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let dist = sqrt(dx * dx + dy * dy)
                let normDist = dist / maxR

                if normDist > 1.0 {
                    // Corner outside the portal circle — dark frame
                    pixels[y * size + x] = c(15, 20, 15)
                    continue
                }

                // Swirling energy pattern using noise at different scales
                let angle = atan2(dy, dx)
                let swirl1 = noise01(Int(angle * 10 + dist * 3), Int(dist * 5), 710)
                let swirl2 = noise01(x / 2, y / 2, 720)
                let swirl3 = noise01(x * 3 + y, y * 2 - x, 730)

                // Core glow — brighter toward center
                let coreBright = max(0.0, 1.0 - normDist)
                let edgeGlow = normDist > 0.7 ? (normDist - 0.7) / 0.3 : 0.0

                // Green energy field
                let baseG = Int(80.0 + coreBright * 175.0 + swirl1 * 40.0)
                let baseR = Int(10.0 + coreBright * 60.0 + swirl2 * 20.0)
                let baseB = Int(20.0 + coreBright * 80.0 + swirl3 * 30.0)

                // Bright ring at edge
                let ringR = Int(edgeGlow * 80.0)
                let ringG = Int(edgeGlow * 200.0)
                let ringB = Int(edgeGlow * 100.0)

                // Bright center hotspot
                let hotspot = normDist < 0.2 ? (0.2 - normDist) / 0.2 : 0.0
                let hotR = Int(hotspot * 100.0)
                let hotG = Int(hotspot * 255.0)
                let hotB = Int(hotspot * 150.0)

                pixels[y * size + x] = c(
                    min(255, baseR + ringR + hotR),
                    min(255, baseG + ringG + hotG),
                    min(255, baseB + ringB + hotB)
                )
            }
        }

        // Add "EXIT" text in bright white across the center
        // Simple 3x5 pixel font for E, X, I, T
        let letters: [[[Int]]] = [
            // E
            [[1,1,1],[1,0,0],[1,1,0],[1,0,0],[1,1,1]],
            // X
            [[1,0,1],[0,1,0],[0,1,0],[0,1,0],[1,0,1]],
            // I
            [[1,1,1],[0,1,0],[0,1,0],[0,1,0],[1,1,1]],
            // T
            [[1,1,1],[0,1,0],[0,1,0],[0,1,0],[0,1,0]],
        ]
        let textStartX = size / 2 - 9
        let textStartY = size / 2 - 3
        let textColor = c(255, 255, 230)

        for (li, letter) in letters.enumerated() {
            let ox = textStartX + li * 5
            for (ry, row) in letter.enumerated() {
                for (rx, val) in row.enumerated() {
                    if val == 1 {
                        let px = ox + rx
                        let py = textStartY + ry
                        if px >= 0 && px < size && py >= 0 && py < size {
                            pixels[py * size + px] = textColor
                        }
                    }
                }
            }
        }

        return pixels
    }

    // MARK: - Locked Door Textures

    private func generateLockedDoorTexture(borderR: Int, borderG: Int, borderB: Int) -> [UInt32] {
        // Start with normal door texture, add colored border
        var pixels = generateDoorTexture()

        let borderColor = c(borderR, borderG, borderB)
        let borderDark = c(borderR * 2/3, borderG * 2/3, borderB * 2/3)

        // Top and bottom colored borders (4 pixels thick)
        for y in 0..<4 {
            for x in 0..<size {
                pixels[y * size + x] = borderColor
                pixels[(size - 1 - y) * size + x] = borderColor
            }
        }

        // Left and right colored borders (4 pixels thick)
        for y in 0..<size {
            for x in 0..<4 {
                pixels[y * size + x] = borderColor
                pixels[y * size + (size - 1 - x)] = borderColor
            }
        }

        // Inner shadow on border
        for x in 4..<(size - 4) {
            pixels[4 * size + x] = borderDark
        }
        for y in 4..<(size - 4) {
            pixels[y * size + 4] = borderDark
        }

        // Key symbol in center (small lock shape)
        let cx = size / 2
        let cy = size / 2
        let lockColor = c(min(255, borderR + 50), min(255, borderG + 50), min(255, borderB + 50))
        // Lock body
        for y in cy...cy+5 {
            for x in (cx-3)...(cx+3) {
                if y < size && x >= 0 && x < size {
                    pixels[y * size + x] = lockColor
                }
            }
        }
        // Lock shackle (arc)
        for x in (cx-2)...(cx+2) {
            let y = cy - 2
            if y >= 0 && x >= 0 && x < size {
                pixels[y * size + x] = lockColor
            }
        }
        for y in (cy-2)...cy {
            if y >= 0 {
                pixels[y * size + (cx - 2)] = lockColor
                pixels[y * size + (cx + 2)] = lockColor
            }
        }

        return pixels
    }

    // MARK: - Damage Floor (toxic green nukage)
    private func generateDamageFloorTexture() -> [UInt32] {
        var pixels = [UInt32](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                // Sludgy green base with noise
                let n1 = noise01(x, y, 800)
                let n2 = noise01(x / 2, y / 2, 810)
                let n3 = noise01(x * 3 + y, y * 2 - x, 820)

                // Turbulent green sludge
                let baseG = 80 + Int(n1 * 60) + Int(n2 * 30)
                let baseR = 15 + Int(n1 * 20) + Int(n3 * 10)
                let baseB = 5 + Int(n2 * 15)

                // Bright toxic veins
                let veinX = sin(Double(x) * 0.3 + n1 * 4.0)
                let veinY = sin(Double(y) * 0.3 + n2 * 4.0)
                let vein = max(0.0, 1.0 - abs(veinX + veinY))
                let veinBright = Int(vein * vein * 80.0)

                // Occasional bright spots (bubbles)
                let bubble = hash(x / 4, y / 4, 830) % 20 == 0 ? 40 : 0

                pixels[y * size + x] = c(
                    min(255, baseR + veinBright / 3),
                    min(255, baseG + veinBright + bubble),
                    min(255, baseB + veinBright / 4)
                )
            }
        }
        return pixels
    }
}
