//
//  TestWorld.swift
//  fpsgame1Tests
//
//  Helpers for building small hand-drawn maps in tests.
//

import Foundation
@testable import fpsgame1

enum TestWorld {
    /// Build a world from an ASCII map. Legend:
    ///   `#` brick wall   `.` floor   `+` door   `R` `B` `Y` locked doors
    ///   `~` damage floor `X` exit portal   `T` brick torch
    static func make(_ rows: [String]) -> GameWorld {
        let h = rows.count
        let w = rows[0].count
        var tiles = [TileType](repeating: .empty, count: w * h)
        var doors: [DoorState] = []
        for (y, row) in rows.enumerated() {
            precondition(row.count == w, "all rows must have the same width")
            for (x, ch) in row.enumerated() {
                let tile: TileType
                switch ch {
                case "#": tile = .brickWall
                case ".": tile = .empty
                case "+": tile = .door
                case "R": tile = .lockedDoorRed
                case "B": tile = .lockedDoorBlue
                case "Y": tile = .lockedDoorYellow
                case "~": tile = .damageFloor
                case "X": tile = .exitPortal
                case "T": tile = .brickTorch
                default: preconditionFailure("unknown map glyph \(ch)")
                }
                tiles[y * w + x] = tile
                if tile.isDoor {
                    doors.append(DoorState(tileX: x, tileY: y))
                }
            }
        }
        var world = GameWorld(width: w, height: h, tiles1D: tiles, doors: doors)
        world.rebuildDoorIndex()
        return world
    }
}
