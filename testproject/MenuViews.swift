//
//  MenuViews.swift
//  testproject
//

import SwiftUI

struct TitleScreenView: View {
    let onStart: () -> Void
    @State private var blinkVisible = true
    @State private var titleScale: CGFloat = 0.8
    @State private var flickerOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Background atmospheric effect
            Canvas { context, size in
                for i in 0..<80 {
                    let x = CGFloat((i * 97 + 13) % Int(size.width))
                    let y = CGFloat((i * 53 + 7) % Int(size.height))
                    let brightness = Double((i * 31) % 40 + 10) / 255.0
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(Path(rect), with: .color(Color(red: brightness, green: 0, blue: 0)))
                }
            }

            VStack(spacing: 30) {
                Spacer()

                // Title
                VStack(spacing: 4) {
                    Text("DOOM")
                        .font(.system(size: 72, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red, Color(red: 0.8, green: 0, blue: 0), Color(red: 0.5, green: 0, blue: 0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .red.opacity(0.5), radius: 20)
                        .shadow(color: .black, radius: 2, x: 3, y: 3)
                        .scaleEffect(titleScale)

                    Text("S W I F T")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .tracking(8)
                }

                Spacer()

                // Menu options
                VStack(spacing: 16) {
                    Text("PRESS ENTER OR CLICK TO START")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(blinkVisible ? 1.0 : 0.3)

                    VStack(spacing: 8) {
                        controlHint("WASD", description: "Move")
                        controlHint("MOUSE / TRACKPAD", description: "Look around")
                        controlHint("SPACE / CLICK", description: "Shoot")
                        controlHint("E", description: "Open doors")
                        controlHint("1 2 3", description: "Switch weapons")
                        controlHint("SHIFT", description: "Sprint")
                        controlHint("ESC", description: "Pause")
                    }
                    .padding(.top, 10)
                }

                Spacer()

                Text("A SwiftUI Raycasting Engine")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                titleScale = 1.0
            }
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                blinkVisible.toggle()
            }
        }
        .onTapGesture { onStart() }
        .background(KeyPressHandler(onEnter: onStart))
    }

    private func controlHint(_ key: String, description: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 160, alignment: .trailing)
            Text("-")
                .foregroundColor(.gray)
            Text(description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 160, alignment: .leading)
        }
    }
}

struct DeathScreenView: View {
    let onRestart: () -> Void
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.3, green: 0, blue: 0).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("YOU DIED")
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(color: .black, radius: 4, x: 2, y: 2)

                Text("PRESS ENTER TO TRY AGAIN")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                opacity = 1.0
            }
        }
        .onTapGesture { onRestart() }
        .background(KeyPressHandler(onEnter: onRestart))
    }
}

struct VictoryScreenView: View {
    let killCount: Int
    let totalEnemies: Int
    let elapsedTime: Double
    var currentLevel: Int = 1
    let onContinue: () -> Void
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("LEVEL \(currentLevel) COMPLETE!")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 10)

                VStack(spacing: 12) {
                    statLine("KILLS", value: "\(killCount) / \(totalEnemies)")
                    statLine("TIME", value: formatTime(elapsedTime))
                    statLine("RATING", value: rating)
                }
                .padding(.vertical, 20)

                Text("PRESS ENTER FOR NEXT LEVEL")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1.0
            }
        }
        .onTapGesture { onContinue() }
        .background(KeyPressHandler(onEnter: onContinue))
    }

    private var rating: String {
        let killPct = totalEnemies > 0 ? Double(killCount) / Double(totalEnemies) : 0
        if killPct >= 1.0 && elapsedTime < 120 { return "ULTRA-VIOLENCE" }
        if killPct >= 1.0 { return "NIGHTMARE" }
        if killPct >= 0.8 { return "HURT ME PLENTY" }
        if killPct >= 0.5 { return "HEY, NOT TOO ROUGH" }
        return "I'M TOO YOUNG TO DIE"
    }

    private func statLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 200, alignment: .leading)
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct PauseOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.white)

                Text("PRESS ESC TO RESUME")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .allowsHitTesting(false)
    }
}

// Helper to capture Enter key on menu screens
struct KeyPressHandler: NSViewRepresentable {
    let onEnter: () -> Void

    func makeNSView(context: Context) -> KeyPressNSView {
        let view = KeyPressNSView()
        view.onEnter = onEnter
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyPressNSView, context: Context) {
        nsView.onEnter = onEnter
    }

    class KeyPressNSView: NSView {
        var onEnter: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36 { // Return
                onEnter?()
            }
        }
    }
}
