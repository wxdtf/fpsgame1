//
//  TouchInputTests.swift
//  fpsgame1Tests
//
//  The on-screen (touch) controls feed InputManager next to the keyboard, mouse
//  and controller: the virtual stick, the held buttons, the one-shot weapon cycle
//  and the PAUSE / MAP buttons that stand in for the ESC and TAB keys.
//

import XCTest
@testable import fpsgame1

final class TouchInputTests: XCTestCase {

    func testVirtualStickMovesAndIsClamped() {
        let input = InputManager()
        input.setTouchMove(forward: 0.5, strafe: -0.25)
        var state = input.getInputState()
        XCTAssertEqual(state.forward, 0.5, accuracy: 1e-9)
        XCTAssertEqual(state.strafe, -0.25, accuracy: 1e-9)

        // Stick plus a keyboard key never exceeds full deflection
        input.setTouchMove(forward: 1.5, strafe: 0)
        input.keyDown(InputManager.keyW)
        state = input.getInputState()
        XCTAssertEqual(state.forward, 1)

        input.setTouchMove(forward: 0, strafe: 0)
        input.keyUp(InputManager.keyW)
        state = input.getInputState()
        XCTAssertEqual(state.forward, 0)
    }

    func testHeldButtonsMapToActions() {
        let input = InputManager()
        input.setTouchButton(.fire, pressed: true)
        input.setTouchButton(.interact, pressed: true)
        input.setTouchButton(.sprint, pressed: true)
        var state = input.getInputState()
        XCTAssertTrue(state.shoot)
        XCTAssertTrue(state.interact)
        XCTAssertTrue(state.sprint)

        input.setTouchButton(.fire, pressed: false)
        input.setTouchButton(.interact, pressed: false)
        input.setTouchButton(.sprint, pressed: false)
        state = input.getInputState()
        XCTAssertFalse(state.shoot)
        XCTAssertFalse(state.interact)
        XCTAssertFalse(state.sprint)
    }

    func testWeaponCycleIsOneShot() {
        let input = InputManager()
        input.setTouchButton(.nextWeapon, pressed: true)
        XCTAssertEqual(input.getInputState().weaponCycle, 1)
        XCTAssertEqual(input.getInputState().weaponCycle, 0, "consumed by the first read")
        input.setTouchButton(.previousWeapon, pressed: true)
        XCTAssertEqual(input.getInputState().weaponCycle, -1)
    }

    func testPauseAndMapButtonsPressTheirKeys() {
        let input = InputManager()
        input.setTouchButton(.pause, pressed: true)
        input.setTouchButton(.map, pressed: true)
        XCTAssertTrue(input.keys.contains(InputManager.keyEscape))
        XCTAssertTrue(input.getInputState().tabPressed)
        input.setTouchButton(.pause, pressed: false)
        input.setTouchButton(.map, pressed: false)
        XCTAssertFalse(input.keys.contains(InputManager.keyEscape))
        XCTAssertFalse(input.getInputState().tabPressed)
    }

    func testClearTouchDropsEverything() {
        let input = InputManager()
        input.setTouchMove(forward: 1, strafe: 1)
        input.setTouchButton(.fire, pressed: true)
        input.setTouchButton(.nextWeapon, pressed: true)
        input.clearTouch()
        let state = input.getInputState()
        XCTAssertEqual(state.forward, 0)
        XCTAssertEqual(state.strafe, 0)
        XCTAssertEqual(state.weaponCycle, 0)
        // The press that came with the FIRE button still counts as one click
        XCTAssertTrue(state.shoot)
        XCTAssertFalse(input.getInputState().shoot)
    }

    #if canImport(UIKit)
    func testHardwareKeyboardMapsToMacKeyCodes() {
        XCTAssertEqual(InputManager.keyCode(for: .keyboardW), InputManager.keyW)
        XCTAssertEqual(InputManager.keyCode(for: .keyboardEscape), InputManager.keyEscape)
        XCTAssertEqual(InputManager.keyCode(for: .keyboardReturnOrEnter), InputManager.keyReturn)
        XCTAssertEqual(InputManager.keyCode(for: .keyboardLeftArrow), InputManager.keyLeft)
        XCTAssertNil(InputManager.keyCode(for: .keyboardF1))
    }
    #endif
}
