//
//  TouchControls.swift
//  fpsgame1
//
//  On-screen controls for iOS / iPadOS, laid over a full-bleed picture:
//
//    - lower left: a move stick that is visible before the first touch. Putting
//      a thumb down anywhere in the left zone recenters it; letting go parks
//      it again.
//    - everywhere else: drag to look. A short tap with no travel fires once
//      and does not twitch the crosshair.
//    - lower right: a large FIRE button where the right thumb rests, with USE,
//      the weapon arrows and RUN on an arc within reach of it.
//    - upper right: MAP and PAUSE, clear of the Dynamic Island.
//
//  Every control has its own gesture, so a stick, a look drag and FIRE can all
//  be held at once.
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
                LookArea(inputManager: inputManager)
                    .padding(.leading, layout.moveZoneWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                StickArea(
                    inputManager: inputManager,
                    anchor: layout.stick.center,
                    radius: layout.stick.radius
                )
                .frame(width: layout.moveZoneWidth, height: geo.size.height, alignment: .topLeading)

                RoundHold(label: "USE", spot: layout.use, inputManager: inputManager, button: .interact, prominent: false)
                RoundHold(label: "\u{25B6}", spot: layout.nextWeapon, inputManager: inputManager, button: .nextWeapon, prominent: false)
                RoundHold(label: "\u{25C0}", spot: layout.previousWeapon, inputManager: inputManager, button: .previousWeapon, prominent: false)
                RoundToggle(label: "RUN", spot: layout.run, inputManager: inputManager, button: .sprint)
                RoundHold(label: "FIRE", spot: layout.fire, inputManager: inputManager, button: .fire, prominent: true)

                RoundHold(label: "MAP", spot: layout.map, inputManager: inputManager, button: .map, prominent: false)
                RoundHold(label: "II", spot: layout.pause, inputManager: inputManager, button: .pause, prominent: false)
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
struct WindowSafeAreaReader: UIViewRepresentable {
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

/// The parked stick, plus a drag zone that recenters it under the thumb.
private struct StickArea: View {
    let inputManager: InputManager
    let anchor: CGPoint
    let radius: CGFloat
    @State private var origin: CGPoint? = nil
    @State private var knob: CGSize = .zero

    private var shownOrigin: CGPoint { origin ?? anchor }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Circle()
                .stroke(Color.white.opacity(origin == nil ? 0.55 : 0.9), lineWidth: 3)
                .background(Circle().fill(Color.black.opacity(origin == nil ? 0.28 : 0.4)))
                .frame(width: radius * 2, height: radius * 2)
                .position(shownOrigin)
            Circle()
                .fill(Color.white.opacity(origin == nil ? 0.55 : 0.9))
                .frame(width: radius * 0.72, height: radius * 0.72)
                .position(x: shownOrigin.x + knob.width, y: shownOrigin.y + knob.height)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if origin == nil { origin = value.startLocation }
                    let base = origin ?? anchor
                    var dx = value.location.x - base.x
                    var dy = value.location.y - base.y
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
        .accessibilityLabel("Move")
    }
}

/// Drag to look around; a short tap with no travel fires once.
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

private struct RoundFace: View {
    let label: String
    let diameter: CGFloat
    let lit: Bool
    let prominent: Bool

    var body: some View {
        Text(label)
            .font(.system(size: diameter >= 90 ? 20 : 15, weight: .black, design: .monospaced))
            .foregroundColor(lit ? .black : .white)
            .frame(width: diameter, height: diameter)
            .background(
                Circle().fill(fill)
            )
            .overlay(Circle().stroke(Color.white.opacity(lit ? 1 : 0.85), lineWidth: 3))
            .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 2)
    }

    private var fill: Color {
        if lit { return Color.yellow.opacity(0.95) }
        if prominent { return Color(red: 0.78, green: 0.1, blue: 0.08).opacity(0.88) }
        return Color.black.opacity(0.5)
    }
}

private struct RoundHold: View {
    let label: String
    let spot: ControlSpot
    let inputManager: InputManager
    let button: InputManager.TouchButton
    let prominent: Bool
    @State private var held = false

    var body: some View {
        RoundFace(label: label, diameter: spot.diameter, lit: held, prominent: prominent)
            .offset(x: spot.center.x - spot.diameter / 2, y: spot.center.y - spot.diameter / 2)
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

private struct RoundToggle: View {
    let label: String
    let spot: ControlSpot
    let inputManager: InputManager
    let button: InputManager.TouchButton
    @State private var on = false

    var body: some View {
        RoundFace(label: label, diameter: spot.diameter, lit: on, prominent: false)
            .offset(x: spot.center.x - spot.diameter / 2, y: spot.center.y - spot.diameter / 2)
            .onTapGesture {
                on.toggle()
                inputManager.setTouchButton(button, pressed: on)
                GameHaptics.buttonDown()
            }
            .accessibilityLabel(label)
    }
}
#endif
