//
//  Renderer.swift
//  testproject
//

import Foundation
import simd

final class Renderer {
    let width: Int
    let height: Int
    var pixelBuffer: PixelBuffer
    var zBuffer: UnsafeMutablePointer<Double>
    let textures: TextureAtlas
    let sprites: SpriteAssets

    // Fog color
    static let fogR: Double = 10
    static let fogG: Double = 8
    static let fogB: Double = 15

    // Pre-computed combined shade+fog lookup: for each distance step, store (shade, fog, ceilShade)
    // Indexed by Int(distance * 10), range 0..200
    private static let lutSize = 201
    private static let lut: [(shade: Double, fog: Double, ceilShade: Double)] = {
        var table = [(Double, Double, Double)](repeating: (0, 0, 0), count: lutSize)
        let density = 0.08
        for i in 0..<lutSize {
            let d = Double(i) * 0.1
            let shade = max(0.08, 1.0 / (1.0 + 0.2 * d * d))
            let fog = max(0.0, min(1.0, exp(-density * d * d)))
            table[i] = (shade, fog, shade * 0.65)
        }
        return table
    }()

    // Cached torch positions
    private var cachedTorches: [(Double, Double)] = []
    private var currentTime: Double = 0
    private var currentWorld: GameWorld?

    init() {
        width = GameConstants.renderWidth
        height = GameConstants.renderHeight
        pixelBuffer = PixelBuffer(width: width, height: height)
        zBuffer = .allocate(capacity: width)
        zBuffer.initialize(repeating: Double.infinity, count: width)
        textures = TextureAtlas()
        sprites = SpriteAssets.shared
    }

    deinit {
        zBuffer.deallocate()
    }

    func render(player: Player, world: GameWorld, enemies: [Enemy], items: [Item], projectiles: [Projectile] = [], elapsedTime: Double = 0) {
        let buf = pixelBuffer.rawPixels
        let n = pixelBuffer.count
        for i in 0..<n { buf[i] = 0xFF000000 }
        for i in 0..<width { zBuffer[i] = Double.infinity }

        currentTime = elapsedTime
        currentWorld = world
        cachedTorches = findNearbyTorches(world: world, aroundX: player.x, aroundY: player.y)

        // Animate exit portal texture
        textures.updateExitPortal(time: elapsedTime)

        renderFloorCeiling(player: player)
        renderWalls(player: player, world: world)
        renderSprites(player: player, enemies: enemies, items: items, projectiles: projectiles)
        renderWeapon(player: player)
    }

    // MARK: - Combined shade+fog in one operation

    @inline(__always)
    private static func getLUT(_ distance: Double) -> (shade: Double, fog: Double, ceilShade: Double) {
        let idx = min(lutSize - 1, max(0, Int(distance * 10.0)))
        return lut[idx]
    }

    // Float versions for Apple Silicon NEON optimization
    private static let fogRf: Float = Float(fogR)
    private static let fogGf: Float = Float(fogG)
    private static let fogBf: Float = Float(fogB)

    @inline(__always)
    private static func shadeThenFog(_ color: UInt32, shade: Double, fog: Double) -> UInt32 {
        let s = Float(shade)
        let f = Float(fog)
        let invF = 1.0 - f
        let r = Float((color >> 16) & 0xFF) * s
        let g = Float((color >> 8) & 0xFF) * s
        let b = Float(color & 0xFF) * s
        return (0xFF << 24)
            | (UInt32(r * f + fogRf * invF) << 16)
            | (UInt32(g * f + fogGf * invF) << 8)
            | UInt32(b * f + fogBf * invF)
    }

    // MARK: - Torch Light

    private func findNearbyTorches(world: GameWorld, aroundX: Double, aroundY: Double) -> [(Double, Double)] {
        var torches: [(Double, Double)] = []
        let cx = Int(aroundX)
        let cy = Int(aroundY)
        let r = 5
        for ty in max(0, cy - r)...min(world.height - 1, cy + r) {
            for tx in max(0, cx - r)...min(world.width - 1, cx + r) {
                if world.tileAt(x: tx, y: ty) == .brickTorch {
                    torches.append((Double(tx) + 0.5, Double(ty) + 0.5))
                }
            }
        }
        return torches
    }

    @inline(__always)
    private func torchLight(worldX: Double, worldY: Double) -> Double {
        var light = 0.0
        let t = currentTime
        for i in 0..<cachedTorches.count {
            let dx = worldX - cachedTorches[i].0
            let dy = worldY - cachedTorches[i].1
            let distSq = dx * dx + dy * dy
            if distSq < 16.0 {
                // Flicker: each torch has a unique phase based on its position
                let phase = cachedTorches[i].0 * 3.0 + cachedTorches[i].1 * 7.0
                let flicker = 0.8 + 0.2 * sin(t * 8.0 + phase)
                light += 1.2 * flicker / (1.0 + distSq * 0.8)
            }
        }
        return min(light, 1.5)
    }

    // MARK: - Floor and Ceiling

    private func renderFloorCeiling(player: Player) {
        let halfH = height / 2
        let w = width
        let h = height
        let texSize = GameConstants.textureSize
        let texMask = texSize - 1
        let buf = pixelBuffer.rawPixels
        let texAtlas = textures.atlas
        let ppt = texSize * texSize
        let floorOff = TextureAtlas.floor * ppt
        let ceilOff = TextureAtlas.ceiling * ppt
        let dmgFloorOff = TextureAtlas.damageFloor * ppt
        let world = currentWorld

        let rayDirX0 = player.dirX - player.planeX
        let rayDirY0 = player.dirY - player.planeY
        let rdxDiff = (player.dirX + player.planeX) - rayDirX0
        let rdyDiff = (player.dirY + player.planeY) - rayDirY0
        let invW = 1.0 / Double(w)
        let dHalfH = Double(halfH)
        let px = player.x, py = player.y
        let dTexSize = Double(texSize)

        // Use concurrent rendering for floor/ceiling rows (Apple Silicon multi-core)
        let rowCount = h - halfH - 1
        DispatchQueue.concurrentPerform(iterations: rowCount) { rowIdx in
            let y = halfH + 1 + rowIdx
            let rowDist = dHalfH / Double(y - halfH)
            let fStepX = rowDist * rdxDiff * invW
            let fStepY = rowDist * rdyDiff * invW
            var floorX = px + rowDist * rayDirX0
            var floorY = py + rowDist * rayDirY0

            let l = Renderer.getLUT(rowDist)
            let floorShade = l.shade
            let ceilShade = l.ceilShade
            let fog = l.fog
            let ceilY = h - 1 - y
            let rowOff = y * w
            let ceilRowOff = ceilY * w

            for x in 0..<w {
                let tx = Int(floorX * dTexSize) & texMask
                let ty = Int(floorY * dTexSize) & texMask
                let texOff = ty * texSize + tx

                // Check if this floor tile is a damage floor for alternate texture
                let tileOff: Int
                if let w = world, w.tileAt(x: Int(floorX), y: Int(floorY)) == .damageFloor {
                    tileOff = dmgFloorOff
                } else {
                    tileOff = floorOff
                }
                buf[rowOff + x] = Renderer.shadeThenFog(texAtlas[tileOff + texOff], shade: floorShade, fog: fog)
                buf[ceilRowOff + x] = Renderer.shadeThenFog(texAtlas[ceilOff + texOff], shade: ceilShade, fog: fog)

                floorX += fStepX
                floorY += fStepY
            }
        }
    }

    // MARK: - Wall Raycasting (DDA)

    private func renderWalls(player: Player, world: GameWorld) {
        let w = width
        let h = height
        let halfH = h / 2
        let texSize = GameConstants.textureSize
        let buf = pixelBuffer.rawPixels
        let texAtlas = textures.atlas
        let ppt = texSize * texSize
        let invW = 2.0 / Double(w)

        for x in 0..<w {
            let cameraX = Double(x) * invW - 1.0
            let rayDirX = player.dirX + player.planeX * cameraX
            let rayDirY = player.dirY + player.planeY * cameraX

            var mapX = Int(player.x)
            var mapY = Int(player.y)

            let deltaDistX = abs(rayDirX) < 1e-10 ? 1e10 : abs(1.0 / rayDirX)
            let deltaDistY = abs(rayDirY) < 1e-10 ? 1e10 : abs(1.0 / rayDirY)

            var stepX: Int, stepY: Int
            var sideDistX: Double, sideDistY: Double

            if rayDirX < 0 {
                stepX = -1; sideDistX = (player.x - Double(mapX)) * deltaDistX
            } else {
                stepX = 1; sideDistX = (Double(mapX) + 1.0 - player.x) * deltaDistX
            }
            if rayDirY < 0 {
                stepY = -1; sideDistY = (player.y - Double(mapY)) * deltaDistY
            } else {
                stepY = 1; sideDistY = (Double(mapY) + 1.0 - player.y) * deltaDistY
            }

            var hit = false
            var side = 0
            var tile = TileType.empty

            while !hit {
                if sideDistX < sideDistY {
                    sideDistX += deltaDistX; mapX += stepX; side = 0
                } else {
                    sideDistY += deltaDistY; mapY += stepY; side = 1
                }

                tile = world.tileAt(x: mapX, y: mapY)

                if tile.isDoor {
                    if let doorIdx = world.doorAt(x: mapX, y: mapY) {
                        let door = world.doors[doorIdx]
                        if door.openAmount >= 0.99 {
                            // Fully open — ray passes through
                        } else {
                            // Door renders at the tile boundary like a normal wall.
                            // Check if ray hits the remaining door or the open gap.
                            let perpDist = side == 0 ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY)
                            var hitWallX = side == 0
                                ? (player.y + perpDist * rayDirY)
                                : (player.x + perpDist * rayDirX)
                            hitWallX -= floor(hitWallX)
                            // Flip wallX for rays coming from the negative direction
                            // so the gap always opens from the same side visually
                            if (side == 0 && rayDirX > 0) || (side == 1 && rayDirY > 0) {
                                hitWallX = 1.0 - hitWallX
                            }
                            if hitWallX > door.openAmount {
                                hit = true  // Ray hits remaining solid door portion
                            }
                            // else: ray passes through the open gap
                        }
                    } else { hit = true }
                } else if tile.isWall { hit = true }

                let pd = side == 0 ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY)
                if pd > GameConstants.maxRenderDistance { break }
            }

            guard hit else { continue }

            let perpWallDist = side == 0 ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY)
            var wallX = side == 0 ? (player.y + perpWallDist * rayDirY) : (player.x + perpWallDist * rayDirX)
            wallX -= floor(wallX)
            // Offset door texture by open amount for sliding effect
            if tile.isDoor {
                if let doorIdx = world.doorAt(x: mapX, y: mapY) {
                    let door = world.doors[doorIdx]
                    // Flip wallX consistent with gap detection
                    if (side == 0 && rayDirX > 0) || (side == 1 && rayDirY > 0) {
                        wallX = 1.0 - wallX
                    }
                    wallX += door.openAmount
                    if wallX >= 1.0 { wallX -= 1.0 }
                    // Flip back
                    if (side == 0 && rayDirX > 0) || (side == 1 && rayDirY > 0) {
                        wallX = 1.0 - wallX
                    }
                }
            }
            guard perpWallDist > 0 else { continue }
            zBuffer[x] = perpWallDist

            let lineHeight = Int(Double(h) / perpWallDist)
            guard lineHeight > 0 else { continue }
            let drawStart = max(0, halfH - lineHeight / 2)
            let drawEnd = min(h - 1, halfH + lineHeight / 2)
            guard drawEnd >= drawStart else { continue }

            var texX = Int(wallX * Double(texSize))
            if texX >= texSize { texX = texSize - 1 }
            if texX < 0 { texX = 0 }

            let texBase = tile.textureIndex * ppt

            // Lighting: distance attenuation + side darkening + torch
            let baseAtten = max(0.12, 1.0 / (1.0 + 0.15 * perpWallDist * perpWallDist))
            let sideFactor: Double = side == 1 ? 0.72 : 1.0
            let wallWorldX = player.x + perpWallDist * rayDirX
            let wallWorldY = player.y + perpWallDist * rayDirY
            let tb = torchLight(worldX: wallWorldX, worldY: wallWorldY)
            let shade = min(1.0, baseAtten * sideFactor + tb * 0.35)

            let l = Renderer.getLUT(perpWallDist)
            let fog = l.fog
            let drawTop = halfH - lineHeight / 2

            for y in drawStart...drawEnd {
                let texY = min(texSize - 1, max(0, (y - drawTop) * texSize / lineHeight))
                let color = texAtlas[texBase + texY * texSize + texX]
                buf[y * w + x] = Renderer.shadeThenFog(color, shade: shade, fog: fog)
            }
        }
    }

    // MARK: - Sprite Rendering

    private func renderSprites(player: Player, enemies: [Enemy], items: [Item], projectiles: [Projectile]) {
        struct SpriteEntry {
            var x: Double; var y: Double; var dist: Double
            var pixels: [UInt32]; var spriteW: Int; var spriteH: Int; var vOffset: Double
            var scale: Double = 1.0
        }

        var entries: [SpriteEntry] = []

        for enemy in enemies {
            let dx = enemy.x - player.x, dy = enemy.y - player.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist < GameConstants.maxRenderDistance else { continue }
            let sheet = sprites.enemySprites(for: enemy.type)
            let frameIdx = min(enemy.spriteFrameOffset, sheet.frameCount - 1)
            entries.append(SpriteEntry(x: enemy.x, y: enemy.y, dist: dist,
                                       pixels: sheet.frames[frameIdx],
                                       spriteW: sheet.width, spriteH: sheet.height,
                                       vOffset: enemy.deathVOffset))
        }

        for item in items where !item.isCollected {
            let dx = item.x - player.x, dy = item.y - player.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist < GameConstants.maxRenderDistance else { continue }
            let si = min(item.spriteIndex, sprites.itemSprites.frameCount - 1)
            entries.append(SpriteEntry(x: item.x, y: item.y, dist: dist,
                                       pixels: sprites.itemSprites.frames[si],
                                       spriteW: sprites.itemSprites.width, spriteH: sprites.itemSprites.height,
                                       vOffset: 0.15 + sin(item.bobPhase) * 0.05,
                                       scale: 0.4))
        }

        // Projectiles
        for proj in projectiles where proj.lifetime > 0 {
            let dx = proj.x - player.x, dy = proj.y - player.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist < GameConstants.maxRenderDistance else { continue }
            let frameIdx = proj.type == .fireball ? 0 : 1
            let sheet = sprites.projectileSprites
            entries.append(SpriteEntry(x: proj.x, y: proj.y, dist: dist,
                                       pixels: sheet.frames[frameIdx],
                                       spriteW: sheet.width, spriteH: sheet.height,
                                       vOffset: 0.15, scale: 0.3))
        }

        entries.sort { $0.dist > $1.dist }

        let invDet = 1.0 / (player.planeX * player.dirY - player.dirX * player.planeY)
        let w = width, h = height, halfH = h / 2
        let buf = pixelBuffer.rawPixels
        let zBuf = zBuffer

        for entry in entries {
            let sx = entry.x - player.x, sy = entry.y - player.y
            let tX = invDet * (player.dirY * sx - player.dirX * sy)
            let tY = invDet * (-player.planeY * sx + player.planeX * sy)
            guard tY > 0.1 else { continue }

            let invTY = 1.0 / tY
            let screenX = Int(Double(w) * 0.5 * (1.0 + tX * invTY))
            let sH = Int(abs(Double(h) * invTY) * entry.scale)
            let sW = Int(abs(Double(h) * invTY) * Double(entry.spriteW) / Double(entry.spriteH) * entry.scale)
            let vOff = Int(entry.vOffset * Double(h) * invTY)

            let dsy = max(0, halfH - sH / 2 + vOff)
            let dey = min(h - 1, halfH + sH / 2 + vOff)
            let dsx = max(0, screenX - sW / 2)
            let dex = min(w - 1, screenX + sW / 2)
            guard dex >= dsx && dey >= dsy && sW > 0 && sH > 0 else { continue }

            let l = Renderer.getLUT(entry.dist)
            let baseShade = max(0.15, 1.0 / (1.0 + 0.15 * entry.dist * entry.dist))
            let tb = torchLight(worldX: entry.x, worldY: entry.y)
            let shade = min(1.0, baseShade + tb * 0.35)
            let fog = l.fog
            let leftX = screenX - sW / 2
            let topY = halfH - sH / 2 + vOff
            let srcW = entry.spriteW, srcH = entry.spriteH

            entry.pixels.withUnsafeBufferPointer { src in
                for scrX in dsx...dex {
                    guard tY < zBuf[scrX] else { continue }
                    let texX = (scrX - leftX) * srcW / sW
                    guard texX >= 0, texX < srcW else { continue }

                    for scrY in dsy...dey {
                        let texY = (scrY - topY) * srcH / sH
                        guard texY >= 0, texY < srcH else { continue }
                        let si = texY * srcW + texX
                        let pixel = src[si]
                        guard (pixel >> 24) != 0 else { continue }
                        buf[scrY * w + scrX] = Renderer.shadeThenFog(pixel, shade: shade, fog: fog)
                    }
                }
            }
        }
    }

    // MARK: - Weapon Overlay

    private func renderWeapon(player: Player) {
        let sheet = sprites.weaponSprites(for: player.currentWeapon)
        let frameIdx = min(player.weaponState.currentFrame, sheet.frameCount - 1)
        let srcPixels = sheet.frames[frameIdx]

        let destW = width / 2
        let destH = height / 2
        let destX = (width - destW) / 2
        var destY = height - destH
        let bobMult = player.isMoving ? 1.0 : 0.0
        let sprintBob = player.isSprinting ? 2.0 : 1.0
        let bobX = Int(sin(player.bobPhase) * 6 * bobMult * sprintBob)
        let bobY = Int(abs(cos(player.bobPhase)) * 4 * bobMult * sprintBob)

        // Weapon switch animation: drop down then come back up
        if player.weaponState.isSwitching {
            let p = player.weaponState.switchProgress
            // Parabolic drop: goes down for first half, up for second half
            let dropAmount: Double
            if p < 0.5 {
                dropAmount = p * 2.0  // 0..1 going down
            } else {
                dropAmount = (1.0 - p) * 2.0  // 1..0 coming back up
            }
            destY += Int(dropAmount * Double(destH))
        }

        pixelBuffer.drawSprite(srcPixels: srcPixels,
                                srcWidth: sheet.width, srcHeight: sheet.height,
                                destX: destX + bobX, destY: destY + bobY,
                                destWidth: destW, destHeight: destH)
    }
}
