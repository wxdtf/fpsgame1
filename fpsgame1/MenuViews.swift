//
//  MenuViews.swift
//  testproject
//

import SwiftUI

struct TitleScreenView: View {
    let hasSavedCampaign: Bool
    let acceptsEnter: Bool
    let onNewGame: () -> Void
    let onContinue: () -> Void
    let onSettings: () -> Void
    @State private var blinkVisible = true
    @State private var titleScale: CGFloat = 0.8
    @State private var flickerOpacity: Double = 1.0
    @State private var blinkTimer: Timer?

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
                    if hasSavedCampaign {
                        menuButton("CONTINUE CAMPAIGN", action: onContinue)
                            .opacity(blinkVisible ? 1.0 : 0.65)
                    }
                    menuButton("NEW CAMPAIGN", action: onNewGame)
                    menuButton("SETTINGS", action: onSettings)

                    VStack(spacing: 8) {
                        controlHint("WASD", description: "Move")
                        controlHint("MOUSE / TRACKPAD", description: "Look around")
                        controlHint("SPACE / CLICK", description: "Shoot")
                        controlHint("E", description: "Open doors")
                        controlHint("1 2 3 4", description: "Switch weapons")
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
            blinkTimer?.invalidate()
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                blinkVisible.toggle()
            }
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
        .background {
            if acceptsEnter {
                KeyPressHandler(onEnter: hasSavedCampaign ? onContinue : onNewGame)
            }
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 260)
                .padding(.vertical, 7)
                .overlay(Rectangle().stroke(Color.red.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
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

                Text(currentLevel >= GameWorld.maxLevel
                    ? "PRESS ENTER TO FINISH CAMPAIGN"
                    : "PRESS ENTER FOR NEXT LEVEL")
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

struct CampaignCompleteView: View {
    let onNewCampaign: () -> Void
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                Text("CAMPAIGN COMPLETE")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 12)

                Text("THE INVASION HAS BEEN STOPPED")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)

                Text("PRESS ENTER TO START A NEW CAMPAIGN")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 20)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
        }
        .onTapGesture { onNewCampaign() }
        .background(KeyPressHandler(onEnter: onNewCampaign))
    }
}

struct BriefingScreenView: View {
    let level: Int
    let onStart: () -> Void
    @State private var visibleLines: Int = 0
    @State private var showPrompt: Bool = false
    @State private var lineTimer: Timer?

    private var briefing: (title: String, lines: [String]) {
        GameWorld.briefingText(for: level)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text(briefing.title)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.3), radius: 8)
                    .padding(.bottom, 12)

                ForEach(0..<min(visibleLines, briefing.lines.count), id: \.self) { i in
                    Text(briefing.lines[i])
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 0.85, blue: 0.0))
                }

                if showPrompt {
                    Text("PRESS ENTER TO BEGIN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }

                Spacer()
            }
            .padding(.horizontal, 100)
        }
        .onAppear {
            visibleLines = 0
            showPrompt = false
            let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if visibleLines < briefing.lines.count {
                    visibleLines += 1
                } else {
                    showPrompt = true
                    timer.invalidate()
                }
            }
            lineTimer = t
        }
        .onDisappear {
            lineTimer?.invalidate()
        }
        .onTapGesture {
            if showPrompt {
                onStart()
            } else {
                // Skip typewriter — show all immediately
                lineTimer?.invalidate()
                visibleLines = briefing.lines.count
                showPrompt = true
            }
        }
        .background(KeyPressHandler(onEnter: {
            if showPrompt {
                onStart()
            } else {
                lineTimer?.invalidate()
                visibleLines = briefing.lines.count
                showPrompt = true
            }
        }))
    }
}

struct PauseOverlayView: View {
    let onResume: () -> Void
    let onSettings: () -> Void
    let onQuitToMenu: () -> Void

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

                Button("RESUME", action: onResume)
                Button("SETTINGS", action: onSettings)
                Button("QUIT TO MENU", action: onQuitToMenu)
            }
            .buttonStyle(PauseButtonStyle())
        }
    }
}

private struct PauseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(configuration.isPressed ? .yellow : .white)
            .frame(width: 220)
            .padding(.vertical, 6)
            .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
    }
}

struct SettingsView: View {
    @Bindable var settings: GameSettingsStore
    let difficultyLocked: Bool
    let onChanged: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("SETTINGS")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(.red)

                settingRow("DIFFICULTY") {
                    Picker("", selection: $settings.difficulty) {
                        ForEach(GameDifficulty.allCases) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .disabled(difficultyLocked)
                }

                if difficultyLocked {
                    Text("DIFFICULTY CAN BE CHANGED FROM THE MAIN MENU")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange)
                }

                settingRow("MOUSE SENSITIVITY") {
                    HStack {
                        Slider(value: $settings.mouseSensitivity, in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.1fx", settings.mouseSensitivity))
                            .frame(width: 48)
                    }
                    .frame(width: 220)
                }

                settingRow("MASTER VOLUME") {
                    HStack {
                        Slider(value: $settings.masterVolume, in: 0...1, step: 0.05)
                        Text("\(Int(settings.masterVolume * 100))%")
                            .frame(width: 48)
                    }
                    .frame(width: 220)
                }

                settingRow("MINIMAP") {
                    Toggle("", isOn: $settings.showMinimap)
                        .labelsHidden()
                }

                Button("BACK", action: onClose)
                    .buttonStyle(PauseButtonStyle())
                    .padding(.top, 12)
            }
            .padding(36)
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            .overlay(Rectangle().stroke(Color.red.opacity(0.8), lineWidth: 2))
        }
        .onChange(of: settings.mouseSensitivity) { _, _ in onChanged() }
        .onChange(of: settings.masterVolume) { _, _ in onChanged() }
        .onChange(of: settings.showMinimap) { _, _ in onChanged() }
    }

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 180, alignment: .trailing)
            content()
                .frame(width: 240, alignment: .leading)
        }
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
