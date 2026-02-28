//
//  GameEngine.swift
//  testproject
//

import Foundation

enum GameStateType {
    case menu
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
    /// Set to the weapon type that fired this frame (nil if nothing fired)
    var firedWeaponThisFrame: WeaponType?

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
        spawnInvincibilityTimer = 1.5
        spawnEntities()
        totalEnemies = enemies.count
    }

    private func spawnEntities() {
        let data = GameWorld.levelData(for: currentLevel)
        enemies = data.enemies.map { Enemy(type: $0.0, x: $0.1, y: $0.2) }
        items = data.items.map { Item(type: $0.0, x: $0.1, y: $0.2) }
    }

    func update(deltaTime: Double, input: InputManager.InputState) {
        guard state == .playing else { return }
        elapsedTime += deltaTime
        firedWeaponThisFrame = nil
        spawnInvincibilityTimer = max(0, spawnInvincibilityTimer - deltaTime)

        // Player movement
        let speedMult = input.sprint ? 1.6 : 1.0
        player.rotate(by: input.turn)
        player.move(
            forward: input.forward * speedMult,
            strafe: input.strafe * speedMult,
            deltaTime: deltaTime,
            world: world
        )

        // Shooting
        if input.shoot {
            firePlayerWeapon()
        }

        // Weapon switch
        if let switchTo = input.weaponSwitch {
            let types: [WeaponType] = [.fist, .pistol, .shotgun]
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
                enemies[i].update(deltaTime: deltaTime, playerX: player.x, playerY: player.y, world: world)
            }

            // Check if enemy is attacking and should deal damage
            if case .attacking = enemies[i].state {
                // Deal damage once per attack, at the midpoint of the animation
                if !enemies[i].hasDealtDamageThisAttack && enemies[i].animationTimer >= 0.15 {
                    enemies[i].hasDealtDamageThisAttack = true

                    let dx = enemies[i].x - player.x
                    let dy = enemies[i].y - player.y
                    let dist = sqrt(dx * dx + dy * dy)

                    if enemies[i].type.isRanged {
                        // Spawn a visible projectile aimed at the player
                        let pdx = player.x - enemies[i].x
                        let pdy = player.y - enemies[i].y
                        let pdist = sqrt(pdx * pdx + pdy * pdy)
                        guard pdist > 0.1 else { continue }
                        let pDirX = pdx / pdist
                        let pDirY = pdy / pdist
                        let projType: ProjectileType = enemies[i].type == .imp ? .fireball : .bullet
                        let projSpeed: Double = enemies[i].type == .imp ? 5.0 : 10.0
                        projectiles.append(Projectile(
                            x: enemies[i].x + pDirX * 0.5,
                            y: enemies[i].y + pDirY * 0.5,
                            dirX: pDirX, dirY: pDirY,
                            speed: projSpeed,
                            damage: enemies[i].type.damage,
                            isEnemy: true,
                            type: projType
                        ))
                    } else {
                        if dist <= enemies[i].type.attackRange {
                            player.takeDamage(enemies[i].type.damage)
                            damageFlashTimer = 0.3
                            lastDamageDirection = atan2(dy, dx)
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

        // Update doors
        updateDoors(deltaTime: deltaTime)

        // Update flash timers
        damageFlashTimer = max(0, damageFlashTimer - deltaTime)
        pickupFlashTimer = max(0, pickupFlashTimer - deltaTime)
        hitMarkerTimer = max(0, hitMarkerTimer - deltaTime)

        // Check death
        if player.isDead {
            state = .dead
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

        // Cast rays for each pellet
        for _ in 0..<def.pellets {
            let spread = Double.random(in: -def.spread...def.spread)
            let rayAngle = player.angle + spread
            let rayDirX = cos(rayAngle)
            let rayDirY = sin(rayAngle)

            if let (enemyIdx, _) = castAttackRay(fromX: player.x, fromY: player.y, dirX: rayDirX, dirY: rayDirY, range: def.range) {
                let wasAlive = !enemies[enemyIdx].isDead && !enemies[enemyIdx].isDying && enemies[enemyIdx].health > 0
                enemies[enemyIdx].takeDamage(def.damage)
                hitMarkerTimer = 0.15
                if wasAlive && enemies[enemyIdx].health <= 0 {
                    killCount += 1
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
                
                if tile == .door {
                    for i in world.doors.indices {
                        if world.doors[i].tileX == tileX && world.doors[i].tileY == tileY {
                            if !world.doors[i].isFullyOpen && !world.doors[i].isOpening {
                                world.doors[i].isOpening = true
                                world.doors[i].isClosing = false
                            }
                        }
                    }
                    return
                }
                
                if tile == .exitPortal {
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
        projectiles = projectiles.filter { $0.lifetime > 0 }

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
            switch items[i].type {
            case .healthPack(let amount):
                if player.health < GameConstants.maxHealth {
                    player.heal(amount)
                    picked = true
                }
            case .armorVest(let amount):
                if player.armor < GameConstants.maxArmor {
                    player.addArmor(amount)
                    picked = true
                }
            case .ammoBullets(let amount):
                player.ammo[.bullets, default: 0] += amount
                picked = true
            case .ammoShells(let amount):
                player.ammo[.shells, default: 0] += amount
                picked = true
            case .shotgunPickup:
                player.weapons.insert(.shotgun)
                player.ammo[.shells, default: 0] += 8
                player.switchWeapon(to: .shotgun)
                picked = true
            }

            if picked {
                items[i].isCollected = true
                pickupFlashTimer = 0.2
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
