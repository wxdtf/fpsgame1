//
//  HUD.swift
//  testproject
//

import SwiftUI

struct HUDView: View {
    let viewModel: GameViewModel

    private func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size * PhoneHUD.textBoost, weight: weight, design: .monospaced)
    }

    var body: some View {
        #if os(iOS)
        phoneHUD
        #else
        macHUD
        #endif
    }

    #if os(iOS)
    /// Slim bar in real screen points over a full-bleed picture. The Mac keeps
    /// the taller status bar inside the 960×600 frame.
    @State private var windowSafe = ScreenInsets()

    private var phoneHUD: some View {
        GeometryReader { geo in
            let hud = PhoneLayout.hudHeight(forHeight: geo.size.height)
            let bottom = max(geo.safeAreaInsets.bottom, windowSafe.bottom)
            let leading = max(geo.safeAreaInsets.leading, windowSafe.leading)
            let trailing = max(geo.safeAreaInsets.trailing, windowSafe.trailing)
            let topInset = max(geo.safeAreaInsets.top, windowSafe.top)
            ZStack(alignment: .top) {
                // Dead center of the picture, which is where the shot goes.
                crosshair
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 6) {
                    if viewModel.levelNameOpacity > 0 {
                        Text(viewModel.levelName)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                            .shadow(color: .black, radius: 3, x: 0, y: 1)
                            .opacity(viewModel.levelNameOpacity)
                    }
                    if !viewModel.objectiveText.isEmpty {
                        HStack(spacing: 6) {
                            Text(viewModel.objectiveComplete ? "✓" : "◆")
                            Text(viewModel.objectiveText)
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.objectiveComplete ? .green : .yellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                    }
                    if viewModel.bossActive {
                        VStack(spacing: 3) {
                            Text(viewModel.bossName)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.black.opacity(0.65)).frame(width: 200, height: 8)
                                Capsule().fill(Color.red).frame(width: max(0, 200 * viewModel.bossHealthFraction), height: 8)
                            }
                        }
                    }
                }
                .padding(.top, max(10, topInset + 8))
                .padding(.horizontal, 120)

                if viewModel.showMinimap, let world = viewModel.currentWorld {
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
                    .frame(width: 108, height: 108)
                    .padding(.top, max(8, topInset + 6))
                    .padding(.leading, leading + 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .shadow(color: .black, radius: 2)
                        .padding(.bottom, hud + bottom + 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }

                phoneStatusBar(height: hud)
                    .padding(.leading, leading)
                    .padding(.trailing, trailing)
                    .padding(.bottom, bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(WindowSafeAreaReader { next in
            if next != windowSafe { windowSafe = next }
        })
    }

    private func phoneStatusBar(height: CGFloat) -> some View {
        HStack(spacing: 14) {
            phoneStat("AMMO", viewModel.ammo < 0 ? "--" : "\(viewModel.ammo)", .yellow)
            phoneStat("HP", "\(viewModel.health)", viewModel.health > 25 ? .green : .red)
            faceView
                .frame(width: 36, height: 36)
            phoneStat("ARM", "\(viewModel.armor)", .blue)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(viewModel.currentWeaponName)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    ForEach(Array(["1", "2", "3", "4", "5"].enumerated()), id: \.offset) { index, slot in
                        let names = ["FIST", "PISTOL", "SHOTGUN", "CHAINGUN", "LAUNCHER"]
                        Text(slot)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(viewModel.currentWeaponName == names[index] ? .yellow : .gray)
                    }
                }
                if !viewModel.heldKeys.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(viewModel.heldKeys, id: \.self) { key in
                            Circle()
                                .fill(key == "R" ? Color.red : key == "B" ? Color.blue : Color.yellow)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: height)
        .background(Color.black.opacity(0.62))
        .overlay(Rectangle().fill(Color.white.opacity(0.28)).frame(height: 1), alignment: .top)
    }

    private func phoneStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
        }
    }
    #endif

    private var macHUD: some View {
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
                        .font(mono(22, .black))
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
                            .font(mono(12, .bold))
                            .foregroundColor(viewModel.objectiveComplete ? .green : .yellow)
                        Text(viewModel.objectiveText)
                            .font(mono(14, .bold))
                            .foregroundColor(viewModel.objectiveComplete ? .green : .yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .opacity(viewModel.objectiveComplete ? 0.6 : 0.85)
                }

                // Boss health bar (shown once a boss has noticed the player)
                if viewModel.bossActive {
                    VStack(spacing: 3) {
                        Text(viewModel.bossName)
                            .font(mono(13, .black))
                            .foregroundColor(.red)
                            .shadow(color: .black, radius: 2)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 220, height: 10)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red)
                                .frame(width: max(0, 220 * viewModel.bossHealthFraction), height: 10)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .padding(.top, 6)
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
                        .padding(.trailing, 8 + PhoneHUD.minimapExtraTrailing)
                    }
                    Spacer()
                }
            }

            // Status message overlay
            if !viewModel.statusMessage.isEmpty {
                VStack {
                    Spacer()
                    Text(viewModel.statusMessage)
                        .font(mono(18, .bold))
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
                .fill(Color.white.opacity(0.9))
                .frame(width: 3, height: 16 * PhoneHUD.textBoost)
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 16 * PhoneHUD.textBoost, height: 3)
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
                .frame(width: 64 * PhoneHUD.faceScale, height: 64 * PhoneHUD.faceScale)
                .padding(.horizontal, 8)

            // Armor section
            statBox(label: "ARMOR", value: "\(viewModel.armor)%", color: .blue)

            Spacer()

            // Weapon + Level section
            VStack(spacing: 2) {
                Text(viewModel.character.name)
                    .font(mono(11, .black))
                    .foregroundColor(viewModel.character.accentColor)
                Text("LVL \(viewModel.currentLevel)")
                    .font(mono(12, .bold))
                    .foregroundColor(.cyan)
                Text(viewModel.currentWeaponName)
                    .font(mono(16, .bold))
                    .foregroundColor(.white)

                // Weapon slots
                HStack(spacing: 3) {
                    Text("1")
                        .font(mono(11))
                        .foregroundColor(viewModel.currentWeaponName == "FIST" ? .yellow : .gray)
                    Text("2")
                        .font(mono(11))
                        .foregroundColor(viewModel.currentWeaponName == "PISTOL" ? .yellow : .gray)
                    Text("3")
                        .font(mono(11))
                        .foregroundColor(viewModel.currentWeaponName == "SHOTGUN" ? .yellow : .gray)
                    Text("4")
                        .font(mono(11))
                        .foregroundColor(viewModel.currentWeaponName == "CHAINGUN" ? .yellow : .gray)
                    Text("5")
                        .font(mono(11))
                        .foregroundColor(viewModel.currentWeaponName == "LAUNCHER" ? .yellow : .gray)
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
            .frame(width: 96 * PhoneHUD.textBoost)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6 + PhoneHUD.statusBarExtraBottom)
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
                .font(mono(12, .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(mono(28, .heavy))
                .foregroundColor(color)
        }
        .frame(width: 108 * PhoneHUD.textBoost)
    }

    private var faceView: some View {
        Group {
            if let image = viewModel.faceFrameImage {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
            } else {
                Color(white: 0.5)
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
                        // Secret doors keep their wall's colour so the map does not give them away
                        case .brickWall, .brickTorch, .secretBrick: color = Color(red: 0.5, green: 0.2, blue: 0.1)
                        case .metalWall, .secretMetal: color = .gray
                        case .techWall, .secretTech: color = Color(red: 0.1, green: 0.3, blue: 0.5)
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
        .frame(width: 120 * PhoneHUD.minimapScale, height: 120 * PhoneHUD.minimapScale)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
    }
}
