//
//  GameViewModel.swift
//  testproject
//

import SwiftUI
import AppKit
import Metal
import MetalKit

@Observable
@MainActor
final class GameViewModel {
    /// CPU fallback only: the last rendered frame for SwiftUI to display
    var frameImage: NSImage?
    /// True once the Metal renderer is up; the game view then hosts an MTKView
    /// whose display link drives the loop instead of the timer.
    var usesMetalView: Bool = false
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
    var isFinalLevel: Bool = false
    var levelResults: [LevelResult] = []
    var bossActive: Bool = false
    var bossName: String = ""
    var bossHealthFraction: Double = 1.0
    /// The marine chosen on the character screen (remembered between launches)
    var character: PlayerCharacter = PlayerCharacter.named(
        id: UserDefaults.standard.string(forKey: "selectedCharacter") ?? PlayerCharacter.sarge.id
    )

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
    private var hasStarted: Bool = false

    var metalDevice: MTLDevice? { metalRenderer?.device }

    func showBriefing() {
        // If no engine yet (first time from menu), create one to know the level
        if gameEngine == nil {
            let engine = GameEngine()
            self.gameEngine = engine
        }
        gameState = .briefing
        currentLevel = gameEngine?.currentLevel ?? 1
    }

    /// From the title screen: pick a marine before the first briefing
    func showCharacterSelect() {
        if gameEngine == nil {
            gameEngine = GameEngine()
        }
        gameState = .characterSelect
    }

    /// From the character screen: lock in the marine, then show the briefing
    func chooseCharacter(_ chosen: PlayerCharacter) {
        character = chosen
        UserDefaults.standard.set(chosen.id, forKey: "selectedCharacter")
        gameEngine?.selectCharacter(chosen)
        doomFace = DoomFace(look: chosen.look)
        showBriefing()
    }

    /// From the character screen: back to the title
    func backToMenu() {
        gameState = .menu
    }

    /// Called when player presses enter on the briefing screen
    func startFromBriefing() {
        if !hasStarted {
            // First start — need full initialization
            startGame()
        } else {
            // Returning from level-advance briefing — just resume
            beginAfterBriefing()
        }
    }

    func startGame() {
        guard let engine = gameEngine else { return }
        hasStarted = true
        engine.state = .playing
        gameState = .playing  // Explicitly exit briefing state
        levelTransitionOpacity = 0
        isTransitioningLevel = false

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
            usesMetalView = useGPU
        } else if useGPU, let mr = metalRenderer {
            mr.uploadWorldData(world: engine.world)
        }

        if doomFace == nil {
            doomFace = DoomFace(look: character.look)
        }

        lastFrameTime = CACurrentMediaTime()
        prevPlayerHealth = engine.player.health
        prevKillCount = 0
        prevPickupFlash = 0
        prevBobPhase = 0
        prevWeaponSwitching = false
        prevGameState = .playing

        updateUIState()
        if !useGPU {
            // The Metal path is driven by the MTKView's display link instead
            startGameLoop()
        }
        audio.playBGM(level: engine.currentLevel)
    }

    /// Drop any held keys / mouse state so a new screen doesn't inherit stale input
    private func clearInput() {
        inputManager.keys.removeAll()
        inputManager.mouseDeltaX = 0
        inputManager.mouseDeltaY = 0
        inputManager.mouseHeld = false
        inputManager.mouseClicked = false
    }

    /// After death: reload the current level (not the whole campaign) behind its briefing
    func restartWithBriefing() {
        clearInput()
        gameEngine?.restartLevel()
        // Keep the engine paused during the briefing
        gameEngine?.state = .paused
        audio.stopBGM()
        gameState = .briefing
        currentLevel = gameEngine?.currentLevel ?? 1
    }

    /// From the level summary: next briefing, or the campaign summary after the final level
    func advanceToNextLevel() {
        clearInput()
        guard let engine = gameEngine else { return }
        audio.stopBGM()

        if engine.isFinalLevel {
            engine.state = .campaignComplete
            levelResults = engine.levelResults
            gameState = .campaignComplete
            return
        }

        engine.nextLevel()
        // Pause engine during briefing so it doesn't update in background
        engine.state = .paused
        // Show briefing before starting the next level
        gameState = .briefing
        currentLevel = engine.currentLevel
    }

    /// From the campaign summary: reset to level 1 and show the title screen
    func returnToMenu() {
        clearInput()
        gameEngine?.resetToMenu()
        audio.stopBGM()
        levelResults = []
        gameState = .menu
        currentLevel = 1
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

    /// CPU fallback loop, one call per timer tick: step the game, then render into
    /// the pixel buffer and hand SwiftUI the frame.
    private func gameLoop() {
        guard let engine = gameEngine, let cr = cpuRenderer else { return }
        guard tick() else { return }

        autoreleasepool {
            let angleOffset = applyScreenShake()
            cr.render(
                player: engine.player,
                world: engine.world,
                enemies: engine.enemies,
                items: engine.items,
                projectiles: engine.projectiles,
                explosions: engine.explosions,
                elapsedTime: engine.elapsedTime
            )
            engine.player.angle -= angleOffset
            currentEffects().apply(to: cr.pixelBuffer)
            frameImage = cr.pixelBuffer.toNSImage()
        }
    }

    /// Metal path, one call per display-link callback from the MTKView: step the
    /// game and encode a frame straight into the drawable.
    func renderMetalFrame(in view: MTKView) {
        guard let engine = gameEngine, let mr = metalRenderer else { return }
        let shouldRender = tick()
        // Keep presenting while paused so the drawable stays valid (resize, overlay)
        guard shouldRender || engine.state == .paused else { return }

        let angleOffset = applyScreenShake()
        mr.draw(
            in: view,
            player: engine.player,
            world: engine.world,
            enemies: engine.enemies,
            items: engine.items,
            projectiles: engine.projectiles,
            explosions: engine.explosions,
            elapsedTime: engine.elapsedTime,
            effects: currentEffects()
        )
        engine.player.angle -= angleOffset
    }

    /// Nudge the camera for screen shake; returns the offset so the caller can undo it
    private func applyScreenShake() -> Double {
        guard let engine = gameEngine, engine.screenShakeTimer > 0 else { return 0 }
        let angleOffset = sin(engine.elapsedTime * 50) * engine.screenShakeIntensity * 0.03
        engine.player.angle += angleOffset
        return angleOffset
    }

    /// Screen effects for the frame about to be rendered
    private func currentEffects() -> PostEffects {
        guard let engine = gameEngine else { return PostEffects() }
        var effects = PostEffects()
        if engine.muzzleFlashTimer > 0 {
            effects.muzzleFlash = min(0.3, engine.muzzleFlashTimer * 6.0)
        }
        if engine.damageFlashTimer > 0 {
            effects.damageIntensity = min(0.5, engine.damageFlashTimer)
            effects.damageDirection = engine.lastDamageDirection
            effects.playerAngle = engine.player.angle
        }
        if engine.pickupFlashTimer > 0 {
            effects.pickupFlash = min(0.2, engine.pickupFlashTimer * 0.5)
        }
        if engine.player.isBerserk {
            effects.berserkTint = 0.08
        }
        if engine.deathAnimTimer > 0 && engine.player.isDead {
            effects.deathProgress = 1.0 - engine.deathAnimTimer / 0.8
        }
        if engine.hitMarkerTimer > 0 {
            effects.hitMarkerAlpha = min(1.0, engine.hitMarkerTimer * 6.0)
        }
        effects.fadeToBlack = levelTransitionOpacity
        return effects
    }

    /// Advance the simulation by one frame: input, engine update, sound triggers,
    /// state transitions and the HUD state. Returns whether a frame should be
    /// rendered (playing, or the death camera is running).
    private func tick() -> Bool {
        guard let engine = gameEngine else { return false }

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
                return false
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
                case .rocketLauncher: audio.playRocketLaunch()
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

            // Boss noticed the player
            if engine.bossAlertedThisFrame {
                audio.playBossRoar()
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

            // Rocket detonated
            if engine.explosionThisFrame {
                audio.playExplosion()
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
            case .campaignComplete:
                audio.stopBGM()
                audio.playLevelComplete()
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
                return false
            }
            // Don't update game state to levelComplete until fade is done;
            // keep rendering the last frame with increasing darkness
            return true
        }

        // Always update UI state so SwiftUI sees state transitions (dead/levelComplete)
        updateUIState()

        // Allow rendering during death animation too
        let isDying = engine.deathAnimTimer > 0 && engine.state == .playing
        return engine.state == .playing || isDying
    }

    private func updateUIState() {
        guard let engine = gameEngine else { return }
        // Don't overwrite menu flow states — they're managed by the view model
        if gameState == .briefing || gameState == .characterSelect { return }
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
        case .rocketLauncher: currentWeaponName = "LAUNCHER"
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

        // Boss health bar
        if let boss = engine.activeBoss {
            bossActive = true
            bossName = boss.name
            bossHealthFraction = Double(boss.health) / Double(max(1, boss.maxHealth))
        } else {
            bossActive = false
        }

        // Campaign progress
        isFinalLevel = engine.isFinalLevel
        if levelResults.count != engine.levelResults.count {
            levelResults = engine.levelResults
        }

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

    /// Pre-rendered image of the current face frame (nil before a face exists)
    var faceFrameImage: CGImage? {
        guard let face = doomFace, !face.images.isEmpty else { return nil }
        return face.images[min(faceFrameIndex, face.images.count - 1)]
    }
}
