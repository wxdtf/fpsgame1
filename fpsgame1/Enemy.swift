//
//  Enemy.swift
//  testproject
//

import Foundation

enum EnemyType: Int {
    case imp = 0
    case demon = 1
    case soldier = 2
    /// Boss: towering horned demon with claws and green plasma (E1M4 arena)
    case baron = 3

    var maxHealth: Int {
        switch self {
        case .imp: return 60
        case .demon: return 100
        case .soldier: return 50
        case .baron: return 500
        }
    }

    var speed: Double {
        switch self {
        case .imp: return 1.5
        case .demon: return 2.5
        case .soldier: return 1.2
        case .baron: return 1.4
        }
    }

    /// Damage of the melee attack (and of the projectile unless projectileDamage differs)
    var damage: Int {
        switch self {
        case .imp: return 10
        case .demon: return 25
        case .soldier: return 15
        case .baron: return 40
        }
    }

    var attackCooldownTime: Double {
        switch self {
        case .imp: return 1.5
        case .demon: return 0.8
        case .soldier: return 1.2
        case .baron: return 1.1
        }
    }

    var isRanged: Bool {
        switch self {
        case .imp, .soldier, .baron: return true
        case .demon: return false
        }
    }

    var attackRange: Double {
        switch self {
        case .imp: return 10.0
        case .demon: return 1.8
        case .soldier: return 12.0
        case .baron: return 11.0
        }
    }

    var sightRange: Double { GameConstants.enemySightRange }

    /// Ranged enemies that switch to a claw attack once the player is within meleeRange
    var hasMeleeAttack: Bool { self == .baron }
    var meleeRange: Double { 1.9 }

    /// Keeps walking toward the player between ranged attacks instead of standing still
    var advancesDuringCooldown: Bool { self == .baron }

    var projectileType: ProjectileType {
        switch self {
        case .imp, .demon: return .fireball
        case .soldier: return .bullet
        case .baron: return .plasma
        }
    }

    var projectileSpeed: Double {
        switch self {
        case .imp, .demon: return 5.0
        case .soldier: return 10.0
        case .baron: return 7.0
        }
    }

    var projectileDamage: Int { self == .baron ? 25 : damage }

    /// Length of the attack animation and the moment within it when damage lands
    var attackDuration: Double { self == .baron ? 0.5 : 0.3 }
    var attackHitTime: Double { self == .baron ? 0.3 : 0.15 }

    var isBoss: Bool { self == .baron }

    /// On-screen size relative to a regular enemy (feet stay on the floor)
    var spriteScale: Double { self == .baron ? 1.25 : 1.0 }

    /// Half-width of the hitbox used for the player's hitscan weapons
    var hitRadius: Double { self == .baron ? 0.55 : 0.4 }

    var displayName: String {
        switch self {
        case .imp: return "IMP"
        case .demon: return "DEMON"
        case .soldier: return "SOLDIER"
        case .baron: return "BARON OF HELL"
        }
    }

    /// Probability that a hit makes the enemy flinch. Flinching interrupts attacks and
    /// movement, so tough enemies get a low value and keep advancing under sustained
    /// fire instead of being stun-locked by the chaingun.
    var painChance: Double {
        switch self {
        case .imp: return 0.55
        case .demon: return 0.3
        case .soldier: return 0.65
        case .baron: return 0.12
        }
    }

    /// Upper-case plural for objective text, e.g. "EXTERMINATE DEMONS"
    var pluralName: String {
        switch self {
        case .imp: return "IMPS"
        case .demon: return "DEMONS"
        case .soldier: return "SOLDIERS"
        case .baron: return "BARONS"
        }
    }
}

enum AIState {
    case idle
    case patrolling
    case chasing
    case attacking
    case hurt(timer: Double)
    case dying(timer: Double)
    case dead
}

struct Enemy: Identifiable {
    let id: UUID = UUID()
    let type: EnemyType
    var x: Double
    var y: Double
    var angle: Double = 0
    var health: Int
    /// Health at spawn after difficulty scaling (for the boss health bar)
    var maxHealth: Int
    var state: AIState = .idle
    var animationFrame: Int = 0
    var animationTimer: Double = 0
    var attackCooldown: Double = 0
    var alertTimer: Double = 0
    var patrolTarget: (Double, Double)?
    var hasDealtDamageThisAttack: Bool = false
    /// Seconds until an idle enemy considers wandering to a new spot
    var idleTimer: Double = Double.random(in: 2.0...6.0)
    /// Unlocked door tile this enemy is waiting on; the engine opens it and clears the request
    var doorRequest: (x: Int, y: Int)? = nil
    /// Stuck counter — increments when enemy can't move, triggers wall-avoidance steering
    var stuckTimer: Double = 0
    var wallAvoidAngle: Double = 0

    init(type: EnemyType, x: Double, y: Double) {
        self.type = type
        self.x = x
        self.y = y
        self.health = type.maxHealth
        self.maxHealth = type.maxHealth
    }

    var isDead: Bool {
        if case .dead = state { return true }
        return false
    }

    var isDying: Bool {
        if case .dying = state { return true }
        return false
    }

    /// Still a threat: counts toward kill objectives, blocks doors and takes hits
    var isAlive: Bool { health > 0 && !isDead && !isDying }

    var spriteFrameOffset: Int {
        switch state {
        case .idle: return 0
        case .patrolling: return animationFrame % 4
        case .chasing: return animationFrame % 4
        case .attacking: return 4 + (animationFrame % 2)
        case .hurt: return 6
        case .dying(let timer):
            // 1.0s total: recoil (1.0-0.6), falling (0.6-0.3), corpse (0.3-0)
            if timer > 0.6 { return 7 }       // Recoil — staggering back
            else if timer > 0.3 { return 8 }  // Falling — body collapsing
            else { return 9 }                  // Corpse on ground
        case .dead: return 9
        }
    }

    /// Vertical offset for death animation (sprite settles toward ground)
    var deathVOffset: Double {
        switch state {
        case .dying(let timer):
            if timer > 0.6 { return 0.0 }
            else if timer > 0.3 {
                // Falling: 0.0 → 0.08 over 0.3s
                let progress = 1.0 - (timer - 0.3) / 0.3
                return progress * 0.08
            } else {
                // Settling: 0.08 → 0.12
                let progress = 1.0 - timer / 0.3
                return 0.08 + progress * 0.04
            }
        case .dead: return 0.12
        default: return 0.0
        }
    }

    mutating func update(deltaTime: Double, playerX: Double, playerY: Double, world: GameWorld, nav: NavigationField) {
        animationTimer += deltaTime

        // Only cycle animation frames for non-attack states.
        // The attacking state uses animationTimer to time the attack duration,
        // so we must not reset it while attacking.
        if case .attacking = state {
            // Don't reset timer — let it accumulate for attack duration check
        } else {
            if animationTimer >= 0.15 {
                animationTimer = 0
                animationFrame += 1
            }
        }

        attackCooldown = max(0, attackCooldown - deltaTime)

        let dx = playerX - x
        let dy = playerY - y
        let distToPlayer = sqrt(dx * dx + dy * dy)
        let angleToPlayer = atan2(dy, dx)

        switch state {
        case .idle:
            if distToPlayer < type.sightRange && canSeePlayer(playerX: playerX, playerY: playerY, world: world) {
                state = .chasing
                alertTimer = 0.5
            } else {
                // Wander occasionally so the level feels inhabited
                idleTimer -= deltaTime
                if idleTimer <= 0 {
                    idleTimer = Double.random(in: 3.0...8.0)
                    if let target = pickPatrolTarget(world: world) {
                        patrolTarget = target
                        state = .patrolling
                    }
                }
            }

        case .patrolling:
            if distToPlayer < type.sightRange && canSeePlayer(playerX: playerX, playerY: playerY, world: world) {
                patrolTarget = nil
                state = .chasing
                alertTimer = 0.5
            } else {
                moveTowardPatrolTarget(deltaTime: deltaTime, world: world)
            }

        case .chasing:
            if canSeePlayer(playerX: playerX, playerY: playerY, world: world) {
                angle = angleToPlayer
                if distToPlayer <= type.attackRange {
                    if attackCooldown <= 0 {
                        state = .attacking
                        animationFrame = 0
                        animationTimer = 0
                        hasDealtDamageThisAttack = false
                    } else if type.advancesDuringCooldown && distToPlayer > type.meleeRange {
                        // Bosses keep closing in between attacks
                        moveToward(targetX: playerX, targetY: playerY, deltaTime: deltaTime, world: world,
                                   stopDistance: 1.0)
                    }
                } else {
                    moveToward(targetX: playerX, targetY: playerY, deltaTime: deltaTime, world: world)
                }
            } else {
                // Lost sight: follow the navigation field around corners and through doors
                huntAlongPath(deltaTime: deltaTime, world: world, nav: nav)
            }

        case .attacking:
            angle = angleToPlayer
            if animationTimer >= type.attackDuration {
                // Attack resolves - damage is dealt by GameEngine
                state = .chasing
                attackCooldown = type.attackCooldownTime
            }

        case .hurt(let timer):
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                if health <= 0 {
                    state = .dying(timer: 1.0)
                    animationFrame = 0
                } else {
                    state = .chasing
                }
            } else {
                state = .hurt(timer: newTimer)
            }

        case .dying(let timer):
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                state = .dead
            } else {
                state = .dying(timer: newTimer)
            }

        case .dead:
            break
        }
    }

    mutating func takeDamage(_ amount: Int) {
        if case .dead = state { return }
        if case .dying = state { return }
        health -= amount
        if health <= 0 {
            // Go directly to dying — don't allow hurt-loop to prevent death
            health = 0
            state = .dying(timer: 1.0)
            animationFrame = 0
            return
        }

        // Already flinching: don't extend the stun, so rapid fire can't lock an enemy forever
        if case .hurt = state { return }

        if Double.random(in: 0..<1) < type.painChance {
            state = .hurt(timer: 0.2)
            animationFrame = 0
        } else {
            // No flinch, but being shot always wakes the enemy up
            switch state {
            case .idle, .patrolling:
                patrolTarget = nil
                state = .chasing
            default:
                break
            }
        }
    }

    private func canSeePlayer(playerX: Double, playerY: Double, world: GameWorld) -> Bool {
        let dx = playerX - x
        let dy = playerY - y
        let dist = sqrt(dx * dx + dy * dy)

        let steps = Int(dist * 4)
        // Point-blank range: nothing can be in between (also keeps 1..<steps a valid range)
        guard steps > 1 else { return true }
        for i in 1..<steps {
            let t = Double(i) / Double(steps)
            let checkX = x + dx * t
            let checkY = y + dy * t
            let tileX = Int(checkX)
            let tileY = Int(checkY)
            if world.isSolid(x: tileX, y: tileY) {
                return false
            }
        }
        return true
    }

    // MARK: - Movement

    /// Move toward a target with wall sliding. Stops within `stopDistance` of it.
    private mutating func moveToward(targetX: Double, targetY: Double, deltaTime: Double, world: GameWorld,
                                     stopDistance: Double = 0.5, speedMult: Double = 1.0) {
        let dx = targetX - x
        let dy = targetY - y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > stopDistance else { return }

        let speed = type.speed * speedMult * deltaTime
        let radius = 0.25

        // Primary direction: straight toward target
        var dirX = dx / dist
        var dirY = dy / dist

        // If stuck, blend in a wall-avoidance direction
        if stuckTimer > 0.15 {
            dirX = cos(wallAvoidAngle)
            dirY = sin(wallAvoidAngle)
        }

        // A closed, unlocked door directly ahead: ask the engine to open it
        var waitingForDoor = false
        let probeX = Int(x + dirX * 0.6)
        let probeY = Int(y + dirY * 0.6)
        if world.tileAt(x: probeX, y: probeY) == .door && world.isSolid(x: probeX, y: probeY) {
            doorRequest = (x: probeX, y: probeY)
            waitingForDoor = true
        }

        let moveX = dirX * speed
        let moveY = dirY * speed

        var moved = false
        let newX = x + moveX
        if world.isPassable(x: newX, y: y, radius: radius) {
            x = newX
            moved = true
        }
        let newY = y + moveY
        if world.isPassable(x: x, y: newY, radius: radius) {
            y = newY
            moved = true
        }

        if !moved {
            if waitingForDoor {
                // Hold position while the door opens instead of sliding along it
                stuckTimer = 0
                return
            }
            stuckTimer += deltaTime
            if stuckTimer > 0.15 {
                // Try wall-sliding: perpendicular directions
                let perpX1 = -dirY, perpY1 = dirX
                let perpX2 = dirY, perpY2 = -dirX

                let slide1X = x + perpX1 * speed
                let slide1Y = y + perpY1 * speed
                let slide2X = x + perpX2 * speed
                let slide2Y = y + perpY2 * speed

                if world.isPassable(x: slide1X, y: slide1Y, radius: radius) {
                    wallAvoidAngle = atan2(perpY1, perpX1)
                } else if world.isPassable(x: slide2X, y: slide2Y, radius: radius) {
                    wallAvoidAngle = atan2(perpY2, perpX2)
                } else {
                    // Random jitter to escape corners
                    wallAvoidAngle = Double.random(in: 0...(2 * .pi))
                }
            }
        } else {
            stuckTimer = max(0, stuckTimer - deltaTime * 2)
        }
    }

    /// Chase without line of sight: step toward the neighbouring tile closest to the player
    private mutating func huntAlongPath(deltaTime: Double, world: GameWorld, nav: NavigationField) {
        guard let next = nav.nextStep(fromX: Int(x), fromY: Int(y)) else {
            // No route (e.g. player behind a locked door): hold position
            return
        }
        let targetX = Double(next.x) + 0.5
        let targetY = Double(next.y) + 0.5
        angle = atan2(targetY - y, targetX - x)
        moveToward(targetX: targetX, targetY: targetY, deltaTime: deltaTime, world: world, stopDistance: 0.05)
    }

    private mutating func moveTowardPatrolTarget(deltaTime: Double, world: GameWorld) {
        guard let target = patrolTarget else {
            state = .idle
            return
        }
        let dx = target.0 - x
        let dy = target.1 - y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < 0.3 || stuckTimer > 0.5 {
            // Arrived, or something is in the way — rest again
            patrolTarget = nil
            stuckTimer = 0
            state = .idle
            return
        }
        angle = atan2(dy, dx)
        moveToward(targetX: target.0, targetY: target.1, deltaTime: deltaTime, world: world,
                   stopDistance: 0.25, speedMult: GameConstants.enemyPatrolSpeedMultiplier)
    }

    /// Pick a nearby floor tile that can be reached by walking in a straight line
    private func pickPatrolTarget(world: GameWorld) -> (Double, Double)? {
        let radius = GameConstants.enemyPatrolRadius
        let hereX = Int(x)
        let hereY = Int(y)
        for _ in 0..<6 {
            let tx = hereX + Int.random(in: -radius...radius)
            let ty = hereY + Int.random(in: -radius...radius)
            if tx == hereX && ty == hereY { continue }
            guard world.tileAt(x: tx, y: ty) == .empty else { continue }
            let targetX = Double(tx) + 0.5
            let targetY = Double(ty) + 0.5
            if isPathClear(toX: targetX, toY: targetY, world: world) {
                return (targetX, targetY)
            }
        }
        return nil
    }

    /// Whether the enemy can walk straight to the target without clipping walls or closed doors
    private func isPathClear(toX: Double, toY: Double, world: GameWorld) -> Bool {
        let dx = toX - x
        let dy = toY - y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.01 else { return true }
        let steps = max(1, Int(dist / 0.2))
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            if !world.isPassable(x: x + dx * t, y: y + dy * t, radius: 0.25) {
                return false
            }
        }
        return true
    }
}
