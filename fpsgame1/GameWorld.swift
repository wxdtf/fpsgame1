//
//  GameWorld.swift
//  testproject
//

import Foundation

enum TileType: Int {
    case empty = 0
    case brickWall = 1
    case metalWall = 2
    case techWall = 3
    case door = 4
    case brickTorch = 5
    case exitPortal = 6
    case lockedDoorRed = 7
    case lockedDoorBlue = 8
    case lockedDoorYellow = 9
    case damageFloor = 10

    var isWall: Bool {
        switch self {
        case .empty, .door, .damageFloor: return false
        case .lockedDoorRed, .lockedDoorBlue, .lockedDoorYellow: return false
        default: return true
        }
    }

    var isDoor: Bool {
        switch self {
        case .door, .lockedDoorRed, .lockedDoorBlue, .lockedDoorYellow: return true
        default: return false
        }
    }

    var textureIndex: Int {
        switch self {
        case .empty: return 0
        case .brickWall: return TextureAtlas.brick
        case .metalWall: return TextureAtlas.metal
        case .techWall: return TextureAtlas.tech
        case .door: return TextureAtlas.door
        case .brickTorch: return TextureAtlas.brickTorch
        case .exitPortal: return TextureAtlas.exitPortal
        case .lockedDoorRed: return TextureAtlas.lockedDoorRed
        case .lockedDoorBlue: return TextureAtlas.lockedDoorBlue
        case .lockedDoorYellow: return TextureAtlas.lockedDoorYellow
        case .damageFloor: return 0
        }
    }
}

struct DoorState {
    var tileX: Int
    var tileY: Int
    var openAmount: Double = 0
    var isOpening: Bool = false
    var isClosing: Bool = false
    var stayOpenTimer: Double = 0
    let openSpeed: Double = 2.0
    let stayOpenDuration: Double = 4.0

    var isFullyOpen: Bool { openAmount >= 1.0 }
    var isFullyClosed: Bool { openAmount <= 0.0 }
}

struct GameWorld {
    let width: Int
    let height: Int
    /// Flat 1D tile array for cache-friendly access: tiles1D[y * width + x]
    var tiles1D: [TileType]
    var doors: [DoorState]
    /// O(1) door lookup: key = tileY * width + tileX, value = index into doors array
    var doorIndex: [Int: Int] = [:]

    /// Rebuild the door index after doors change
    mutating func rebuildDoorIndex() {
        doorIndex.removeAll(keepingCapacity: true)
        for i in doors.indices {
            let key = doors[i].tileY * width + doors[i].tileX
            doorIndex[key] = i
        }
    }

    @inline(__always)
    func doorAt(x: Int, y: Int) -> Int? {
        doorIndex[y * width + x]
    }

    @inline(__always)
    func tileAt(x: Int, y: Int) -> TileType {
        guard x >= 0, x < width, y >= 0, y < height else { return .brickWall }
        return tiles1D[y * width + x]
    }

    func isSolid(x: Int, y: Int) -> Bool {
        let tile = tileAt(x: x, y: y)
        if tile.isWall { return true }
        if tile.isDoor {
            if let idx = doorAt(x: x, y: y) {
                return doors[idx].openAmount < 0.8
            }
            return true
        }
        return false
    }

    func isPassable(x: Double, y: Double, radius: Double) -> Bool {
        let checks = [
            (x - radius, y - radius),
            (x + radius, y - radius),
            (x - radius, y + radius),
            (x + radius, y + radius),
        ]
        for (cx, cy) in checks {
            let tileX = Int(cx)
            let tileY = Int(cy)
            if isSolid(x: tileX, y: tileY) {
                return false
            }
        }
        return true
    }

    // Level data structure for multi-level support
    struct LevelData {
        let layout: [[Int]]
        let playerStartX: Double
        let playerStartY: Double
        let playerStartAngle: Double
        let enemies: [(EnemyType, Double, Double)]
        let items: [(ItemType, Double, Double)]
    }

    static func createLevel(_ number: Int) -> GameWorld {
        let data = levelData(for: number)
        let w = data.layout[0].count
        let h = data.layout.count
        var tiles1D = [TileType](repeating: .empty, count: w * h)
        var doors: [DoorState] = []

        for (y, row) in data.layout.enumerated() {
            for (x, val) in row.enumerated() {
                let tile = TileType(rawValue: val) ?? .empty
                tiles1D[y * w + x] = tile
                if tile.isDoor {
                    doors.append(DoorState(tileX: x, tileY: y))
                }
            }
        }

        var world = GameWorld(width: w, height: h, tiles1D: tiles1D, doors: doors)
        world.rebuildDoorIndex()
        return world
    }

    static func levelData(for number: Int) -> LevelData {
        switch number {
        case 1: return level1Data()
        case 2: return level2Data()
        case 3: return level3Data()
        default: return level1Data()
        }
    }

    static let maxLevel = 3

    static func briefingText(for level: Int) -> (title: String, lines: [String]) {
        switch level {
        case 1:
            return (
                "E1M1: UAC Military Base",
                [
                    "The UAC facility has gone dark.",
                    "Reports of hostile entities throughout.",
                    "Retrieve the INTEL DATA from the",
                    "command center and reach the exit.",
                    "",
                    "Objective: Retrieve the intel data."
                ]
            )
        case 2:
            return (
                "E1M2: Hell's Gateway",
                [
                    "You've entered an ancient temple",
                    "corrupted by demonic energy.",
                    "Find the DEMONIC ARTIFACT hidden",
                    "deep within. The RED KEY opens the exit.",
                    "",
                    "Objective: Find the demonic artifact."
                ]
            )
        case 3:
            return (
                "E1M3: Toxin Refinery",
                [
                    "The refinery is overrun. Heavy resistance.",
                    "A RED KEY opens the mid-section.",
                    "A BLUE KEY beyond opens the final arena.",
                    "EXTERMINATE ALL DEMONS. Leave none alive.",
                    "",
                    "Objective: Exterminate all demons."
                ]
            )
        default:
            return ("UNKNOWN", ["No briefing available."])
        }
    }

    // MARK: - Level 1: "UAC Military Base" — Metal/industrial theme
    //
    // Design: Indoor military facility. Primarily METAL walls (gray/silver).
    // Linear start-to-exit. No keys required (tutorial level).
    // Start bottom-left, exit portal top-right.
    // Corridors, barracks, armory. Optional side room with chaingun + berserk.
    // ~12 enemies, introductory difficulty.

    private static func level1Data() -> LevelData {
        // 0=empty, 1=brick, 2=metal, 3=tech, 4=door, 5=brickTorch, 6=exitPortal
        let layout: [[Int]] = [
            //0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2], // 0
            [2,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,2], // 1
            [2,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,2], // 2
            [2,0,0,0,0,0,0,0,0,4,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,2,0,0,6,0,2], // 3  EXIT at (29,3)
            [2,0,0,0,2,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,2], // 4
            [2,0,0,0,0,0,0,0,0,2,0,0,2,0,0,0,2,0,0,0,0,0,0,2,0,0,0,0,2,0,0,2], // 5
            [2,0,0,0,0,0,0,0,0,2,2,2,2,2,4,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,2], // 6
            [2,2,2,2,4,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,2,0,0,0,2,2,2,4,2,2,2,2], // 7
            [2,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,4,0,0,0,2,0,0,0,0,0,0,2], // 8
            [2,0,0,0,0,0,0,0,0,2,0,0,0,2,0,0,2,0,0,0,2,0,0,0,2,0,0,0,0,0,0,2], // 9
            [2,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,0,0,2,0,0,0,2], // 10
            [2,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,2], // 11
            [2,0,0,0,2,0,0,0,0,2,2,2,2,4,2,2,2,0,0,0,0,0,0,0,2,0,0,0,0,0,0,2], // 12
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,2,2,2,2,4,2,2,2], // 13
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,2], // 14
            [2,2,2,2,2,2,2,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2], // 15
            [2,0,0,0,0,0,2,0,0,0,0,0,0,2,0,0,2,2,2,2,2,2,4,2,2,2,2,0,0,0,0,2], // 16
            [2,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,2,0,0,0,0,2], // 17
            [2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,2,0,0,0,0,2], // 18
            [2,2,2,2,2,2,2,0,0,0,2,0,0,0,2,0,2,2,0,0,2,0,0,2,0,0,2,2,2,4,2,2], // 19
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2], // 20
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2], // 21
            [2,0,0,0,2,0,0,0,0,2,0,0,0,0,0,0,0,2,2,2,2,2,4,2,2,2,2,0,0,0,0,2], // 22
            [2,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2], // 23
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,2], // 24
            [2,2,2,4,2,2,2,2,0,0,0,2,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,2], // 25
            [2,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,2], // 26
            [2,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,2], // 27
            [2,0,0,0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,2], // 28
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,2], // 29
            [2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2], // 30
            [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2], // 31
        ]
        return LevelData(
            layout: layout,
            playerStartX: 2.5, playerStartY: 29.5, playerStartAngle: -.pi / 2,
            enemies: [
                // Starting corridor — easy intro
                (.imp, 5.5, 27.5),
                (.imp, 11.5, 29.5),
                // Barracks rooms
                (.imp, 3.5, 20.5),
                (.soldier, 7.5, 22.5),
                // Central corridor ambush
                (.imp, 13.5, 15.5),
                (.soldier, 8.5, 10.5),
                // Armory guard
                (.soldier, 12.5, 9.5),
                // Courtyard (upper area)
                (.imp, 14.5, 3.5),
                (.soldier, 5.5, 2.5),
                // Command center room
                (.demon, 28.5, 9.5),
                (.imp, 26.5, 12.5),
                // Exit hall
                (.soldier, 22.5, 21.5),
                (.imp, 29.5, 17.5),
            ],
            items: [
                // Start area — bullets
                (.ammoBullets(amount: 20), 2.5, 27.5),
                // Barracks — health
                (.healthPack(amount: 25), 3.5, 17.5),
                // Central junction — ammo
                (.ammoBullets(amount: 20), 13.5, 18.5),
                // Armory — shotgun & shells
                (.shotgunPickup, 14.5, 9.5),
                (.ammoShells(amount: 8), 11.5, 11.5),
                // Courtyard — health after fight
                (.healthPack(amount: 25), 4.5, 5.5),
                // Command room — armor
                (.armorVest(amount: 50), 28.5, 11.5),
                // Supplies for final push
                (.healthPack(amount: 50), 20.5, 20.5),
                (.ammoShells(amount: 10), 24.5, 18.5),
                // Exit corridor
                (.ammoBullets(amount: 20), 29.5, 24.5),
                (.healthPack(amount: 25), 29.5, 5.5),
                // Optional side room — chaingun & berserk
                (.chaingunPickup, 2.5, 17.5),
                (.berserkPack, 4.5, 17.5),
                // Mission item — intel data in command center area
                (.intelData, 3.5, 26.5),
            ]
        )
    }

    // MARK: - Level 2: "Hell's Gateway" — Brick/torch hell theme
    //
    // Design: Central hub with branching paths. Primarily BRICK walls with
    // torch pillars for a hellish dungeon atmosphere. Exit portal in north wing.
    // West: Armory (RED KEY here). East: Demon pits. North: Arena → RED LOCKED DOOR → Exit.
    // ~16 enemies, moderate difficulty.

    private static func level2Data() -> LevelData {
        // 0=empty, 1=brick, 2=metal, 3=tech, 4=door, 5=brickTorch, 6=exitPortal
        let layout: [[Int]] = [
            //0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], // 0
            [1,0,0,0,0,0,0,5,0,0,0,1,1,0,0,0,6,0,0,1,1,0,0,0,0,0,0,5,0,0,0,1], // 1  EXIT at (16,1)
            [1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1], // 2
            [1,0,0,0,0,0,0,0,0,0,0,4,0,0,0,1,1,0,0,4,0,0,0,0,0,0,0,0,0,0,0,1], // 3
            [1,0,0,5,0,0,0,0,5,0,0,1,1,0,0,0,0,0,0,1,1,0,0,5,0,0,0,0,5,0,0,1], // 4
            [1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1], // 5
            [1,1,1,1,5,1,1,1,1,0,0,1,1,1,1,7,1,1,1,1,1,0,0,1,1,1,1,5,1,1,1,1], // 6  RED LOCKED DOOR at (15,6)
            [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1], // 7
            [1,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,1], // 8
            [1,0,0,0,5,0,0,0,1,0,0,0,0,5,0,0,0,0,5,0,0,0,0,1,0,0,0,5,0,0,0,1], // 9
            [1,0,0,0,0,0,0,0,1,1,4,1,1,1,1,0,0,1,1,1,1,4,1,1,0,0,0,0,0,0,0,1], // 10
            [1,1,1,4,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,4,1,1,1], // 11
            [1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1], // 12
            [1,0,0,0,0,1,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,5,0,0,0,1,0,0,0,0,1], // 13
            [1,0,0,0,0,5,0,0,0,0,0,0,1,1,5,1,1,5,1,1,0,0,0,0,0,0,5,0,0,0,0,1], // 14
            [1,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1], // 15
            [1,1,1,1,1,1,0,0,0,5,0,0,5,0,0,0,0,0,5,0,0,5,0,0,0,0,1,1,1,1,1,1], // 16
            [1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1], // 17
            [1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,5,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1], // 18
            [1,0,0,5,0,0,0,0,5,0,0,0,1,1,4,1,1,4,1,0,0,0,5,0,0,0,5,0,0,0,0,1], // 19
            [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1], // 20
            [1,5,1,1,4,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,4,1,5,1], // 21
            [1,0,0,0,0,0,1,0,0,0,0,0,0,0,5,0,0,5,0,0,0,0,0,0,0,0,1,0,0,0,0,1], // 22
            [1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1], // 23
            [1,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,1], // 24
            [1,0,0,0,0,0,1,0,0,0,5,0,0,0,0,0,0,0,0,0,5,0,0,0,0,0,1,0,0,0,0,1], // 25
            [1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1], // 26
            [1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,5,1,5,1,1,0,0,0,0,0,0,1,1,1,1,1,1], // 27
            [1,1,1,1,1,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,1,1,1], // 28
            [1,0,0,0,1,0,0,0,0,0,5,0,0,5,0,0,0,0,5,0,0,5,0,0,0,0,0,1,0,0,0,1], // 29
            [1,0,0,0,4,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,4,0,0,0,1], // 30
            [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], // 31
        ]
        return LevelData(
            layout: layout,
            playerStartX: 2.5, playerStartY: 29.5, playerStartAngle: -.pi / 2,
            enemies: [
                // Entry area
                (.imp, 8.5, 28.5),
                (.imp, 5.5, 25.5),
                // Central hub
                (.soldier, 11.5, 12.5),
                (.imp, 7.5, 9.5),
                (.soldier, 18.5, 9.5),
                // West wing (armory)
                (.imp, 2.5, 13.5),
                (.soldier, 3.5, 7.5),
                (.demon, 2.5, 2.5),
                // Hub room (center)
                (.soldier, 15.5, 16.5),
                (.imp, 14.5, 19.5),
                // East wing
                (.imp, 29.5, 15.5),
                (.soldier, 28.5, 5.5),
                (.demon, 30.5, 9.5),
                // North arena (before exit)
                (.demon, 14.5, 2.5),
                (.soldier, 17.5, 4.5),
                (.imp, 9.5, 1.5),
                // South passage
                (.soldier, 16.5, 29.5),
            ],
            items: [
                // Entry — bullets
                (.ammoBullets(amount: 20), 2.5, 28.5),
                // West wing — armory (RED KEY here)
                (.keyCard(color: .red), 2.5, 7.5),
                (.shotgunPickup, 2.5, 23.5),
                (.ammoShells(amount: 12), 3.5, 14.5),
                (.armorVest(amount: 50), 2.5, 8.5),
                // Central hub — supplies
                (.healthPack(amount: 25), 15.5, 15.5),
                (.ammoBullets(amount: 20), 7.5, 11.5),
                // Hub room
                (.healthPack(amount: 25), 15.5, 18.5),
                // East wing — supplies
                (.healthPack(amount: 50), 29.5, 17.5),
                (.ammoBullets(amount: 30), 30.5, 2.5),
                (.ammoShells(amount: 8), 28.5, 12.5),
                // North arena — fight prep
                (.healthPack(amount: 50), 5.5, 4.5),
                (.ammoShells(amount: 10), 17.5, 1.5),
                (.armorVest(amount: 25), 9.5, 3.5),
                // South passage
                (.healthPack(amount: 25), 11.5, 27.5),
                // Mission item — demonic artifact deep in east wing
                (.demonicArtifact, 29.5, 12.5),
            ]
        )
    }

    // MARK: - Level 3: "Toxin Refinery" — Tech/high-tech theme
    //
    // Design: High-tech facility. Primarily TECH walls (blue/green panels).
    // RED KEY in upper section → RED DOOR to mid section → BLUE KEY → BLUE DOOR to final arena.
    // Start top-left, exit bottom-right.
    // Dense enemy encounters. ~24 enemies, high difficulty.

    private static func level3Data() -> LevelData {
        // 0=empty, 1=brick, 2=metal, 3=tech, 4=door, 5=brickTorch, 6=exitPortal
        let layout: [[Int]] = [
            //0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3], // 0
            [3,0,0,0,0,0,3,0,0,0,0,0,0,0,3,3,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,3], // 1
            [3,0,0,0,0,0,0,0,0,0,3,0,0,0,3,3,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,3], // 2
            [3,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,3], // 3
            [3,0,0,3,0,0,0,0,3,0,0,0,0,0,3,3,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,3], // 4
            [3,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,0,0,0,0,3,0,0,3,0,0,0,0,0,0,0,3], // 5
            [3,3,3,3,3,3,4,3,3,3,3,0,0,0,3,3,3,3,4,3,3,0,0,3,3,4,3,3,3,0,0,3], // 6
            [3,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,3], // 7
            [3,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,3], // 8
            [3,0,0,3,0,0,0,0,0,0,0,0,0,0,0,3,0,0,3,3,3,3,4,3,3,0,0,0,4,0,0,3], // 9
            [3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,3,0,0,0,0,0,3,0,0,0,3,0,0,3], // 10
            [3,0,0,0,0,0,3,0,0,0,0,0,0,0,0,3,0,0,3,0,0,0,0,0,3,0,0,0,3,0,0,3], // 11
            [3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,3,0,0,3,0,0,3,0,0,3,0,0,0,3,3,3,3], // 12
            [3,3,3,3,3,3,3,3,0,0,0,3,0,0,0,3,0,0,3,0,0,0,0,0,3,0,0,0,0,0,0,3], // 13
            [3,0,0,0,0,0,0,3,0,0,0,3,3,3,3,3,0,0,3,0,0,0,0,0,3,0,0,0,0,0,0,3], // 14
            [3,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,3,3,3,7,3,3,3,0,0,0,3,0,0,3], // 15  RED LOCKED DOOR at (21,15)
            [3,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3], // 16
            [3,0,0,3,0,0,0,3,3,3,3,4,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,3], // 17
            [3,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,3,3,3,3,3,3,3,3,0,0,0,3], // 18
            [3,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,3], // 19
            [3,3,3,3,3,3,3,0,0,0,3,0,0,0,3,0,0,0,0,0,3,0,0,0,0,0,0,0,3,0,0,3], // 20
            [3,3,3,3,3,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,3], // 21
            [3,0,0,0,3,0,0,0,0,0,0,0,0,0,3,3,3,8,3,3,3,0,0,3,0,0,0,3,0,0,0,3], // 22  BLUE LOCKED DOOR at (17,22)
            [3,0,0,0,4,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,3], // 23
            [3,0,0,0,3,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,3], // 24
            [3,0,0,0,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,3,0,0,0,0,3], // 25
            [3,0,0,0,0,0,0,0,0,3,0,0,0,0,3,0,0,3,0,0,3,3,3,3,3,3,3,0,0,0,0,3], // 26
            [3,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3], // 27
            [3,0,0,0,3,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,3], // 28
            [3,0,0,0,0,0,0,0,0,3,3,3,0,0,0,3,0,0,3,0,0,0,3,0,0,0,0,0,0,0,6,3], // 29  EXIT at (30,29)
            [3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3], // 30
            [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3], // 31
        ]
        return LevelData(
            layout: layout,
            playerStartX: 2.5, playerStartY: 2.5, playerStartAngle: .pi / 2,
            enemies: [
                // Start area (tech)
                (.imp, 8.5, 3.5),
                (.soldier, 5.5, 5.5),
                // Tech corridor
                (.imp, 3.5, 8.5),
                (.soldier, 8.5, 10.5),
                // Side room
                (.demon, 3.5, 15.5),
                (.imp, 5.5, 18.5),
                // Connecting passage
                (.soldier, 9.5, 14.5),
                (.imp, 13.5, 11.5),
                // Open courtyard (upper-right)
                (.soldier, 21.5, 3.5),
                (.imp, 27.5, 2.5),
                (.imp, 17.5, 5.5),
                // Toxic vault (inner room)
                (.demon, 21.5, 11.5),
                (.soldier, 23.5, 13.5),
                // Central gallery
                (.imp, 10.5, 17.5),
                (.soldier, 15.5, 16.5),
                // Lower passages
                (.demon, 7.5, 22.5),
                (.imp, 12.5, 23.5),
                (.soldier, 16.5, 22.5),
                // South barracks
                (.demon, 3.5, 27.5),
                (.soldier, 7.5, 29.5),
                // Final arena (bottom-right)
                (.demon, 25.5, 21.5),
                (.demon, 29.5, 24.5),
                (.soldier, 23.5, 27.5),
                (.imp, 27.5, 29.5),
                (.imp, 22.5, 30.5),
            ],
            items: [
                // Start area
                (.ammoBullets(amount: 20), 2.5, 4.5),
                (.healthPack(amount: 25), 8.5, 1.5),
                // Tech corridor
                (.ammoBullets(amount: 20), 8.5, 8.5),
                // Side room — shotgun
                (.shotgunPickup, 2.5, 14.5),
                (.ammoShells(amount: 8), 5.5, 14.5),
                // Open courtyard — RED KEY here
                (.keyCard(color: .red), 29.5, 4.5),
                (.healthPack(amount: 50), 25.5, 4.5),
                (.ammoBullets(amount: 30), 29.5, 7.5),
                // Toxic vault — armor
                (.armorVest(amount: 50), 21.5, 10.5),
                // Central gallery — BLUE KEY here
                (.keyCard(color: .blue), 14.5, 16.5),
                (.healthPack(amount: 25), 12.5, 16.5),
                (.ammoShells(amount: 12), 4.5, 19.5),
                // Lower passages
                (.healthPack(amount: 50), 15.5, 22.5),
                (.ammoBullets(amount: 30), 9.5, 26.5),
                // South barracks
                (.healthPack(amount: 25), 2.5, 26.5),
                (.ammoShells(amount: 10), 6.5, 28.5),
                // Final arena — supplies
                (.armorVest(amount: 50), 24.5, 24.5),
                (.healthPack(amount: 50), 28.5, 27.5),
                (.ammoShells(amount: 12), 30.5, 30.5),
            ]
        )
    }
}
