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
    case campaignComplete
}

enum ProjectileType {
    case fireball  // Imp — slow, glowing orange
    case bullet    // Soldier — fast, bright tracer
    case plasma    // Baron — green hellfire

    /// Frame in the projectile sprite sheet
    var spriteFrame: Int {
        switch self {
        case .fireball: return 0
        case .bullet: return 1
        case .plasma: return 2
        }
    }
}

/// Name and health of the boss the player is fighting, for the HUD bar
struct BossStatus {
    let name: String
    let health: Int
    let maxHealth: Int
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

/// Score card for one finished level, kept for the end-of-campaign summary
struct LevelResult {
    let level: Int
    let title: String
    let kills: Int
    let totalEnemies: Int
    let time: Double
}

final class GameEngine {
    var state: GameStateType = .menu
    var world: GameWorld
    var player: Player
    var enemies: [Enemy]
    var items: [Item]
    var projectiles: [Projectile] = []
    /// Static data of the loaded level: layout, spawns and mission objective
    private(set) var levelData: GameWorld.LevelData
    /// Tile-distance field from the player, rebuilt every frame for enemy pathfinding
    private var navField: NavigationField

    var killCount: Int = 0
    var totalEnemies: Int = 0
    var elapsedTime: Double = 0
    var currentLevel: Int = 1
    /// Results of every level finished in the current campaign run
    private(set) var levelResults: [LevelResult] = []

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
    /// Accumulates time spent standing in nukage; damage lands every damageFloorInterval
    private var damageFloorTimer: Double = 0
    var statusMessage: String = ""
    var statusMessageTimer: Double = 0
    var levelNameTimer: Double = 3.0
    var exploredTiles: Set<Int> = []
    /// Set to the weapon type that fired this frame (nil if nothing fired)
    var firedWeaponThisFrame: WeaponType?
    /// Audio event flags — reset each frame, checked by GameViewModel for sound triggers
    var doorOpenedThisFrame: Bool = false
    var enemyAlertedThisFrame: Bool = false
    /// A boss noticed the player this frame (plays the roar)
    var bossAlertedThisFrame: Bool = false
    var enemyHurtThisFrame: Bool = false
    var enemyAttackedThisFrame: EnemyType? = nil

    init() {
        let data = GameWorld.levelData(for: 1)
        let newWorld = GameWorld.createLevel(1)
        levelData = data
        world = newWorld
        navField = NavigationField(width: newWorld.width, height: newWorld.height)
        player = Player(x: data.playerStartX, y: data.playerStartY, angle: data.playerStartAngle)
        enemies = []
        items = []
        currentLevel = 1
        spawnEntities()
        totalEnemies = enemies.count
        spawnInvincibilityTimer = 1.5
    }

    /// Whether the loaded level is the last one of the campaign
    var isFinalLevel: Bool { currentLevel >= GameWorld.maxLevel }

    /// Reload the current level after death (pistol start, like DOOM)
    func restartLevel() {
        loadLevel(currentLevel)
        state = .playing
    }

    /// Reset everything back to level 1 and hand control to the title screen
    func resetToMenu() {
        currentLevel = 1
        levelResults = []
        loadLevel(1)
        state = .menu
    }

    func nextLevel() {
        guard !isFinalLevel else { return }
        currentLevel += 1
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
        levelData = data
        world = GameWorld.createLevel(level)
        navField = NavigationField(width: world.width, height: world.height)
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
        damageFloorTimer = 0
        statusMessage = ""
        statusMessageTimer = 0
        levelNameTimer = 3.0
        exploredTiles = []
        spawnInvincibilityTimer = 1.5
        spawnEntities()
        totalEnemies = enemies.count
    }

    private func spawnEntities() {
        let healthMult = GameConstants.difficultyHealthMultiplier(for: currentLevel)
        enemies = levelData.enemies.map {
            var e = Enemy(type: $0.0, x: $0.1, y: $0.2)
            e.health = Int(Double(e.health) * healthMult)
            e.maxHealth = e.health
            return e
        }
        items = levelData.items.map { Item(type: $0.0, x: $0.1, y: $0.2) }
    }

    func update(deltaTime: Double, input: InputManager.InputState) {
        guard state == .playing else { return }
        elapsedTime += deltaTime
        firedWeaponThisFrame = nil
        doorOpenedThisFrame = false
        enemyAlertedThisFrame = false
        bossAlertedThisFrame = false
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

        // Distance field from the player's tile, so enemies can hunt without line of sight
        navField.rebuild(world: world, goalX: Int(player.x), goalY: Int(player.y))

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

                enemies[i].update(deltaTime: deltaTime, playerX: player.x, playerY: player.y, world: world, nav: navField)

                if wasIdle, case .chasing = enemies[i].state {
                    enemyAlertedThisFrame = true
                    if enemies[i].type.isBoss { bossAlertedThisFrame = true }
                }

                // Enemies can open unlocked doors that block their way
                if let request = enemies[i].doorRequest {
                    enemies[i].doorRequest = nil
                    openDoorForEnemy(x: request.x, y: request.y)
                }
            }

            // Check if enemy is attacking and should deal damage
            if case .attacking = enemies[i].state {
                // Deal damage once per attack, partway through the animation
                let type = enemies[i].type
                if !enemies[i].hasDealtDamageThisAttack && enemies[i].animationTimer >= type.attackHitTime {
                    enemies[i].hasDealtDamageThisAttack = true
                    enemyAttackedThisFrame = type

                    let dx = enemies[i].x - player.x
                    let dy = enemies[i].y - player.y
                    let dist = sqrt(dx * dx + dy * dy)

                    let dmgMult = GameConstants.difficultyDamageMultiplier(for: currentLevel)
                    let spdMult = GameConstants.difficultySpeedMultiplier(for: currentLevel)

                    // Melee-only enemies always swing; bosses claw when close, throw plasma otherwise
                    let useMelee = !type.isRanged || (type.hasMeleeAttack && dist <= type.meleeRange)
                    if useMelee {
                        let reach = type.isRanged ? type.meleeRange : type.attackRange
                        if dist <= reach {
                            let scaledDamage = Int(Double(type.damage) * dmgMult)
                            player.takeDamage(scaledDamage)
                            damageFlashTimer = 0.3
                            lastDamageDirection = atan2(dy, dx)
                            screenShakeIntensity = min(1.0, Double(type.damage) / 30.0)
                            screenShakeTimer = 0.3
                        }
                    } else {
                        // Spawn a visible projectile aimed at the player
                        let pdx = player.x - enemies[i].x
                        let pdy = player.y - enemies[i].y
                        let pdist = sqrt(pdx * pdx + pdy * pdy)
                        guard pdist > 0.1 else { continue }
                        let pDirX = pdx / pdist
                        let pDirY = pdy / pdist
                        projectiles.append(Projectile(
                            x: enemies[i].x + pDirX * 0.5,
                            y: enemies[i].y + pDirY * 0.5,
                            dirX: pDirX, dirY: pDirY,
                            speed: type.projectileSpeed * spdMult,
                            damage: Int(Double(type.projectileDamage) * dmgMult),
                            isEnemy: true,
                            type: type.projectileType
                        ))
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

        // Damage floor: periodic ticks while standing in nukage
        updateDamageFloor(deltaTime: deltaTime)

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

    // MARK: - Hazards

    private func updateDamageFloor(deltaTime: Double) {
        let playerTile = world.tileAt(x: Int(player.x), y: Int(player.y))
        guard playerTile == .damageFloor, spawnInvincibilityTimer <= 0, !player.isDead else {
            damageFloorTimer = 0
            return
        }
        damageFloorTimer += deltaTime
        if damageFloorTimer >= GameConstants.damageFloorInterval {
            damageFloorTimer -= GameConstants.damageFloorInterval
            player.takeDamage(GameConstants.damageFloorDamage)
            damageFlashTimer = max(damageFlashTimer, 0.2)
            // Flash from the bottom edge: the hurt comes from underfoot
            lastDamageDirection = player.angle + .pi
        }
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
                let wasAlive = enemies[enemyIdx].isAlive
                let wasDormant = isDormant(enemies[enemyIdx])
                enemies[enemyIdx].takeDamage(def.damage * damageMult)
                hitMarkerTimer = 0.15
                if wasDormant && enemies[enemyIdx].type.isBoss && !isDormant(enemies[enemyIdx]) {
                    bossAlertedThisFrame = true
                }
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
            if !enemies[i].isAlive { continue }

            let ex = enemies[i].x - fromX
            let ey = enemies[i].y - fromY

            // Project enemy onto ray
            let dot = ex * dirX + ey * dirY
            guard dot > 0 && dot < closestDist else { continue }

            // Perpendicular distance from ray
            let perpDist = abs(ex * (-dirY) + ey * dirX)
            let hitRadius = enemies[i].type.hitRadius

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
        guard steps > 1 else { return true }

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
            if !enemies[i].isAlive { continue }
            if case .chasing = enemies[i].state { continue }
            if case .attacking = enemies[i].state { continue }

            let dx = enemies[i].x - x
            let dy = enemies[i].y - y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < radius {
                enemies[i].patrolTarget = nil
                enemies[i].state = .chasing
                enemyAlertedThisFrame = true
                if enemies[i].type.isBoss { bossAlertedThisFrame = true }
            }
        }
    }

    /// Idle or patrolling: the enemy has not noticed the player yet
    private func isDormant(_ enemy: Enemy) -> Bool {
        switch enemy.state {
        case .idle, .patrolling: return true
        default: return false
        }
    }

    /// The boss currently engaged with the player, if any (dormant bosses stay hidden)
    var activeBoss: BossStatus? {
        for enemy in enemies where enemy.type.isBoss && enemy.isAlive && !isDormant(enemy) {
            return BossStatus(name: enemy.type.displayName, health: enemy.health, maxHealth: enemy.maxHealth)
        }
        return nil
    }

    // MARK: - Player-Enemy Separation

    private func separatePlayerFromEnemies() {
        let separationDist = 0.5  // Minimum distance between player and enemy
        let radius = GameConstants.playerRadius

        for enemy in enemies {
            // Corpses (dying or dead) are not solid
            if !enemy.isAlive { continue }
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
            if !enemies[i].isAlive { continue }
            for j in (i + 1)..<enemies.count {
                if !enemies[j].isAlive { continue }
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
                        statusMessage = objectiveIncompleteMessage
                        statusMessageTimer = 2.0
                        return
                    }
                    completeLevel()
                    return
                }

                // Stop if we hit a solid wall (hazard floors don't block the interaction ray)
                if tile.isWall {
                    return
                }
            }

            dist += stepSize
        }
    }

    private func completeLevel() {
        let title = GameWorld.briefingText(for: currentLevel).title
        levelResults.append(LevelResult(
            level: currentLevel,
            title: title,
            kills: killCount,
            totalEnemies: totalEnemies,
            time: elapsedTime
        ))
        state = .levelComplete
    }

    /// Enemies open unlocked doors that block their path (locked doors stay shut for them)
    private func openDoorForEnemy(x: Int, y: Int) {
        guard world.tileAt(x: x, y: y) == .door, let doorIdx = world.doorAt(x: x, y: y) else { return }
        if !world.doors[doorIdx].isFullyOpen && !world.doors[doorIdx].isOpening {
            world.doors[doorIdx].isOpening = true
            world.doors[doorIdx].isClosing = false
            doorOpenedThisFrame = true
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

    /// The loaded level's objective (defined in its LevelData)
    var objective: MissionObjective { levelData.objective }

    /// Living enemies the current kill objective still requires (0 for item objectives)
    var remainingObjectiveTargets: Int {
        switch levelData.objective {
        case .exterminate(let type):
            return enemies.filter { $0.type == type && $0.isAlive }.count
        case .exterminateAll:
            return enemies.filter { $0.isAlive }.count
        default:
            return 0
        }
    }

    /// Whether the current level's mission objective is complete
    var missionObjectiveComplete: Bool {
        switch levelData.objective {
        case .retrieveIntel:
            return items.contains { item in
                if case .intelData = item.type { return item.isCollected }
                return false
            }
        case .retrieveArtifact:
            return items.contains { item in
                if case .demonicArtifact = item.type { return item.isCollected }
                return false
            }
        case .exterminate, .exterminateAll:
            return remainingObjectiveTargets == 0
        case .reachExit:
            return true
        }
    }

    /// Description of the current objective for HUD display
    var objectiveText: String {
        let obj = levelData.objective
        if obj.isKillObjective {
            let remaining = remainingObjectiveTargets
            if remaining > 0 {
                return "\(obj.title): \(remaining) LEFT"
            }
        }
        return obj.title
    }

    /// Status message when the player reaches the exit before finishing the objective
    private var objectiveIncompleteMessage: String {
        let obj = levelData.objective
        if obj.isKillObjective {
            return "\(obj.incompleteMessage): \(remainingObjectiveTargets)"
        }
        return obj.incompleteMessage
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
                if isDoorwayOccupied(tileX: world.doors[i].tileX, tileY: world.doors[i].tileY) {
                    // Don't close on the player or an enemy standing in the doorway
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

    /// Whether the player's or a living enemy's bounding box overlaps the door tile
    private func isDoorwayOccupied(tileX: Int, tileY: Int) -> Bool {
        if overlapsTile(x: player.x, y: player.y, radius: GameConstants.playerRadius, tileX: tileX, tileY: tileY) {
            return true
        }
        for enemy in enemies where enemy.isAlive {
            if overlapsTile(x: enemy.x, y: enemy.y, radius: 0.25, tileX: tileX, tileY: tileY) {
                return true
            }
        }
        return false
    }

    private func overlapsTile(x: Double, y: Double, radius: Double, tileX: Int, tileY: Int) -> Bool {
        let minX = Int(x - radius)
        let maxX = Int(x + radius)
        let minY = Int(y - radius)
        let maxY = Int(y + radius)
        return minX <= tileX && maxX >= tileX && minY <= tileY && maxY >= tileY
    }
}
