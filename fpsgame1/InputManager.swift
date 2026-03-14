//
//  InputManager.swift
//  testproject
//

import AppKit

final class InputManager {
    var keys: Set<UInt16> = []
    var mouseDeltaX: CGFloat = 0
    var mouseDeltaY: CGFloat = 0
    var mouseClicked: Bool = false
    var mouseHeld: Bool = false

    // macOS key codes
    static let keyW: UInt16 = 13
    static let keyA: UInt16 = 0
    static let keyS: UInt16 = 1
    static let keyD: UInt16 = 2
    static let keyE: UInt16 = 14
    static let keySpace: UInt16 = 49
    static let key1: UInt16 = 18
    static let key2: UInt16 = 19
    static let key3: UInt16 = 20
    static let key4: UInt16 = 21
    static let keyEscape: UInt16 = 53
    static let keyReturn: UInt16 = 36
    static let keyShift: UInt16 = 56
    static let keyTab: UInt16 = 48
    static let keyLeft: UInt16 = 123
    static let keyRight: UInt16 = 124
    static let keyDown: UInt16 = 125
    static let keyUp: UInt16 = 126

    struct InputState {
        var forward: Double = 0
        var strafe: Double = 0
        var turn: Double = 0
        var shoot: Bool = false
        var interact: Bool = false
        var weaponSwitch: Int? = nil
        var escapePressed: Bool = false
        var enterPressed: Bool = false
        var sprint: Bool = false
        var tabPressed: Bool = false
    }

    func getInputState() -> InputState {
        var state = InputState()
        if keys.contains(Self.keyW) || keys.contains(Self.keyUp) { state.forward += 1 }
        if keys.contains(Self.keyS) || keys.contains(Self.keyDown) { state.forward -= 1 }
        if keys.contains(Self.keyA) { state.strafe -= 1 }
        if keys.contains(Self.keyD) { state.strafe += 1 }
        if keys.contains(Self.keyShift) { state.sprint = true }

        // Rotation: mouse delta + arrow keys
        var turn = Double(mouseDeltaX) * 0.003
        if keys.contains(Self.keyLeft) { turn -= 0.04 }
        if keys.contains(Self.keyRight) { turn += 0.04 }
        state.turn = turn
        state.shoot = mouseClicked || mouseHeld || keys.contains(Self.keySpace)
        state.interact = keys.contains(Self.keyE)
        state.escapePressed = keys.contains(Self.keyEscape)
        state.enterPressed = keys.contains(Self.keyReturn)

        state.tabPressed = keys.contains(Self.keyTab)

        if keys.contains(Self.key1) { state.weaponSwitch = 1 }
        else if keys.contains(Self.key2) { state.weaponSwitch = 2 }
        else if keys.contains(Self.key3) { state.weaponSwitch = 3 }
        else if keys.contains(Self.key4) { state.weaponSwitch = 4 }

        mouseDeltaX = 0
        mouseDeltaY = 0
        mouseClicked = false

        return state
    }

    func keyDown(_ keyCode: UInt16) {
        keys.insert(keyCode)
    }

    func keyUp(_ keyCode: UInt16) {
        keys.remove(keyCode)
    }

    func mouseMoved(deltaX: CGFloat, deltaY: CGFloat) {
        mouseDeltaX += deltaX
        mouseDeltaY += deltaY
    }

    func mouseDown() {
        mouseClicked = true
        mouseHeld = true
    }

    func mouseUp() {
        mouseHeld = false
    }
}
