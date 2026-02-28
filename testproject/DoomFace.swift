//
//  DoomFace.swift
//  testproject
//

import Foundation

final class DoomFace {
    // 48x48 pixel face with 22 frames
    let size = 48
    var frames: [[UInt32]] = []

    // Frame indices
    // Center face: 5 health levels (100%→0%)
    static let centerHealth100 = 0
    static let centerHealth80  = 1
    static let centerHealth60  = 2
    static let centerHealth40  = 3
    static let centerHealth20  = 4
    // Left-look: 5 health levels
    static let leftHealth100   = 5
    static let leftHealth80    = 6
    static let leftHealth60    = 7
    static let leftHealth40    = 8
    static let leftHealth20    = 9
    // Right-look: 5 health levels
    static let rightHealth100  = 10
    static let rightHealth80   = 11
    static let rightHealth60   = 12
    static let rightHealth40   = 13
    static let rightHealth20   = 14
    // Special states
    static let ouch            = 15
    static let grin            = 16
    static let godMode         = 17
    static let blinkHalf       = 18
    static let blinkFull       = 19
    static let idleEyeLeft     = 20
    static let idleEyeRight    = 21

    init() {
        generateAllFrames()
    }

    // MARK: - Frame Selection Logic

    func frameForState(
        health: Int,
        recentDamage: Bool,
        damageDir: Double,
        pickupGrin: Bool,
        isGodMode: Bool = false,
        elapsedTime: Double = 0,
        playerAngle: Double = 0
    ) -> Int {
        if health <= 0 { return healthIndex(for: 0, direction: .center) }
        if isGodMode { return DoomFace.godMode }
        if pickupGrin { return DoomFace.grin }

        // Ouch on recent strong damage
        if recentDamage {
            // Use damage direction to look toward the source
            let relAngle = normalizeAngle(damageDir - playerAngle)
            if relAngle > 0.5 && relAngle < 2.64 {
                return healthIndex(for: health, direction: .left)
            } else if relAngle > 3.64 && relAngle < 5.78 {
                return healthIndex(for: health, direction: .right)
            }
            return DoomFace.ouch
        }

        // Periodic blink (every 3-4s, 0.15s duration)
        let blinkCycle = elapsedTime.truncatingRemainder(dividingBy: 3.5)
        if blinkCycle > 3.35 {
            return DoomFace.blinkFull
        } else if blinkCycle > 3.25 {
            return DoomFace.blinkHalf
        }

        // Subtle idle eye movement (every 2s)
        let idleCycle = elapsedTime.truncatingRemainder(dividingBy: 4.0)
        if idleCycle > 1.8 && idleCycle < 2.3 {
            return DoomFace.idleEyeLeft
        } else if idleCycle > 3.3 && idleCycle < 3.8 {
            return DoomFace.idleEyeRight
        }

        return healthIndex(for: health, direction: .center)
    }

    // MARK: - Helpers

    private enum LookDirection { case left, center, right }

    private func healthIndex(for health: Int, direction: LookDirection) -> Int {
        let healthPct = Double(health) / Double(GameConstants.maxHealth)
        let level: Int
        if healthPct > 0.8 { level = 0 }
        else if healthPct > 0.6 { level = 1 }
        else if healthPct > 0.4 { level = 2 }
        else if healthPct > 0.2 { level = 3 }
        else { level = 4 }

        switch direction {
        case .center: return level
        case .left: return 5 + level
        case .right: return 10 + level
        }
    }

    private func normalizeAngle(_ a: Double) -> Double {
        var r = a
        while r < 0 { r += .pi * 2 }
        while r >= .pi * 2 { r -= .pi * 2 }
        return r
    }

    // MARK: - Frame Generation

    private func generateAllFrames() {
        frames.removeAll()

        // 0-4: Center face, 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .none)) }
        // 5-9: Left look, 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: -1, special: .none)) }
        // 10-14: Right look, 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 1, special: .none)) }
        // 15: Ouch
        frames.append(generateFace(healthLevel: 2, lookDir: 0, special: .ouch))
        // 16: Grin
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .grin))
        // 17: God mode
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .godMode))
        // 18: Blink half
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .blinkHalf))
        // 19: Blink full
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .blinkFull))
        // 20: Idle eye left
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .idleEyeLeft))
        // 21: Idle eye right
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .idleEyeRight))
    }

    private enum SpecialFrame { case none, ouch, grin, godMode, blinkHalf, blinkFull, idleEyeLeft, idleEyeRight }

    private func generateFace(healthLevel: Int, lookDir: Int, special: SpecialFrame) -> [UInt32] {
        let T = UInt32(0) // transparent
        var px = [UInt32](repeating: T, count: size * size)

        // Health level: 0 = full (100%), 4 = dead (0%)
        let skinColor = skinColorForHealth(healthLevel)
        let darkerSkin = darkenColor(skinColor, factor: 0.8)
        let shadowSkin = darkenColor(skinColor, factor: 0.65)

        // 1. Face shape (oval)
        drawFaceShape(&px, skin: skinColor, darkerSkin: darkerSkin, shadow: shadowSkin)

        // 2. Hair
        drawHair(&px, healthLevel: healthLevel)

        // 3. Eyes
        let eyeLook: Int
        switch special {
        case .idleEyeLeft: eyeLook = -2
        case .idleEyeRight: eyeLook = 2
        default: eyeLook = lookDir
        }
        drawEyes(&px, lookDir: eyeLook, healthLevel: healthLevel, special: special)

        // 4. Eyebrows
        drawEyebrows(&px, healthLevel: healthLevel, special: special)

        // 5. Nose
        drawNose(&px, skin: darkerSkin)

        // 6. Mouth
        drawMouth(&px, healthLevel: healthLevel, special: special)

        // 7. Blood overlay (drawn last so it's on top)
        drawBlood(&px, healthLevel: healthLevel)

        // 8. Bruise
        if healthLevel >= 2 {
            drawBruise(&px, healthLevel: healthLevel)
        }

        return px
    }

    // MARK: - Skin Color

    private func skinColorForHealth(_ level: Int) -> UInt32 {
        // Warm peach at full health → pale green at near-death
        switch level {
        case 0: return makeColor(r: 220, g: 180, b: 140)  // Healthy peach
        case 1: return makeColor(r: 210, g: 170, b: 130)  // Slightly paler
        case 2: return makeColor(r: 195, g: 165, b: 130)  // Noticeably pale
        case 3: return makeColor(r: 175, g: 170, b: 130)  // Sickly yellow
        default: return makeColor(r: 150, g: 170, b: 140) // Pale green (dead)
        }
    }

    // MARK: - Face Shape

    private func drawFaceShape(_ px: inout [UInt32], skin: UInt32, darkerSkin: UInt32, shadow: UInt32) {
        let cx = size / 2
        let cy = size / 2 + 1
        let rx = 19  // horizontal radius
        let ry = 21  // vertical radius

        for y in 0..<size {
            for x in 0..<size {
                let dx = Double(x - cx) / Double(rx)
                let dy = Double(y - cy) / Double(ry)
                let d = dx * dx + dy * dy

                if d < 0.85 {
                    // Inner face — smooth shading
                    let shade = 1.0 - d * 0.15
                    // Jawline shading (darken bottom)
                    let jawShade = y > cy + 10 ? 0.9 : 1.0
                    if shade * jawShade < 0.88 {
                        px[y * size + x] = darkerSkin
                    } else {
                        px[y * size + x] = skin
                    }
                } else if d < 1.0 {
                    // Edge of face — darker outline
                    px[y * size + x] = shadow
                }
            }
        }
    }

    // MARK: - Hair

    private func drawHair(_ px: inout [UInt32], healthLevel: Int) {
        let hairDark = makeColor(r: 60, g: 40, b: 25)
        let hairLight = makeColor(r: 85, g: 55, b: 35)

        let cx = size / 2
        let rx = 19
        let messiness = healthLevel // More disheveled at lower health

        for y in 2..<14 {
            for x in 5..<(size - 5) {
                let dx = Double(x - cx) / Double(rx)
                let dy = Double(y - 7) / 14.0
                let d = dx * dx + dy * dy

                // Hair follows top of head curve
                let headEdge = 1.0 - Double(y - 2) * 0.06
                if d < headEdge && y < 12 - (abs(x - cx) > 12 ? 2 : 0) {
                    // Add some texture variation
                    let isLight = (x + y * 3) % (4 + messiness) == 0
                    px[y * size + x] = isLight ? hairLight : hairDark

                    // Messy strands at low health
                    if messiness >= 2 && y > 9 && (x % (5 - min(messiness, 3))) == 0 {
                        if y + 1 < size {
                            px[(y + 1) * size + x] = hairDark
                        }
                        if messiness >= 3 && y + 2 < size {
                            px[(y + 2) * size + x] = hairDark
                        }
                    }
                }
            }
        }
    }

    // MARK: - Eyes

    private func drawEyes(_ px: inout [UInt32], lookDir: Int, healthLevel: Int, special: SpecialFrame) {
        let eyeWhite = makeColor(r: 240, g: 240, b: 240)
        let iris = makeColor(r: 70, g: 110, b: 60)   // Green-brown iris
        let pupil = makeColor(r: 20, g: 20, b: 20)
        let bloodshot = makeColor(r: 200, g: 60, b: 60)
        let goldEye = makeColor(r: 255, g: 215, b: 0)

        let leftEyeCX = 16
        let rightEyeCX = 32
        let eyeCY = 20

        // Eye dimensions: 5 wide x 3 tall (sclera)
        let eyeW = 5
        let eyeH = 3

        // Dead eyes (X shape)
        if healthLevel >= 4 {
            drawDeadEyes(&px, leftCX: leftEyeCX, rightCX: rightEyeCX, cy: eyeCY)
            return
        }

        // Blink states
        if case .blinkFull = special {
            // Fully closed — just draw thin lines
            let lineColor = makeColor(r: 100, g: 70, b: 50)
            for dx in (-eyeW/2)...(eyeW/2) {
                px[eyeCY * size + leftEyeCX + dx] = lineColor
                px[eyeCY * size + rightEyeCX + dx] = lineColor
            }
            return
        }

        let halfBlink = { () -> Bool in
            if case .blinkHalf = special { return true }
            return false
        }()

        // Draw each eye
        for (ecx, _) in [(leftEyeCX, -1), (rightEyeCX, 1)] {
            // Sclera (eye white)
            let yStart = halfBlink ? eyeCY : eyeCY - eyeH / 2
            let yEnd = eyeCY + eyeH / 2

            for dy in yStart...yEnd {
                for dx in (ecx - eyeW / 2)...(ecx + eyeW / 2) {
                    guard dx >= 0 && dx < size && dy >= 0 && dy < size else { continue }
                    // Rounded corners
                    let cornerDist = abs(dx - ecx) + abs(dy - eyeCY)
                    if cornerDist <= eyeW / 2 + 1 {
                        if healthLevel >= 2 && (dx == ecx - eyeW/2 || dx == ecx + eyeW/2) {
                            // Bloodshot edges at low health
                            px[dy * size + dx] = bloodshot
                        } else {
                            px[dy * size + dx] = eyeWhite
                        }
                    }
                }
            }

            // Iris (2x2) — offset by look direction
            let irisOffX = min(1, max(-1, lookDir))
            let irisCX = ecx + irisOffX
            let irisCY = eyeCY

            if case .godMode = special {
                // Gold glowing eyes
                for dy in (irisCY - 1)...(irisCY + 1) {
                    for dx in (irisCX - 1)...(irisCX + 1) {
                        guard dx >= 0 && dx < size && dy >= 0 && dy < size else { continue }
                        px[dy * size + dx] = goldEye
                    }
                }
            } else {
                // Normal iris + pupil
                for dy in (irisCY - 1)...irisCY {
                    for dx in (irisCX - 1)...irisCX {
                        guard dx >= 0 && dx < size && dy >= 0 && dy < size else { continue }
                        px[dy * size + dx] = iris
                    }
                }
                // Pupil (1x1 center)
                let pupilX = irisCX + (lookDir > 0 ? 0 : -1) + (lookDir == 0 ? 0 : 0)
                let pupilY = irisCY
                if pupilX >= 0 && pupilX < size && pupilY >= 0 && pupilY < size {
                    px[pupilY * size + pupilX] = pupil
                }
            }
        }
    }

    private func drawDeadEyes(_ px: inout [UInt32], leftCX: Int, rightCX: Int, cy: Int) {
        let xColor = makeColor(r: 30, g: 30, b: 30)
        for (ecx, _) in [(leftCX, 0), (rightCX, 0)] {
            // Draw X
            for i in -2...2 {
                let x1 = ecx + i
                let y1 = cy + i
                let y2 = cy - i
                if x1 >= 0 && x1 < size {
                    if y1 >= 0 && y1 < size { px[y1 * size + x1] = xColor }
                    if y2 >= 0 && y2 < size { px[y2 * size + x1] = xColor }
                }
            }
        }
    }

    // MARK: - Eyebrows

    private func drawEyebrows(_ px: inout [UInt32], healthLevel: Int, special: SpecialFrame) {
        let browColor = makeColor(r: 70, g: 45, b: 30)

        let leftBrowCX = 16
        let rightBrowCX = 32
        let browY = 16

        // Anger tilt increases at lower health
        let innerTilt = healthLevel >= 3 ? -2 : (healthLevel >= 2 ? -1 : 0)
        let isOuch = { () -> Bool in
            if case .ouch = special { return true }
            return false
        }()
        let outerRaise = isOuch ? -2 : 0

        // Left eyebrow
        for dx in -3...3 {
            let x = leftBrowCX + dx
            let tilt = dx < 0 ? outerRaise : innerTilt
            let y = browY + tilt
            if x >= 0 && x < size && y >= 0 && y < size {
                px[y * size + x] = browColor
                if y + 1 < size { px[(y + 1) * size + x] = browColor }
            }
        }

        // Right eyebrow
        for dx in -3...3 {
            let x = rightBrowCX + dx
            let tilt = dx > 0 ? outerRaise : innerTilt
            let y = browY + tilt
            if x >= 0 && x < size && y >= 0 && y < size {
                px[y * size + x] = browColor
                if y + 1 < size { px[(y + 1) * size + x] = browColor }
            }
        }
    }

    // MARK: - Nose

    private func drawNose(_ px: inout [UInt32], skin: UInt32) {
        let noseShadow = darkenColor(skin, factor: 0.7)
        let noseHighlight = lightenColor(skin, factor: 1.15)

        // Triangle nose shadow
        let noseY = 26
        // Nose bridge
        for y in 23...25 {
            px[y * size + 24] = noseHighlight
            px[y * size + 23] = noseShadow
        }
        // Nose base (wider at bottom)
        for x in 22...26 {
            px[noseY * size + x] = noseShadow
        }
        // Nostrils
        let nostril = darkenColor(skin, factor: 0.5)
        px[(noseY + 1) * size + 22] = nostril
        px[(noseY + 1) * size + 26] = nostril
    }

    // MARK: - Mouth

    private func drawMouth(_ px: inout [UInt32], healthLevel: Int, special: SpecialFrame) {
        let lipColor = makeColor(r: 170, g: 80, b: 70)
        let darkMouth = makeColor(r: 60, g: 20, b: 20)
        let teethColor = makeColor(r: 235, g: 230, b: 220)

        let mouthY = 32
        let cx = size / 2

        switch special {
        case .ouch:
            // Wide open mouth — shock/pain
            for y in mouthY...(mouthY + 5) {
                for x in (cx - 5)...(cx + 5) {
                    let dx = abs(x - cx)
                    let dy = y - mouthY
                    if dx * dx + dy * dy < 30 {
                        if dy <= 1 {
                            px[y * size + x] = teethColor  // Top teeth
                        } else {
                            px[y * size + x] = darkMouth
                        }
                    }
                }
            }
            // Lips around
            for x in (cx - 5)...(cx + 5) {
                px[(mouthY - 1) * size + x] = lipColor
                px[(mouthY + 6) * size + x] = lipColor
            }

        case .grin:
            // Wide toothy grin
            for x in (cx - 7)...(cx + 7) {
                px[mouthY * size + x] = lipColor
                px[(mouthY + 1) * size + x] = teethColor
                px[(mouthY + 2) * size + x] = teethColor
                px[(mouthY + 3) * size + x] = lipColor
            }
            // Teeth separators
            for x in stride(from: cx - 6, to: cx + 7, by: 2) {
                px[(mouthY + 1) * size + x] = makeColor(r: 200, g: 195, b: 185)
            }

        default:
            // Health-based mouth expression
            switch healthLevel {
            case 0:
                // Neutral — slight confident line
                for x in (cx - 4)...(cx + 4) {
                    px[mouthY * size + x] = lipColor
                    px[(mouthY + 1) * size + x] = lipColor
                }
            case 1:
                // Slight frown
                for x in (cx - 4)...(cx + 4) {
                    let droop = abs(x - cx) > 2 ? 1 : 0
                    px[(mouthY + droop) * size + x] = lipColor
                    px[(mouthY + 1 + droop) * size + x] = lipColor
                }
            case 2:
                // Grimace with some teeth showing
                for x in (cx - 5)...(cx + 5) {
                    px[mouthY * size + x] = lipColor
                    px[(mouthY + 1) * size + x] = teethColor
                    px[(mouthY + 2) * size + x] = lipColor
                }
            case 3:
                // Grimace + open grimace
                for x in (cx - 5)...(cx + 5) {
                    px[mouthY * size + x] = lipColor
                    px[(mouthY + 1) * size + x] = teethColor
                    px[(mouthY + 2) * size + x] = darkMouth
                    px[(mouthY + 3) * size + x] = lipColor
                }
            default:
                // Dead — slack jaw
                for y in mouthY...(mouthY + 4) {
                    for x in (cx - 4)...(cx + 4) {
                        let dy = y - mouthY
                        if dy <= 1 {
                            px[y * size + x] = teethColor
                        } else {
                            px[y * size + x] = darkMouth
                        }
                    }
                }
                for x in (cx - 4)...(cx + 4) {
                    px[(mouthY - 1) * size + x] = lipColor
                }
            }
        }
    }

    // MARK: - Blood

    private func drawBlood(_ px: inout [UInt32], healthLevel: Int) {
        let bloodBright = makeColor(r: 200, g: 20, b: 10)
        let bloodDark = makeColor(r: 140, g: 10, b: 5)

        guard healthLevel >= 1 else { return }

        // Level 1: Small forehead cut
        if healthLevel >= 1 {
            px[10 * size + 18] = bloodBright
            px[11 * size + 18] = bloodBright
            px[12 * size + 18] = bloodDark
            px[12 * size + 19] = bloodDark
        }

        // Level 2: Nose bleed + more forehead blood
        if healthLevel >= 2 {
            // Nose bleed
            for y in 28...32 {
                px[y * size + 24] = bloodBright
            }
            px[33 * size + 24] = bloodDark
            // Forehead drip
            for y in 10...15 {
                px[y * size + 18] = bloodBright
            }
            px[16 * size + 18] = bloodDark
        }

        // Level 3: Heavy bleeding + streams
        if healthLevel >= 3 {
            // Left side stream
            for y in 8...22 {
                px[y * size + 12] = bloodBright
                px[y * size + 13] = bloodDark
            }
            // Right side
            for y in 14...20 {
                px[y * size + 35] = bloodBright
            }
            // More nose blood
            for x in 23...25 {
                px[30 * size + x] = bloodBright
                px[31 * size + x] = bloodDark
            }
        }

        // Level 4: Face covered
        if healthLevel >= 4 {
            for y in 6...40 {
                for x in 8...40 {
                    if px[y * size + x] != 0 && (x + y) % 3 == 0 {
                        px[y * size + x] = bloodDark
                    }
                }
            }
        }
    }

    // MARK: - Bruise

    private func drawBruise(_ px: inout [UInt32], healthLevel: Int) {
        let bruise1 = makeColor(r: 120, g: 80, b: 140)   // Purple
        let bruise2 = makeColor(r: 100, g: 70, b: 120)   // Darker purple

        // Right cheek bruise
        let bcx = 34
        let bcy = 25
        let radius = healthLevel >= 3 ? 4 : 3

        for y in (bcy - radius)...(bcy + radius) {
            for x in (bcx - radius)...(bcx + radius) {
                let dx = x - bcx
                let dy = y - bcy
                if dx * dx + dy * dy < radius * radius {
                    guard x >= 0 && x < size && y >= 0 && y < size else { continue }
                    // Only bruise over existing skin pixels
                    if px[y * size + x] != 0 {
                        px[y * size + x] = (dx + dy) % 2 == 0 ? bruise1 : bruise2
                    }
                }
            }
        }

        // Black eye at very low health
        if healthLevel >= 3 {
            let eyeX = 32
            let eyeY = 20
            for y in (eyeY - 2)...(eyeY + 2) {
                for x in (eyeX + 2)...(eyeX + 4) {
                    guard x >= 0 && x < size && y >= 0 && y < size else { continue }
                    if px[y * size + x] != 0 {
                        px[y * size + x] = makeColor(r: 80, g: 50, b: 90)
                    }
                }
            }
        }
    }

    // MARK: - Color Utilities

    private func makeColor(r: UInt8, g: UInt8, b: UInt8) -> UInt32 {
        return (0xFF << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }

    private func darkenColor(_ color: UInt32, factor: Double) -> UInt32 {
        let r = Double((color >> 16) & 0xFF) * factor
        let g = Double((color >> 8) & 0xFF) * factor
        let b = Double(color & 0xFF) * factor
        return makeColor(r: UInt8(min(255, r)), g: UInt8(min(255, g)), b: UInt8(min(255, b)))
    }

    private func lightenColor(_ color: UInt32, factor: Double) -> UInt32 {
        let r = min(255, Double((color >> 16) & 0xFF) * factor)
        let g = min(255, Double((color >> 8) & 0xFF) * factor)
        let b = min(255, Double(color & 0xFF) * factor)
        return makeColor(r: UInt8(r), g: UInt8(g), b: UInt8(b))
    }
}
