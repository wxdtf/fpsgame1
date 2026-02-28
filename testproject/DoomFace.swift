//
//  DoomFace.swift
//  testproject
//

import Foundation

final class DoomFace {
    // 5 health states x 3 directions (left, center, right) + special states
    // Each face is 24x24 pixels
    let size = 24
    var frames: [[UInt32]] = []

    // Frame indices
    static let centerHealthy = 0
    static let centerHurt1 = 1
    static let centerHurt2 = 2
    static let centerHurt3 = 3
    static let centerDying = 4
    static let leftHealthy = 5
    static let rightHealthy = 6
    static let ouch = 7
    static let grin = 8

    init() {
        generateAllFrames()
    }

    private func generateAllFrames() {
        let skinColor = PixelBuffer.makeColor(r: 210, g: 170, b: 130)
        let T = UInt32(0)

        // Generate 9 face frames
        for frameIdx in 0..<9 {
            var px = [UInt32](repeating: T, count: size * size)
            let healthLevel: Int
            let lookDir: Int  // -1 left, 0 center, 1 right

            switch frameIdx {
            case 0: healthLevel = 4; lookDir = 0
            case 1: healthLevel = 3; lookDir = 0
            case 2: healthLevel = 2; lookDir = 0
            case 3: healthLevel = 1; lookDir = 0
            case 4: healthLevel = 0; lookDir = 0
            case 5: healthLevel = 4; lookDir = -1
            case 6: healthLevel = 4; lookDir = 1
            case 7: healthLevel = 2; lookDir = 0  // ouch
            case 8: healthLevel = 4; lookDir = 0  // grin
            default: healthLevel = 4; lookDir = 0
            }

            // Face shape (circle-ish)
            for y in 0..<size {
                for x in 0..<size {
                    let dx = x - size / 2
                    let dy = y - size / 2
                    if dx * dx + dy * dy < (size / 2 - 1) * (size / 2 - 1) {
                        px[y * size + x] = skinColor
                    }
                }
            }

            // Blood based on health
            let bloodColor = PixelBuffer.makeColor(r: 180, g: 0, b: 0)
            if healthLevel <= 3 {
                // Some blood on forehead
                px[5 * size + 8] = bloodColor
                px[5 * size + 9] = bloodColor
                px[6 * size + 8] = bloodColor
            }
            if healthLevel <= 2 {
                // More blood
                px[4 * size + 15] = bloodColor
                px[5 * size + 15] = bloodColor
                px[5 * size + 16] = bloodColor
                px[10 * size + 6] = bloodColor
                px[11 * size + 6] = bloodColor
            }
            if healthLevel <= 1 {
                // Lots of blood
                for x in 7...10 {
                    px[4 * size + x] = bloodColor
                    px[3 * size + x] = bloodColor
                }
                px[12 * size + 16] = bloodColor
                px[13 * size + 16] = bloodColor
                px[13 * size + 17] = bloodColor
            }

            // Eyes
            let eyeWhite = PixelBuffer.makeColor(r: 240, g: 240, b: 240)
            let eyePupil = PixelBuffer.makeColor(r: 30, g: 30, b: 30)
            let leftEyeX = 8 + lookDir
            let rightEyeX = 15 + lookDir

            if healthLevel > 0 {
                // Eye whites
                for dy in -1...1 {
                    for dx in -1...1 {
                        px[(9 + dy) * size + (leftEyeX + dx)] = eyeWhite
                        px[(9 + dy) * size + (rightEyeX + dx)] = eyeWhite
                    }
                }
                // Pupils
                px[9 * size + leftEyeX + lookDir] = eyePupil
                px[9 * size + rightEyeX + lookDir] = eyePupil
            } else {
                // Dead eyes (X)
                px[8 * size + 7] = eyePupil; px[10 * size + 9] = eyePupil
                px[10 * size + 7] = eyePupil; px[8 * size + 9] = eyePupil
                px[8 * size + 14] = eyePupil; px[10 * size + 16] = eyePupil
                px[10 * size + 14] = eyePupil; px[8 * size + 16] = eyePupil
            }

            // Nose
            px[12 * size + 11] = PixelBuffer.makeColor(r: 180, g: 140, b: 100)
            px[12 * size + 12] = PixelBuffer.makeColor(r: 180, g: 140, b: 100)

            // Mouth
            let mouthColor = PixelBuffer.makeColor(r: 150, g: 60, b: 60)
            if frameIdx == 7 {
                // Ouch - open mouth
                for y in 15...18 {
                    for x in 9...14 {
                        px[y * size + x] = PixelBuffer.makeColor(r: 80, g: 20, b: 20)
                    }
                }
            } else if frameIdx == 8 {
                // Grin
                for x in 8...15 {
                    px[15 * size + x] = mouthColor
                    px[16 * size + x] = mouthColor
                }
                // Teeth
                let teethColor = PixelBuffer.makeColor(r: 240, g: 240, b: 240)
                for x in stride(from: 9, to: 15, by: 2) {
                    px[15 * size + x] = teethColor
                }
            } else if healthLevel <= 1 {
                // Grimace
                for x in 8...15 {
                    px[16 * size + x] = mouthColor
                }
                px[15 * size + 8] = mouthColor
                px[15 * size + 15] = mouthColor
            } else {
                // Neutral / slight frown
                for x in 9...14 {
                    px[15 * size + x] = mouthColor
                }
            }

            frames.append(px)
        }
    }

    func frameForState(health: Int, recentDamage: Bool, damageDir: Double, pickupGrin: Bool) -> Int {
        if pickupGrin { return DoomFace.grin }
        if health <= 0 { return DoomFace.centerDying }
        if recentDamage { return DoomFace.ouch }

        // Health-based center face
        let healthPct = Double(health) / Double(GameConstants.maxHealth)
        if healthPct > 0.8 { return DoomFace.centerHealthy }
        if healthPct > 0.6 { return DoomFace.centerHurt1 }
        if healthPct > 0.4 { return DoomFace.centerHurt2 }
        if healthPct > 0.2 { return DoomFace.centerHurt3 }
        return DoomFace.centerDying
    }
}
