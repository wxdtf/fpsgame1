//
//  HUD.swift
//  testproject
//

import SwiftUI

struct HUDView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Crosshair
            Spacer()
            crosshair
            Spacer()

            // Bottom status bar
            statusBar
        }
    }

    private var crosshair: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 2, height: 12)
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 12, height: 2)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            // Ammo section
            statBox(label: "AMMO", value: viewModel.ammo < 0 ? "--" : "\(viewModel.ammo)", color: .yellow)

            Spacer()

            // Health section
            statBox(label: "HEALTH", value: "\(viewModel.health)%", color: viewModel.health > 25 ? .green : .red)

            // Face
            faceView
                .frame(width: 52, height: 52)
                .padding(.horizontal, 8)

            // Armor section
            statBox(label: "ARMOR", value: "\(viewModel.armor)%", color: .blue)

            Spacer()

            // Weapon + Level section
            VStack(spacing: 2) {
                Text("LVL \(viewModel.currentLevel)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text(viewModel.currentWeaponName)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // Weapon slots
                HStack(spacing: 4) {
                    Text("1")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "FIST" ? .yellow : .gray)
                    Text("2")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "PISTOL" ? .yellow : .gray)
                    Text("3")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "SHOTGUN" ? .yellow : .gray)
                }
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(Color(white: 0.3))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(width: 100)
    }

    private var faceView: some View {
        Canvas { context, size in
            let pixels = viewModel.faceFramePixels
            let faceSize = 24
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
        .background(Color(white: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct MinimapView: View {
    let playerX: Double
    let playerY: Double
    let playerAngle: Double
    let world: GameWorld

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 20.0
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Draw visible tiles around player
            let viewRadius = 10
            let startTileX = max(0, Int(playerX) - viewRadius)
            let endTileX = min(world.width - 1, Int(playerX) + viewRadius)
            let startTileY = max(0, Int(playerY) - viewRadius)
            let endTileY = min(world.height - 1, Int(playerY) + viewRadius)

            for ty in startTileY...endTileY {
                for tx in startTileX...endTileX {
                    let tile = world.tileAt(x: tx, y: ty)
                    guard tile != .empty else { continue }

                    let screenX = centerX + (CGFloat(tx) - CGFloat(playerX)) * scale
                    let screenY = centerY + (CGFloat(ty) - CGFloat(playerY)) * scale
                    let rect = CGRect(x: screenX, y: screenY, width: scale, height: scale)

                    let color: Color
                    switch tile {
                    case .brickWall, .brickTorch: color = Color(red: 0.5, green: 0.2, blue: 0.1)
                    case .metalWall: color = .gray
                    case .techWall: color = Color(red: 0.1, green: 0.3, blue: 0.5)
                    case .door: color = .yellow
                    case .exitPortal: color = Color(red: 0.0, green: 1.0, blue: 0.3)
                    case .empty: color = .clear
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }

            // Player dot
            let playerDot = CGRect(x: centerX - 2, y: centerY - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: playerDot), with: .color(.green))

            // Direction line
            let lineEnd = CGPoint(
                x: centerX + cos(playerAngle) * 8,
                y: centerY + sin(playerAngle) * 8
            )
            var path = Path()
            path.move(to: CGPoint(x: centerX, y: centerY))
            path.addLine(to: lineEnd)
            context.stroke(path, with: .color(.green), lineWidth: 1)
        }
        .frame(width: 120, height: 120)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
    }
}
