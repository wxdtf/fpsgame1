//
//  MenuViews.swift
//  testproject
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TitleScreenView: View {
    let settings: GameSettings
    let onStart: () -> Void
    var onSettings: () -> Void = {}
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
                    Text(InputHints.start)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(blinkVisible ? 1.0 : 0.3)
                        .onTapGesture { onStart() }

                    // Skill level: ← → cycle it, remembered between launches
                    VStack(spacing: 4) {
                        HStack(spacing: 14) {
                            Text("\u{25C0}")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .onTapGesture { settings.setDifficulty(settings.difficulty.previous) }
                            Text(settings.difficulty.name)
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .foregroundColor(.orange)
                                .frame(width: 300)
                            Text("\u{25B6}")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .onTapGesture { settings.setDifficulty(settings.difficulty.next) }
                        }
                        Text(settings.difficulty.blurb)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)

                    Text(InputHints.settings)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .onTapGesture { onSettings() }

                    VStack(spacing: 6) {
                        if InputHints.isTouch {
                            controlHint("LEFT SIDE / LEFT STICK", description: "Move")
                            controlHint("RIGHT SIDE / RIGHT STICK", description: "Look around")
                            controlHint("FIRE / TAP / RT", description: "Shoot")
                            controlHint("USE / X", description: "Open doors")
                            controlHint("\u{25C0} \u{25B6} / LB RB", description: "Switch weapons")
                            controlHint("RUN / L3", description: "Sprint")
                            controlHint("II / MENU", description: "Pause")
                        } else {
                            controlHint("WASD / LEFT STICK", description: "Move")
                            controlHint("MOUSE / RIGHT STICK", description: "Look around")
                            controlHint("SPACE / CLICK / RT", description: "Shoot")
                            controlHint("E / X", description: "Open doors")
                            controlHint("1 - 5 / LB RB", description: "Switch weapons")
                            controlHint("SHIFT / L3", description: "Sprint")
                            controlHint("ESC / MENU", description: "Pause")
                        }
                    }
                    .padding(.top, 6)
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
        .background(KeyPressHandler(onEnter: onStart, onKey: handleKey))
    }

    private func handleKey(_ keyCode: UInt16) {
        switch keyCode {
        case InputManager.keyLeft:
            settings.setDifficulty(settings.difficulty.previous)
        case InputManager.keyRight:
            settings.setDifficulty(settings.difficulty.next)
        case InputManager.keyS:
            onSettings()
        default:
            break
        }
    }

    private func controlHint(_ key: String, description: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 200, alignment: .trailing)
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

                Text(InputHints.tryAgain)
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
    var isFinalLevel: Bool = false
    /// Full tally of the level just finished (secrets, items, par)
    var result: LevelResult? = nil
    /// Best results for this level and skill, after this run was merged in
    var record: RecordUpdate? = nil
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
                    if let result {
                        statLine("ITEMS", value: "\(result.itemPercent)%")
                        statLine("SECRETS", value: "\(result.secretsFound) / \(result.totalSecrets)",
                                 badge: result.totalSecrets > 0 && result.secretsFound == result.totalSecrets ? "ALL FOUND" : nil)
                    }
                    statLine("TIME", value: formatTime(elapsedTime), badge: "PAR \(formatTime(parTime))")
                    statLine("RATING", value: rating)
                    if let record {
                        statLine("BEST TIME", value: record.record.bestTime.map(formatTime) ?? "--:--",
                                 badge: record.newBestTime ? "NEW RECORD!" : nil)
                        statLine("BEST KILLS", value: record.record.bestKillPercent.map { "\($0)%" } ?? "--",
                                 badge: record.newBestKills ? "NEW RECORD!" : nil)
                    }
                }
                .padding(.vertical, 20)

                Text(isFinalLevel ? InputHints.continueHint : InputHints.nextLevel)
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

    private var parTime: Double { result?.parTime ?? 120 }

    private var rating: String {
        performanceRating(kills: killCount, totalEnemies: totalEnemies, time: elapsedTime, parTime: parTime)
    }

    private func statLine(_ label: String, value: String, badge: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .trailing)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 120, alignment: .leading)
            Text(badge ?? "")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.red)
                .frame(width: 130, alignment: .leading)
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Shown after the final level: per-level results plus campaign totals
struct CampaignCompleteView: View {
    let results: [LevelResult]
    var operative: String = ""
    let onContinue: () -> Void
    @State private var opacity: Double = 0

    private var totalKills: Int { results.reduce(0) { $0 + $1.kills } }
    private var totalEnemies: Int { results.reduce(0) { $0 + $1.totalEnemies } }
    private var totalTime: Double { results.reduce(0) { $0 + $1.time } }
    private var totalPar: Double { results.reduce(0) { $0 + $1.parTime } }
    private var totalSecrets: Int { results.reduce(0) { $0 + $1.totalSecrets } }
    private var secretsFound: Int { results.reduce(0) { $0 + $1.secretsFound } }
    private var totalItems: Int { results.reduce(0) { $0 + $1.totalItems } }
    private var itemsCollected: Int { results.reduce(0) { $0 + $1.itemsCollected } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("EPISODE COMPLETE")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.5), radius: 12)

                Text(operative.isEmpty ? "THE FACILITY IS SILENT. FOR NOW." : "\(operative) WALKS OUT. THE FACILITY IS SILENT. FOR NOW.")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .tracking(2)

                VStack(spacing: 8) {
                    ForEach(results, id: \.level) { result in
                        HStack {
                            Text(result.title)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(width: 260, alignment: .leading)
                            Text("\(result.kills) / \(result.totalEnemies)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                                .frame(width: 90, alignment: .trailing)
                            Text(formatClockTime(result.time))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                                .frame(width: 80, alignment: .trailing)
                            Text("S \(result.secretsFound)/\(result.totalSecrets)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 12)

                VStack(spacing: 10) {
                    statLine("TOTAL KILLS", value: "\(totalKills) / \(totalEnemies)")
                    statLine("ITEMS", value: totalItems > 0 ? "\(itemsCollected * 100 / totalItems)%" : "--")
                    statLine("SECRETS", value: "\(secretsFound) / \(totalSecrets)")
                    statLine("TOTAL TIME", value: formatClockTime(totalTime) + "  (PAR \(formatClockTime(totalPar)))")
                    statLine("RATING", value: performanceRating(
                        kills: totalKills, totalEnemies: totalEnemies,
                        time: totalTime, parTime: totalPar > 0 ? totalPar : 120 * Double(max(1, results.count))))
                }

                Text(InputHints.isTouch ? "TAP TO RETURN TO THE MENU" : "PRESS ENTER TO RETURN TO THE MENU")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 10)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                opacity = 1.0
            }
        }
        .onTapGesture { onContinue() }
        .background(KeyPressHandler(onEnter: onContinue))
    }

    private func statLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 160, alignment: .trailing)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 220, alignment: .leading)
        }
    }
}

/// DOOM-flavoured performance rating shared by the level and campaign summaries
func performanceRating(kills: Int, totalEnemies: Int, time: Double, parTime: Double) -> String {
    let killPct = totalEnemies > 0 ? Double(kills) / Double(totalEnemies) : 0
    if killPct >= 1.0 && time < parTime { return "ULTRA-VIOLENCE" }
    if killPct >= 1.0 { return "NIGHTMARE" }
    if killPct >= 0.8 { return "HURT ME PLENTY" }
    if killPct >= 0.5 { return "HEY, NOT TOO ROUGH" }
    return "I'M TOO YOUNG TO DIE"
}

func formatClockTime(_ time: Double) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

struct BriefingScreenView: View {
    let level: Int
    var operative: PlayerCharacter? = nil
    var difficulty: Difficulty? = nil
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

                if let operative {
                    Text("OPERATIVE: \(operative.name) \u{00B7} \(operative.title)"
                         + (difficulty.map { " \u{00B7} SKILL: \($0.name)" } ?? ""))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(operative.accentColor)
                        .padding(.bottom, 4)
                }

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
                    Text(InputHints.isTouch ? "TAP TO BEGIN" : "PRESS ENTER TO BEGIN")
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

// Helper to capture keys on menu screens: Enter fires onEnter, every other key goes to onKey
// (mac key codes; an iPad keyboard is translated to the same codes). A game controller
// feeds the same handlers through ControllerMenuPoller.
#if os(macOS)
struct KeyPressHandler: NSViewRepresentable {
    let onEnter: () -> Void
    var onKey: ((UInt16) -> Void)? = nil

    func makeNSView(context: Context) -> KeyPressNSView {
        let view = KeyPressNSView()
        view.onEnter = onEnter
        view.onKey = onKey
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyPressNSView, context: Context) {
        nsView.onEnter = onEnter
        nsView.onKey = onKey
    }

    class KeyPressNSView: NSView {
        var onEnter: (() -> Void)? { didSet { poller.onEnter = onEnter } }
        var onKey: ((UInt16) -> Void)? { didSet { poller.onKey = onKey } }
        private let poller = ControllerMenuPoller()
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36 { // Return
                onEnter?()
            } else {
                onKey?(event.keyCode)
            }
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                poller.onEnter = onEnter
                poller.onKey = onKey
                poller.start()
            } else {
                poller.stop()
            }
        }
    }
}
#else
struct KeyPressHandler: UIViewRepresentable {
    let onEnter: () -> Void
    var onKey: ((UInt16) -> Void)? = nil

    func makeUIView(context: Context) -> KeyPressUIView {
        let view = KeyPressUIView()
        view.backgroundColor = .clear
        view.onEnter = onEnter
        view.onKey = onKey
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        return view
    }

    func updateUIView(_ uiView: KeyPressUIView, context: Context) {
        uiView.onEnter = onEnter
        uiView.onKey = onKey
    }

    class KeyPressUIView: UIView {
        var onEnter: (() -> Void)? { didSet { poller.onEnter = onEnter } }
        var onKey: ((UInt16) -> Void)? { didSet { poller.onKey = onKey } }
        private let poller = ControllerMenuPoller()
        override var canBecomeFirstResponder: Bool { true }
        /// Sits behind the screen's tap targets; never swallows a touch
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var handled = false
            for press in presses {
                guard let key = press.key, let code = InputManager.keyCode(for: key.keyCode) else { continue }
                handled = true
                if code == InputManager.keyReturn {
                    onEnter?()
                } else {
                    onKey?(code)
                }
            }
            if !handled { super.pressesBegan(presses, with: event) }
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                poller.onEnter = onEnter
                poller.onKey = onKey
                poller.start()
                becomeFirstResponder()
            } else {
                poller.stop()
            }
        }
    }
}
#endif

/// Platform-specific wording for the on-screen hints
enum InputHints {
    #if os(iOS)
    static let isTouch = true
    #else
    static let isTouch = false
    #endif
    static let start = isTouch ? "TAP TO START" : "PRESS ENTER OR CLICK TO START"
    static let continueHint = isTouch ? "TAP TO CONTINUE" : "PRESS ENTER TO CONTINUE"
    static let nextLevel = isTouch ? "TAP FOR NEXT LEVEL" : "PRESS ENTER FOR NEXT LEVEL"
    static let tryAgain = isTouch ? "TAP TO TRY AGAIN" : "PRESS ENTER TO TRY AGAIN"
    static let settings = isTouch ? "SETTINGS" : "S - SETTINGS"
    static let lookSensitivity = isTouch ? "LOOK SENSITIVITY" : "MOUSE SENSITIVITY"
    static func deploy(_ name: String) -> String {
        isTouch ? "TAP TO DEPLOY AS \(name)" : "PRESS ENTER TO DEPLOY AS \(name)"
    }
}

extension PlayerCharacter {
    /// SwiftUI colour for the marine's accent
    var accentColor: Color {
        Color(red: Double(accent.r) / 255.0, green: Double(accent.g) / 255.0, blue: Double(accent.b) / 255.0)
    }
}

/// Pick one of the playable marines before the campaign starts
struct CharacterSelectView: View {
    let initialID: String
    let onSelect: (PlayerCharacter) -> Void
    let onBack: () -> Void
    @State private var selectedIndex: Int = 0
    @State private var portraits: [String: [UInt32]] = [:]

    private var characters: [PlayerCharacter] { PlayerCharacter.all }
    private var selected: PlayerCharacter { characters[min(selectedIndex, characters.count - 1)] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text("CHOOSE YOUR MARINE")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.5), radius: 12)

                HStack(spacing: 24) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        characterCard(character, isSelected: index == selectedIndex)
                            .onTapGesture { selectedIndex = index }
                    }
                }

                VStack(spacing: 6) {
                    Text(selected.bio)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(width: 560)
                    Text(InputHints.deploy(selected.name))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                        .onTapGesture { onSelect(selected) }
                    Text(InputHints.isTouch ? "TAP A MARINE TO CHOOSE" : "\u{2190} \u{2192}  OR  1 2 3  TO CHOOSE   \u{00B7}   ESC  BACK")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\u{25C0} BACK")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.top, 4)
                        .onTapGesture { onBack() }
                }

                Spacer()
            }
        }
        .onAppear {
            if let index = characters.firstIndex(where: { $0.id == initialID }) {
                selectedIndex = index
            }
            for character in characters {
                portraits[character.id] = DoomFace(look: character.look).frames[0]
            }
        }
        .background(KeyPressHandler(onEnter: { onSelect(selected) }, onKey: handleKey))
    }

    private func handleKey(_ keyCode: UInt16) {
        let count = characters.count
        switch keyCode {
        case InputManager.keyLeft:
            selectedIndex = (selectedIndex + count - 1) % count
        case InputManager.keyRight:
            selectedIndex = (selectedIndex + 1) % count
        case InputManager.key1:
            selectedIndex = 0
        case InputManager.key2:
            selectedIndex = min(1, count - 1)
        case InputManager.key3:
            selectedIndex = min(2, count - 1)
        case InputManager.keyEscape:
            onBack()
        default:
            break
        }
    }

    private func characterCard(_ character: PlayerCharacter, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            PixelPortraitView(pixels: portraits[character.id])
                .frame(width: 96, height: 96)
            Text(character.name)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(character.accentColor)
            Text(character.title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .tracking(2)
            Text("\u{201C}\(character.tagline)\u{201D}")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(height: 30)
            VStack(alignment: .leading, spacing: 3) {
                statRow("WEAPON", character.loadoutText)
                statRow("ARMOR", "\(character.startingArmor)%")
                statRow("SPEED", speedText(character.moveSpeedMultiplier))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 214)
        .background(Color(white: isSelected ? 0.14 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? character.accentColor : Color(white: 0.25), lineWidth: isSelected ? 3 : 1)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
        }
    }

    private func speedText(_ multiplier: Double) -> String {
        if multiplier > 1.05 { return "FAST" }
        if multiplier < 0.95 { return "HEAVY" }
        return "NORMAL"
    }
}

/// Draws a 48x48 portrait frame as chunky pixels
struct PixelPortraitView: View {
    let pixels: [UInt32]?

    var body: some View {
        Canvas { context, size in
            let faceSize = 48
            guard let pixels, pixels.count == faceSize * faceSize else {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.2)))
                return
            }
            let pixelW = size.width / CGFloat(faceSize)
            let pixelH = size.height / CGFloat(faceSize)
            for y in 0..<faceSize {
                for x in 0..<faceSize {
                    let color = pixels[y * faceSize + x]
                    guard (color >> 24) != 0 else { continue }
                    let r = Double((color >> 16) & 0xFF) / 255.0
                    let g = Double((color >> 8) & 0xFF) / 255.0
                    let b = Double(color & 0xFF) / 255.0
                    let rect = CGRect(
                        x: CGFloat(x) * pixelW,
                        y: CGFloat(y) * pixelH,
                        width: pixelW + 0.5,
                        height: pixelH + 0.5
                    )
                    context.fill(Path(rect), with: .color(Color(red: r, green: g, blue: b)))
                }
            }
        }
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
