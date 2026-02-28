//
//  Player.swift
//  testproject
//

import Foundation

struct Player {
    var x: Double
    var y: Double
    var angle: Double  // Radians

    var health: Int = GameConstants.maxHealth
    var armor: Int = 0
    var isDead: Bool { health <= 0 }

    // Camera vectors
    var dirX: Double { cos(angle) }
    var dirY: Double { sin(angle) }
    var planeX: Double { -sin(angle) * tan(GameConstants.fov / 2) }
    var planeY: Double { cos(angle) * tan(GameConstants.fov / 2) }

    // Weapons
    var currentWeapon: WeaponType = .pistol
    var weapons: Set<WeaponType> = [.fist, .pistol, .shotgun]
    var ammo: [AmmoType: Int] = [.bullets: 50, .shells: 8]
    var weaponState: WeaponState = WeaponState(type: .pistol)

    // View bobbing
    var bobPhase: Double = 0
    var bobAmount: Double = 0
    var isMoving: Bool = false

    // Keys
    var keys: Set<KeyColor> = []

    mutating func rotate(by amount: Double) {
        angle += amount
        if angle < 0 { angle += .pi * 2 }
        if angle >= .pi * 2 { angle -= .pi * 2 }
    }

    mutating func move(forward: Double, strafe: Double, deltaTime: Double, world: GameWorld) {
        let speed = GameConstants.playerMoveSpeed * deltaTime
        let moveX = dirX * forward * speed + (-dirY) * strafe * speed
        let moveY = dirY * forward * speed + dirX * strafe * speed

        isMoving = abs(forward) > 0.01 || abs(strafe) > 0.01

        if isMoving {
            bobPhase += deltaTime * 8.0
            bobAmount = sin(bobPhase) * 0.03
        } else {
            bobAmount *= 0.9
        }

        let radius = GameConstants.playerRadius

        // Slide along walls: try X and Y independently
        let newX = x + moveX
        if world.isPassable(x: newX, y: y, radius: radius) {
            x = newX
        }

        let newY = y + moveY
        if world.isPassable(x: x, y: newY, radius: radius) {
            y = newY
        }

        // Push player out of solid geometry if stuck (e.g., door closed on them)
        if !world.isPassable(x: x, y: y, radius: radius) {
            pushOutOfSolid(radius: radius, world: world)
        }
    }

    private mutating func pushOutOfSolid(radius: Double, world: GameWorld) {
        // Check surrounding tiles and push player toward nearest open space
        let tileX = Int(x)
        let tileY = Int(y)
        let pushForce = 0.05

        // Try pushing in each cardinal direction
        let directions: [(Double, Double)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        for (dx, dy) in directions {
            let testX = x + dx * pushForce
            let testY = y + dy * pushForce
            if world.isPassable(x: testX, y: testY, radius: radius) {
                x = testX
                y = testY
                return
            }
        }

        // If still stuck, try pushing toward the center of adjacent empty tiles
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let checkX = tileX + dx
                let checkY = tileY + dy
                if !world.isSolid(x: checkX, y: checkY) {
                    let targetX = Double(checkX) + 0.5
                    let targetY = Double(checkY) + 0.5
                    let tdx = targetX - x
                    let tdy = targetY - y
                    let dist = sqrt(tdx * tdx + tdy * tdy)
                    if dist > 0.01 {
                        x += (tdx / dist) * pushForce
                        y += (tdy / dist) * pushForce
                        return
                    }
                }
            }
        }
    }

    mutating func takeDamage(_ amount: Int) {
        let absorbed = min(armor, amount / 2)
        armor -= absorbed
        health -= (amount - absorbed)
        if health < 0 { health = 0 }
    }

    mutating func heal(_ amount: Int) {
        health = min(GameConstants.maxHealth, health + amount)
    }

    mutating func addArmor(_ amount: Int) {
        armor = min(GameConstants.maxArmor, armor + amount)
    }

    mutating func switchWeapon(to type: WeaponType) {
        guard weapons.contains(type), type != currentWeapon else { return }
        currentWeapon = type
        weaponState.beginSwitch(to: type)
    }
}
