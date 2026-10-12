//
//  PhonePlayTests.swift
//  fpsgame1Tests
//
//  Phone-play decisions that do not need a device: the virtual stick, drag-to-look,
//  touch aim assist, button placement around the island and the home indicator,
//  frame pacing, and when audio or the fight should pause.
//

import XCTest
@testable import fpsgame1

final class PhonePlayTests: XCTestCase {

    // MARK: Stick

    func testRestingThumbInsideTheDeadZoneDoesNotMove() {
        let radius = 64.0
        let inside = radius * TouchStickMath.deadzone * 0.5
        let axes = TouchStickMath.axes(dx: inside, dy: inside * 0.3, radius: radius)
        XCTAssertEqual(axes.forward, 0)
        XCTAssertEqual(axes.strafe, 0)
    }

    func testFullPushReachesFullSpeedOnEachAxis() {
        let radius = 64.0
        let right = TouchStickMath.axes(dx: radius, dy: 0, radius: radius)
        XCTAssertEqual(right.strafe, 1, accuracy: 1e-9)
        XCTAssertEqual(right.forward, 0, accuracy: 1e-9)

        let up = TouchStickMath.axes(dx: 0, dy: -radius, radius: radius)
        XCTAssertEqual(up.forward, 1, accuracy: 1e-9)
        XCTAssertEqual(up.strafe, 0, accuracy: 1e-9)

        let downLeft = TouchStickMath.axes(dx: -radius * 4, dy: radius * 4, radius: radius)
        XCTAssertEqual(hypot(downLeft.forward, downLeft.strafe), 1, accuracy: 1e-6)
        XCTAssertLessThan(downLeft.forward, 0)
        XCTAssertLessThan(downLeft.strafe, 0)
    }

    func testHalfPushIsFinerThanAStraightLine() {
        let radius = 70.0
        let mid = TouchStickMath.deadzone + (1 - TouchStickMath.deadzone) * 0.5
        let axes = TouchStickMath.axes(dx: radius * mid, dy: 0, radius: radius)
        XCTAssertGreaterThan(axes.strafe, 0)
        XCTAssertLessThan(axes.strafe, 0.5, "the curve keeps small corrections small")
    }

    func testZeroRadiusStickDoesNothing() {
        let axes = TouchStickMath.axes(dx: 20, dy: -10, radius: 0)
        XCTAssertEqual(axes.forward, 0)
        XCTAssertEqual(axes.strafe, 0)
    }

    // MARK: Look

    func testLookIsIgnoredUntilTheFingerClearsTheTapSlop() {
        let first = TouchLookMath.sample(dx: 6, dy: -2, previousTravel: 0)
        XCTAssertEqual(first.deltaX, 0)
        XCTAssertEqual(first.deltaY, 0)
        XCTAssertTrue(TouchLookMath.isTap(totalTravel: 8))
    }

    func testCrossingTheSlopDoesNotJumpTheCamera() {
        let previous = 6.0
        let dx = 20.0
        let sample = TouchLookMath.sample(dx: dx, dy: 0, previousTravel: previous)
        let overflow = (previous + dx) - TouchLookMath.tapSlop
        let expected = overflow * TouchLookMath.mouseUnitsPerPoint
        XCTAssertEqual(sample.deltaX, expected, accuracy: 1e-9)
        XCTAssertEqual(sample.deltaY, 0)
        XCTAssertFalse(TouchLookMath.isTap(totalTravel: previous + dx))
    }

    func testLookAfterTheSlopTracksTheFinger() {
        let sample = TouchLookMath.sample(dx: 10, dy: -4, previousTravel: TouchLookMath.tapSlop)
        XCTAssertEqual(sample.deltaX, 10 * TouchLookMath.mouseUnitsPerPoint, accuracy: 1e-9)
        XCTAssertEqual(sample.deltaY, -4 * TouchLookMath.mouseUnitsPerPoint, accuracy: 1e-9)
    }

    func testTouchLookOptsIntoAimAssistAndTheMouseDoesNot() {
        let input = InputManager()
        input.addTouchLook(deltaX: 10, deltaY: 0)
        let touched = input.getInputState()
        XCTAssertTrue(touched.touchLooking)
        XCTAssertEqual(touched.turn, 0.03, accuracy: 1e-9)

        input.mouseMoved(deltaX: 10, deltaY: 0)
        let mouse = input.getInputState()
        XCTAssertFalse(mouse.touchLooking)
        XCTAssertEqual(mouse.turn, 0.03, accuracy: 1e-9)
    }

    // MARK: Aim assist

    private func openHall() -> GameWorld {
        TestWorld.make([
            "#######",
            "#.....#",
            "#######",
        ])
    }

    func testAimAssistPullsTowardAnEnemyJustOffTheCrosshair() {
        let world = openHall()
        let yaw = AimAssist.yaw(
            playerX: 1.5, playerY: 1.5, angle: 0,
            turnThisFrame: 0, deltaTime: 1.0 / 60.0,
            targets: [AimAssist.Target(x: 4.5, y: 1.75, alive: true, hitRadius: 0.4)],
            blocksTile: { world.isSolid(x: $0, y: $1) }
        )
        XCTAssertGreaterThan(yaw, 0.001)
        XCTAssertLessThan(yaw, 0.2)
    }

    func testAimAssistIgnoresEnemiesBehindWallsDeadOnesAndWideMisses() {
        let walled = TestWorld.make([
            "#######",
            "#.#...#",
            "#######",
        ])
        let blocked = AimAssist.yaw(
            playerX: 1.5, playerY: 1.5, angle: 0,
            turnThisFrame: 0, deltaTime: 1.0 / 30.0,
            targets: [AimAssist.Target(x: 4.5, y: 1.5, alive: true, hitRadius: 0.4)],
            blocksTile: { walled.isSolid(x: $0, y: $1) }
        )
        XCTAssertEqual(blocked, 0)

        let world = openHall()
        let dead = AimAssist.yaw(
            playerX: 1.5, playerY: 1.5, angle: 0,
            turnThisFrame: 0, deltaTime: 1.0 / 60.0,
            targets: [AimAssist.Target(x: 4.5, y: 1.75, alive: false, hitRadius: 0.4)],
            blocksTile: { world.isSolid(x: $0, y: $1) }
        )
        XCTAssertEqual(dead, 0)

        let wide = AimAssist.yaw(
            playerX: 1.5, playerY: 1.5, angle: 0,
            turnThisFrame: 0, deltaTime: 1.0 / 60.0,
            targets: [AimAssist.Target(x: 1.5, y: 1.5 + 3, alive: true, hitRadius: 0.4)],
            blocksTile: { _, _ in false }
        )
        XCTAssertEqual(wide, 0, "an enemy far off to the side is not dragged onto")
    }

    func testAimAssistGivesWayWhenThePlayerFlicksAndNeverExceedsItsCap() {
        let world = openHall()
        let target = [AimAssist.Target(x: 4.5, y: 1.75, alive: true, hitRadius: 0.4)]
        let blocks = { world.isSolid(x: $0, y: $1) }
        let away = AimAssist.yaw(
            playerX: 1.5, playerY: 1.5, angle: 0,
            turnThisFrame: -0.2, deltaTime: 1.0 / 60.0,
            targets: target, blocksTile: blocks
        )
        XCTAssertEqual(away, 0)

        let dt = 0.05
        let capped = AimAssist.yaw(
            playerX: 1.5, playerY: 1.5, angle: 0,
            turnThisFrame: 0, deltaTime: dt,
            targets: target, blocksTile: blocks
        )
        XCTAssertLessThanOrEqual(abs(capped), AimAssist.maxRadiansPerSecond * dt + 1e-9)
        XCTAssertGreaterThan(capped, 0)
    }

    func testEngineAppliesAimAssistOnlyWhileTouchLooking() {
        func harness() -> GameEngine {
            let engine = GameEngine()
            engine.state = .playing
            engine.world = openHall()
            engine.player = Player(x: 1.5, y: 1.5, angle: 0)
            engine.enemies = [Enemy(type: .imp, x: 4.5, y: 1.75)]
            return engine
        }

        let assisted = harness()
        var input = InputManager.InputState()
        input.touchLooking = true
        assisted.update(deltaTime: 1.0 / 60.0, input: input)
        XCTAssertGreaterThan(assisted.player.angle, 0)

        let mouse = harness()
        mouse.update(deltaTime: 1.0 / 60.0, input: InputManager.InputState())
        XCTAssertEqual(mouse.player.angle, 0, accuracy: 1e-9)
    }

    // MARK: Layout

    /// A 6.3-inch-class phone in landscape: island on the trailing edge, home indicator along the bottom.
    private func proPhone() -> (CGSize, ScreenInsets) {
        (CGSize(width: 874, height: 402), ScreenInsets(top: 0, leading: 0, bottom: 21, trailing: 59))
    }

    func testProPhonePutsFireUnderTheRightThumbAndAStickOnTheLeft() {
        let (canvas, safe) = proPhone()
        let layout = PhoneLayout.layout(canvas: canvas, safe: safe)
        let hudTop = canvas.height - safe.bottom - layout.hudHeight

        XCTAssertGreaterThanOrEqual(layout.fire.diameter, 96)
        XCTAssertGreaterThan(layout.fire.center.x, canvas.width * 0.7)
        XCTAssertGreaterThan(layout.fire.center.y, canvas.height * 0.5)
        assertInside(layout.fire, canvas: canvas, safe: safe, hudTop: hudTop)

        XCTAssertGreaterThanOrEqual(layout.stick.diameter, 110, "the stick is visible before you touch it")
        XCTAssertLessThan(layout.stick.center.x, canvas.width * 0.3)
        assertInside(layout.stick, canvas: canvas, safe: safe, hudTop: hudTop)

        let secondaries = [layout.use, layout.nextWeapon, layout.previousWeapon, layout.run]
        for spot in secondaries {
            let reach = hypot(spot.center.x - layout.fire.center.x, spot.center.y - layout.fire.center.y)
            XCTAssertLessThan(reach, 140, "secondary buttons stay under the thumb")
            XCTAssertGreaterThan(reach, layout.fire.radius)
            assertInside(spot, canvas: canvas, safe: safe, hudTop: hudTop)
        }
        assertSeparated([layout.fire, layout.use, layout.nextWeapon, layout.previousWeapon, layout.run])

        XCTAssertGreaterThanOrEqual(layout.map.diameter, 44)
        XCTAssertGreaterThanOrEqual(layout.pause.diameter, 44)
        XCTAssertLessThan(layout.pause.center.y, canvas.height * 0.25)
        assertInside(layout.map, canvas: canvas, safe: safe, hudTop: canvas.height)
        assertInside(layout.pause, canvas: canvas, safe: safe, hudTop: canvas.height)
        XCTAssertGreaterThan(layout.moveZoneWidth, layout.stick.center.x)
    }

    func testIslandOnTheLeadingEdgeInsetsTheStick() {
        let layout = PhoneLayout.layout(
            canvas: CGSize(width: 874, height: 402),
            safe: ScreenInsets(top: 0, leading: 59, bottom: 21, trailing: 0)
        )
        XCTAssertGreaterThanOrEqual(layout.stick.center.x - layout.stick.radius, 59)
        XCTAssertGreaterThan(layout.fire.center.x, 800)
    }

    func testShortPhoneStillFitsTheClusterOnScreen() {
        let canvas = CGSize(width: 667, height: 375)
        let layout = PhoneLayout.layout(canvas: canvas, safe: ScreenInsets())
        let hudTop = canvas.height - layout.hudHeight
        let spots = [layout.stick, layout.fire, layout.use, layout.nextWeapon,
                     layout.previousWeapon, layout.run, layout.map, layout.pause]
        for spot in spots {
            assertInside(spot, canvas: canvas, safe: ScreenInsets(), hudTop: hudTop)
        }
        assertSeparated([layout.fire, layout.use, layout.nextWeapon, layout.previousWeapon, layout.run])
        XCTAssertGreaterThan(hudTop - layout.fire.radius, canvas.height * 0.4, "room left to look above the buttons")
    }

    func testPadGetsALargerStickAndFireButton() {
        let phone = PhoneLayout.layout(canvas: CGSize(width: 874, height: 402), safe: ScreenInsets())
        let pad = PhoneLayout.layout(canvas: CGSize(width: 1194, height: 834), safe: ScreenInsets())
        XCTAssertGreaterThan(pad.stick.diameter, phone.stick.diameter)
        XCTAssertGreaterThan(pad.fire.diameter, phone.fire.diameter)
    }

    private func assertInside(_ spot: ControlSpot, canvas: CGSize, safe: ScreenInsets, hudTop: CGFloat) {
        XCTAssertGreaterThanOrEqual(spot.center.x - spot.radius, safe.leading - 0.5)
        XCTAssertGreaterThanOrEqual(spot.center.y - spot.radius, safe.top - 0.5)
        XCTAssertLessThanOrEqual(spot.center.x + spot.radius, canvas.width - safe.trailing + 0.5)
        XCTAssertLessThanOrEqual(spot.center.y + spot.radius, hudTop + 0.5)
    }

    private func assertSeparated(_ spots: [ControlSpot]) {
        for i in spots.indices {
            for j in spots.indices where j > i {
                let a = spots[i], b = spots[j]
                let dist = hypot(a.center.x - b.center.x, a.center.y - b.center.y)
                XCTAssertGreaterThanOrEqual(dist, a.radius + b.radius + 4)
            }
        }
    }

    // MARK: Full-bleed frame

    func testWidePhoneFillsTheScreenAndAMacWindowDoesNot() {
        let mac = SceneFrame.size(drawableWidth: 960, drawableHeight: 600)
        XCTAssertEqual(mac.width, 960)
        XCTAssertEqual(mac.height, 600)
        XCTAssertEqual(SceneFrame.planeScale(renderWidth: mac.width), 1, accuracy: 1e-9)

        // iPhone-class landscape pixels, much wider than 16:10.
        let phone = SceneFrame.size(drawableWidth: 2622, drawableHeight: 1206)
        XCTAssertEqual(phone.height, 600)
        XCTAssertGreaterThan(phone.width, 960)
        let aspect = Double(phone.width) / Double(phone.height)
        XCTAssertEqual(aspect, 2622.0 / 1206.0, accuracy: 0.02)
        XCTAssertGreaterThan(SceneFrame.planeScale(renderWidth: phone.width), 1)

        // Narrower than 16:10 (an iPad landscape): keep the native frame and letterbox.
        let pad = SceneFrame.size(drawableWidth: 2388, drawableHeight: 1668)
        XCTAssertEqual(pad.width, 960)
        XCTAssertEqual(pad.height, 600)

        let empty = SceneFrame.size(drawableWidth: 0, drawableHeight: 0)
        XCTAssertEqual(empty.width, 960)
        let capped = SceneFrame.size(drawableWidth: 4000, drawableHeight: 600)
        XCTAssertEqual(capped.width, SceneFrame.maxWidth)
    }

    // MARK: Pacing, audio, lifecycle

    func testProMotionStaysAt120UntilTheDeviceIsHot() {
        XCTAssertEqual(DisplayPacing.framesPerSecond(thermal: .nominal), 120)
        XCTAssertEqual(DisplayPacing.framesPerSecond(thermal: .fair), 120)
        XCTAssertEqual(DisplayPacing.framesPerSecond(thermal: .serious), 60)
        XCTAssertEqual(DisplayPacing.framesPerSecond(thermal: .critical), 60)
        XCTAssertEqual(DisplayPacing.thermal(.nominal), .nominal)
        XCTAssertEqual(DisplayPacing.thermal(.critical), .critical)
    }

    func testInterruptionsPauseAndResumeOnlyWhenTold() {
        XCTAssertEqual(AudioInterruptions.reaction(to: .began), .suspend)
        XCTAssertEqual(AudioInterruptions.reaction(to: .ended(shouldResume: true)), .resume)
        XCTAssertNil(AudioInterruptions.reaction(to: .ended(shouldResume: false)))
    }

    func testLeavingTheAppPausesOnlyAnActiveFight() {
        XCTAssertTrue(PlayLifecycle.shouldAutoPause(isPlaying: true, isActive: false))
        XCTAssertFalse(PlayLifecycle.shouldAutoPause(isPlaying: true, isActive: true))
        XCTAssertFalse(PlayLifecycle.shouldAutoPause(isPlaying: false, isActive: false))
    }
}
