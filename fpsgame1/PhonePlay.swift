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

struct ControlSpot: Equatable {
    var center: CGPoint
    var diameter: CGFloat

    var radius: CGFloat { diameter / 2 }
}

struct PhoneControlLayout: Equatable {
    /// Always drawn, lower left, so the move control is visible before the first touch.
    var stick: ControlSpot
    /// Large button where the right thumb rests.
    var fire: ControlSpot
    /// USE, weapon next, weapon previous, RUN, in an arc opening up and left of FIRE.
    var use: ControlSpot
    var nextWeapon: ControlSpot
    var previousWeapon: ControlSpot
    var run: ControlSpot
    var map: ControlSpot
    var pause: ControlSpot
    /// Left-hand touch region. Looking starts to the right of this.
    var moveZoneWidth: CGFloat
    /// Slim status bar, in points, not counting the home-indicator inset.
    var hudHeight: CGFloat
}

enum PhoneLayout {
    /// Thumb layout for a landscape phone or iPad.
    ///
    /// FIRE sits in the lower corner, clear of the Dynamic Island, the home
    /// indicator and the status bar. USE, the weapon arrows and RUN sit on an
    /// arc within a thumb's reach of it. The move stick is parked in the
    /// opposite corner. A shorter screen uses slightly smaller targets; every
    /// one stays at least 44 points.
    static func hudHeight(forHeight height: CGFloat) -> CGFloat {
        height < 430 ? 46 : 50
    }

    static func layout(canvas: CGSize, safe: ScreenInsets) -> PhoneControlLayout {
        let compact = canvas.height < 430
        let hud = hudHeight(forHeight: canvas.height)
        let fireD: CGFloat = compact ? 100 : 118
        let secD: CGFloat = compact ? 56 : 64
        let utilD: CGFloat = 50
        let stickD: CGFloat = compact ? 118 : 136
        let margin: CGFloat = 12

        let top = max(0, safe.top)
        let leading = max(0, safe.leading)
        let bottom = max(0, safe.bottom)
        let trailing = max(0, safe.trailing)

        let floorY = canvas.height - bottom - hud - margin
        let rightX = canvas.width - trailing - margin
        let leftX = leading + margin

        let fire = ControlSpot(
            center: CGPoint(x: rightX - fireD / 2, y: floorY - fireD / 2),
            diameter: fireD
        )

        // Four secondaries across a 102° arc centered up-and-left of FIRE.
        // The orbit is wide enough that neighbours do not overlap, and the
        // lowest button still clears the status bar.
        let step: CGFloat = 34
        let chord = secD + 8
        let orbit = max(
            fireD / 2 + secD / 2 + 10,
            chord / (2 * sin(step / 2 * .pi / 180))
        )
        let mid: CGFloat = 142
        let angles: [CGFloat] = [
            mid - 1.5 * step, mid - 0.5 * step, mid + 0.5 * step, mid + 1.5 * step,
        ]
        func spot(_ degrees: CGFloat) -> ControlSpot {
            let radians = degrees * .pi / 180
            return ControlSpot(
                center: CGPoint(
                    x: fire.center.x + cos(radians) * orbit,
                    y: fire.center.y - sin(radians) * orbit
                ),
                diameter: secD
            )
        }
        // 91° is just left of straight up, then around to the lower left.
        let use = spot(angles[0])
        let nextWeapon = spot(angles[1])
        let previousWeapon = spot(angles[2])
        let run = spot(angles[3])

        let stick = ControlSpot(
            center: CGPoint(x: leftX + stickD / 2, y: floorY - stickD / 2),
            diameter: stickD
        )
        let pause = ControlSpot(
            center: CGPoint(x: rightX - utilD / 2, y: top + margin + utilD / 2),
            diameter: utilD
        )
        let map = ControlSpot(
            center: CGPoint(x: pause.center.x - utilD - 10, y: pause.center.y),
            diameter: utilD
        )
        let moveZone = min(canvas.width * 0.46, stick.center.x + stick.radius + 28)

        return PhoneControlLayout(
            stick: stick,
            fire: fire,
            use: use,
            nextWeapon: nextWeapon,
            previousWeapon: previousWeapon,
            run: run,
            map: map,
            pause: pause,
            moveZoneWidth: moveZone,
            hudHeight: hud
        )
    }
}

// MARK: - Full-bleed frame

enum SceneFrame {
    /// The Mac window and the raycaster's native 16:10 frame.
    static let baseWidth = 960
    static let baseHeight = 600
    /// Widest phone we will raycast for (a very wide landscape display).
    static let maxWidth = 1600

    /// Raycast size for a drawable. A screen wider than 16:10 (an iPhone in
    /// landscape) gets a wider target so the picture fills the display and the
    /// view shows more to the sides. A 16:10 or narrower drawable, including
    /// the Mac window, stays 960×600 and letterboxes as before.
    static func size(drawableWidth: Int, drawableHeight: Int) -> (width: Int, height: Int) {
        guard drawableWidth > 0, drawableHeight > 0 else {
            return (baseWidth, baseHeight)
        }
        let aspect = Double(drawableWidth) / Double(drawableHeight)
        let baseAspect = Double(baseWidth) / Double(baseHeight)
        guard aspect > baseAspect + 0.02 else {
            return (baseWidth, baseHeight)
        }
        let widened = Int((Double(baseHeight) * aspect).rounded())
        let width = min(maxWidth, max(baseWidth, widened))
        return (width, baseHeight)
    }

    /// Scales the horizontal camera so the extra columns are extra view, not a
    /// stretched 16:10 picture. 960 wide stays at 1.
    static func planeScale(renderWidth: Int) -> Double {
        guard renderWidth > 0 else { return 1 }
        return Double(renderWidth) / Double(baseWidth)
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
