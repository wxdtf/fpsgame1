//
//  Weapon.swift
//  testproject
//

import Foundation

enum WeaponType: Hashable, CaseIterable {
    case fist
    case pistol
    case shotgun
    case chaingun
}

enum AmmoType: Hashable {
    case bullets
    case shells
}

enum KeyColor: Hashable {
    case red, blue, yellow
}

struct WeaponDefinition {
    let type: WeaponType
    let damage: Int
    let fireRate: Double
    let ammoType: AmmoType?
    let ammoPerShot: Int
    let spread: Double
    let pellets: Int
    let range: Double
    let animationFrames: Int
    let frameDuration: Double

    static let fist = WeaponDefinition(
        type: .fist, damage: 10, fireRate: 0.4, ammoType: nil, ammoPerShot: 0,
        spread: 0, pellets: 1, range: 1.5, animationFrames: 4, frameDuration: 0.08
    )

    static let pistol = WeaponDefinition(
        type: .pistol, damage: 20, fireRate: 0.3, ammoType: .bullets, ammoPerShot: 1,
        spread: 0.02, pellets: 1, range: 20, animationFrames: 4, frameDuration: 0.06
    )

    static let shotgun = WeaponDefinition(
        type: .shotgun, damage: 12, fireRate: 0.7, ammoType: .shells, ammoPerShot: 1,
        spread: 0.1, pellets: 7, range: 12, animationFrames: 5, frameDuration: 0.08
    )

    static let chaingun = WeaponDefinition(
        type: .chaingun, damage: 12, fireRate: 0.08, ammoType: .bullets, ammoPerShot: 1,
        spread: 0.04, pellets: 1, range: 20, animationFrames: 3, frameDuration: 0.025
    )

    static func forType(_ type: WeaponType) -> WeaponDefinition {
        switch type {
        case .fist: return .fist
        case .pistol: return .pistol
        case .shotgun: return .shotgun
        case .chaingun: return .chaingun
        }
    }
}

struct WeaponState {
    var type: WeaponType
    var currentFrame: Int = 0
    var frameTimer: Double = 0
    var cooldownTimer: Double = 0
    var isFiring: Bool = false
    var isSwitching: Bool = false
    var switchProgress: Double = 0  // 0..1 (0=up, 0.5=down, 1=up with new weapon)

    var definition: WeaponDefinition { WeaponDefinition.forType(type) }
    var isAnimating: Bool { currentFrame > 0 || isSwitching }
    var canFire: Bool { cooldownTimer <= 0 && !isAnimating }

    init(type: WeaponType) {
        self.type = type
    }

    mutating func update(deltaTime: Double) {
        cooldownTimer = max(0, cooldownTimer - deltaTime)

        if isSwitching {
            switchProgress += deltaTime * 4.0  // ~0.25s total
            if switchProgress >= 1.0 {
                switchProgress = 0
                isSwitching = false
            }
            return
        }

        if currentFrame > 0 {
            frameTimer += deltaTime
            if frameTimer >= definition.frameDuration {
                frameTimer = 0
                currentFrame += 1
                if currentFrame >= definition.animationFrames {
                    currentFrame = 0
                    isFiring = false
                }
            }
        }
    }

    mutating func fire() -> Bool {
        guard canFire else { return false }
        isFiring = true
        currentFrame = 1
        frameTimer = 0
        cooldownTimer = definition.fireRate
        return true
    }

    mutating func beginSwitch(to newType: WeaponType) {
        guard !isSwitching else { return }
        type = newType
        isSwitching = true
        switchProgress = 0
        currentFrame = 0
        isFiring = false
    }
}
