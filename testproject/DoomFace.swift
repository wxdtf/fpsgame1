//
//  DoomFace.swift
//  testproject
//

import Foundation

final class DoomFace {
    // 48x48 pixel face with 42 frames (health-aware for all states)
    let size = 48
    var frames: [[UInt32]] = []

    // Frame layout:
    //  0- 4: Center face × 5 health levels
    //  5- 9: Left-look × 5 health levels
    // 10-14: Right-look × 5 health levels
    // 15-19: Ouch × 5 health levels
    // 20: Grin (always healthy)
    // 21: God mode (always healthy)
    // 22-26: Blink half × 5 health levels
    // 27-31: Blink full × 5 health levels
    // 32-36: Idle eye left × 5 health levels
    // 37-41: Idle eye right × 5 health levels

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
        let hLevel = healthLevel(for: health)

        if health <= 0 { return hLevel }  // Center dead face
        if isGodMode { return 21 }
        if pickupGrin { return 20 }

        // Ouch on recent strong damage
        if recentDamage {
            let relAngle = normalizeAngle(damageDir - playerAngle)
            if relAngle > 0.5 && relAngle < 2.64 {
                return 5 + hLevel  // Left-look with health
            } else if relAngle > 3.64 && relAngle < 5.78 {
                return 10 + hLevel  // Right-look with health
            }
            return 15 + hLevel  // Ouch with health
        }

        // Periodic blink (every 3-4s, 0.15s duration)
        let blinkCycle = elapsedTime.truncatingRemainder(dividingBy: 3.5)
        if blinkCycle > 3.35 {
            return 27 + hLevel  // Blink full with health
        } else if blinkCycle > 3.25 {
            return 22 + hLevel  // Blink half with health
        }

        // Subtle idle eye movement (every 2s)
        let idleCycle = elapsedTime.truncatingRemainder(dividingBy: 4.0)
        if idleCycle > 1.8 && idleCycle < 2.3 {
            return 32 + hLevel  // Idle eye left with health
        } else if idleCycle > 3.3 && idleCycle < 3.8 {
            return 37 + hLevel  // Idle eye right with health
        }

        return hLevel  // Center face with health
    }

    // MARK: - Helpers

    private func healthLevel(for health: Int) -> Int {
        let healthPct = Double(max(0, health)) / Double(GameConstants.maxHealth)
        if healthPct > 0.8 { return 0 }
        else if healthPct > 0.6 { return 1 }
        else if healthPct > 0.4 { return 2 }
        else if healthPct > 0.2 { return 3 }
        else { return 4 }
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

        // 0-4: Center face × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .none)) }
        // 5-9: Left look × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: -1, special: .none)) }
        // 10-14: Right look × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 1, special: .none)) }
        // 15-19: Ouch × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .ouch)) }
        // 20: Grin
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .grin))
        // 21: God mode
        frames.append(generateFace(healthLevel: 0, lookDir: 0, special: .godMode))
        // 22-26: Blink half × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .blinkHalf)) }
        // 27-31: Blink full × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .blinkFull)) }
        // 32-36: Idle eye left × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .idleEyeLeft)) }
        // 37-41: Idle eye right × 5 health levels
        for h in 0..<5 { frames.append(generateFace(healthLevel: h, lookDir: 0, special: .idleEyeRight)) }
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

        // 5. Nose (shows damage at low health)
        drawNose(&px, skin: darkerSkin, healthLevel: healthLevel)

        // 6. Mouth
        drawMouth(&px, healthLevel: healthLevel, special: special)

        // 7. Bruise/swelling (drawn before blood so blood overlays)
        if healthLevel >= 1 {
            drawBruise(&px, healthLevel: healthLevel)
        }

        // 8. Blood overlay (drawn last so it's on top of everything)
        drawBlood(&px, healthLevel: healthLevel)

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

    private func drawNose(_ px: inout [UInt32], skin: UInt32, healthLevel: Int) {
        let noseShadow = darkenColor(skin, factor: 0.7)
        let noseHighlight = lightenColor(skin, factor: 1.15)
        let swollen = makeColor(r: 180, g: 100, b: 100)

        let noseY = 26
        // Nose bridge (shifts slightly at high damage = crooked)
        let crook = healthLevel >= 3 ? 1 : 0
        for y in 23...25 {
            px[y * size + 24 + crook] = noseHighlight
            px[y * size + 23 + crook] = noseShadow
        }
        // Nose base (wider when swollen)
        let noseWidth = healthLevel >= 2 ? 3 : 2
        for x in (23 - noseWidth)...(25 + noseWidth) {
            guard x >= 0 && x < size else { continue }
            px[noseY * size + x] = healthLevel >= 3 ? swollen : noseShadow
        }
        // Nostrils
        let nostril = darkenColor(skin, factor: 0.5)
        px[(noseY + 1) * size + 22] = nostril
        px[(noseY + 1) * size + 26] = nostril
        // Slight redness around nose tip at low health
        if healthLevel >= 3 {
            let redNose = makeColor(r: 195, g: 120, b: 110)
            px[26 * size + 23] = redNose
            px[26 * size + 25] = redNose
        }
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
                // Grimace with teeth showing, split lip
                let splitLip = makeColor(r: 180, g: 30, b: 20)
                for x in (cx - 5)...(cx + 5) {
                    px[mouthY * size + x] = lipColor
                    px[(mouthY + 1) * size + x] = teethColor
                    px[(mouthY + 2) * size + x] = lipColor
                }
                // Split lip on right side
                px[mouthY * size + (cx + 3)] = splitLip
                px[(mouthY + 1) * size + (cx + 4)] = splitLip
            case 3:
                // Pained grimace with teeth clenched, slight blood at corner
                let mouthBlood = makeColor(r: 180, g: 15, b: 10)
                for x in (cx - 5)...(cx + 5) {
                    px[mouthY * size + x] = lipColor
                    px[(mouthY + 1) * size + x] = teethColor
                    px[(mouthY + 2) * size + x] = lipColor
                }
                // Small blood spot at right mouth corner
                px[(mouthY + 2) * size + (cx + 5)] = mouthBlood
                px[(mouthY + 3) * size + (cx + 5)] = mouthBlood
            default:
                // Dead — slack jaw, open mouth
                for y in mouthY...(mouthY + 4) {
                    for x in (cx - 5)...(cx + 5) {
                        guard y < size else { break }
                        let dy = y - mouthY
                        if dy <= 1 {
                            px[y * size + x] = teethColor
                        } else {
                            px[y * size + x] = darkMouth
                        }
                    }
                }
                for x in (cx - 5)...(cx + 5) {
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

        // Level 1: Small forehead cut only
        px[10 * size + 18] = bloodBright
        px[11 * size + 18] = bloodDark

        // Level 2: Forehead drip + single nostril bleed
        if healthLevel >= 2 {
            // Forehead drip extends
            px[12 * size + 18] = bloodBright
            px[13 * size + 18] = bloodDark
            // Single nostril bleed (right)
            for y in 28...30 {
                px[y * size + 25] = bloodBright
            }
            px[31 * size + 25] = bloodDark
        }

        // Level 3: Blood tear from one eye + nosebleed both sides
        if healthLevel >= 3 {
            // Blood tear from left eye (thin, short)
            for y in 22...27 {
                px[y * size + 15] = bloodBright
            }
            px[28 * size + 15] = bloodDark
            // Nosebleed from both nostrils
            for y in 28...31 {
                px[y * size + 23] = bloodBright
                px[y * size + 25] = bloodBright
            }
            px[32 * size + 23] = bloodDark
            px[32 * size + 25] = bloodDark
        }

        // Level 4: Both eye tears + forehead gash + nosebleed
        if healthLevel >= 4 {
            // Blood tear from right eye too
            for y in 22...27 {
                px[y * size + 33] = bloodBright
            }
            px[28 * size + 33] = bloodDark
            // Forehead gash (short, 2px wide)
            for y in 9...14 {
                px[y * size + 18] = bloodBright
                px[y * size + 19] = bloodDark
            }
        }
    }

    // MARK: - Bruise

    private func drawBruise(_ px: inout [UInt32], healthLevel: Int) {
        let bruiseLight = makeColor(r: 150, g: 100, b: 110)  // Reddish
        let bruiseMid = makeColor(r: 120, g: 75, b: 130)     // Purple
        let bruiseDark = makeColor(r: 90, g: 55, b: 110)     // Dark purple
        let blackEye = makeColor(r: 60, g: 35, b: 70)

        // Helper to apply a small bruise spot
        func applyBruise(cx: Int, cy: Int, radius: Int, colors: [UInt32]) {
            for y in (cy - radius)...(cy + radius) {
                for x in (cx - radius)...(cx + radius) {
                    let dx = x - cx
                    let dy = y - cy
                    let dist = dx * dx + dy * dy
                    guard dist < radius * radius else { continue }
                    guard x >= 0 && x < size && y >= 0 && y < size else { continue }
                    guard px[y * size + x] != 0 else { continue }
                    let colorIdx = min(colors.count - 1, dist * colors.count / (radius * radius))
                    px[y * size + x] = colors[colorIdx]
                }
            }
        }

        // Level 1: Minor reddening on right cheek
        if healthLevel >= 1 {
            applyBruise(cx: 34, cy: 26, radius: 2, colors: [bruiseLight])
        }

        // Level 2: Cheek bruise + slight under-eye swelling
        if healthLevel >= 2 {
            applyBruise(cx: 34, cy: 25, radius: 3, colors: [bruiseMid, bruiseLight])
            applyBruise(cx: 33, cy: 22, radius: 2, colors: [bruiseLight])
        }

        // Level 3: Black eye on right side + left cheek bruise
        if healthLevel >= 3 {
            // Right black eye (small, focused under eye)
            applyBruise(cx: 33, cy: 21, radius: 3, colors: [blackEye, bruiseDark])
            // Left cheek bruise
            applyBruise(cx: 14, cy: 26, radius: 2, colors: [bruiseMid])
        }

        // Level 4: Both black eyes + jaw bruise
        if healthLevel >= 4 {
            // Left black eye too
            applyBruise(cx: 15, cy: 21, radius: 3, colors: [blackEye, bruiseDark])
            // Jaw bruise
            applyBruise(cx: 22, cy: 37, radius: 2, colors: [bruiseMid, bruiseLight])
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
