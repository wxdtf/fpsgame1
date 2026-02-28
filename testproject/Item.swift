//
//  Item.swift
//  testproject
//

import Foundation

enum ItemType {
    case healthPack(amount: Int)
    case armorVest(amount: Int)
    case ammoBullets(amount: Int)
    case ammoShells(amount: Int)
    case shotgunPickup
    case chaingunPickup
    case keyCard(color: KeyColor)
    case berserkPack
}

struct Item: Identifiable {
    let id: UUID = UUID()
    let type: ItemType
    var x: Double
    var y: Double
    var isCollected: Bool = false
    var bobPhase: Double = Double.random(in: 0..<(.pi * 2))

    mutating func update(deltaTime: Double) {
        bobPhase += deltaTime * 3.0
    }

    func distanceTo(playerX: Double, playerY: Double) -> Double {
        let dx = playerX - x
        let dy = playerY - y
        return sqrt(dx * dx + dy * dy)
    }

    func canPickUp(playerX: Double, playerY: Double) -> Bool {
        return distanceTo(playerX: playerX, playerY: playerY) < 0.6 && !isCollected
    }

    var spriteIndex: Int {
        switch type {
        case .healthPack: return 0
        case .armorVest: return 1
        case .ammoBullets: return 2
        case .ammoShells: return 3
        case .shotgunPickup: return 4
        case .chaingunPickup: return 5
        case .keyCard(let color):
            switch color {
            case .red: return 6
            case .blue: return 7
            case .yellow: return 8
            }
        case .berserkPack: return 9
        }
    }
}
