//
//  GameView.swift
//  testproject
//
//  The platform views under the game screen: the MTKView the Metal renderer
//  presents into, and a transparent input view that feeds InputManager.
//  AppKit and UIKit variants share the same names so ContentView is identical
//  on the Mac and on iOS / iPadOS.
//

import SwiftUI
import MetalKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Drives the game loop from the MTKView's display link: every vsync it asks the
/// view model to step the simulation and encode a frame.
final class MetalViewCoordinator: NSObject, MTKViewDelegate {
    private let viewModel: GameViewModel

    init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        // MTKView calls this on the main thread
        MainActor.assumeIsolated {
            viewModel.renderMetalFrame(in: view)
        }
    }
}

private func makeMetalView(viewModel: GameViewModel, coordinator: MetalViewCoordinator) -> MTKView {
    let view = MTKView(frame: .zero, device: viewModel.metalDevice)
    view.colorPixelFormat = .bgra8Unorm
    view.framebufferOnly = false        // the post kernel writes the drawable directly
    view.preferredFramesPerSecond = 60
    view.isPaused = false
    view.enableSetNeedsDisplay = false
    view.delegate = coordinator
    return view
}

#if os(macOS)

/// Hosts the MTKView the Metal renderer presents into.
struct MetalGameView: NSViewRepresentable {
    let viewModel: GameViewModel

    func makeCoordinator() -> MetalViewCoordinator {
        MetalViewCoordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> MTKView {
        makeMetalView(viewModel: viewModel, coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}

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

#else

/// Hosts the MTKView the Metal renderer presents into.
struct MetalGameView: UIViewRepresentable {
    let viewModel: GameViewModel

    func makeCoordinator() -> MetalViewCoordinator {
        MetalViewCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> MTKView {
        makeMetalView(viewModel: viewModel, coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

/// Reads a hardware keyboard (iPad keyboards, Bluetooth keyboards) into the same
/// key codes the Mac view produces. Touches fall straight through to the
/// on-screen controls below it.
class GameUIView: UIView {
    var inputManager: InputManager?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key, let code = InputManager.keyCode(for: key.keyCode) {
                inputManager?.keyDown(code)
                handled = true
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        release(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        release(presses, with: event)
    }

    private func release(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key, let code = InputManager.keyCode(for: key.keyCode) {
                inputManager?.keyUp(code)
                handled = true
            }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }
}

struct GameInputView: UIViewRepresentable {
    let inputManager: InputManager

    func makeUIView(context: Context) -> GameUIView {
        let view = GameUIView()
        view.backgroundColor = .clear
        view.inputManager = inputManager
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        return view
    }

    func updateUIView(_ uiView: GameUIView, context: Context) {
        uiView.inputManager = inputManager
    }
}

#endif
