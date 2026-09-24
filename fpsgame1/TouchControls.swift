//
//  TouchControls.swift
//  fpsgame1
//
//  On-screen controls for iOS / iPadOS, laid over the game view:
//
//    - left half: a floating virtual stick (put a finger down anywhere, drag) moves
//    - right half: dragging looks around, a quick tap fires once
//    - buttons on the right: FIRE (hold), USE, SPRINT (toggle), weapon ◀ ▶
//    - top corners: MAP and PAUSE, which press the TAB and ESC keys the game
//      already reads
//
//  Every control is its own view with its own drag gesture, so SwiftUI routes
//  simultaneous touches (stick + look + fire) to the right one.
//

#if os(iOS)
import SwiftUI

struct TouchControlsView: View {
    let inputManager: InputManager
    /// Full stick deflection in points
    static let stickRadius: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    VirtualStickArea(inputManager: inputManager)
                        .frame(width: size.width * 0.45)
                    LookArea(inputManager: inputManager)
                }

                // Top corners: MAP, PAUSE
                HStack {
                    Spacer()
                    HoldButton(label: "MAP", width: 64, inputManager: inputManager, button: .map)
                    HoldButton(label: "II", width: 48, inputManager: inputManager, button: .pause)
                }
                .padding(.top, 10)
                .padding(.trailing, 12)

                // Bottom right cluster: weapon cycle, USE, SPRINT, FIRE
                VStack(alignment: .trailing, spacing: 10) {
                    Spacer()
                    HStack(spacing: 10) {
                        HoldButton(label: "\u{25C0}", width: 44, inputManager: inputManager, button: .previousWeapon)
                        HoldButton(label: "\u{25B6}", width: 44, inputManager: inputManager, button: .nextWeapon)
                        HoldButton(label: "USE", width: 64, inputManager: inputManager, button: .interact)
                    }
                    HStack(alignment: .bottom, spacing: 12) {
                        ToggleButton(label: "RUN", width: 56, inputManager: inputManager, button: .sprint)
                        HoldButton(label: "FIRE", width: 92, inputManager: inputManager, button: .fire)
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 92)   // clear the status bar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .onDisappear {
            inputManager.clearTouch()
        }
    }
}

/// A stick that appears where the finger lands and follows it up to `stickRadius`
private struct VirtualStickArea: View {
    let inputManager: InputManager
    @State private var origin: CGPoint? = nil
    @State private var knob: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if let origin {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .frame(width: TouchControlsView.stickRadius * 2, height: TouchControlsView.stickRadius * 2)
                    .position(origin)
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .position(x: origin.x + knob.width, y: origin.y + knob.height)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if origin == nil { origin = value.startLocation }
                    var dx = value.translation.width
                    var dy = value.translation.height
                    let radius = TouchControlsView.stickRadius
                    let length = max(1, hypot(dx, dy))
                    if length > radius {
                        dx *= radius / length
                        dy *= radius / length
                    }
                    knob = CGSize(width: dx, height: dy)
                    inputManager.setTouchMove(forward: Double(-dy / radius), strafe: Double(dx / radius))
                }
                .onEnded { _ in
                    origin = nil
                    knob = .zero
                    inputManager.setTouchMove(forward: 0, strafe: 0)
                }
        )
    }
}

/// Drag to look around; a short tap with no travel fires once
private struct LookArea: View {
    let inputManager: InputManager
    @State private var lastTranslation: CGSize = .zero
    @State private var travelled: CGFloat = 0

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let dx = value.translation.width - lastTranslation.width
                        let dy = value.translation.height - lastTranslation.height
                        lastTranslation = value.translation
                        travelled += abs(dx) + abs(dy)
                        inputManager.mouseMoved(deltaX: dx * InputManager.touchLookScale,
                                                deltaY: dy * InputManager.touchLookScale)
                    }
                    .onEnded { _ in
                        if travelled < 10 {
                            inputManager.mouseDown()
                            inputManager.mouseUp()
                        }
                        lastTranslation = .zero
                        travelled = 0
                    }
            )
    }
}

private struct ButtonFace: View {
    let label: String
    let width: CGFloat
    let lit: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundColor(lit ? .black : .white)
            .frame(width: width, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(lit ? Color.yellow.opacity(0.85) : Color.black.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
            )
    }
}

/// Pressed while the finger is down
private struct HoldButton: View {
    let label: String
    let width: CGFloat
    let inputManager: InputManager
    let button: InputManager.TouchButton
    @State private var held = false

    var body: some View {
        ButtonFace(label: label, width: width, lit: held)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !held else { return }
                        held = true
                        inputManager.setTouchButton(button, pressed: true)
                    }
                    .onEnded { _ in
                        held = false
                        inputManager.setTouchButton(button, pressed: false)
                    }
            )
    }
}

/// Each tap flips the state (sprint)
private struct ToggleButton: View {
    let label: String
    let width: CGFloat
    let inputManager: InputManager
    let button: InputManager.TouchButton
    @State private var on = false

    var body: some View {
        ButtonFace(label: label, width: width, lit: on)
            .contentShape(Rectangle())
            .onTapGesture {
                on.toggle()
                inputManager.setTouchButton(button, pressed: on)
            }
    }
}
#endif
