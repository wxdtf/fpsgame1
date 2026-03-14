//
//  GameEngine.swift
//  testproject
//

import Foundation

enum GameStateType {
    case menu
    case briefing
    case playing
    case paused
    case dead
    case levelComplete
}

enum ProjectileType {
    case fireball  // Imp — slow, glowing orange
    case bullet    // Soldier — fast, bright tracer
}

struct Projectile {
    var x: Double
    var y: Double
    var dirX: Double
    var dirY: Double
    var speed: Double = 6.0
    var damage: Int
    var isEnemy: Bool
    var lifetime: Double = 3.0
    var type: ProjectileType = .fireball
}

final class GameEngine {
    var state: GameStateType = .menu
    var world: GameWorld
    var player: Player
    var enemies: [Enemy]
    var items: [Item]
    var projectiles: [Projectile] = []

    var killCount: Int = 0
    var totalEnemies: Int = 0
    var elapsedTime: Double = 0
    var currentLevel: Int = 1

    var damageFlashTimer: Double = 0
    var pickupFlashTimer: Double = 0
    var lastDamageDirection: Double = 0
    var hitMarkerTimer: Double = 0
    var spawnInvincibilityTimer: Double = 0
    var screenShakeIntensity: Double = 0
    var screenShakeTimer: Double = 0
    var muzzleFlashTimer: Double = 0
    var deathAnimTimer: Double = 0
    private var deathAnimStarted: Bool = false
    var statusMessage: String = ""
    var statusMessageTimer: Double = 0
    var levelNameTimer: Double = 3.0
    var exploredTiles: Set<Int> = []
    /// Set to the weapon type that fired this frame (nil if nothing fired)
    var firedWeaponThisFrame: WeaponType?
    /// Audio event flags — reset each frame, checked by GameViewModel for sound triggers
    var doorOpenedThisFrame: Bool = false
    var enemyAlertedThisFrame: Bool = false
    var enemyHurtThisFrame: Bool = false
    var enemyAttackedThisFrame: EnemyType? = nil

    init() {
        let data = GameWorld.levelData(for: 1)
        world = GameWorld.createLevel(1)
        player = Player(x: data.playerStartX, y: data.playerStartY, angle: data.playerStartAngle)
        enemies = []
        items = []
        currentLevel = 1
        spawnEntities()
        totalEnemies = enemies.count
        spawnInvincibilityTimer = 1.5
    }

    func restart() {
        loadLevel(1)
        state = .playing
    }

    func nextLevel() {
        currentLevel += 1
        if currentLevel > GameWorld.maxLevel {
            currentLevel = 1  // Loop back
        }
        // Keep player weapons and ammo
        let savedWeapons = player.weapons
        let savedAmmo = player.ammo
        let savedWeapon = player.currentWeapon

        loadLevel(currentLevel)

        player.weapons = savedWeapons
        player.ammo = savedAmmo
        player.currentWeapon = savedWeapon
        player.weaponState = WeaponState(type: savedWeapon)
        // Restore some health between levels
        player.health = min(GameConstants.maxHealth, player.health + 25)
        spawnInvincibilityTimer = 1.5
        state = .playing
    }

    private func loadLevel(_ level: Int) {
        let data = GameWorld.levelData(for: level)
        world = GameWorld.createLevel(level)
        player = Player(x: data.playerStartX, y: data.playerStartY, angle: data.playerStartAngle)
        enemies = []
        items = []
        projectiles = []
        killCount = 0
        elapsedTime = 0
        damageFlashTimer = 0
        pickupFlashTimer = 0
        hitMarkerTimer = 0
        screenShakeIntensity = 0
        screenShakeTimer = 0
        muzzleFlashTimer = 0
        deathAnimTimer = 0
        deathAnimStarted = false
        statusMessage = ""
        statusMessageTimer = 0
        levelNameTimer = 3.0
        exploredTiles = []
        spawnInvincibilityTimer = 1.5
        spawnEntities()
        totalEnemies = enemies.count
    }

    private func spawnEntities() {
        let data = GameWorld.levelData(for: currentLevel)
        let healthMult = GameConstants.difficultyHealthMultiplier(for: currentLevel)
        enemies = data.enemies.map {
            var e = Enemy(type: $0.0, x: $0.1, y: $0.2)
            e.health = Int(Double(e.health) * healthMult)
            return e
        }
        items = data.items.map { Item(type: $0.0, x: $0.1, y: $0.2) }
    }

    func update(deltaTime: Double, input: InputManager.InputState) {
        guard state == .playing else { return }
        elapsedTime += deltaTime
        firedWeaponThisFrame = nil
        doorOpenedThisFrame = false
        enemyAlertedThisFrame = false
        enemyHurtThisFrame = false
        enemyAttackedThisFrame = nil
        spawnInvincibilityTimer = max(0, spawnInvincibilityTimer - deltaTime)

        // Player movement
        player.rotate(by: input.turn)
        player.move(
            forward: input.forward,
            strafe: input.strafe,
            deltaTime: deltaTime,
            world: world,
            sprint: input.sprint
        )

        // Shooting
        if input.shoot {
            firePlayerWeapon()
        }

        // Weapon switch
        if let switchTo = input.weaponSwitch {
            let types: [WeaponType] = [.fist, .pistol, .shotgun, .chaingun]
            if switchTo >= 1 && switchTo <= types.count {
                player.switchWeapon(to: types[switchTo - 1])
            }
        }

        // Interaction (doors)
        if input.interact {
            tryInteract()
        }

        // Update weapon animation
        player.weaponState.update(deltaTime: deltaTime)

        // Update enemies
        let invincible = spawnInvincibilityTimer > 0
        for i in enemies.indices {
            // During spawn invincibility, enemies don't react to the player
            if invincible {
                // Only update animation timers, no AI
                enemies[i].animationTimer += deltaTime
            } else {
                let wasIdle: Bool
                if case .idle = enemies[i].state { wasIdle = true }
                else if case .patrolling = enemies[i].state { wasIdle = true }
                else { wasIdle = false }
                
                enemies[i].update(deltaTime: deltaTime, playerX: player.x, playerY: player.y, world: world)
                
                if wasIdle, case .chasing = enemies[i].state {
                    enemyAlertedThisFrame = true
                }
            }

            // Check if enemy is attacking and should deal damage
            if case .attacking = enemies[i].state {
                // Deal damage once per attack, at the midpoint of the animation
                if !enemies[i].hasDealtDamageThisAttack && enemies[i].animationTimer >= 0.15 {
                    enemies[i].hasDealtDamageThisAttack = true
                    enemyAttackedThisFrame = enemies[i].type

                    let dx = enemies[i].x - player.x
                    let dy = enemies[i].y - player.y
                    let dist = sqrt(dx * dx + dy * dy)

                    let dmgMult = GameConstants.difficultyDamageMultiplier(for: currentLevel)
                    let spdMult = GameConstants.difficultySpeedMultiplier(for: currentLevel)
                    let scaledDamage = Int(Double(enemies[i].type.damage) * dmgMult)

                    if enemies[i].type.isRanged {
                        // Spawn a visible projectile aimed at the player
                        let pdx = player.x - enemies[i].x
                        let pdy = player.y - enemies[i].y
                        let pdist = sqrt(pdx * pdx + pdy * pdy)
                        guard pdist > 0.1 else { continue }
                        let pDirX = pdx / pdist
                        let pDirY = pdy / pdist
                        let projType: ProjectileType = enemies[i].type == .imp ? .fireball : .bullet
                        let projSpeed: Double = (enemies[i].type == .imp ? 5.0 : 10.0) * spdMult
                        projectiles.append(Projectile(
                            x: enemies[i].x + pDirX * 0.5,
                            y: enemies[i].y + pDirY * 0.5,
                            dirX: pDirX, dirY: pDirY,
                            speed: projSpeed,
                            damage: scaledDamage,
                            isEnemy: true,
                            type: projType
                        ))
                    } else {
                        if dist <= enemies[i].type.attackRange {
                            player.takeDamage(scaledDamage)
                            damageFlashTimer = 0.3
                            lastDamageDirection = atan2(dy, dx)
                            screenShakeIntensity = min(1.0, Double(enemies[i].type.damage) / 30.0)
                            screenShakeTimer = 0.3
                        }
                    }
                }
            }
        }

        // Separate enemies from each other and player from enemies
        separateEnemies()
        separatePlayerFromEnemies()

        // Update projectiles
        updateProjectiles(deltaTime: deltaTime)

        // Update items
        for i in items.indices {
            items[i].update(deltaTime: deltaTime)
        }
        checkItemPickups()

        // Damage floor check
        let playerTile = world.tileAt(x: Int(player.x), y: Int(player.y))
        if playerTile == .damageFloor {
            let dmg = Int(5.0 * deltaTime)
            if dmg > 0 {
                player.takeDamage(dmg)
                damageFlashTimer = max(damageFlashTimer, 0.1)
            }
        }

        // Explore tiles around player
        updateExploredTiles()

        // Update doors
        updateDoors(deltaTime: deltaTime)

        // Update flash timers
        damageFlashTimer = max(0, damageFlashTimer - deltaTime)
        pickupFlashTimer = max(0, pickupFlashTimer - deltaTime)
        hitMarkerTimer = max(0, hitMarkerTimer - deltaTime)
        muzzleFlashTimer = max(0, muzzleFlashTimer - deltaTime)
        statusMessageTimer = max(0, statusMessageTimer - deltaTime)
        levelNameTimer = max(0, levelNameTimer - deltaTime)
        if player.berserkTimer > 0 {
            player.berserkTimer -= deltaTime
        }

        // Screen shake decay
        if screenShakeTimer > 0 {
            screenShakeTimer -= deltaTime
            if screenShakeTimer <= 0 {
                screenShakeIntensity = 0
            }
        }

        // Check death — start death animation
        if player.isDead && !deathAnimStarted {
            deathAnimStarted = true
            deathAnimTimer = 0.8
        }
        if deathAnimStarted {
            deathAnimTimer -= deltaTime
            if deathAnimTimer <= 0 {
                state = .dead
                deathAnimStarted = false
            }
        }

        // Victory is triggered by reaching the exit portal (see tryInteract)
    }

    // MARK: - Weapon Firing

    private func firePlayerWeapon() {
        guard player.weaponState.canFire else { return }
        let def = player.weaponState.definition

        // Check ammo
        if let ammoType = def.ammoType {
            let ammoCount = player.ammo[ammoType] ?? 0
            guard ammoCount >= def.ammoPerShot else { return }
            player.ammo[ammoType] = ammoCount - def.ammoPerShot
        }

        guard player.weaponState.fire() else { return }
        firedWeaponThisFrame = def.type
        muzzleFlashTimer = 0.05
        // Shotgun kick
        if def.type == .shotgun {
            screenShakeIntensity = 0.4
            screenShakeTimer = 0.15
        }

        // Berserk multiplier for fist
        let damageMult = (player.isBerserk && def.type == .fist) ? 10 : 1

        // Cast rays for each pellet
        for _ in 0..<def.pellets {
            let spread = Double.random(in: -def.spread...def.spread)
            let rayAngle = player.angle + spread
            let rayDirX = cos(rayAngle)
            let rayDirY = sin(rayAngle)

            if let (enemyIdx, _) = castAttackRay(fromX: player.x, fromY: player.y, dirX: rayDirX, dirY: rayDirY, range: def.range) {
                let wasAlive = !enemies[enemyIdx].isDead && !enemies[enemyIdx].isDying && enemies[enemyIdx].health > 0
                enemies[enemyIdx].takeDamage(def.damage * damageMult)
                hitMarkerTimer = 0.15
                if wasAlive && enemies[enemyIdx].health <= 0 {
                    killCount += 1
                    // 30% chance to drop health or ammo
                    if Double.random(in: 0...1) < 0.3 {
                        let dropType: ItemType = Bool.random() ?
                            .healthPack(amount: 10) : .ammoBullets(amount: 10)
                        items.append(Item(type: dropType, x: enemies[enemyIdx].x, y: enemies[enemyIdx].y))
                    }
                } else if wasAlive && enemies[enemyIdx].health > 0 {
                    enemyHurtThisFrame = true
                }
                // Alert nearby enemies
                alertNearbyEnemies(x: enemies[enemyIdx].x, y: enemies[enemyIdx].y, radius: 10)
            }
        }

        // Gunshot alerts nearby enemies
        alertNearbyEnemies(x: player.x, y: player.y, radius: 15)
    }

    private func castAttackRay(fromX: Double, fromY: Double, dirX: Double, dirY: Double, range: Double) -> (Int, Double)? {
        var closestEnemy: Int?
        var closestDist = range

        for i in enemies.indices {
            if enemies[i].isDead || enemies[i].isDying { continue }

            let ex = enemies[i].x - fromX
            let ey = enemies[i].y - fromY

            // Project enemy onto ray
            let dot = ex * dirX + ey * dirY
            guard dot > 0 && dot < closestDist else { continue }

            // Perpendicular distance from ray
            let perpDist = abs(ex * (-dirY) + ey * dirX)
            let hitRadius = 0.4

            guard perpDist < hitRadius else { continue }

            // Check if wall blocks the shot
            if !isLineOfSightClear(fromX: fromX, fromY: fromY, toX: enemies[i].x, toY: enemies[i].y) {
                continue
            }

            closestDist = dot
            closestEnemy = i
        }

        if let idx = closestEnemy {
            return (idx, closestDist)
        }
        return nil
    }

    private func isLineOfSightClear(fromX: Double, fromY: Double, toX: Double, toY: Double) -> Bool {
        let dx = toX - fromX
        let dy = toY - fromY
        let dist = sqrt(dx * dx + dy * dy)
        let steps = Int(dist * 4)
        guard steps > 0 else { return true }

        for i in 1..<steps {
            let t = Double(i) / Double(steps)
            let checkX = fromX + dx * t
            let checkY = fromY + dy * t
            if world.isSolid(x: Int(checkX), y: Int(checkY)) {
                return false
            }
        }
        return true
    }

    private func alertNearbyEnemies(x: Double, y: Double, radius: Double) {
        for i in enemies.indices {
            if enemies[i].isDead || enemies[i].isDying { continue }
            if case .chasing = enemies[i].state { continue }
            if case .attacking = enemies[i].state { continue }

            let dx = enemies[i].x - x
            let dy = enemies[i].y - y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < radius {
                enemies[i].state = .chasing
                enemyAlertedThisFrame = true
            }
        }
    }

    // MARK: - Player-Enemy Separation

    private func separatePlayerFromEnemies() {
        let separationDist = 0.5  // Minimum distance between player and enemy
        let radius = GameConstants.playerRadius

        for enemy in enemies {
            if enemy.isDead { continue }
            let dx = player.x - enemy.x
            let dy = player.y - enemy.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist < separationDist && dist > 0.01 {
                // Push player away from enemy
                let pushDist = (separationDist - dist) * 0.5
                let pushX = (dx / dist) * pushDist
                let pushY = (dy / dist) * pushDist

                let newX = player.x + pushX
                if world.isPassable(x: newX, y: player.y, radius: radius) {
                    player.x = newX
                }
                let newY = player.y + pushY
                if world.isPassable(x: player.x, y: newY, radius: radius) {
                    player.y = newY
                }
            }
        }
    }

    // MARK: - Enemy-Enemy Separation

    private func separateEnemies() {
        let minDist = 0.8
        let enemyRadius = 0.25
        for i in 0..<enemies.count {
            if enemies[i].isDead { continue }
            for j in (i + 1)..<enemies.count {
                if enemies[j].isDead { continue }
                let dx = enemies[i].x - enemies[j].x
                let dy = enemies[i].y - enemies[j].y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < minDist && dist > 0.01 {
                    let pushDist = (minDist - dist) * 0.5
                    let nx = dx / dist
                    let ny = dy / dist
                    let pushX = nx * pushDist
                    let pushY = ny * pushDist

                    // Push enemy i away
                    let newIX = enemies[i].x + pushX
                    if world.isPassable(x: newIX, y: enemies[i].y, radius: enemyRadius) {
                        enemies[i].x = newIX
                    }
                    let newIY = enemies[i].y + pushY
                    if world.isPassable(x: enemies[i].x, y: newIY, radius: enemyRadius) {
                        enemies[i].y = newIY
                    }

                    // Push enemy j the other way
                    let newJX = enemies[j].x - pushX
                    if world.isPassable(x: newJX, y: enemies[j].y, radius: enemyRadius) {
                        enemies[j].x = newJX
                    }
                    let newJY = enemies[j].y - pushY
                    if world.isPassable(x: enemies[j].x, y: newJY, radius: enemyRadius) {
                        enemies[j].y = newJY
                    }
                }
            }
        }
    }

    // MARK: - Interaction

    private func tryInteract() {
        let maxDist = 2.0
        let stepSize = 0.5
        var dist = stepSize
        var checkedTiles = Set<Int>()
        
        while dist <= maxDist {
            let checkX = player.x + player.dirX * dist
            let checkY = player.y + player.dirY * dist
            let tileX = Int(checkX)
            let tileY = Int(checkY)
            let tileKey = tileY * world.width + tileX
            
            if !checkedTiles.contains(tileKey) {
                checkedTiles.insert(tileKey)
                
                let tile = world.tileAt(x: tileX, y: tileY)
                
                if tile.isDoor {
                    // Check if locked door requires a key
                    if tile == .lockedDoorRed && !player.keys.contains(.red) {
                        statusMessage = "YOU NEED THE RED KEY"
                        statusMessageTimer = 2.0
                        return
                    }
                    if tile == .lockedDoorBlue && !player.keys.contains(.blue) {
                        statusMessage = "YOU NEED THE BLUE KEY"
                        statusMessageTimer = 2.0
                        return
                    }
                    if tile == .lockedDoorYellow && !player.keys.contains(.yellow) {
                        statusMessage = "YOU NEED THE YELLOW KEY"
                        statusMessageTimer = 2.0
                        return
                    }

                    if let doorIdx = world.doorAt(x: tileX, y: tileY) {
                        if !world.doors[doorIdx].isFullyOpen && !world.doors[doorIdx].isOpening {
                            world.doors[doorIdx].isOpening = true
                            world.doors[doorIdx].isClosing = false
                            doorOpenedThisFrame = true
                        }
                    }
                    return
                }
                
                if tile == .exitPortal {
                    if !missionObjectiveComplete {
                        switch currentLevel {
                        case 1:
                            statusMessage = "RETRIEVE THE INTEL DATA FIRST"
                        case 2:
                            statusMessage = "FIND THE DEMONIC ARTIFACT FIRST"
                        case 3:
                            let remaining = enemies.filter { $0.type == .demon && !$0.isDead }.count
                            statusMessage = "DEMONS REMAIN: \(remaining)"
                        default:
                            statusMessage = "OBJECTIVE INCOMPLETE"
                        }
                        statusMessageTimer = 2.0
                        return
                    }
                    state = .levelComplete
                    return
                }
                
                // Stop if we hit a solid wall
                if tile != .empty {
                    return
                }
            }
            
            dist += stepSize
        }
    }

    // MARK: - Projectiles

    private func updateProjectiles(deltaTime: Double) {
        projectiles.removeAll(where: { $0.lifetime <= 0 })

        for i in projectiles.indices {
            projectiles[i].x += projectiles[i].dirX * projectiles[i].speed * deltaTime
            projectiles[i].y += projectiles[i].dirY * projectiles[i].speed * deltaTime
            projectiles[i].lifetime -= deltaTime

            let tileX = Int(projectiles[i].x)
            let tileY = Int(projectiles[i].y)
            if world.isSolid(x: tileX, y: tileY) {
                projectiles[i].lifetime = 0
                continue
            }

            if projectiles[i].isEnemy && spawnInvincibilityTimer <= 0 {
                let dx = projectiles[i].x - player.x
                let dy = projectiles[i].y - player.y
                if sqrt(dx * dx + dy * dy) < 0.5 {
                    player.takeDamage(projectiles[i].damage)
                    damageFlashTimer = 0.3
                    lastDamageDirection = atan2(dy, dx)
                    screenShakeIntensity = min(1.0, Double(projectiles[i].damage) / 30.0)
                    screenShakeTimer = 0.3
                    projectiles[i].lifetime = 0
                }
            }
        }
    }

    // MARK: - Items

    private func checkItemPickups() {
        for i in items.indices {
            guard items[i].canPickUp(playerX: player.x, playerY: player.y) else { continue }

            var picked = false
            var message = ""
            switch items[i].type {
            case .healthPack(let amount):
                if player.health < GameConstants.maxHealth {
                    player.heal(amount)
                    picked = true
                    message = "PICKED UP A MEDKIT"
                }
            case .armorVest(let amount):
                if player.armor < GameConstants.maxArmor {
                    player.addArmor(amount)
                    picked = true
                    message = "PICKED UP ARMOR"
                }
            case .ammoBullets(let amount):
                let cap = GameConstants.maxBullets
                let current = player.ammo[.bullets, default: 0]
                guard current < cap else { continue }
                player.ammo[.bullets] = min(cap, current + amount)
                picked = true
                message = "PICKED UP BULLETS"
            case .ammoShells(let amount):
                let cap = GameConstants.maxShells
                let current = player.ammo[.shells, default: 0]
                guard current < cap else { continue }
                player.ammo[.shells] = min(cap, current + amount)
                picked = true
                message = "PICKED UP SHELLS"
            case .shotgunPickup:
                player.weapons.insert(.shotgun)
                player.ammo[.shells] = min(GameConstants.maxShells, player.ammo[.shells, default: 0] + 8)
                player.switchWeapon(to: .shotgun)
                picked = true
                message = "PICKED UP A SHOTGUN!"
            case .chaingunPickup:
                player.weapons.insert(.chaingun)
                player.ammo[.bullets] = min(GameConstants.maxBullets, player.ammo[.bullets, default: 0] + 40)
                player.switchWeapon(to: .chaingun)
                picked = true
                message = "PICKED UP A CHAINGUN!"
            case .keyCard(let color):
                player.keys.insert(color)
                picked = true
                switch color {
                case .red: message = "PICKED UP THE RED KEY"
                case .blue: message = "PICKED UP THE BLUE KEY"
                case .yellow: message = "PICKED UP THE YELLOW KEY"
                }
            case .berserkPack:
                player.berserkTimer = 30.0
                player.heal(100)
                player.switchWeapon(to: .fist)
                picked = true
                message = "BERSERK!"
            case .intelData:
                picked = true
                message = "RETRIEVED INTEL DATA"
            case .demonicArtifact:
                picked = true
                message = "RETRIEVED DEMONIC ARTIFACT"
            }

            if picked {
                items[i].isCollected = true
                pickupFlashTimer = 0.2
                if !message.isEmpty {
                    statusMessage = message
                    statusMessageTimer = 1.5
                }
            }
        }
    }

    // MARK: - Mission Objectives

    /// Whether the current level's mission objective is complete
    var missionObjectiveComplete: Bool {
        switch currentLevel {
        case 1:
            // Level 1: Collect Intel Data
            return items.contains { if case .intelData = $0.type { return $0.isCollected } else { return false } }
        case 2:
            // Level 2: Retrieve Demonic Artifact
            return items.contains { if case .demonicArtifact = $0.type { return $0.isCollected } else { return false } }
        case 3:
            // Level 3: Exterminate all Demons
            return enemies.filter { $0.type == .demon }.allSatisfy { $0.isDead }
        default:
            return true
        }
    }

    /// Description of the current objective for HUD display
    var objectiveText: String {
        switch currentLevel {
        case 1: return "RETRIEVE INTEL DATA"
        case 2: return "FIND DEMONIC ARTIFACT"
        case 3:
            let remaining = enemies.filter { $0.type == .demon && !$0.isDead }.count
            if remaining > 0 {
                return "EXTERMINATE DEMONS: \(remaining) LEFT"
            }
            return "EXTERMINATE DEMONS"
        default: return ""
        }
    }

    // MARK: - Fog of War

    /// Percentage of walkable tiles the player has explored (0-100)
    var explorationPercentage: Int {
        var walkable = 0
        for y in 0..<world.height {
            for x in 0..<world.width {
                let tile = world.tileAt(x: x, y: y)
                if !tile.isWall { walkable += 1 }
            }
        }
        guard walkable > 0 else { return 100 }
        let explored = exploredTiles.filter { key in
            let x = key % world.width
            let y = key / world.width
            return !world.tileAt(x: x, y: y).isWall
        }.count
        return min(100, explored * 100 / walkable)
    }

    private func updateExploredTiles() {
        let px = Int(player.x)
        let py = Int(player.y)
        let radius = 5
        for ty in max(0, py - radius)...min(world.height - 1, py + radius) {
            for tx in max(0, px - radius)...min(world.width - 1, px + radius) {
                let dx = tx - px
                let dy = ty - py
                if dx * dx + dy * dy <= radius * radius {
                    exploredTiles.insert(ty * world.width + tx)
                }
            }
        }
    }

    // MARK: - Doors

    private func updateDoors(deltaTime: Double) {
        for i in world.doors.indices {
            if world.doors[i].isOpening {
                world.doors[i].openAmount += world.doors[i].openSpeed * deltaTime
                if world.doors[i].openAmount >= 1.0 {
                    world.doors[i].openAmount = 1.0
                    world.doors[i].isOpening = false
                    world.doors[i].stayOpenTimer = world.doors[i].stayOpenDuration
                }
            } else if world.doors[i].stayOpenTimer > 0 {
                world.doors[i].stayOpenTimer -= deltaTime
                if world.doors[i].stayOpenTimer <= 0 {
                    world.doors[i].isClosing = true
                }
            } else if world.doors[i].isClosing {
                // Check if player's bounding box overlaps the door tile
                let doorX = world.doors[i].tileX
                let doorY = world.doors[i].tileY
                let r = GameConstants.playerRadius
                let playerMinX = Int(player.x - r)
                let playerMaxX = Int(player.x + r)
                let playerMinY = Int(player.y - r)
                let playerMaxY = Int(player.y + r)
                let playerInDoor = (playerMinX <= doorX && playerMaxX >= doorX &&
                                    playerMinY <= doorY && playerMaxY >= doorY)
                if playerInDoor {
                    // Don't close on player
                    world.doors[i].stayOpenTimer = 1.0
                    world.doors[i].isClosing = false
                    continue
                }

                world.doors[i].openAmount -= world.doors[i].openSpeed * deltaTime
                if world.doors[i].openAmount <= 0 {
                    world.doors[i].openAmount = 0
                    world.doors[i].isClosing = false
                }
            }
        }
    }
}
