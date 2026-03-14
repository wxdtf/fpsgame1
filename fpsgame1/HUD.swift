//
//  HUD.swift
//  testproject
//

import SwiftUI

struct HUDView: View {
    let viewModel: GameViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Crosshair
                Spacer()
                crosshair
                Spacer()

                // Bottom status bar
                statusBar
            }

            // Level name overlay (top center, fades out) + objective
            VStack(spacing: 4) {
                if viewModel.levelNameOpacity > 0 {
                    Text(viewModel.levelName)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                        .shadow(color: .black, radius: 4, x: 2, y: 2)
                        .opacity(viewModel.levelNameOpacity)
                        .padding(.top, 30)
                } else {
                    Spacer().frame(height: 30)
                }

                // Persistent objective indicator
                if !viewModel.objectiveText.isEmpty {
                    HStack(spacing: 6) {
                        Text(viewModel.objectiveComplete ? "✓" : "◆")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(viewModel.objectiveComplete ? .green : .yellow)
                        Text(viewModel.objectiveText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(viewModel.objectiveComplete ? .green : .yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .opacity(viewModel.objectiveComplete ? 0.6 : 0.85)
                }

                Spacer()
            }

            // Minimap (top-right corner, toggle with TAB)
            if viewModel.showMinimap, let world = viewModel.currentWorld {
                VStack {
                    HStack {
                        Spacer()
                        MinimapView(
                            playerX: viewModel.playerX,
                            playerY: viewModel.playerY,
                            playerAngle: viewModel.playerAngle,
                            world: world,
                            exploredTiles: viewModel.exploredTiles,
                            worldWidth: viewModel.worldWidth,
                            enemyPositions: viewModel.enemyPositions,
                            itemPositions: viewModel.itemPositions
                        )
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }
                    Spacer()
                }
            }

            // Status message overlay
            if !viewModel.statusMessage.isEmpty {
                VStack {
                    Spacer()
                    Text(viewModel.statusMessage)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .shadow(color: .black, radius: 2)
                        .padding(.bottom, 80)
                }
            }
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
                .frame(width: 64, height: 64)
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
                HStack(spacing: 3) {
                    Text("1")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "FIST" ? .yellow : .gray)
                    Text("2")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "PISTOL" ? .yellow : .gray)
                    Text("3")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "SHOTGUN" ? .yellow : .gray)
                    Text("4")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.currentWeaponName == "CHAINGUN" ? .yellow : .gray)
                }

                // Key indicators
                if !viewModel.heldKeys.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(viewModel.heldKeys, id: \.self) { key in
                            Circle()
                                .fill(key == "R" ? Color.red : key == "B" ? Color.blue : Color.yellow)
                                .frame(width: 6, height: 6)
                        }
                    }
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
            let faceSize = 48
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
    let exploredTiles: Set<Int>
    let worldWidth: Int
    let enemyPositions: [(x: Double, y: Double, isDead: Bool)]
    let itemPositions: [(x: Double, y: Double, collected: Bool)]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 20.0
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Draw explored tiles around player (fog of war)
            let viewRadius = 10
            let startTileX = max(0, Int(playerX) - viewRadius)
            let endTileX = min(world.width - 1, Int(playerX) + viewRadius)
            let startTileY = max(0, Int(playerY) - viewRadius)
            let endTileY = min(world.height - 1, Int(playerY) + viewRadius)

            for ty in startTileY...endTileY {
                for tx in startTileX...endTileX {
                    // Only show explored tiles
                    let tileKey = ty * worldWidth + tx
                    guard exploredTiles.contains(tileKey) else { continue }

                    let tile = world.tileAt(x: tx, y: ty)

                    let screenX = centerX + (CGFloat(tx) - CGFloat(playerX)) * scale
                    let screenY = centerY + (CGFloat(ty) - CGFloat(playerY)) * scale
                    let rect = CGRect(x: screenX, y: screenY, width: scale, height: scale)

                    if tile == .empty {
                        // Explored empty tiles shown as very dark (walkable floor)
                        context.fill(Path(rect), with: .color(Color(white: 0.12)))
                    } else {
                        let color: Color
                        switch tile {
                        case .brickWall, .brickTorch: color = Color(red: 0.5, green: 0.2, blue: 0.1)
                        case .metalWall: color = .gray
                        case .techWall: color = Color(red: 0.1, green: 0.3, blue: 0.5)
                        case .door: color = .yellow
                        case .exitPortal: color = Color(red: 0.0, green: 1.0, blue: 0.3)
                        case .lockedDoorRed: color = .red
                        case .lockedDoorBlue: color = .blue
                        case .lockedDoorYellow: color = Color(red: 0.9, green: 0.8, blue: 0.0)
                        case .damageFloor: color = Color(red: 0.2, green: 0.5, blue: 0.1).opacity(0.5)
                        case .empty: color = .clear
                        }
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }

            // Draw items as yellow dots (only on explored tiles)
            for item in itemPositions where !item.collected {
                let tileKey = Int(item.y) * worldWidth + Int(item.x)
                guard exploredTiles.contains(tileKey) else { continue }
                let sx = centerX + (CGFloat(item.x) - CGFloat(playerX)) * scale
                let sy = centerY + (CGFloat(item.y) - CGFloat(playerY)) * scale
                let dotRect = CGRect(x: sx - 1.5, y: sy - 1.5, width: 3, height: 3)
                context.fill(Path(ellipseIn: dotRect), with: .color(.yellow))
            }

            // Draw enemies as red dots (only visible ones near player)
            let enemyVisRadius = 6.0
            for enemy in enemyPositions where !enemy.isDead {
                let dx = enemy.x - playerX
                let dy = enemy.y - playerY
                let dist = sqrt(dx * dx + dy * dy)
                guard dist < enemyVisRadius else { continue }
                let tileKey = Int(enemy.y) * worldWidth + Int(enemy.x)
                guard exploredTiles.contains(tileKey) else { continue }
                let sx = centerX + (CGFloat(enemy.x) - CGFloat(playerX)) * scale
                let sy = centerY + (CGFloat(enemy.y) - CGFloat(playerY)) * scale
                let dotRect = CGRect(x: sx - 1.5, y: sy - 1.5, width: 3, height: 3)
                context.fill(Path(ellipseIn: dotRect), with: .color(.red))
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
