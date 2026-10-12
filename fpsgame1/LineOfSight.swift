//
//  LineOfSight.swift
//  fpsgame1
//
//  Whether a straight look from one point to another crosses a solid tile.
//
//  The previous check walked the segment in steps of a quarter tile and asked
//  which cell each sample fell in. A look that only clips a corner of a wall
//  lands between those samples, so the wall is skipped and the enemy spots the
//  player through it. This walk visits every cell the segment actually enters.
//

import Foundation

extension GameWorld {
    /// True when the open segment from `(fromX, fromY)` to `(toX, toY)` crosses
    /// a solid tile. The tile each endpoint stands on is ignored: an enemy in a
    /// doorway is not hidden by their own cell, and the player is not hidden by
    /// theirs.
    func blocksSight(fromX: Double, fromY: Double, toX: Double, toY: Double) -> Bool {
        let dx = toX - fromX
        let dy = toY - fromY
        var mapX = Int(floor(fromX))
        var mapY = Int(floor(fromY))
        let endX = Int(floor(toX))
        let endY = Int(floor(toY))

        // A cell the ray enters on the way. The destination cell is the target,
        // not an obstacle in front of them.
        func enteredSolid(_ x: Int, _ y: Int) -> Bool {
            if x == endX && y == endY { return false }
            return isSolid(x: x, y: y)
        }

        let stepX: Int
        let stepY: Int
        var tMaxX: Double
        var tMaxY: Double
        let tDeltaX: Double
        let tDeltaY: Double

        if dx > 0 {
            stepX = 1
            tDeltaX = 1 / dx
            tMaxX = (Double(mapX + 1) - fromX) * tDeltaX
        } else if dx < 0 {
            stepX = -1
            tDeltaX = 1 / -dx
            tMaxX = (fromX - Double(mapX)) * tDeltaX
        } else {
            stepX = 0
            tDeltaX = .infinity
            tMaxX = .infinity
        }

        if dy > 0 {
            stepY = 1
            tDeltaY = 1 / dy
            tMaxY = (Double(mapY + 1) - fromY) * tDeltaY
        } else if dy < 0 {
            stepY = -1
            tDeltaY = 1 / -dy
            tMaxY = (fromY - Double(mapY)) * tDeltaY
        } else {
            stepY = 0
            tDeltaY = .infinity
            tMaxY = .infinity
        }

        // Two boundary crossings that land on the same corner differ by a few
        // ulps. Treat that as one corner, so the wall that owns the point still
        // counts. A real gap of even a thousandth of the segment stays a normal step.
        let cornerSlop = 1e-8
        let limit = width + height + 2
        var steps = 0
        while mapX != endX || mapY != endY {
            if abs(tMaxX - tMaxY) <= cornerSlop {
                // Through a grid corner: both tiles that meet there are touched.
                if enteredSolid(mapX + stepX, mapY) || enteredSolid(mapX, mapY + stepY) {
                    return true
                }
                mapX += stepX
                mapY += stepY
                tMaxX += tDeltaX
                tMaxY += tDeltaY
            } else if tMaxX < tMaxY {
                mapX += stepX
                tMaxX += tDeltaX
            } else {
                mapY += stepY
                tMaxY += tDeltaY
            }

            steps += 1
            // Fail closed: a bad input blocks sight instead of looping forever.
            if steps > limit { return true }
            if mapX == endX && mapY == endY { return false }
            if enteredSolid(mapX, mapY) { return true }
        }
        return false
    }
}
