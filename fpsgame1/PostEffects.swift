//
//  PostEffects.swift
//  fpsgame1
//
//  Full-screen feedback drawn over the rendered scene: muzzle flash, directional
//  damage, pickup flash, berserk tint, death camera, hit marker and the fade to
//  black between levels. The Metal path applies these in the post kernel; the CPU
//  fallback applies them to the pixel buffer with `apply(to:)`.
//

import Foundation

struct PostEffects {
    /// Warm white tint intensity (0...0.3) right after firing
    var muzzleFlash: Double = 0
    /// Red edge gradient strength (0...0.5) and where the hit came from
    var damageIntensity: Double = 0
    var damageDirection: Double = 0
    var playerAngle: Double = 0
    /// Yellow tint intensity (0...0.2) after picking something up
    var pickupFlash: Double = 0
    /// Constant red tint while berserk (0 or 0.08)
    var berserkTint: Double = 0
    /// Death camera progress, 0 = alive, 1 = fully collapsed
    var deathProgress: Double = 0
    /// Hit marker opacity; drawn when >= 0.5
    var hitMarkerAlpha: Double = 0
    /// Level transition fade, 0 = none, 1 = black
    var fadeToBlack: Double = 0

    static let muzzleColor = (r: 255.0, g: 240.0, b: 200.0)
    static let pickupColor = (r: 255.0, g: 255.0, b: 0.0)
    static let berserkColor = (r: 200.0, g: 0.0, b: 0.0)

    /// Relative angle of the damage source in [0, 2π): 0 = behind, π = in front
    static func normalizedDamageAngle(direction: Double, playerAngle: Double) -> Double {
        let relAngle = direction - playerAngle + .pi
        return relAngle - floor(relAngle / (2 * .pi)) * 2 * .pi
    }

    /// CPU fallback: apply the effects to a rendered frame in the same order the
    /// Metal post kernel uses.
    func apply(to buffer: PixelBuffer) {
        if muzzleFlash > 0 {
            buffer.applyTint(color: PixelBuffer.makeColor(r: 255, g: 240, b: 200), intensity: muzzleFlash)
        }
        if damageIntensity > 0 {
            buffer.applyDirectionalDamage(intensity: damageIntensity, direction: damageDirection, playerAngle: playerAngle)
        }
        if pickupFlash > 0 {
            buffer.applyTint(color: PixelBuffer.makeColor(r: 255, g: 255, b: 0), intensity: pickupFlash)
        }
        if berserkTint > 0 {
            buffer.applyTint(color: PixelBuffer.makeColor(r: 200, g: 0, b: 0), intensity: berserkTint)
        }
        if deathProgress > 0 {
            buffer.applyDeathEffect(progress: deathProgress)
        }
        if hitMarkerAlpha >= 0.5 {
            let cx = buffer.width / 2
            let cy = buffer.height / 2
            let white = PixelBuffer.makeColor(r: 255, g: 255, b: 255)
            for i in 1...4 {
                buffer.setPixel(x: cx + i, y: cy + i, color: white)
                buffer.setPixel(x: cx - i, y: cy - i, color: white)
                buffer.setPixel(x: cx + i, y: cy - i, color: white)
                buffer.setPixel(x: cx - i, y: cy + i, color: white)
            }
        }
        if fadeToBlack > 0 {
            buffer.applyTint(color: PixelBuffer.makeColor(r: 0, g: 0, b: 0), intensity: fadeToBlack)
        }
    }
}
