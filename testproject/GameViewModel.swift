//
//  GameViewModel.swift
//  testproject
//

import SwiftUI
import AppKit

@Observable
@MainActor
final class GameViewModel {
    var frameImage: NSImage?
    var gameState: GameStateType = .menu
    var health: Int = 100
    var armor: Int = 0
    var ammo: Int = 50
    var currentWeaponName: String = "PISTOL"
    var killCount: Int = 0
    var totalEnemies: Int = 0
    var elapsedTime: Double = 0
    var currentLevel: Int = 1
    var recentDamage: Bool = false
    var recentPickup: Bool = false

    let inputManager = InputManager()

    private var gameEngine: GameEngine?
    private var metalRenderer: MetalRenderer?
    private var cpuRenderer: Renderer?  // Fallback
    private var useGPU: Bool = false
    private var timer: DispatchSourceTimer?
    private var lastFrameTime: CFTimeInterval = 0
    private var doomFace: DoomFace?
    private let audio = AudioManager.shared

    private var prevPlayerHealth: Int = 100
    private var prevKillCount: Int = 0
    private var prevPickupFlash: Double = 0
    private var prevEscapeState: Bool = false

    func startGame() {
        let engine = GameEngine()
        engine.state = .playing
        self.gameEngine = engine

        // Try Metal renderer first, fall back to CPU
        if let mr = MetalRenderer() {
            metalRenderer = mr
            mr.uploadWorldData(world: engine.world)
            useGPU = true
        } else {
            cpuRenderer = Renderer()
            useGPU = false
        }

        doomFace = DoomFace()

        lastFrameTime = CACurrentMediaTime()
        prevPlayerHealth = engine.player.health
        prevKillCount = 0
        prevPickupFlash = 0

        updateUIState()
        startGameLoop()
    }

    func restartGame() {
        // Clear any lingering input to prevent uncontrolled movement on respawn
        inputManager.keys.removeAll()
        inputManager.mouseDeltaX = 0
        inputManager.mouseDeltaY = 0
        inputManager.mouseHeld = false
        inputManager.mouseClicked = false

        gameEngine?.restart()
        if useGPU, let engine = gameEngine {
            metalRenderer?.uploadWorldData(world: engine.world)
        }
        prevPlayerHealth = gameEngine?.player.health ?? 100
        prevKillCount = 0
        prevPickupFlash = 0
        lastFrameTime = CACurrentMediaTime()
        updateUIState()
    }

    func advanceToNextLevel() {
        // Clear any lingering input
        inputManager.keys.removeAll()
        inputManager.mouseDeltaX = 0
        inputManager.mouseDeltaY = 0
        inputManager.mouseHeld = false
        inputManager.mouseClicked = false

        gameEngine?.nextLevel()
        if useGPU, let engine = gameEngine {
            metalRenderer?.uploadWorldData(world: engine.world)
        }
        prevPlayerHealth = gameEngine?.player.health ?? 100
        prevKillCount = 0
        prevPickupFlash = 0
        lastFrameTime = CACurrentMediaTime()
        updateUIState()
    }

    func stopGame() {
        timer?.cancel()
        timer = nil
    }

    func togglePause() {
        guard let engine = gameEngine else { return }
        if engine.state == .playing {
            engine.state = .paused
        } else if engine.state == .paused {
            engine.state = .playing
            lastFrameTime = CACurrentMediaTime()
        }
        gameState = engine.state
    }

    private func startGameLoop() {
        timer?.cancel()

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 1.0 / 60.0)
        t.setEventHandler { [weak self] in
            self?.gameLoop()
        }
        t.resume()
        timer = t
    }

    private func gameLoop() {
        guard let engine = gameEngine else { return }

        let now = CACurrentMediaTime()
        var deltaTime = now - lastFrameTime
        lastFrameTime = now

        // Clamp delta to prevent huge jumps
        deltaTime = min(deltaTime, 1.0 / 20.0)

        // Check ESC with edge detection (trigger on press, not hold)
        let escapeDown = inputManager.keys.contains(InputManager.keyEscape)
        let escapeJustPressed = escapeDown && !prevEscapeState
        prevEscapeState = escapeDown

        if escapeJustPressed && (engine.state == .playing || engine.state == .paused) {
            togglePause()
            if engine.state == .paused {
                updateUIState()
                return
            }
        }

        if engine.state == .playing {
            let input = inputManager.getInputState()

            // Play sounds based on state changes
            let prevHealth = prevPlayerHealth
            let prevKills = prevKillCount
            let prevPickup = prevPickupFlash

            engine.update(deltaTime: deltaTime, input: input)

            // Sound effects — use the engine's flag so sound plays on the exact frame of firing
            if let firedWeapon = engine.firedWeaponThisFrame {
                switch firedWeapon {
                case .pistol: audio.playGunshot()
                case .shotgun: audio.playShotgun()
                case .fist: audio.playPunch()
                }
            }

            if engine.player.health < prevHealth {
                audio.playHurt()
            }

            if engine.killCount > prevKills {
                audio.playEnemyDeath()
            }

            if engine.pickupFlashTimer > prevPickup {
                audio.playPickup()
            }

            prevPlayerHealth = engine.player.health
            prevKillCount = engine.killCount
            prevPickupFlash = engine.pickupFlashTimer
        }

        // Always update UI state so SwiftUI sees state transitions (dead/levelComplete)
        updateUIState()

        // Skip rendering when not actively playing (paused frame already showing, or transitioned away)
        guard engine.state == .playing else { return }

        // Render
        autoreleasepool {
            // Get the active pixel buffer (GPU or CPU path)
            let activePixelBuffer: PixelBuffer

            if useGPU, let mr = metalRenderer {
                mr.render(
                    player: engine.player,
                    world: engine.world,
                    enemies: engine.enemies,
                    items: engine.items,
                    projectiles: engine.projectiles
                )
                activePixelBuffer = mr.pixelBuffer
            } else if let cr = cpuRenderer {
                cr.render(
                    player: engine.player,
                    world: engine.world,
                    enemies: engine.enemies,
                    items: engine.items,
                    projectiles: engine.projectiles
                )
                activePixelBuffer = cr.pixelBuffer
            } else {
                return
            }

            // Damage flash
            if engine.damageFlashTimer > 0 {
                let intensity = min(0.5, engine.damageFlashTimer)
                activePixelBuffer.applyTint(
                    color: PixelBuffer.makeColor(r: 255, g: 0, b: 0),
                    intensity: intensity
                )
            }

            // Pickup flash
            if engine.pickupFlashTimer > 0 {
                let intensity = min(0.2, engine.pickupFlashTimer * 0.5)
                activePixelBuffer.applyTint(
                    color: PixelBuffer.makeColor(r: 255, g: 255, b: 0),
                    intensity: intensity
                )
            }

            // Hit marker (X at center of screen)
            if engine.hitMarkerTimer > 0 {
                let cx = GameConstants.renderWidth / 2
                let cy = GameConstants.renderHeight / 2
                let alpha = min(1.0, engine.hitMarkerTimer * 6.0)
                let white = PixelBuffer.makeColor(r: 255, g: 255, b: 255)
                let size = 4
                for i in 1...size {
                    let offset = i
                    for (dx, dy) in [(offset, offset), (-offset, -offset), (offset, -offset), (-offset, offset)] {
                        let px = cx + dx
                        let py = cy + dy
                        if px >= 0 && px < GameConstants.renderWidth && py >= 0 && py < GameConstants.renderHeight {
                            if alpha >= 0.5 {
                                activePixelBuffer.setPixel(x: px, y: py, color: white)
                            }
                        }
                    }
                }
            }

            frameImage = activePixelBuffer.toNSImage()
        }
    }

    private func updateUIState() {
        guard let engine = gameEngine else { return }
        gameState = engine.state
        health = engine.player.health
        armor = engine.player.armor
        killCount = engine.killCount
        totalEnemies = engine.totalEnemies
        elapsedTime = engine.elapsedTime
        currentLevel = engine.currentLevel
        recentDamage = engine.damageFlashTimer > 0
        recentPickup = engine.pickupFlashTimer > 0

        switch engine.player.currentWeapon {
        case .fist: currentWeaponName = "FIST"
        case .pistol: currentWeaponName = "PISTOL"
        case .shotgun: currentWeaponName = "SHOTGUN"
        }

        let ammoType = WeaponDefinition.forType(engine.player.currentWeapon).ammoType
        if let type = ammoType {
            ammo = engine.player.ammo[type] ?? 0
        } else {
            ammo = -1  // Infinite (fist)
        }
    }

    var faceFramePixels: [UInt32] {
        guard let face = doomFace, let engine = gameEngine else {
            return [UInt32](repeating: 0xFF808080, count: 24 * 24)
        }
        let frameIdx = face.frameForState(
            health: engine.player.health,
            recentDamage: engine.damageFlashTimer > 0.1,
            damageDir: engine.lastDamageDirection,
            pickupGrin: engine.pickupFlashTimer > 0
        )
        return face.frames[min(frameIdx, face.frames.count - 1)]
    }
}
