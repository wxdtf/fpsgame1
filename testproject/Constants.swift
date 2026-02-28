//
//  Constants.swift
//  testproject
//

import Foundation

enum GameConstants {
    // Internal render resolution (low-res for CPU speed, upscaled by GPU/SwiftUI)
    static let renderWidth = 480
    static let renderHeight = 300

    // Window / display size (SwiftUI scales the render image up to this)
    static let windowWidth = 960
    static let windowHeight = 600

    static let fov: Double = 66.0 * .pi / 180.0
    static let halfFov: Double = fov / 2.0

    // Map
    static let tileSize: Double = 1.0

    // Player
    static let playerMoveSpeed: Double = 3.0
    static let playerRotateSpeed: Double = 2.0
    static let playerRadius: Double = 0.25
    static let maxHealth = 100
    static let maxArmor = 100

    // Enemies
    static let enemyMoveSpeed: Double = 1.5
    static let enemyAttackRange: Double = 10.0
    static let enemyMeleeRange: Double = 1.5
    static let enemySightRange: Double = 16.0

    // Weapons
    static let pistolDamage = 20
    static let shotgunDamage = 12
    static let shotgunPellets = 7

    // Rendering performance
    static let maxRenderDistance: Double = 20.0
    static let textureSize = 64
}
