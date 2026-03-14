//
//  GameView.swift
//  testproject
//

import SwiftUI
import AppKit

class GameNSView: NSView {
    var inputManager: InputManager?
    var onCursorCaptured: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isCursorCaptured = false

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
            updateTrackingAreas()
        } else {
            // View was removed from window — release cursor
            releaseCursor()
        }
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func resignFirstResponder() -> Bool {
        // Re-grab focus after a brief delay (SwiftUI may temporarily steal it)
        // But only if we're still in the window hierarchy
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, self.superview != nil else { return }
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
        }
        return true
    }

    override func updateTrackingAreas() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func keyDown(with event: NSEvent) {
        inputManager?.keyDown(event.keyCode)
        // ESC releases cursor capture
        if event.keyCode == InputManager.keyEscape {
            releaseCursor()
        }
    }

    override func keyUp(with event: NSEvent) {
        inputManager?.keyUp(event.keyCode)
    }

    override func mouseMoved(with event: NSEvent) {
        inputManager?.mouseMoved(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func mouseDragged(with event: NSEvent) {
        inputManager?.mouseMoved(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func mouseDown(with event: NSEvent) {
        inputManager?.mouseDown()
        if !isCursorCaptured {
            captureCursor()
        }
    }

    override func mouseUp(with event: NSEvent) {
        inputManager?.mouseUp()
    }

    override func rightMouseDown(with event: NSEvent) {
        inputManager?.mouseDown()
    }

    override func rightMouseUp(with event: NSEvent) {
        inputManager?.mouseUp()
    }

    override func flagsChanged(with event: NSEvent) {
        // Track modifier keys (shift for sprint)
        let shiftDown = event.modifierFlags.contains(.shift)
        if shiftDown {
            inputManager?.keyDown(InputManager.keyShift)
        } else {
            inputManager?.keyUp(InputManager.keyShift)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        inputManager?.mouseMoved(deltaX: event.scrollingDeltaX * 2, deltaY: event.scrollingDeltaY * 2)
    }

    override func mouseEntered(with event: NSEvent) {
        if isCursorCaptured {
            NSCursor.hide()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.unhide()
    }

    func captureCursor() {
        isCursorCaptured = true
        CGAssociateMouseAndMouseCursorPosition(0)
        NSCursor.hide()
        onCursorCaptured?(true)
    }

    func releaseCursor() {
        isCursorCaptured = false
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
        onCursorCaptured?(false)
    }
}

struct GameInputView: NSViewRepresentable {
    let inputManager: InputManager

    func makeNSView(context: Context) -> GameNSView {
        let view = GameNSView()
        view.inputManager = inputManager
        // Ensure focus and capture cursor after view hierarchy settles
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
            view.captureCursor()
        }
        return view
    }

    func updateNSView(_ nsView: GameNSView, context: Context) {
        nsView.inputManager = inputManager
        // Only re-grab focus if the view has a window and truly lost it
        // Don't do this on every update to avoid disrupting event delivery
    }
}
