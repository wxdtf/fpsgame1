//
//  Navigation.swift
//  fpsgame1
//
//  Grid navigation for enemy AI.
//
//  Every frame the engine floods the tile grid from the player's tile with a
//  breadth-first search, producing the number of steps each walkable tile is
//  away from the player. An enemy that has lost sight of the player simply
//  moves to whichever neighbouring tile has the smallest step count, which
//  carries it around corners and through doors instead of into walls.
//

import Foundation

struct NavigationField {
    static let unreachable = -1

    // 4-connected neighbourhood: enemies never cut diagonally across wall corners
    private static let offsetsX = [1, -1, 0, 0]
    private static let offsetsY = [0, 0, 1, -1]

    let width: Int
    let height: Int
    /// Steps from each tile to the goal tile, or `unreachable`
    private(set) var distances: [Int]
    /// Reusable BFS queue storage
    private var queue: [Int]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        distances = [Int](repeating: NavigationField.unreachable, count: width * height)
        queue = []
        queue.reserveCapacity(width * height)
    }

    @inline(__always)
    func distance(x: Int, y: Int) -> Int {
        guard x >= 0, x < width, y >= 0, y < height else { return NavigationField.unreachable }
        return distances[y * width + x]
    }

    /// Whether an enemy may walk through the tile. Enemies can open unlocked doors,
    /// so those always count as passable; locked doors only count once open.
    static func isTraversable(world: GameWorld, x: Int, y: Int) -> Bool {
        switch world.tileAt(x: x, y: y) {
        case .empty, .damageFloor, .door:
            return true
        case .lockedDoorRed, .lockedDoorBlue, .lockedDoorYellow:
            if let idx = world.doorAt(x: x, y: y) {
                return world.doors[idx].openAmount >= 0.8
            }
            return false
        default:
            return false
        }
    }

    /// Flood the grid from the goal tile. Cheap enough (a few thousand cell visits)
    /// to run every frame, which keeps door state changes reflected immediately.
    mutating func rebuild(world: GameWorld, goalX: Int, goalY: Int) {
        let count = width * height
        for i in 0..<count {
            distances[i] = NavigationField.unreachable
        }
        queue.removeAll(keepingCapacity: true)

        guard goalX >= 0, goalX < width, goalY >= 0, goalY < height else { return }

        let start = goalY * width + goalX
        distances[start] = 0
        queue.append(start)

        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            let cx = current % width
            let cy = current / width
            let nextDist = distances[current] + 1

            for k in 0..<4 {
                let nx = cx + NavigationField.offsetsX[k]
                let ny = cy + NavigationField.offsetsY[k]
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let ni = ny * width + nx
                guard distances[ni] == NavigationField.unreachable else { continue }
                guard NavigationField.isTraversable(world: world, x: nx, y: ny) else { continue }
                distances[ni] = nextDist
                queue.append(ni)
            }
        }
    }

    /// The neighbouring tile that leads toward the goal from (x, y), or nil when the
    /// tile is unreachable or is the goal itself.
    func nextStep(fromX x: Int, fromY y: Int) -> (x: Int, y: Int)? {
        let here = distance(x: x, y: y)
        guard here > 0 else { return nil }

        var best: (x: Int, y: Int)? = nil
        var bestDist = here
        for k in 0..<4 {
            let nx = x + NavigationField.offsetsX[k]
            let ny = y + NavigationField.offsetsY[k]
            let d = distance(x: nx, y: ny)
            if d >= 0 && d < bestDist {
                bestDist = d
                best = (x: nx, y: ny)
            }
        }
        return best
    }
}
