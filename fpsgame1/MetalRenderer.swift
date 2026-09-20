//
//  MetalRenderer.swift
//  testproject
//
//  GPU rendering of the whole frame, presented straight into an MTKView.
//
//  Per frame, one command buffer runs four compute passes over a private
//  low-resolution scene texture: floor/ceiling, walls (which also write the
//  z-buffer), sprites + weapon overlay (z-tested against the walls) and finally a
//  post pass that applies the screen effects and upscales into the drawable.
//  Nothing is read back to the CPU and up to `maxFramesInFlight` frames are
//  encoded ahead, with the per-frame buffers (uniforms, torches, doors, sprite
//  list, post effects) held in a ring so the CPU never writes what the GPU is
//  still reading.
//

import Metal
import MetalKit

// Must match the struct layout in Raycaster.metal
struct RaycastUniforms {
    var playerX: Float
    var playerY: Float
    var dirX: Float
    var dirY: Float
    var planeX: Float
    var planeY: Float
    var renderWidth: Int32
    var renderHeight: Int32
    var texSize: Int32
    var texCount: Int32
    var worldWidth: Int32
    var worldHeight: Int32
    var maxRenderDist: Float
    var fogR: Float
    var fogG: Float
    var fogB: Float
    var torchCount: Int32
    var elapsedTime: Float
    var portalFrame: Int32
}

struct TorchData {
    var x: Float
    var y: Float
}

/// One sprite for the GPU compositor. Must match SpriteInstance in Raycaster.metal.
struct SpriteInstance {
    var x0: Int32 = 0, y0: Int32 = 0, x1: Int32 = 0, y1: Int32 = 0
    var leftX: Int32 = 0, topY: Int32 = 0, sW: Int32 = 0, sH: Int32 = 0
    var atlasOffset: Int32 = 0, srcW: Int32 = 0, srcH: Int32 = 0
    var flags: Int32 = 0
    var depth: Float = 0
    var shade: Float = 1
    var fog: Float = 1
    var pad: Float = 0

    static let depthTest: Int32 = 1
    static let shaded: Int32 = 2
}

/// Must match PostUniforms in Raycaster.metal
struct PostUniforms {
    /// rgb 0...255 and intensity: muzzle, pickup, berserk, fade
    var tints: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    var damageIntensity: Float
    var damageAngle: Float
    var deathProgress: Float
    var hitMarkerAlpha: Float
    var srcW: Int32
    var srcH: Int32
    var pad0: Int32 = 0
    var pad1: Int32 = 0
}

final class MetalRenderer {
    static let maxFramesInFlight = 3
    static let maxSprites = 256
    static let maxTorches = 64
    static let maxTiles = 64 * 64

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let floorCeilingPipeline: MTLComputePipelineState
    private let wallPipeline: MTLComputePipelineState
    private let spritePipeline: MTLComputePipelineState
    private let postPipeline: MTLComputePipelineState

    let width: Int
    let height: Int

    // Static GPU resources
    private let sceneTexture: MTLTexture     // low-res frame before the post pass
    private let texAtlasBuffer: MTLBuffer    // wall/floor/ceiling textures + portal animation frames
    private let spriteAtlasBuffer: MTLBuffer // every sprite frame
    private let worldTilesBuffer: MTLBuffer  // tile ids of the loaded level
    private let zBufferGPU: MTLBuffer        // per-column wall depth, wall kernel → sprite kernel

    // Per-frame ring buffers
    private let uniformsBuffers: [MTLBuffer]
    private let torchBuffers: [MTLBuffer]
    private let doorBuffers: [MTLBuffer]
    private let spriteBuffers: [MTLBuffer]
    private let postBuffers: [MTLBuffer]
    private var frameIndex = 0
    private let inflight = DispatchSemaphore(value: MetalRenderer.maxFramesInFlight)

    private let textures: TextureAtlas
    private let spriteAtlas: SpriteAtlas
    private var uploadedPortalFrames: Set<Int> = []
    private var cachedTorches: [TorchData] = []

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MetalRenderer: Metal is not supported on this device")
            return nil
        }
        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            print("MetalRenderer: failed to create the command queue or load the shader library")
            return nil
        }

        func makePipeline(_ name: String) -> MTLComputePipelineState? {
            guard let function = library.makeFunction(name: name) else {
                print("MetalRenderer: missing kernel \(name)")
                return nil
            }
            do {
                return try device.makeComputePipelineState(function: function)
            } catch {
                print("MetalRenderer: failed to build pipeline \(name): \(error)")
                return nil
            }
        }
        guard let floorCeil = makePipeline("floorCeilingKernel"),
              let wall = makePipeline("wallKernel"),
              let sprite = makePipeline("spriteKernel"),
              let post = makePipeline("postKernel") else { return nil }

        self.device = device
        self.commandQueue = queue
        self.floorCeilingPipeline = floorCeil
        self.wallPipeline = wall
        self.spritePipeline = sprite
        self.postPipeline = post

        width = GameConstants.renderWidth
        height = GameConstants.renderHeight

        let sceneDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        sceneDesc.usage = [.shaderRead, .shaderWrite]
        sceneDesc.storageMode = .private
        guard let scene = device.makeTexture(descriptor: sceneDesc) else { return nil }
        sceneTexture = scene

        // Texture atlas: the base textures followed by one slot per portal animation
        // frame, filled lazily as frames are first shown.
        let textureAtlas = TextureAtlas()
        let ppt = GameConstants.textureSize * GameConstants.textureSize
        let atlasPixels = (textureAtlas.texCount + TextureAtlas.exitPortalFrameCount) * ppt
        guard let atlas = device.makeBuffer(length: atlasPixels * MemoryLayout<UInt32>.stride,
                                            options: .storageModeShared) else { return nil }
        memcpy(atlas.contents(), textureAtlas.atlas, textureAtlas.texCount * ppt * MemoryLayout<UInt32>.stride)
        textures = textureAtlas
        texAtlasBuffer = atlas

        let packedSprites = SpriteAtlas(assets: SpriteAssets.shared)
        guard let spriteBuffer = packedSprites.pixels.withUnsafeBufferPointer({ buf -> MTLBuffer? in
            guard let base = buf.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: buf.count * MemoryLayout<UInt32>.stride,
                                     options: .storageModeShared)
        }) else { return nil }
        spriteAtlas = packedSprites
        spriteAtlasBuffer = spriteBuffer

        guard let tiles = device.makeBuffer(length: Self.maxTiles * MemoryLayout<Int32>.stride,
                                            options: .storageModeShared),
              let zBuf = device.makeBuffer(length: width * MemoryLayout<Float>.stride,
                                           options: .storageModePrivate) else { return nil }
        worldTilesBuffer = tiles
        zBufferGPU = zBuf

        func makeRing(_ length: Int) -> [MTLBuffer]? {
            var ring: [MTLBuffer] = []
            for _ in 0..<Self.maxFramesInFlight {
                guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else { return nil }
                ring.append(buffer)
            }
            return ring
        }
        guard let uniforms = makeRing(MemoryLayout<RaycastUniforms>.stride),
              let torches = makeRing(Self.maxTorches * MemoryLayout<TorchData>.stride),
              let doors = makeRing(Self.maxTiles * MemoryLayout<Float>.stride),
              let spriteList = makeRing(Self.maxSprites * MemoryLayout<SpriteInstance>.stride),
              let posts = makeRing(MemoryLayout<PostUniforms>.stride) else { return nil }
        uniformsBuffers = uniforms
        torchBuffers = torches
        doorBuffers = doors
        spriteBuffers = spriteList
        postBuffers = posts

        print("MetalRenderer: ready (\(device.name), \(Self.maxFramesInFlight) frames in flight)")
    }

    // MARK: - Upload World Data (call once per level)

    func uploadWorldData(world: GameWorld) {
        let tileCount = min(world.width * world.height, Self.maxTiles)
        let ptr = worldTilesBuffer.contents().bindMemory(to: Int32.self, capacity: tileCount)
        for i in 0..<tileCount {
            ptr[i] = Int32(world.tiles1D[i].rawValue)
        }
    }

    // MARK: - Frame

    /// Encode and present one frame into the view's current drawable.
    func draw(in view: MTKView, player: Player, world: GameWorld, enemies: [Enemy], items: [Item],
              projectiles: [Projectile], explosions: [Explosion], elapsedTime: Double, effects: PostEffects) {
        inflight.wait()
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            inflight.signal()
            return
        }
        let slot = frameIndex % Self.maxFramesInFlight
        frameIndex += 1
        currentTime = elapsedTime

        let portalFrame = TextureAtlas.exitPortalFrame(at: elapsedTime)
        ensurePortalFrameUploaded(portalFrame)
        let torchCount = fillTorches(slot: slot, world: world, playerX: player.x, playerY: player.y)
        fillDoors(slot: slot, world: world)
        fillUniforms(slot: slot, player: player, world: world, torchCount: torchCount,
                     portalFrame: portalFrame, elapsedTime: elapsedTime)
        let spriteCount = fillSprites(slot: slot, player: player, enemies: enemies, items: items,
                                      projectiles: projectiles, explosions: explosions)
        fillPost(slot: slot, effects: effects)

        let uniforms = uniformsBuffers[slot]
        let torches = torchBuffers[slot]
        let doors = doorBuffers[slot]
        let sceneGrid = MTLSize(width: width, height: height, depth: 1)
        let group2D = MTLSize(width: 16, height: 16, depth: 1)

        // Pass 1: floor + ceiling
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.label = "floor/ceiling"
            encoder.setComputePipelineState(floorCeilingPipeline)
            encoder.setTexture(sceneTexture, index: 0)
            encoder.setBuffer(texAtlasBuffer, offset: 0, index: 0)
            encoder.setBuffer(uniforms, offset: 0, index: 1)
            encoder.setBuffer(torches, offset: 0, index: 2)
            encoder.setBuffer(worldTilesBuffer, offset: 0, index: 3)
            encoder.dispatchThreads(sceneGrid, threadsPerThreadgroup: group2D)
            encoder.endEncoding()
        }

        // Pass 2: walls (one thread per column), writes the z-buffer
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.label = "walls"
            encoder.setComputePipelineState(wallPipeline)
            encoder.setTexture(sceneTexture, index: 0)
            encoder.setBuffer(texAtlasBuffer, offset: 0, index: 0)
            encoder.setBuffer(uniforms, offset: 0, index: 1)
            encoder.setBuffer(torches, offset: 0, index: 2)
            encoder.setBuffer(worldTilesBuffer, offset: 0, index: 3)
            encoder.setBuffer(zBufferGPU, offset: 0, index: 4)
            encoder.setBuffer(doors, offset: 0, index: 5)
            encoder.dispatchThreads(MTLSize(width: width, height: 1, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: min(64, width), height: 1, depth: 1))
            encoder.endEncoding()
        }

        // Pass 3: sprites + weapon overlay
        if spriteCount > 0, let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.label = "sprites"
            var count = Int32(spriteCount)
            encoder.setComputePipelineState(spritePipeline)
            encoder.setTexture(sceneTexture, index: 0)
            encoder.setBuffer(spriteAtlasBuffer, offset: 0, index: 0)
            encoder.setBuffer(uniforms, offset: 0, index: 1)
            encoder.setBuffer(spriteBuffers[slot], offset: 0, index: 2)
            encoder.setBytes(&count, length: MemoryLayout<Int32>.stride, index: 3)
            encoder.setBuffer(zBufferGPU, offset: 0, index: 4)
            encoder.dispatchThreads(sceneGrid, threadsPerThreadgroup: group2D)
            encoder.endEncoding()
        }

        // Pass 4: screen effects + upscale into the drawable
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.label = "post"
            let target = drawable.texture
            encoder.setComputePipelineState(postPipeline)
            encoder.setTexture(sceneTexture, index: 0)
            encoder.setTexture(target, index: 1)
            encoder.setBuffer(postBuffers[slot], offset: 0, index: 0)
            encoder.dispatchThreads(MTLSize(width: target.width, height: target.height, depth: 1),
                                    threadsPerThreadgroup: group2D)
            encoder.endEncoding()
        }

        let semaphore = inflight
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Per-frame data

    /// Copy a portal animation frame into its atlas slot the first time it is shown.
    /// Frames in flight only read slots that were already uploaded, so this never
    /// races the GPU.
    private func ensurePortalFrameUploaded(_ index: Int) {
        guard !uploadedPortalFrames.contains(index) else { return }
        uploadedPortalFrames.insert(index)
        let ppt = GameConstants.textureSize * GameConstants.textureSize
        let pixels = textures.exitPortalFramePixels(index)
        let slot = textures.texCount + index
        let dest = texAtlasBuffer.contents().advanced(by: slot * ppt * MemoryLayout<UInt32>.stride)
        pixels.withUnsafeBufferPointer { buf in
            memcpy(dest, buf.baseAddress!, min(buf.count, ppt) * MemoryLayout<UInt32>.stride)
        }
    }

    private func fillUniforms(slot: Int, player: Player, world: GameWorld, torchCount: Int,
                              portalFrame: Int, elapsedTime: Double) {
        var uniforms = RaycastUniforms(
            playerX: Float(player.x),
            playerY: Float(player.y),
            dirX: Float(player.dirX),
            dirY: Float(player.dirY),
            planeX: Float(player.planeX),
            planeY: Float(player.planeY),
            renderWidth: Int32(width),
            renderHeight: Int32(height),
            texSize: Int32(GameConstants.textureSize),
            texCount: Int32(textures.texCount),
            worldWidth: Int32(world.width),
            worldHeight: Int32(world.height),
            maxRenderDist: Float(GameConstants.maxRenderDistance),
            fogR: Self.fogR,
            fogG: Self.fogG,
            fogB: Self.fogB,
            torchCount: Int32(torchCount),
            elapsedTime: Float(elapsedTime),
            portalFrame: Int32(portalFrame)
        )
        memcpy(uniformsBuffers[slot].contents(), &uniforms, MemoryLayout<RaycastUniforms>.stride)
    }

    private func fillDoors(slot: Int, world: GameWorld) {
        let totalTiles = min(world.width * world.height, Self.maxTiles)
        let ptr = doorBuffers[slot].contents().bindMemory(to: Float.self, capacity: totalTiles)
        memset(ptr, 0, totalTiles * MemoryLayout<Float>.stride)
        for door in world.doors {
            let idx = door.tileY * world.width + door.tileX
            if idx >= 0 && idx < totalTiles {
                ptr[idx] = Float(door.openAmount)
            }
        }
    }

    /// Collect the torches near the player into this frame's buffer; returns the count
    private func fillTorches(slot: Int, world: GameWorld, playerX: Double, playerY: Double) -> Int {
        cachedTorches.removeAll(keepingCapacity: true)
        let cx = Int(playerX)
        let cy = Int(playerY)
        let r = 5
        for ty in max(0, cy - r)...min(world.height - 1, cy + r) {
            for tx in max(0, cx - r)...min(world.width - 1, cx + r) {
                if world.tileAt(x: tx, y: ty) == .brickTorch {
                    cachedTorches.append(TorchData(x: Float(tx) + 0.5, y: Float(ty) + 0.5))
                }
            }
        }
        let count = min(cachedTorches.count, Self.maxTorches)
        let ptr = torchBuffers[slot].contents().bindMemory(to: TorchData.self, capacity: Self.maxTorches)
        for i in 0..<count {
            ptr[i] = cachedTorches[i]
        }
        return count
    }

    private func fillPost(slot: Int, effects: PostEffects) {
        func tint(_ c: (r: Double, g: Double, b: Double), _ intensity: Double) -> SIMD4<Float> {
            SIMD4<Float>(Float(c.r), Float(c.g), Float(c.b), Float(intensity))
        }
        var post = PostUniforms(
            tints: (tint(PostEffects.muzzleColor, effects.muzzleFlash),
                    tint(PostEffects.pickupColor, effects.pickupFlash),
                    tint(PostEffects.berserkColor, effects.berserkTint),
                    tint((r: 0, g: 0, b: 0), effects.fadeToBlack)),
            damageIntensity: Float(effects.damageIntensity),
            damageAngle: Float(PostEffects.normalizedDamageAngle(direction: effects.damageDirection,
                                                                  playerAngle: effects.playerAngle)),
            deathProgress: Float(effects.deathProgress),
            hitMarkerAlpha: Float(effects.hitMarkerAlpha),
            srcW: Int32(width),
            srcH: Int32(height)
        )
        memcpy(postBuffers[slot].contents(), &post, MemoryLayout<PostUniforms>.stride)
    }

    // MARK: - Sprite list

    private struct Candidate {
        var dist: Double
        var instance: SpriteInstance
    }

    /// Project every visible sprite to the screen and write the list, nearest first,
    /// with the weapon overlay in front. Returns the number of instances written.
    private func fillSprites(slot: Int, player: Player, enemies: [Enemy], items: [Item],
                             projectiles: [Projectile], explosions: [Explosion]) -> Int {
        var candidates: [Candidate] = []
        candidates.reserveCapacity(enemies.count + items.count + projectiles.count + explosions.count)

        let w = width, h = height, halfH = h / 2
        let invDet = 1.0 / (player.planeX * player.dirY - player.dirX * player.planeY)

        func add(x: Double, y: Double, location: SpriteAtlas.FrameLocation,
                 vOffset: Double, scale: Double, fullBright: Bool) {
            let dx = x - player.x, dy = y - player.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist < GameConstants.maxRenderDistance else { return }

            let tX = invDet * (player.dirY * dx - player.dirX * dy)
            let tY = invDet * (-player.planeY * dx + player.planeX * dy)
            guard tY > 0.1 else { return }

            let invTY = 1.0 / tY
            let screenX = Int(Double(w) * 0.5 * (1.0 + tX * invTY))
            let sH = Int(abs(Double(h) * invTY) * scale)
            let sW = Int(abs(Double(h) * invTY) * Double(location.width) / Double(location.height) * scale)
            let vOff = Int(vOffset * Double(h) * invTY)

            let dsy = max(0, halfH - sH / 2 + vOff)
            let dey = min(h - 1, halfH + sH / 2 + vOff)
            let dsx = max(0, screenX - sW / 2)
            let dex = min(w - 1, screenX + sW / 2)
            guard dex >= dsx && dey >= dsy && sW > 0 && sH > 0 else { return }

            let baseShade = max(0.15, 1.0 / (1.0 + 0.15 * dist * dist))
            let fog = max(0.0, min(1.0, exp(-0.08 * dist * dist)))
            let tb = torchLight(worldX: x, worldY: y)
            let shade = fullBright ? 1.0 : min(1.0, baseShade + tb * 0.35)

            var inst = SpriteInstance()
            inst.x0 = Int32(dsx); inst.x1 = Int32(dex)
            inst.y0 = Int32(dsy); inst.y1 = Int32(dey)
            inst.leftX = Int32(screenX - sW / 2)
            inst.topY = Int32(halfH - sH / 2 + vOff)
            inst.sW = Int32(sW); inst.sH = Int32(sH)
            inst.atlasOffset = Int32(location.offset)
            inst.srcW = Int32(location.width); inst.srcH = Int32(location.height)
            inst.flags = SpriteInstance.depthTest | SpriteInstance.shaded
            inst.depth = Float(tY)
            inst.shade = Float(shade)
            inst.fog = Float(fog)
            candidates.append(Candidate(dist: dist, instance: inst))
        }

        for enemy in enemies {
            let id = SpriteSheetID.enemy(enemy.type)
            let location = spriteAtlas.location(id, frame: enemy.spriteFrameOffset)
            let scale = enemy.type.spriteScale
            // Bigger enemies are raised so their feet stay on the floor line
            add(x: enemy.x, y: enemy.y, location: location,
                vOffset: enemy.deathVOffset + (1.0 - scale) / 2.0, scale: scale, fullBright: false)
        }
        for item in items where !item.isCollected {
            let location = spriteAtlas.location(.items, frame: item.spriteIndex)
            add(x: item.x, y: item.y, location: location,
                vOffset: 0.15 + sin(item.bobPhase) * 0.05, scale: 0.4, fullBright: false)
        }
        for proj in projectiles where proj.lifetime > 0 {
            let location = spriteAtlas.location(.projectiles, frame: proj.type.spriteFrame)
            add(x: proj.x, y: proj.y, location: location, vOffset: 0.15, scale: 0.3, fullBright: true)
        }
        let explosionFrames = spriteAtlas.frameCount(.explosions)
        for explosion in explosions {
            let frame = min(explosionFrames - 1, Int(explosion.progress * Double(explosionFrames)))
            let location = spriteAtlas.location(.explosions, frame: frame)
            add(x: explosion.x, y: explosion.y, location: location, vOffset: 0.05, scale: 1.2, fullBright: true)
        }

        // Nearest first: the kernel keeps the first opaque texel that passes the z test
        candidates.sort { $0.dist < $1.dist }

        let ptr = spriteBuffers[slot].contents().bindMemory(to: SpriteInstance.self, capacity: Self.maxSprites)
        var count = 0
        ptr[count] = weaponInstance(player: player)
        count += 1
        for candidate in candidates where count < Self.maxSprites {
            ptr[count] = candidate.instance
            count += 1
        }
        return count
    }

    /// The weapon overlay as a sprite in front of everything, unshaded and unfogged
    private func weaponInstance(player: Player) -> SpriteInstance {
        let id = SpriteSheetID.weapon(player.currentWeapon)
        let location = spriteAtlas.location(id, frame: player.weaponState.currentFrame)

        let destW = width / 2
        let destH = height / 2
        var destX = (width - destW) / 2
        var destY = height - destH
        let bobMult = player.isMoving ? 1.0 : 0.0
        let sprintBob = player.isSprinting ? 2.0 : 1.0
        destX += Int(sin(player.bobPhase) * 6 * bobMult * sprintBob)
        destY += Int(abs(cos(player.bobPhase)) * 4 * bobMult * sprintBob)

        if player.weaponState.isSwitching {
            let p = player.weaponState.switchProgress
            let dropAmount: Double = p < 0.5 ? p * 2.0 : (1.0 - p) * 2.0
            destY += Int(dropAmount * Double(destH))
        }

        var inst = SpriteInstance()
        inst.x0 = Int32(max(0, destX)); inst.x1 = Int32(min(width - 1, destX + destW - 1))
        inst.y0 = Int32(max(0, destY)); inst.y1 = Int32(min(height - 1, destY + destH - 1))
        inst.leftX = Int32(destX); inst.topY = Int32(destY)
        inst.sW = Int32(destW); inst.sH = Int32(destH)
        inst.atlasOffset = Int32(location.offset)
        inst.srcW = Int32(location.width); inst.srcH = Int32(location.height)
        inst.flags = 0
        return inst
    }

    // MARK: - Lighting helpers (CPU side, for sprite shading)

    private static let fogR: Float = 10
    private static let fogG: Float = 8
    private static let fogB: Float = 15

    /// Elapsed game time of the frame being encoded (torch flicker phase)
    private var currentTime: Double = 0

    private func torchLight(worldX: Double, worldY: Double) -> Double {
        var light = 0.0
        let t = currentTime
        for torch in cachedTorches {
            let dx = worldX - Double(torch.x)
            let dy = worldY - Double(torch.y)
            let distSq = dx * dx + dy * dy
            if distSq < 16.0 {
                let phase = Double(torch.x) * 3.0 + Double(torch.y) * 7.0
                let flicker = 0.8 + 0.2 * sin(t * 8.0 + phase)
                light += 1.2 * flicker / (1.0 + distSq * 0.8)
            }
        }
        return min(light, 1.5)
    }
}
