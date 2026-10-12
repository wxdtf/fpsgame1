//
//  TouchControls.swift
//  fpsgame1
//
//  On-screen controls for iOS / iPadOS, laid over the game view:
//
//    - left side: a floating virtual stick (thumb down anywhere, drag) moves.
//      A dead zone and a soft curve keep a resting thumb still and small
//      corrections fine.
//    - right side: dragging looks around; a quick tap with no travel fires once
//      and does not twitch the crosshair.
//    - bottom corner: FIRE (hold), RUN (toggle), USE, weapon ◀ ▶. Sized for a
//      thumb and kept clear of the Dynamic Island, the home indicator and the
//      status bar.
//    - top corner: MAP and PAUSE.
//
//  Every control is its own view with its own drag gesture, so SwiftUI routes
//  simultaneous touches (stick + look + fire) to the right one. The picture is
//  drawn edge to edge; these insets are what keep thumbs off the island.
//

#if os(iOS)
import SwiftUI

struct TouchControlsView: View {
    let inputManager: InputManager
    /// Window insets, in case the geometry reader's safe area was already consumed.
    @State private var windowSafe = ScreenInsets()

    var body: some View {
        GeometryReader { geo in
            let fromGeo = ScreenInsets(
                top: geo.safeAreaInsets.top,
                leading: geo.safeAreaInsets.leading,
                bottom: geo.safeAreaInsets.bottom,
                trailing: geo.safeAreaInsets.trailing
            )
            let safe = ScreenInsets(
                top: max(fromGeo.top, windowSafe.top),
                leading: max(fromGeo.leading, windowSafe.leading),
                bottom: max(fromGeo.bottom, windowSafe.bottom),
                trailing: max(fromGeo.trailing, windowSafe.trailing)
            )
            let layout = PhoneLayout.layout(canvas: geo.size, safe: safe)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    VirtualStickArea(inputManager: inputManager, radius: layout.stickRadius)
                        .padding(.leading, layout.leadingInset)
                        .frame(width: geo.size.width * layout.moveFraction)
                    LookArea(inputManager: inputManager)
                        .padding(.trailing, layout.clusterTrailing)
                }

                HStack {
                    Spacer()
                    HoldButton(label: "MAP", width: layout.utilityWidth, height: layout.buttonHeight,
                               inputManager: inputManager, button: .map)
                    HoldButton(label: "II", width: layout.pauseWidth, height: layout.buttonHeight,
                               inputManager: inputManager, button: .pause)
                }
                .padding(.top, layout.topInset)
                .padding(.trailing, layout.trailingInset)

                VStack(alignment: .trailing, spacing: 8) {
                    Spacer()
                    HStack(spacing: 8) {
                        HoldButton(label: "\u{25C0}", width: layout.weaponWidth, height: layout.buttonHeight,
                                   inputManager: inputManager, button: .previousWeapon)
                        HoldButton(label: "\u{25B6}", width: layout.weaponWidth, height: layout.buttonHeight,
                                   inputManager: inputManager, button: .nextWeapon)
                        HoldButton(label: "USE", width: layout.useWidth, height: layout.buttonHeight,
                                   inputManager: inputManager, button: .interact)
                    }
                    HStack(alignment: .bottom, spacing: 10) {
                        ToggleButton(label: "RUN", width: layout.runWidth, height: layout.buttonHeight,
                                     inputManager: inputManager, button: .sprint)
                        HoldButton(label: "FIRE", width: layout.fireWidth, height: layout.fireHeight,
                                   inputManager: inputManager, button: .fire)
                    }
                }
                .padding(.trailing, layout.clusterTrailing)
                .padding(.bottom, layout.clusterBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .background(WindowSafeAreaReader { next in
            if next != windowSafe { windowSafe = next }
        })
        .onAppear { GameHaptics.prepare() }
        .onDisappear { inputManager.clearTouch() }
    }
}

/// Reads the window's safe area (Dynamic Island, home indicator) in screen points.
private struct WindowSafeAreaReader: UIViewRepresentable {
    var onChange: (ScreenInsets) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let raw = window.safeAreaInsets
            onChange(ScreenInsets(top: raw.top, leading: raw.left, bottom: raw.bottom, trailing: raw.right))
        }
    }
}

/// A stick that appears where the finger lands and follows it up to `radius`
private struct VirtualStickArea: View {
    let inputManager: InputManager
    let radius: CGFloat
    @State private var origin: CGPoint? = nil
    @State private var knob: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if let origin {
                Circle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 2)
                    .background(Circle().fill(Color.black.opacity(0.28)))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(origin)
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 48, height: 48)
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
                    let length = max(1, hypot(dx, dy))
                    if length > radius {
                        dx *= radius / length
                        dy *= radius / length
                    }
                    knob = CGSize(width: dx, height: dy)
                    let axes = TouchStickMath.axes(dx: Double(dx), dy: Double(dy), radius: Double(radius))
                    inputManager.setTouchMove(forward: axes.forward, strafe: axes.strafe)
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
                        let sample = TouchLookMath.sample(
                            dx: Double(dx), dy: Double(dy), previousTravel: Double(travelled)
                        )
                        travelled += abs(dx) + abs(dy)
                        inputManager.addTouchLook(deltaX: sample.deltaX, deltaY: sample.deltaY)
                    }
                    .onEnded { _ in
                        if TouchLookMath.isTap(totalTravel: Double(travelled)) {
                            inputManager.mouseDown()
                            inputManager.mouseUp()
                            GameHaptics.buttonDown()
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
    let height: CGFloat
    let lit: Bool

    var body: some View {
        Text(label)
            .font(.system(size: width >= 90 ? 18 : 15, weight: .black, design: .monospaced))
            .foregroundColor(lit ? .black : .white)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(lit ? Color.yellow.opacity(0.92) : Color.black.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(lit ? 0.9 : 0.65), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
    }
}

/// Pressed while the finger is down
private struct HoldButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let inputManager: InputManager
    let button: InputManager.TouchButton
    @State private var held = false

    var body: some View {
        ButtonFace(label: label, width: width, height: height, lit: held)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !held else { return }
                        held = true
                        inputManager.setTouchButton(button, pressed: true)
                        GameHaptics.buttonDown()
                    }
                    .onEnded { _ in
                        held = false
                        inputManager.setTouchButton(button, pressed: false)
                    }
            )
            .accessibilityLabel(label == "II" ? "Pause" : label)
    }
}

/// Each tap flips the state (sprint). The lit state is local because a thumb
/// cannot hold RUN and FIRE at once; leaving the fight drops the view, which
/// resets it together with the input.
private struct ToggleButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let inputManager: InputManager
    let button: InputManager.TouchButton
    @State private var on = false

    var body: some View {
        ButtonFace(label: label, width: width, height: height, lit: on)
            .contentShape(Rectangle())
            .onTapGesture {
                on.toggle()
                inputManager.setTouchButton(button, pressed: on)
                GameHaptics.buttonDown()
            }
            .accessibilityLabel(label)
    }
}
#endif
