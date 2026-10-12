//
//  PhonePlay.swift
//  fpsgame1
//
//  Decisions for playing on a phone, kept as plain values so the unit tests can
//  pin them down: virtual-stick response, drag-to-look, a light touch-only aim
//  assist, where the on-screen buttons sit around the Dynamic Island and the
//  home indicator, when a phone call or an app switch should pause, and the
//  frame rate asked of a ProMotion display.
//

import CoreGraphics
import Foundation
#if os(iOS)
import QuartzCore
import UIKit
#endif

// MARK: - Virtual stick

enum TouchStickMath {
    /// Fraction of the stick radius that does not move the player. A resting
    /// thumb jitters inside this, and the live range beyond it is stretched
    /// back out to a full 1 so a hard push still sprints at full speed.
    static let deadzone: Double = 0.18
    /// Above 1, small pushes turn less than they would on a straight line,
    /// which makes doorways and strafing easier. Full deflection stays at 1.
    static let responseExponent: Double = 1.45

    struct Axes: Equatable {
        var forward: Double
        var strafe: Double
    }

    /// `dx` / `dy` are finger travel in points from where the thumb landed
    /// (y grows downward, matching the gesture). `radius` is full deflection.
    static func axes(dx: Double, dy: Double, radius: Double) -> Axes {
        guard radius > 0 else { return Axes(forward: 0, strafe: 0) }
        let length = hypot(dx, dy)
        guard length > 0 else { return Axes(forward: 0, strafe: 0) }
        let deflection = min(length, radius) / radius
        guard deflection > deadzone else { return Axes(forward: 0, strafe: 0) }
        let remapped = (deflection - deadzone) / (1 - deadzone)
        let curved = pow(remapped, responseExponent)
        return Axes(forward: -dy / length * curved, strafe: dx / length * curved)
    }
}

// MARK: - Drag to look

enum TouchLookMath {
    /// Points of finger travel before a drag turns the camera. Anything shorter
    /// is a tap, which fires once and must not twitch the crosshair.
    static let tapSlop: Double = 14
    /// Mouse-delta units per point, fed through the same 0.003 rad scale as the
    /// Mac mouse. At sensitivity 1 a 400-point swipe (a comfortable right-thumb
    /// drag on a 6.3-inch landscape phone) turns about 220 degrees.
    static let mouseUnitsPerPoint: Double = 3.2

    struct Sample: Equatable {
        var deltaX: Double
        var deltaY: Double
    }

    /// One movement of an in-progress drag. `previousTravel` is the Manhattan
    /// distance already seen in this gesture. Look is withheld until the finger
    /// passes `tapSlop`, and the sample that crosses it only contributes the
    /// overflow, so the view does not jump.
    static func sample(dx: Double, dy: Double, previousTravel: Double) -> Sample {
        let step = abs(dx) + abs(dy)
        let next = previousTravel + step
        guard next >= tapSlop else { return Sample(deltaX: 0, deltaY: 0) }
        let portion: Double
        if previousTravel >= tapSlop {
            portion = 1
        } else if step > 0 {
            portion = (next - tapSlop) / step
        } else {
            portion = 0
        }
        let scale = portion * mouseUnitsPerPoint
        return Sample(deltaX: dx * scale, deltaY: dy * scale)
    }

    /// A gesture that ends inside the slop is a tap-to-fire, not a look.
    static func isTap(totalTravel: Double) -> Bool {
        totalTravel < tapSlop
    }
}

// MARK: - Touch aim assist

enum AimAssist {
    struct Target {
        var x: Double
        var y: Double
        var alive: Bool
        var hitRadius: Double
    }

    /// Half-width of the cone, in radians. Narrow on purpose: it tidies a
    /// near miss, it does not drag the view onto something you were not aiming at.
    static let coneRadians: Double = 7.0 * .pi / 180.0
    /// Hard cap so the assist can never spin the player.
    static let maxRadiansPerSecond: Double = 50.0 * .pi / 180.0
    /// How much of the remaining error to close per second.
    static let gain: Double = 9.0
    static let maxRange: Double = 16
    /// Player turn, in radians this frame, above which the assist fades, then cuts out.
    static let turnFade: Double = 0.035
    static let turnCut: Double = 0.11

    /// Extra yaw to add after the player's own turn. Zero unless a living enemy
    /// is just off the crosshair and nothing solid is in the way. `blocksTile`
    /// is the world's solidity test.
    static func yaw(
        playerX: Double,
        playerY: Double,
        angle: Double,
        turnThisFrame: Double,
        deltaTime: Double,
        targets: [Target],
        blocksTile: (Int, Int) -> Bool
    ) -> Double {
        guard deltaTime > 0 else { return 0 }
        let flick = abs(turnThisFrame)
        if flick >= turnCut { return 0 }
        let flickScale = flick <= turnFade ? 1.0 : (turnCut - flick) / (turnCut - turnFade)

        var bestError: Double?
        var bestScore = Double.greatestFiniteMagnitude
        for target in targets where target.alive {
            let dx = target.x - playerX
            let dy = target.y - playerY
            let dist = hypot(dx, dy)
            guard dist > 0.05, dist <= maxRange else { continue }
            let error = wrap(atan2(dy, dx) - angle)
            let widen = min(coneRadians, atan2(max(0.05, target.hitRadius), dist))
            guard abs(error) <= coneRadians + widen else { continue }
            if !sees(fromX: playerX, fromY: playerY, toX: target.x, toY: target.y, blocksTile: blocksTile) {
                continue
            }
            // Prefer the enemy closest to the crosshair; distance breaks ties.
            let score = abs(error) + dist * 0.001
            if score < bestScore {
                bestScore = score
                bestError = error
            }
        }
        guard let error = bestError else { return 0 }
        // A deliberate drag away from the target wins over the magnet.
        if flick > 0.01 && turnThisFrame * error < 0 { return 0 }

        let maxStep = maxRadiansPerSecond * deltaTime
        var nudge = error * min(1.0, gain * deltaTime) * flickScale
        if nudge > maxStep { nudge = maxStep }
        if nudge < -maxStep { nudge = -maxStep }
        return nudge
    }

    private static func wrap(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if value > .pi { value -= 2 * .pi }
        if value < -.pi { value += 2 * .pi }
        return value
    }

    /// Same stepping test the shot ray uses: a solid tile between the points blocks it.
    private static func sees(
        fromX: Double, fromY: Double, toX: Double, toY: Double,
        blocksTile: (Int, Int) -> Bool
    ) -> Bool {
        let dx = toX - fromX
        let dy = toY - fromY
        let steps = Int(hypot(dx, dy) * 4)
        guard steps > 1 else { return true }
        for i in 1..<steps {
            let t = Double(i) / Double(steps)
            if blocksTile(Int(fromX + dx * t), Int(fromY + dy * t)) { return false }
        }
        return true
    }
}

// MARK: - On-screen layout

struct ScreenInsets: Equatable {
    var top: CGFloat = 0
    var leading: CGFloat = 0
    var bottom: CGFloat = 0
    var trailing: CGFloat = 0
}

struct PhoneControlLayout: Equatable {
    var moveFraction: CGFloat
    var stickRadius: CGFloat
    var leadingInset: CGFloat
    var topInset: CGFloat
    var trailingInset: CGFloat
    var clusterTrailing: CGFloat
    var clusterBottom: CGFloat
    var buttonHeight: CGFloat
    var fireWidth: CGFloat
    var fireHeight: CGFloat
    var utilityWidth: CGFloat
    var useWidth: CGFloat
    var weaponWidth: CGFloat
    var runWidth: CGFloat
    var pauseWidth: CGFloat
}

enum PhoneLayout {
    /// Where the thumb controls go on a landscape screen.
    ///
    /// The picture is letterboxed to 960×600 and drawn edge to edge, so the
    /// home indicator and the Dynamic Island can cover it. Buttons are pushed
    /// in by those insets and lifted above the status bar. A short phone gets
    /// slightly smaller targets; they stay at least 44 points.
    static func layout(canvas: CGSize, safe: ScreenInsets) -> PhoneControlLayout {
        let scale = FitDesignSize.scale(for: canvas)
        let pictureH = FitDesignSize.designHeight * scale
        let marginY = max(0, (canvas.height - pictureH) / 2)
        let compact = canvas.height < 430
        let hudTop = marginY + PhoneHUD.statusBarDesignHeight * scale + 4
        return PhoneControlLayout(
            moveFraction: 0.40,
            stickRadius: compact ? 64 : 76,
            leadingInset: max(0, safe.leading),
            topInset: max(0, safe.top) + 8,
            trailingInset: max(0, safe.trailing) + 10,
            clusterTrailing: max(0, safe.trailing) + 10,
            clusterBottom: max(max(0, safe.bottom) + 10, hudTop),
            buttonHeight: compact ? 50 : 56,
            fireWidth: compact ? 100 : 116,
            fireHeight: compact ? 66 : 78,
            utilityWidth: compact ? 68 : 76,
            useWidth: compact ? 72 : 80,
            weaponWidth: compact ? 50 : 56,
            runWidth: compact ? 64 : 72,
            pauseWidth: compact ? 52 : 58
        )
    }
}

// MARK: - HUD metrics

enum PhoneHUD {
    #if os(iOS)
    /// The 960×600 layouts are shrunk to fit a phone, which makes 10pt labels
    /// about 7pt. This boosts the HUD inside that frame so it is still readable
    /// on a 6.3-inch screen. Mac layouts stay at 1.
    static let textBoost: CGFloat = 1.32
    static let faceScale: CGFloat = 1.15
    static let minimapScale: CGFloat = 1.15
    static let minimapExtraTrailing: CGFloat = 52
    /// Empty space under the numbers, in design pixels, so the home indicator
    /// sits in the bar instead of on the health readout. 28 design points is
    /// about 21 screen points once a 6.3-inch phone has scaled the frame down.
    static let statusBarExtraBottom: CGFloat = 28
    #else
    static let textBoost: CGFloat = 1
    static let faceScale: CGFloat = 1
    static let minimapScale: CGFloat = 1
    static let minimapExtraTrailing: CGFloat = 0
    static let statusBarExtraBottom: CGFloat = 0
    #endif

    /// Design pixels from the bottom of the frame to the top of the status bar.
    static var statusBarDesignHeight: CGFloat {
        64 * faceScale + 6 + 6 + statusBarExtraBottom
    }
}

// MARK: - Frame pacing

enum DisplayPacing {
    /// Nominal and warm: ask for ProMotion. Serious or critical: drop to 60
    /// so a long fight can cool down. A display that cannot do 120 clamps this.
    enum Thermal: Equatable {
        case nominal, fair, serious, critical
    }

    static let highRate = 120
    static let coolRate = 60

    static func framesPerSecond(thermal: Thermal) -> Int {
        switch thermal {
        case .nominal, .fair: return highRate
        case .serious, .critical: return coolRate
        }
    }

    static func thermal(_ state: ProcessInfo.ThermalState) -> Thermal {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .serious
        }
    }
}

// MARK: - Audio interruptions and leaving the app

enum AudioInterruptions {
    enum Kind: Equatable {
        case began
        case ended(shouldResume: Bool)
    }

    enum Reaction: Equatable {
        case suspend
        case resume
    }

    /// A phone call or Siri takes the speakers. Resume only when the system
    /// says the interruption is over and playback should continue.
    static func reaction(to kind: Kind) -> Reaction? {
        switch kind {
        case .began:
            return .suspend
        case .ended(shouldResume: true):
            return .resume
        case .ended(shouldResume: false):
            return nil
        }
    }
}

enum PlayLifecycle {
    /// Switching away mid-fight pauses. Menus and an already-paused game stay put.
    static func shouldAutoPause(isPlaying: Bool, isActive: Bool) -> Bool {
        isPlaying && !isActive
    }
}

// MARK: - Haptics

enum GameHaptics {
    #if os(iOS)
    private static let buttonGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let fireGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let hurtGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let pickupGenerator = UINotificationFeedbackGenerator()
    private static var lastShotHaptic: CFTimeInterval = 0
    #endif

    static func prepare() {
        #if os(iOS)
        buttonGenerator.prepare()
        fireGenerator.prepare()
        hurtGenerator.prepare()
        pickupGenerator.prepare()
        #endif
    }

    static func buttonDown() {
        #if os(iOS)
        buttonGenerator.impactOccurred(intensity: 0.65)
        buttonGenerator.prepare()
        #endif
    }

    /// `rapid` is the chaingun: a tap on every round would buzz, so those are throttled.
    static func weaponFired(rapid: Bool) {
        #if os(iOS)
        let now = CACurrentMediaTime()
        if rapid, now - lastShotHaptic < 0.12 { return }
        lastShotHaptic = now
        fireGenerator.impactOccurred(intensity: rapid ? 0.4 : 0.9)
        fireGenerator.prepare()
        #endif
    }

    static func playerHurt() {
        #if os(iOS)
        hurtGenerator.impactOccurred()
        hurtGenerator.prepare()
        #endif
    }

    static func itemPickup() {
        #if os(iOS)
        pickupGenerator.notificationOccurred(.success)
        pickupGenerator.prepare()
        #endif
    }
}
