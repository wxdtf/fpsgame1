//
//  SettingsViews.swift
//  fpsgame1
//
//  The options menu (from the title screen or the pause menu) and the pause menu.
//  Both are driven by the keyboard or a controller: ↑↓ pick a row, ←→ adjust,
//  Enter confirms, Esc goes back.
//

import SwiftUI

struct SettingsView: View {
    let settings: GameSettings
    let onBack: () -> Void
    @State private var selectedRow: Int = 0

    private enum Row: Int, CaseIterable {
        case sensitivity, master, sfx, music, minimap, reset, back
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Text("SETTINGS")
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.5), radius: 12)

                VStack(spacing: 10) {
                    sliderRow(.sensitivity, "MOUSE SENSITIVITY", value: settings.mouseSensitivity / GameSettings.sensitivityRange.upperBound,
                              text: String(format: "%.1fx", settings.mouseSensitivity))
                    sliderRow(.master, "MASTER VOLUME", value: settings.masterVolume, text: percent(settings.masterVolume))
                    sliderRow(.sfx, "EFFECTS VOLUME", value: settings.sfxVolume, text: percent(settings.sfxVolume))
                    sliderRow(.music, "MUSIC VOLUME", value: settings.musicVolume, text: percent(settings.musicVolume))
                    toggleRow(.minimap, "MINIMAP AT START", on: settings.minimapDefault)
                    actionRow(.reset, "RESET TO DEFAULTS")
                    actionRow(.back, "BACK")
                }
                .padding(.vertical, 10)

                Text("\u{2191} \u{2193}  SELECT   \u{00B7}   \u{2190} \u{2192}  ADJUST   \u{00B7}   ENTER  CONFIRM   \u{00B7}   ESC  BACK")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()
            }
        }
        .background(KeyPressHandler(onEnter: confirm, onKey: handleKey))
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func rowColor(_ row: Row) -> Color { row.rawValue == selectedRow ? .yellow : .white }

    private func label(_ row: Row, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(row.rawValue == selectedRow ? "\u{25B6}" : " ")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(rowColor(row))
                .frame(width: 220, alignment: .leading)
        }
    }

    private func sliderRow(_ row: Row, _ title: String, value: Double, text: String) -> some View {
        HStack(spacing: 12) {
            label(row, title)
            Text("\u{2190}")
                .foregroundColor(.gray)
                .onTapGesture { selectedRow = row.rawValue; adjust(-1) }
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.15)).frame(width: 180, height: 10)
                Rectangle().fill(rowColor(row)).frame(width: max(0, 180 * min(1, value)), height: 10)
            }
            .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
            Text("\u{2192}")
                .foregroundColor(.gray)
                .onTapGesture { selectedRow = row.rawValue; adjust(1) }
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
                .frame(width: 50, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedRow = row.rawValue }
    }

    private func toggleRow(_ row: Row, _ title: String, on: Bool) -> some View {
        HStack(spacing: 12) {
            label(row, title)
            Text(on ? "[ ON ]" : "[ OFF ]")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(on ? .green : .gray)
                .frame(width: 254, alignment: .leading)
            Spacer().frame(width: 50)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedRow = row.rawValue; adjust(1) }
    }

    private func actionRow(_ row: Row, _ title: String) -> some View {
        HStack(spacing: 12) {
            label(row, title)
            Spacer().frame(width: 304)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedRow = row.rawValue; confirm() }
    }

    private func handleKey(_ keyCode: UInt16) {
        let count = Row.allCases.count
        switch keyCode {
        case InputManager.keyUp:
            selectedRow = (selectedRow + count - 1) % count
        case InputManager.keyDown:
            selectedRow = (selectedRow + 1) % count
        case InputManager.keyLeft:
            adjust(-1)
        case InputManager.keyRight:
            adjust(1)
        case InputManager.keyEscape:
            onBack()
        default:
            break
        }
    }

    private func adjust(_ direction: Int) {
        switch Row(rawValue: selectedRow) ?? .back {
        case .sensitivity: settings.adjustSensitivity(by: direction)
        case .master: settings.adjustMasterVolume(by: direction)
        case .sfx: settings.adjustSfxVolume(by: direction)
        case .music: settings.adjustMusicVolume(by: direction)
        case .minimap: settings.minimapDefault.toggle()
        case .reset, .back: break
        }
    }

    private func confirm() {
        switch Row(rawValue: selectedRow) ?? .back {
        case .reset: settings.resetToDefaults()
        case .back: onBack()
        case .minimap: settings.minimapDefault.toggle()
        default: break
        }
    }
}

/// The in-game pause menu. Selection lives in the view model because the game view keeps
/// keyboard focus while paused; the keys are read in GameViewModel.tick.
struct PauseOverlayView: View {
    static let items = ["RESUME", "SETTINGS", "QUIT TO TITLE"]
    var selectedIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("PAUSED")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.white)

                VStack(spacing: 10) {
                    ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 10) {
                            Text(index == selectedIndex ? "\u{25B6}" : " ")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                            Text(item)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(index == selectedIndex ? .yellow : .white)
                                .frame(width: 200, alignment: .leading)
                        }
                    }
                }

                Text("\u{2191} \u{2193}  SELECT   \u{00B7}   ENTER  CONFIRM   \u{00B7}   ESC  RESUME")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .allowsHitTesting(false)
    }
}
