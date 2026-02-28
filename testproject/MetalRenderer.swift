//
//  MetalRenderer.swift
//  testproject
//
//  GPU-accelerated raycasting via Metal compute shaders.
//  Handles walls, floor, and ceiling on GPU.
//  Sprites and weapon overlay remain on CPU and are composited afterward.
//
//  Supports Metal 4 API when available, with fallback to Metal 3.
//

import Metal
import MetalKit
import AppKit

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
}

struct TorchData {
    var x: Float
    var y: Float
}

final class MetalRenderer {
    let device: MTLDevice
    let floorCeilingPipeline: MTLComputePipelineState
    let wallPipeline: MTLComputePipelineState

    let width: Int
    let height: Int

    // Metal 4 support flag
    let useMetal4: Bool

    // Metal 3 command queue (fallback)
    let commandQueue: MTLCommandQueue

    // Metal 4 infrastructure (stored as Any? for backward compatibility)
    private var mtl4Queue: Any?
    private var mtl4CommandBuffer: Any?
    private var mtl4Allocator: Any?
    private var floorCeilArgTable: Any?
    private var wallArgTable: Any?
    private var syncEvent: (any MTLSharedEvent)?
    private var syncEventValue: UInt64 = 0
    private var eventListener: MTLSharedEventListener?

    // GPU resources
    var outTexture: MTLTexture
    var texAtlasBuffer: MTLBuffer       // Texture atlas (all wall/floor/ceiling textures)
    var uniformsBuffer: MTLBuffer       // Per-frame uniforms
    var torchBuffer: MTLBuffer          // Torch positions
    var worldTilesBuffer: MTLBuffer     // World tile data (int array)
    var zBufferGPU: MTLBuffer           // Z-buffer output from wall kernel
    var doorOpenBuffer: MTLBuffer       // Door open amounts

    // CPU-side z-buffer mirror (for sprite occlusion on CPU)
    var zBuffer: UnsafeMutablePointer<Float>

    // CPU pixel buffer for sprite/weapon overlay compositing
    var pixelBuffer: PixelBuffer
    let textures: TextureAtlas
    let sprites: SpriteAssets

    // Cached torch data
    private var cachedTorches: [TorchData] = []
    private var currentTime: Double = 0

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        self.device = device

        // Detect Metal 4 support
        // Note: Metal 4 compute dispatch with argument tables requires shader
        // recompilation targeting Metal 4. The existing shaders compiled for Metal 3
        // use the legacy setBuffer/setTexture binding model. Until the shaders are
        // updated, we use the Metal 3 path which works with both Metal 3 and Metal 4 hardware.
        var metal4Supported = false
        if #available(macOS 26.0, *) {
            // metal4Supported = device.supportsFamily(.metal4)
            // TODO: Enable Metal 4 path once shaders are recompiled for Metal 4 argument tables
            metal4Supported = false
        }
        self.useMetal4 = metal4Supported

        // Always create Metal 3 command queue (needed for fallback and shared use)
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        // Load shaders
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to load Metal library")
            return nil
        }

        guard let floorCeilFunc = library.makeFunction(name: "floorCeilingKernel"),
              let wallFunc = library.makeFunction(name: "wallKernel") else {
            print("Failed to find Metal kernel functions")
            return nil
        }

        do {
            floorCeilingPipeline = try device.makeComputePipelineState(function: floorCeilFunc)
            wallPipeline = try device.makeComputePipelineState(function: wallFunc)
        } catch {
            print("Failed to create compute pipeline: \(error)")
            return nil
        }

        width = GameConstants.renderWidth
        height = GameConstants.renderHeight

        // Output texture (BGRA8Unorm for easy conversion to CGImage)
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width, height: height,
            mipmapped: false
        )
        texDesc.usage = [.shaderWrite, .shaderRead]
        texDesc.storageMode = .managed
        guard let tex = device.makeTexture(descriptor: texDesc) else { return nil }
        self.outTexture = tex

        // Texture atlas buffer
        textures = TextureAtlas()
        let atlasSize = textures.texCount * GameConstants.textureSize * GameConstants.textureSize
        guard let atlasBuffer = device.makeBuffer(
            bytes: textures.atlas,
            length: atlasSize * MemoryLayout<UInt32>.size,
            options: .storageModeShared
        ) else { return nil }
        self.texAtlasBuffer = atlasBuffer

        // Uniforms buffer
        guard let uniBuffer = device.makeBuffer(
            length: MemoryLayout<RaycastUniforms>.size,
            options: .storageModeShared
        ) else { return nil }
        self.uniformsBuffer = uniBuffer

        // Torch buffer (max 64 torches)
        guard let tBuffer = device.makeBuffer(
            length: 64 * MemoryLayout<TorchData>.size,
            options: .storageModeShared
        ) else { return nil }
        self.torchBuffer = tBuffer

        // World tiles buffer (max 64x64 = 4096 tiles)
        let maxTiles = 64 * 64
        guard let wBuffer = device.makeBuffer(
            length: maxTiles * MemoryLayout<Int32>.size,
            options: .storageModeShared
        ) else { return nil }
        self.worldTilesBuffer = wBuffer

        // Z-buffer (one float per column)
        guard let zBuf = device.makeBuffer(
            length: width * MemoryLayout<Float>.size,
            options: .storageModeShared
        ) else { return nil }
        self.zBufferGPU = zBuf

        // Door open amounts (one float per tile)
        guard let doorBuf = device.makeBuffer(
            length: maxTiles * MemoryLayout<Float>.size,
            options: .storageModeShared
        ) else { return nil }
        self.doorOpenBuffer = doorBuf

        // CPU z-buffer for sprite rendering
        zBuffer = .allocate(capacity: width)
        zBuffer.initialize(repeating: Float.infinity, count: width)

        // CPU pixel buffer for sprite/weapon overlay
        pixelBuffer = PixelBuffer(width: width, height: height)
        sprites = SpriteAssets.shared

        // Initialize Metal 4 infrastructure if supported
        if metal4Supported {
            if #available(macOS 26.0, *) {
                setupMetal4()
            }
        }

        if useMetal4 && mtl4Queue != nil {
            print("MetalRenderer: Using Metal 4 API")
        } else {
            print("MetalRenderer: Using Metal 3 API (fallback)")
        }
    }

    deinit {
        zBuffer.deallocate()
    }

    // MARK: - Metal 4 Setup

    @available(macOS 26.0, *)
    private func setupMetal4() {
        // Create Metal 4 command queue
        mtl4Queue = device.makeMTL4CommandQueue()

        // Create reusable command buffer (Metal 4 creates from device, not queue)
        mtl4CommandBuffer = (device as MTLDevice).makeCommandBuffer() as (any MTL4CommandBuffer)?

        // Create command allocator for encoding memory management
        mtl4Allocator = device.makeCommandAllocator()

        // Create shared event for CPU-GPU synchronization
        syncEvent = device.makeSharedEvent()
        eventListener = MTLSharedEventListener(dispatchQueue: DispatchQueue(label: "metal4.sync"))

        // Create argument tables for floor/ceiling kernel
        // Floor/ceiling kernel uses: texture(0), buffer(0)=atlas, buffer(1)=uniforms, buffer(2)=torches
        do {
            let fcDesc = MTL4ArgumentTableDescriptor()
            fcDesc.maxBufferBindCount = 3
            fcDesc.maxTextureBindCount = 1
            floorCeilArgTable = try device.makeArgumentTable(descriptor: fcDesc)
        } catch {
            print("Failed to create floor/ceiling argument table: \(error)")
        }

        // Create argument tables for wall kernel
        // Wall kernel uses: texture(0), buffer(0)=atlas, buffer(1)=uniforms, buffer(2)=torches,
        //                   buffer(3)=worldTiles, buffer(4)=zBuffer, buffer(5)=doorOpenAmounts
        do {
            let wallDesc = MTL4ArgumentTableDescriptor()
            wallDesc.maxBufferBindCount = 6
            wallDesc.maxTextureBindCount = 1
            wallArgTable = try device.makeArgumentTable(descriptor: wallDesc)
        } catch {
            print("Failed to create wall argument table: \(error)")
        }
    }

    // MARK: - Upload World Data (call once per level)

    func uploadWorldData(world: GameWorld) {
        let tileCount = world.width * world.height
        let ptr = worldTilesBuffer.contents().bindMemory(to: Int32.self, capacity: tileCount)
        for i in 0..<tileCount {
            ptr[i] = Int32(world.tiles1D[i].rawValue)
        }
    }

    // MARK: - Render Frame

    func render(player: Player, world: GameWorld, enemies: [Enemy], items: [Item], projectiles: [Projectile] = [], elapsedTime: Double = 0) {
        currentTime = elapsedTime

        // Update door open amounts
        updateDoorBuffer(world: world)

        // Find nearby torches
        updateTorchBuffer(world: world, playerX: player.x, playerY: player.y)

        // Update uniforms
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
            fogR: 10.0,
            fogG: 8.0,
            fogB: 15.0,
            torchCount: Int32(cachedTorches.count),
            elapsedTime: Float(elapsedTime)
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<RaycastUniforms>.size)

        // Dispatch to Metal 4 or Metal 3 path
        if #available(macOS 26.0, *),
           useMetal4,
           let queue = mtl4Queue as? any MTL4CommandQueue,
           let cmdBuf = mtl4CommandBuffer as? any MTL4CommandBuffer,
           let allocator = mtl4Allocator as? any MTL4CommandAllocator {
            renderMetal4(queue: queue, commandBuffer: cmdBuf, allocator: allocator)
        } else {
            renderMetal3()
        }

        // Copy GPU output texture to CPU pixel buffer
        copyTextureToPixelBuffer()

        // Copy GPU z-buffer to CPU for sprite occlusion
        let gpuZPtr = zBufferGPU.contents().bindMemory(to: Float.self, capacity: width)
        memcpy(zBuffer, gpuZPtr, width * MemoryLayout<Float>.size)

        // CPU passes: sprites + weapon overlay
        renderSprites(player: player, enemies: enemies, items: items, projectiles: projectiles)
        renderWeapon(player: player)
    }

    // MARK: - Metal 4 Render Path

    @available(macOS 26.0, *)
    private func renderMetal4(queue: any MTL4CommandQueue, commandBuffer: any MTL4CommandBuffer, allocator: any MTL4CommandAllocator) {
        // Reset allocator for reuse (safe because previous frame is complete)
        allocator.reset()

        // Begin encoding into the reusable command buffer
        commandBuffer.beginCommandBuffer(allocator: allocator)

        // Update argument tables with current resource bindings
        // Textures use gpuResourceID, buffers use gpuAddress with setAddress
        let texResID = outTexture.gpuResourceID
        let atlasAddr = texAtlasBuffer.gpuAddress
        let uniformsAddr = uniformsBuffer.gpuAddress
        let torchAddr = torchBuffer.gpuAddress
        let worldAddr = worldTilesBuffer.gpuAddress
        let zBufAddr = zBufferGPU.gpuAddress
        let doorAddr = doorOpenBuffer.gpuAddress

        if let fcTable = floorCeilArgTable as? any MTL4ArgumentTable {
            fcTable.setTexture(texResID, index: 0)
            fcTable.setAddress(atlasAddr, index: 0)
            fcTable.setAddress(uniformsAddr, index: 1)
            fcTable.setAddress(torchAddr, index: 2)
            fcTable.setAddress(worldAddr, index: 3)
        }

        if let wTable = wallArgTable as? any MTL4ArgumentTable {
            wTable.setTexture(texResID, index: 0)
            wTable.setAddress(atlasAddr, index: 0)
            wTable.setAddress(uniformsAddr, index: 1)
            wTable.setAddress(torchAddr, index: 2)
            wTable.setAddress(worldAddr, index: 3)
            wTable.setAddress(zBufAddr, index: 4)
            wTable.setAddress(doorAddr, index: 5)
        }

        // Pass 1: Floor + Ceiling
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(floorCeilingPipeline)
            if let fcTable = floorCeilArgTable as? any MTL4ArgumentTable {
                encoder.setArgumentTable(fcTable)
            }

            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let gridSize = MTLSize(width: width, height: height, depth: 1)
            encoder.dispatchThreads(threadsPerGrid: gridSize, threadsPerThreadgroup: threadGroupSize)
            encoder.endEncoding()
        }

        // Pass 2: Walls (one thread per column)
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(wallPipeline)
            if let wTable = wallArgTable as? any MTL4ArgumentTable {
                encoder.setArgumentTable(wTable)
            }

            let threadGroupSize = MTLSize(width: min(64, width), height: 1, depth: 1)
            let gridSize = MTLSize(width: width, height: 1, depth: 1)
            encoder.dispatchThreads(threadsPerGrid: gridSize, threadsPerThreadgroup: threadGroupSize)

            // Metal 4: use compute encoder for CPU access optimization (replaces blit synchronize)
            encoder.optimizeContents(forCPUAccess: outTexture, slice: 0, level: 0)
            encoder.endEncoding()
        }

        // End command buffer encoding
        commandBuffer.endCommandBuffer()

        // Commit and wait using shared event
        syncEventValue += 1
        queue.commit([commandBuffer])
        queue.signalEvent(syncEvent!, value: syncEventValue)

        // Wait for completion on CPU
        // Use shared event notification to block until GPU is done
        let semaphore = DispatchSemaphore(value: 0)
        let targetValue = syncEventValue
        syncEvent!.notify(eventListener!, atValue: targetValue) { _, _ in
            semaphore.signal()
        }
        semaphore.wait()
    }

    // MARK: - Metal 3 Render Path (Fallback)

    private func renderMetal3() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Pass 1: Floor + Ceiling
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(floorCeilingPipeline)
            encoder.setTexture(outTexture, index: 0)
            encoder.setBuffer(texAtlasBuffer, offset: 0, index: 0)
            encoder.setBuffer(uniformsBuffer, offset: 0, index: 1)
            encoder.setBuffer(torchBuffer, offset: 0, index: 2)
            encoder.setBuffer(worldTilesBuffer, offset: 0, index: 3)

            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let gridSize = MTLSize(width: width, height: height, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            encoder.endEncoding()
        }

        // Pass 2: Walls (one thread per column)
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(wallPipeline)
            encoder.setTexture(outTexture, index: 0)
            encoder.setBuffer(texAtlasBuffer, offset: 0, index: 0)
            encoder.setBuffer(uniformsBuffer, offset: 0, index: 1)
            encoder.setBuffer(torchBuffer, offset: 0, index: 2)
            encoder.setBuffer(worldTilesBuffer, offset: 0, index: 3)
            encoder.setBuffer(zBufferGPU, offset: 0, index: 4)
            encoder.setBuffer(doorOpenBuffer, offset: 0, index: 5)

            let threadGroupSize = MTLSize(width: min(64, width), height: 1, depth: 1)
            let gridSize = MTLSize(width: width, height: 1, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            encoder.endEncoding()
        }

        // Synchronize managed texture for CPU read
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.synchronize(texture: outTexture, slice: 0, level: 0)
            blitEncoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    // MARK: - Copy GPU Texture to CPU Pixel Buffer

    private func copyTextureToPixelBuffer() {
        let bytesPerRow = width * 4
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: width, height: height, depth: 1))
        outTexture.getBytes(pixelBuffer.rawPixels, bytesPerRow: bytesPerRow,
                            from: region, mipmapLevel: 0)
    }

    // MARK: - Door Buffer Update

    private func updateDoorBuffer(world: GameWorld) {
        let totalTiles = world.width * world.height
        let ptr = doorOpenBuffer.contents().bindMemory(to: Float.self, capacity: totalTiles)
        // Zero out (all doors closed by default)
        memset(ptr, 0, totalTiles * MemoryLayout<Float>.size)
        // Set open amounts for doors
        for door in world.doors {
            let idx = door.tileY * world.width + door.tileX
            if idx >= 0 && idx < totalTiles {
                ptr[idx] = Float(door.openAmount)
            }
        }
    }

    // MARK: - Torch Buffer Update

    private func updateTorchBuffer(world: GameWorld, playerX: Double, playerY: Double) {
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

        let maxTorches = min(cachedTorches.count, 64)
        let ptr = torchBuffer.contents().bindMemory(to: TorchData.self, capacity: 64)
        for i in 0..<maxTorches {
            ptr[i] = cachedTorches[i]
        }
    }

    // MARK: - Sprite Rendering (CPU — same logic as original Renderer)

    private func renderSprites(player: Player, enemies: [Enemy], items: [Item], projectiles: [Projectile]) {
        struct SpriteEntry {
            var x: Double; var y: Double; var dist: Double
            var pixels: [UInt32]; var spriteW: Int; var spriteH: Int; var vOffset: Double
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
                                       vOffset: 0.15 + sin(item.bobPhase) * 0.05))
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
                                       vOffset: 0.15))
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
            let sH = Int(abs(Double(h) * invTY))
            let sW = Int(abs(Double(h) * invTY) * Double(entry.spriteW) / Double(entry.spriteH))
            let vOff = Int(entry.vOffset * Double(h) * invTY)

            let dsy = max(0, halfH - sH / 2 + vOff)
            let dey = min(h - 1, halfH + sH / 2 + vOff)
            let dsx = max(0, screenX - sW / 2)
            let dex = min(w - 1, screenX + sW / 2)
            guard dex >= dsx && dey >= dsy && sW > 0 && sH > 0 else { continue }

            // Shade + fog for sprite (including torch light)
            let dist = entry.dist
            let baseShade = max(0.15, 1.0 / (1.0 + 0.15 * dist * dist))
            let density = 0.08
            let fog = max(0.0, min(1.0, exp(-density * dist * dist)))
            let tb = spriteTorchLight(worldX: entry.x, worldY: entry.y)
            let shade = min(1.0, baseShade + tb * 0.35)

            let leftX = screenX - sW / 2
            let topY = halfH - sH / 2 + vOff
            let srcW = entry.spriteW, srcH = entry.spriteH

            entry.pixels.withUnsafeBufferPointer { src in
                for scrX in dsx...dex {
                    guard Float(tY) < zBuf[scrX] else { continue }
                    let texX = (scrX - leftX) * srcW / sW
                    guard texX >= 0, texX < srcW else { continue }

                    for scrY in dsy...dey {
                        let texY = (scrY - topY) * srcH / sH
                        guard texY >= 0, texY < srcH else { continue }
                        let si = texY * srcW + texX
                        let pixel = src[si]
                        guard (pixel >> 24) != 0 else { continue }
                        buf[scrY * w + scrX] = Self.shadeThenFog(pixel, shade: shade, fog: fog)
                    }
                }
            }
        }
    }

    // MARK: - Weapon Overlay (CPU)

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

        if player.weaponState.isSwitching {
            let p = player.weaponState.switchProgress
            let dropAmount: Double = p < 0.5 ? p * 2.0 : (1.0 - p) * 2.0
            destY += Int(dropAmount * Double(destH))
        }

        pixelBuffer.drawSprite(srcPixels: srcPixels,
                                srcWidth: sheet.width, srcHeight: sheet.height,
                                destX: destX + bobX, destY: destY + bobY,
                                destWidth: destW, destHeight: destH)
    }

    // MARK: - Torch light for sprites (CPU)

    private func spriteTorchLight(worldX: Double, worldY: Double) -> Double {
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

    // MARK: - CPU shade+fog helper (for sprites)

    private static let fogRf: Float = 10.0
    private static let fogGf: Float = 8.0
    private static let fogBf: Float = 15.0

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
}
