//
//  GameView.swift
//  testproject
//

import SwiftUI
import AppKit

class GameNSView: NSView {
    var inputManager: InputManager?
    var onCursorCaptured: ((Bool) -> Void)?
    var acceptsInput = true {
        didSet {
            guard oldValue && !acceptsInput else { return }
            inputManager?.keys.removeAll()
            inputManager?.mouseUp()
        }
    }
    var allowsCursorCapture = false {
        didSet {
            guard oldValue != allowsCursorCapture else { return }
            if allowsCursorCapture {
                if window != nil { captureCursor() }
            } else {
                releaseCursor()
            }
        }
    }
    private var trackingArea: NSTrackingArea?
    private var isCursorCaptured = false
    private var cursorHidden = false

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
        guard acceptsInput else { return }
        inputManager?.keyDown(event.keyCode)
        // ESC releases cursor capture
        if event.keyCode == InputManager.keyEscape {
            releaseCursor()
        }
    }

    override func keyUp(with event: NSEvent) {
        guard acceptsInput else { return }
        inputManager?.keyUp(event.keyCode)
    }

    override func mouseMoved(with event: NSEvent) {
        guard allowsCursorCapture && isCursorCaptured else { return }
        inputManager?.mouseMoved(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func mouseDragged(with event: NSEvent) {
        guard allowsCursorCapture && isCursorCaptured else { return }
        inputManager?.mouseMoved(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func mouseDown(with event: NSEvent) {
        guard allowsCursorCapture else { return }
        inputManager?.mouseDown()
        if !isCursorCaptured {
            captureCursor()
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard allowsCursorCapture else { return }
        inputManager?.mouseUp()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard allowsCursorCapture else { return }
        inputManager?.mouseDown()
    }

    override func rightMouseUp(with event: NSEvent) {
        guard allowsCursorCapture else { return }
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
        guard allowsCursorCapture && isCursorCaptured else { return }
        inputManager?.mouseMoved(deltaX: event.scrollingDeltaX * 2, deltaY: event.scrollingDeltaY * 2)
    }

    override func mouseEntered(with event: NSEvent) {
        if isCursorCaptured {
            hideCursorIfNeeded()
        }
    }

    override func mouseExited(with event: NSEvent) {
        showCursorIfNeeded()
    }

    func captureCursor() {
        guard allowsCursorCapture else { return }
        guard !isCursorCaptured else {
            hideCursorIfNeeded()
            return
        }
        isCursorCaptured = true
        CGAssociateMouseAndMouseCursorPosition(0)
        hideCursorIfNeeded()
        onCursorCaptured?(true)
    }

    func releaseCursor() {
        let wasCaptured = isCursorCaptured
        isCursorCaptured = false
        if wasCaptured {
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        showCursorIfNeeded()
        if wasCaptured {
            onCursorCaptured?(false)
        }
    }

    private func hideCursorIfNeeded() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func showCursorIfNeeded() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }
}

struct GameInputView: NSViewRepresentable {
    let inputManager: InputManager
    let shouldCaptureCursor: Bool
    let acceptsInput: Bool

    func makeNSView(context: Context) -> GameNSView {
        let view = GameNSView()
        view.inputManager = inputManager
        view.acceptsInput = acceptsInput
        view.allowsCursorCapture = shouldCaptureCursor
        // Ensure focus and capture cursor after view hierarchy settles
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
            if shouldCaptureCursor {
                view.captureCursor()
            }
        }
        return view
    }

    func updateNSView(_ nsView: GameNSView, context: Context) {
        nsView.inputManager = inputManager
        nsView.acceptsInput = acceptsInput
        nsView.allowsCursorCapture = shouldCaptureCursor
        // Only re-grab focus if the view has a window and truly lost it
        // Don't do this on every update to avoid disrupting event delivery
    }
}
