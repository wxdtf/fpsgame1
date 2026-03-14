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
    var lastDamageDirection: Double = 0
    var statusMessage: String = ""
    var heldKeys: [String] = []
    var isBerserk: Bool = false
    var levelName: String = ""
    var levelNameOpacity: Double = 0
    var exploredTiles: Set<Int> = []
    var worldWidth: Int = 0
    var enemyPositions: [(x: Double, y: Double, isDead: Bool)] = []
    var itemPositions: [(x: Double, y: Double, collected: Bool)] = []
    var playerX: Double = 0
    var playerY: Double = 0
    var playerAngle: Double = 0
    var currentWorld: GameWorld?
    var showMinimap: Bool = true
    var levelTransitionOpacity: Double = 0  // 0 = no fade, 1 = fully black
    var faceFrameIndex: Int = 0
    var objectiveText: String = ""
    var objectiveComplete: Bool = false

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
    private var prevBobPhase: Double = 0
    private var prevWeaponSwitching: Bool = false
    private var prevGameState: GameStateType = .menu
    private var prevTabState: Bool = false
    private var levelTransitionTimer: Double = 0
    private var isTransitioningLevel: Bool = false

    func showBriefing() {
        // If no engine yet (first time from menu), create one to know the level
        if gameEngine == nil {
            let engine = GameEngine()
            self.gameEngine = engine
        }
        gameState = .briefing
        currentLevel = gameEngine?.currentLevel ?? 1
    }

    /// Called when player presses enter on the briefing screen
    func startFromBriefing() {
        if timer == nil {
            // First start — need full initialization
            startGame()
        } else {
            // Returning from level-advance briefing — just resume
            beginAfterBriefing()
        }
    }

    func startGame() {
        guard let engine = gameEngine else { return }
        engine.state = .playing
        gameState = .playing  // Explicitly exit briefing state

        // Try Metal renderer first, fall back to CPU
        if metalRenderer == nil && cpuRenderer == nil {
            if let mr = MetalRenderer() {
                metalRenderer = mr
                mr.uploadWorldData(world: engine.world)
                useGPU = true
            } else {
                cpuRenderer = Renderer()
                useGPU = false
            }
        } else if useGPU, let mr = metalRenderer {
            mr.uploadWorldData(world: engine.world)
        }

        if doomFace == nil {
            doomFace = DoomFace()
        }

        lastFrameTime = CACurrentMediaTime()
        prevPlayerHealth = engine.player.health
        prevKillCount = 0
        prevPickupFlash = 0
        prevBobPhase = 0
        prevWeaponSwitching = false
        prevGameState = .playing

        updateUIState()
        startGameLoop()
        audio.playBGM(level: engine.currentLevel)
    }

    func restartGame() {
        // Clear any lingering input to prevent uncontrolled movement on respawn
        inputManager.keys.removeAll()
        inputManager.mouseDeltaX = 0
        inputManager.mouseDeltaY = 0
        inputManager.mouseHeld = false
        inputManager.mouseClicked = false

        gameEngine?.restart()
        gameState = .playing
        if useGPU, let engine = gameEngine {
            metalRenderer?.uploadWorldData(world: engine.world)
        }
        prevPlayerHealth = gameEngine?.player.health ?? 100
        prevKillCount = 0
        prevPickupFlash = 0
        prevBobPhase = 0
        prevWeaponSwitching = false
        prevGameState = .playing
        lastFrameTime = CACurrentMediaTime()
        updateUIState()
        audio.playBGM(level: gameEngine?.currentLevel ?? 1)
    }

    func restartWithBriefing() {
        // Clear any lingering input
        inputManager.keys.removeAll()
        inputManager.mouseDeltaX = 0
        inputManager.mouseDeltaY = 0
        inputManager.mouseHeld = false
        inputManager.mouseClicked = false

        // Reset level but keep engine paused during briefing
        gameEngine?.restart()
        gameEngine?.state = .paused
        audio.stopBGM()
        gameState = .briefing
        currentLevel = gameEngine?.currentLevel ?? 1
    }

    func advanceToNextLevel() {
        // Clear any lingering input
        inputManager.keys.removeAll()
        inputManager.mouseDeltaX = 0
        inputManager.mouseDeltaY = 0
        inputManager.mouseHeld = false
        inputManager.mouseClicked = false

        gameEngine?.nextLevel()
        // Pause engine during briefing so it doesn't update in background
        gameEngine?.state = .paused
        audio.stopBGM()
        // Show briefing before starting the next level
        gameState = .briefing
        currentLevel = gameEngine?.currentLevel ?? 1
    }

    /// Called from briefing screen when player presses enter to begin next level
    func beginAfterBriefing() {
        guard let engine = gameEngine else { return }
        engine.state = .playing
        gameState = .playing
        levelTransitionOpacity = 0
        isTransitioningLevel = false
        if useGPU {
            metalRenderer?.uploadWorldData(world: engine.world)
        }
        prevPlayerHealth = engine.player.health
        prevKillCount = 0
        prevPickupFlash = 0
        prevBobPhase = 0
        prevWeaponSwitching = false
        prevGameState = .playing
        lastFrameTime = CACurrentMediaTime()
        updateUIState()
        audio.playBGM(level: engine.currentLevel)
    }

    func stopGame() {
        timer?.cancel()
        timer = nil
        audio.stopBGM()
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

            // Toggle minimap with TAB (edge detection)
            if input.tabPressed && !prevTabState {
                showMinimap.toggle()
            }
            prevTabState = input.tabPressed

            // Snapshot state before update
            let prevHealth = prevPlayerHealth
            let prevKills = prevKillCount
            let prevPickup = prevPickupFlash
            let oldBobPhase = engine.player.bobPhase

            engine.update(deltaTime: deltaTime, input: input)

            // --- Sound effects ---

            // Weapon fire
            if let firedWeapon = engine.firedWeaponThisFrame {
                switch firedWeapon {
                case .pistol: audio.playGunshot()
                case .shotgun: audio.playShotgun()
                case .fist: audio.playPunch()
                case .chaingun: audio.playGunshot()
                }
            }

            // Footsteps: detect half-cycle crossings of bobPhase (every π)
            if engine.player.isMoving {
                let oldHalf = Int(oldBobPhase / .pi)
                let newHalf = Int(engine.player.bobPhase / .pi)
                if newHalf > oldHalf {
                    audio.playFootstep()
                }
            }

            // Weapon switch: edge detect isSwitching going true
            if engine.player.weaponState.isSwitching && !prevWeaponSwitching {
                audio.playWeaponSwitch()
            }
            prevWeaponSwitching = engine.player.weaponState.isSwitching

            // Door opened
            if engine.doorOpenedThisFrame {
                audio.playDoorOpen()
            }

            // Enemy alerted
            if engine.enemyAlertedThisFrame {
                audio.playEnemyAlert()
            }

            // Enemy hurt (but not killed)
            if engine.enemyHurtThisFrame {
                audio.playEnemyPain()
            }

            // Enemy attack (per-type sounds)
            if let attackType = engine.enemyAttackedThisFrame {
                audio.playEnemyAttack(type: attackType)
            }

            // Player hurt
            if engine.player.health < prevHealth {
                audio.playHurt()
            }

            // Enemy killed
            if engine.killCount > prevKills {
                audio.playEnemyDeath()
            }

            // Item pickup
            if engine.pickupFlashTimer > prevPickup {
                audio.playPickup()
            }

            prevPlayerHealth = engine.player.health
            prevKillCount = engine.killCount
            prevPickupFlash = engine.pickupFlashTimer
        }

        // State transition sounds
        let currentState = engine.state
        if currentState != prevGameState {
            switch currentState {
            case .levelComplete:
                audio.stopBGM()
                audio.playLevelComplete()
                // Start fade-to-black transition
                isTransitioningLevel = true
                levelTransitionTimer = 0
                levelTransitionOpacity = 0
            case .dead:
                audio.stopBGM()
            case .paused:
                audio.stopBGM()
            case .playing where prevGameState == .paused:
                audio.playBGM(level: engine.currentLevel)
            default:
                break
            }
            prevGameState = currentState
        }

        // Handle level transition fade
        if isTransitioningLevel {
            levelTransitionTimer += deltaTime
            levelTransitionOpacity = min(1.0, levelTransitionTimer / 0.6)
            if levelTransitionTimer >= 0.8 {
                isTransitioningLevel = false
                updateUIState()
                return
            }
            // Don't update game state to levelComplete until fade is done
            // Keep rendering the last frame with increasing darkness
            return
        }

        // Always update UI state so SwiftUI sees state transitions (dead/levelComplete)
        updateUIState()

        // Allow rendering during death animation too
        let isDying = engine.deathAnimTimer > 0 && engine.state == .playing
        guard engine.state == .playing || isDying else { return }

        // Render
        autoreleasepool {
            // Screen shake: apply angle offset before rendering
            var angleOffset = 0.0
            if engine.screenShakeTimer > 0 {
                angleOffset = sin(engine.elapsedTime * 50) * engine.screenShakeIntensity * 0.03
                engine.player.angle += angleOffset
            }

            // Get the active pixel buffer (GPU or CPU path)
            let activePixelBuffer: PixelBuffer

            if useGPU, let mr = metalRenderer {
                mr.render(
                    player: engine.player,
                    world: engine.world,
                    enemies: engine.enemies,
                    items: engine.items,
                    projectiles: engine.projectiles,
                    elapsedTime: engine.elapsedTime
                )
                activePixelBuffer = mr.pixelBuffer
            } else if let cr = cpuRenderer {
                cr.render(
                    player: engine.player,
                    world: engine.world,
                    enemies: engine.enemies,
                    items: engine.items,
                    projectiles: engine.projectiles,
                    elapsedTime: engine.elapsedTime
                )
                activePixelBuffer = cr.pixelBuffer
            } else {
                return
            }

            // Restore angle after rendering
            if angleOffset != 0 {
                engine.player.angle -= angleOffset
            }

            // Muzzle flash — brief white brightness
            if engine.muzzleFlashTimer > 0 {
                let intensity = min(0.3, engine.muzzleFlashTimer * 6.0)
                activePixelBuffer.applyTint(
                    color: PixelBuffer.makeColor(r: 255, g: 240, b: 200),
                    intensity: intensity
                )
            }

            // Directional damage indicator
            if engine.damageFlashTimer > 0 {
                let intensity = min(0.5, engine.damageFlashTimer)
                activePixelBuffer.applyDirectionalDamage(
                    intensity: intensity,
                    direction: engine.lastDamageDirection,
                    playerAngle: engine.player.angle
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

            // Berserk red tint
            if engine.player.isBerserk {
                activePixelBuffer.applyTint(
                    color: PixelBuffer.makeColor(r: 200, g: 0, b: 0),
                    intensity: 0.08
                )
            }

            // Death screen effect
            if engine.deathAnimTimer > 0 && engine.player.isDead {
                let progress = 1.0 - engine.deathAnimTimer / 0.8
                activePixelBuffer.applyDeathEffect(progress: progress)
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

            // Level transition fade to black
            if levelTransitionOpacity > 0 {
                activePixelBuffer.applyTint(
                    color: PixelBuffer.makeColor(r: 0, g: 0, b: 0),
                    intensity: levelTransitionOpacity
                )
            }

            frameImage = activePixelBuffer.toNSImage()
        }
    }

    private func updateUIState() {
        guard let engine = gameEngine else { return }
        // Don't overwrite briefing state — it's managed by the view model
        if gameState == .briefing { return }
        gameState = engine.state
        health = engine.player.health
        armor = engine.player.armor
        killCount = engine.killCount
        totalEnemies = engine.totalEnemies
        elapsedTime = engine.elapsedTime
        currentLevel = engine.currentLevel
        recentDamage = engine.damageFlashTimer > 0
        recentPickup = engine.pickupFlashTimer > 0
        lastDamageDirection = engine.lastDamageDirection

        switch engine.player.currentWeapon {
        case .fist: currentWeaponName = "FIST"
        case .pistol: currentWeaponName = "PISTOL"
        case .shotgun: currentWeaponName = "SHOTGUN"
        case .chaingun: currentWeaponName = "CHAINGUN"
        }

        statusMessage = engine.statusMessageTimer > 0 ? engine.statusMessage : ""
        isBerserk = engine.player.isBerserk

        // Level name display
        if engine.levelNameTimer > 0 {
            levelName = GameWorld.briefingText(for: engine.currentLevel).title
            levelNameOpacity = min(1.0, engine.levelNameTimer * 2)
        } else {
            levelNameOpacity = 0
        }
        heldKeys = []
        if engine.player.keys.contains(.red) { heldKeys.append("R") }
        if engine.player.keys.contains(.blue) { heldKeys.append("B") }
        if engine.player.keys.contains(.yellow) { heldKeys.append("Y") }

        // Fog of war / minimap data
        exploredTiles = engine.exploredTiles
        worldWidth = engine.world.width

        // Reuse arrays instead of allocating new ones each frame
        if enemyPositions.count != engine.enemies.count {
            enemyPositions = engine.enemies.map { (x: $0.x, y: $0.y, isDead: $0.isDead) }
        } else {
            for i in engine.enemies.indices {
                enemyPositions[i] = (x: engine.enemies[i].x, y: engine.enemies[i].y, isDead: engine.enemies[i].isDead)
            }
        }
        if itemPositions.count != engine.items.count {
            itemPositions = engine.items.map { (x: $0.x, y: $0.y, collected: $0.isCollected) }
        } else {
            for i in engine.items.indices {
                itemPositions[i] = (x: engine.items[i].x, y: engine.items[i].y, collected: engine.items[i].isCollected)
            }
        }
        playerX = engine.player.x
        playerY = engine.player.y
        playerAngle = engine.player.angle
        currentWorld = engine.world

        // Mission objective
        objectiveText = engine.objectiveText
        objectiveComplete = engine.missionObjectiveComplete

        let ammoType = WeaponDefinition.forType(engine.player.currentWeapon).ammoType
        if let type = ammoType {
            ammo = engine.player.ammo[type] ?? 0
        } else {
            ammo = -1  // Infinite (fist)
        }

        // Update face frame (must use tracked properties so SwiftUI redraws)
        if let face = doomFace {
            faceFrameIndex = face.frameForState(
                health: health,
                recentDamage: engine.damageFlashTimer > 0.1,
                damageDir: lastDamageDirection,
                pickupGrin: recentPickup,
                elapsedTime: elapsedTime,
                playerAngle: playerAngle
            )
        }
    }

    var faceFramePixels: [UInt32] {
        guard let face = doomFace else {
            return [UInt32](repeating: 0xFF808080, count: 48 * 48)
        }
        return face.frames[min(faceFrameIndex, face.frames.count - 1)]
    }
}
