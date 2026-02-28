//
//  Enemy.swift
//  testproject
//

import Foundation

enum EnemyType: Int {
    case imp = 0
    case demon = 1
    case soldier = 2

    var maxHealth: Int {
        switch self {
        case .imp: return 60
        case .demon: return 100
        case .soldier: return 50
        }
    }

    var speed: Double {
        switch self {
        case .imp: return 1.5
        case .demon: return 2.5
        case .soldier: return 1.2
        }
    }

    var damage: Int {
        switch self {
        case .imp: return 10
        case .demon: return 25
        case .soldier: return 15
        }
    }

    var attackCooldownTime: Double {
        switch self {
        case .imp: return 1.5
        case .demon: return 0.8
        case .soldier: return 1.2
        }
    }

    var isRanged: Bool {
        switch self {
        case .imp, .soldier: return true
        case .demon: return false
        }
    }

    var attackRange: Double {
        switch self {
        case .imp: return 10.0
        case .demon: return 1.8
        case .soldier: return 12.0
        }
    }

    var sightRange: Double { GameConstants.enemySightRange }
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
    var state: AIState = .idle
    var animationFrame: Int = 0
    var animationTimer: Double = 0
    var attackCooldown: Double = 0
    var alertTimer: Double = 0
    var patrolTarget: (Double, Double)?
    var hasDealtDamageThisAttack: Bool = false

    init(type: EnemyType, x: Double, y: Double) {
        self.type = type
        self.x = x
        self.y = y
        self.health = type.maxHealth
    }

    var isDead: Bool {
        if case .dead = state { return true }
        return false
    }

    var isDying: Bool {
        if case .dying = state { return true }
        return false
    }

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

    /// Vertical offset for death animation (sprite sinks toward ground)
    var deathVOffset: Double {
        switch state {
        case .dying(let timer):
            if timer > 0.6 { return 0.0 }
            else if timer > 0.3 {
                // Falling: 0.0 → 0.1 over 0.3s
                let progress = 1.0 - (timer - 0.3) / 0.3
                return progress * 0.1
            } else {
                // On ground: 0.1 → 0.2
                let progress = 1.0 - timer / 0.3
                return 0.1 + progress * 0.1
            }
        case .dead: return 0.2
        default: return 0.0
        }
    }
    
    mutating func update(deltaTime: Double, playerX: Double, playerY: Double, world: GameWorld) {
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
            }

        case .patrolling:
            if distToPlayer < type.sightRange && canSeePlayer(playerX: playerX, playerY: playerY, world: world) {
                state = .chasing
                alertTimer = 0.5
            } else {
                moveTowardTarget(deltaTime: deltaTime, world: world)
            }

        case .chasing:
            angle = angleToPlayer
            if distToPlayer <= type.attackRange && canSeePlayer(playerX: playerX, playerY: playerY, world: world) {
                if attackCooldown <= 0 {
                    state = .attacking
                    animationFrame = 0
                    animationTimer = 0
                    hasDealtDamageThisAttack = false
                }
            } else {
                moveToward(targetX: playerX, targetY: playerY, deltaTime: deltaTime, world: world)
            }

        case .attacking:
            angle = angleToPlayer
            if animationTimer >= 0.3 {
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
        } else {
            state = .hurt(timer: 0.2)
            animationFrame = 0
        }
    }

    private func canSeePlayer(playerX: Double, playerY: Double, world: GameWorld) -> Bool {
        let dx = playerX - x
        let dy = playerY - y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < 0.1 { return true }

        let steps = Int(dist * 4)
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

    private mutating func moveToward(targetX: Double, targetY: Double, deltaTime: Double, world: GameWorld) {
        let dx = targetX - x
        let dy = targetY - y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.5 else { return }

        let speed = type.speed * deltaTime
        let moveX = (dx / dist) * speed
        let moveY = (dy / dist) * speed

        let radius = 0.25
        let newX = x + moveX
        if world.isPassable(x: newX, y: y, radius: radius) {
            x = newX
        }
        let newY = y + moveY
        if world.isPassable(x: x, y: newY, radius: radius) {
            y = newY
        }
    }

    private mutating func moveTowardTarget(deltaTime: Double, world: GameWorld) {
        guard let target = patrolTarget else {
            state = .idle
            return
        }
        let dx = target.0 - x
        let dy = target.1 - y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < 0.5 {
            patrolTarget = nil
            state = .idle
            return
        }
        angle = atan2(dy, dx)
        moveToward(targetX: target.0, targetY: target.1, deltaTime: deltaTime, world: world)
    }
}
