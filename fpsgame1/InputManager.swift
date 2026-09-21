//
//  InputManager.swift
//  testproject
//
//  Keyboard and mouse state from the game view, plus the first connected game
//  controller, folded into one InputState per frame.
//

import AppKit
import GameController

final class InputManager {
    var keys: Set<UInt16> = []
    var mouseDeltaX: CGFloat = 0
    var mouseDeltaY: CGFloat = 0
    var mouseClicked: Bool = false
    var mouseHeld: Bool = false
    /// Multiplier on mouse and right-stick turn speed (settings menu)
    var mouseSensitivity: Double = 1.0

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
    static let key5: UInt16 = 23
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
        /// +1 next weapon, -1 previous (controller shoulder buttons)
        var weaponCycle: Int = 0
        var escapePressed: Bool = false
        var enterPressed: Bool = false
        var sprint: Bool = false
        var tabPressed: Bool = false
    }

    // MARK: - Game controller

    /// Analog state read from the first extended gamepad on the last poll
    struct PadState {
        var forward: Double = 0
        var strafe: Double = 0
        var turn: Double = 0
        var shoot = false
        var interact = false
        var sprint = false
        var cycle = 0
        var connected = false
    }
    private(set) var pad = PadState()
    /// Virtual keys the controller is holding down (menu → ESC, A → Return, d-pad → arrows, options → TAB)
    private var padKeys: Set<UInt16> = []
    private var prevLeftShoulder = false
    private var prevRightShoulder = false
    static let stickDeadzone: Double = 0.18
    static let padTurnSpeed: Double = 0.06

    /// Read the controller once per frame. Buttons that stand in for keys are merged into
    /// `keys`, so menus and the pause screen see them like keyboard presses.
    func pollController() {
        var next = PadState()
        var virtualKeys: Set<UInt16> = []
        if let gamepad = GCController.controllers().first?.extendedGamepad {
            next.connected = true
            next.forward = Self.deadzoned(Double(gamepad.leftThumbstick.yAxis.value))
            next.strafe = Self.deadzoned(Double(gamepad.leftThumbstick.xAxis.value))
            next.turn = Self.deadzoned(Double(gamepad.rightThumbstick.xAxis.value)) * Self.padTurnSpeed
            next.shoot = gamepad.rightTrigger.isPressed || gamepad.buttonA.isPressed
            next.interact = gamepad.buttonX.isPressed || gamepad.buttonB.isPressed
            next.sprint = (gamepad.leftThumbstickButton?.isPressed ?? false) || gamepad.leftTrigger.isPressed
            let left = gamepad.leftShoulder.isPressed, right = gamepad.rightShoulder.isPressed
            if right && !prevRightShoulder { next.cycle = 1 } else if left && !prevLeftShoulder { next.cycle = -1 }
            prevLeftShoulder = left
            prevRightShoulder = right
            if gamepad.buttonMenu.isPressed { virtualKeys.insert(Self.keyEscape) }
            if gamepad.buttonOptions?.isPressed ?? false { virtualKeys.insert(Self.keyTab) }
            if gamepad.dpad.up.isPressed { virtualKeys.insert(Self.keyUp) }
            if gamepad.dpad.down.isPressed { virtualKeys.insert(Self.keyDown) }
            if gamepad.dpad.left.isPressed { virtualKeys.insert(Self.keyLeft) }
            if gamepad.dpad.right.isPressed { virtualKeys.insert(Self.keyRight) }
            if gamepad.buttonA.isPressed { virtualKeys.insert(Self.keyReturn) }
        } else {
            prevLeftShoulder = false
            prevRightShoulder = false
        }
        for key in padKeys.subtracting(virtualKeys) { keys.remove(key) }
        for key in virtualKeys { keys.insert(key) }
        padKeys = virtualKeys
        pad = next
    }

    static func deadzoned(_ value: Double) -> Double {
        guard abs(value) > stickDeadzone else { return 0 }
        let scaled = (abs(value) - stickDeadzone) / (1 - stickDeadzone)
        return value < 0 ? -scaled : scaled
    }

    // MARK: - Per-frame state

    func getInputState() -> InputState {
        var state = InputState()
        if keys.contains(Self.keyW) || keys.contains(Self.keyUp) { state.forward += 1 }
        if keys.contains(Self.keyS) || keys.contains(Self.keyDown) { state.forward -= 1 }
        if keys.contains(Self.keyA) { state.strafe -= 1 }
        if keys.contains(Self.keyD) { state.strafe += 1 }
        if keys.contains(Self.keyShift) || pad.sprint { state.sprint = true }
        state.forward = max(-1, min(1, state.forward + pad.forward))
        state.strafe = max(-1, min(1, state.strafe + pad.strafe))

        // Rotation: mouse delta + arrow keys + right stick
        var turn = Double(mouseDeltaX) * 0.003 * mouseSensitivity
        if keys.contains(Self.keyLeft) { turn -= 0.04 }
        if keys.contains(Self.keyRight) { turn += 0.04 }
        turn += pad.turn * mouseSensitivity
        state.turn = turn
        state.shoot = mouseClicked || mouseHeld || keys.contains(Self.keySpace) || pad.shoot
        state.interact = keys.contains(Self.keyE) || pad.interact
        state.escapePressed = keys.contains(Self.keyEscape)
        state.enterPressed = keys.contains(Self.keyReturn)

        state.tabPressed = keys.contains(Self.keyTab)

        if keys.contains(Self.key1) { state.weaponSwitch = 1 }
        else if keys.contains(Self.key2) { state.weaponSwitch = 2 }
        else if keys.contains(Self.key3) { state.weaponSwitch = 3 }
        else if keys.contains(Self.key4) { state.weaponSwitch = 4 }
        else if keys.contains(Self.key5) { state.weaponSwitch = 5 }
        state.weaponCycle = pad.cycle

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

/// Lets the menu screens take a game controller: A → Enter, B → Escape, d-pad → arrow keys,
/// delivered as edge-triggered key codes at 30 Hz to the same handlers the keyboard uses.
final class ControllerMenuPoller {
    private var timer: Timer?
    private var held: Set<UInt16> = []
    var onEnter: (() -> Void)?
    var onKey: ((UInt16) -> Void)?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        held = []
    }

    private func poll() {
        guard let gamepad = GCController.controllers().first?.extendedGamepad else { return }
        var now: Set<UInt16> = []
        if gamepad.buttonA.isPressed { now.insert(InputManager.keyReturn) }
        if gamepad.buttonB.isPressed || gamepad.buttonMenu.isPressed { now.insert(InputManager.keyEscape) }
        if gamepad.dpad.up.isPressed || gamepad.leftThumbstick.yAxis.value > 0.6 { now.insert(InputManager.keyUp) }
        if gamepad.dpad.down.isPressed || gamepad.leftThumbstick.yAxis.value < -0.6 { now.insert(InputManager.keyDown) }
        if gamepad.dpad.left.isPressed || gamepad.leftThumbstick.xAxis.value < -0.6 { now.insert(InputManager.keyLeft) }
        if gamepad.dpad.right.isPressed || gamepad.leftThumbstick.xAxis.value > 0.6 { now.insert(InputManager.keyRight) }
        for key in now.subtracting(held) {
            if key == InputManager.keyReturn { onEnter?() } else { onKey?(key) }
        }
        held = now
    }
}
