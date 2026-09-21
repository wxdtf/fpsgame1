//
//  Raycaster.metal
//  testproject
//
//  Metal compute kernels for the whole frame:
//    floorCeilingKernel  – textured floor and ceiling with distance fog
//    wallKernel          – DDA raycast per column, writes the z-buffer
//    spriteKernel        – enemies, items, projectiles, explosions and the weapon
//                          overlay, z-tested against the walls
//    postKernel          – screen tints, damage / death effects, hit marker and the
//                          nearest-neighbour upscale into the drawable
//

#include <metal_stdlib>
using namespace metal;

// Must match Swift-side struct layout
struct RaycastUniforms {
    float playerX;
    float playerY;
    float dirX;
    float dirY;
    float planeX;
    float planeY;
    int renderWidth;
    int renderHeight;
    int texSize;
    int texCount;
    int worldWidth;
    int worldHeight;
    float maxRenderDist;
    float fogR;
    float fogG;
    float fogB;
    // Torch data
    int torchCount;
    float elapsedTime;
    // Which sampled frame of the exit portal animation to draw (stored after the
    // texCount base textures in the atlas)
    int portalFrame;
};

struct TorchData {
    float x;
    float y;
};

// One sprite to composite. Must match SpriteInstance in MetalRenderer.swift.
struct SpriteInstance {
    int x0, y0, x1, y1;          // clipped screen rect, inclusive
    int leftX, topY, sW, sH;     // unclipped origin and size, for texel mapping
    int atlasOffset, srcW, srcH; // frame location in the sprite atlas
    int flags;
    float depth;                 // camera-space depth for the z test
    float shade;
    float fog;
    float pad;
};
constant int kSpriteDepthTest = 1;
constant int kSpriteShaded = 2;
constant int kSpriteFlipX = 4;     // draw the frame mirrored (other-side rotations)

// Must match PostUniforms in MetalRenderer.swift
struct PostUniforms {
    float4 tints[4];            // rgb 0..255 + intensity; muzzle, pickup, berserk, fade
    float damageIntensity;
    float damageAngle;          // relative angle of the hit in [0, 2pi): 0 behind, pi front
    float deathProgress;
    float hitMarkerAlpha;
    int srcW;
    int srcH;
    int pixelScale;             // scene pixels per 480x300 design pixel
    int pad1;
};

// Shade + fog in one step. The atlas stores 0xAARRGGBB; the texture is written as
// ordinary RGBA (Metal swizzles to the bgra8Unorm storage itself).
inline float4 shadeThenFog(uint color, float shade, float fog, float fogR, float fogG, float fogB) {
    float r = float((color >> 16) & 0xFF) * shade;
    float g = float((color >> 8) & 0xFF) * shade;
    float b = float(color & 0xFF) * shade;
    float invFog = 1.0 - fog;
    r = r * fog + fogR * invFog;
    g = g * fog + fogG * invFog;
    b = b * fog + fogB * invFog;
    return float4(r / 255.0, g / 255.0, b / 255.0, 1.0);
}

// Distance-based shade/fog LUT equivalent
inline float3 getLighting(float distance) {
    float shade = max(0.08f, 1.0f / (1.0f + 0.2f * distance * distance));
    float density = 0.08f;
    float fog = max(0.0f, min(1.0f, exp(-density * distance * distance)));
    float ceilShade = shade * 0.65f;
    return float3(shade, fog, ceilShade);
}

// Torch light contribution with flicker
inline float torchLight(float worldX, float worldY,
                        device const TorchData* torches,
                        int torchCount, float elapsedTime) {
    float light = 0.0;
    for (int i = 0; i < torchCount; i++) {
        float dx = worldX - torches[i].x;
        float dy = worldY - torches[i].y;
        float distSq = dx * dx + dy * dy;
        if (distSq < 16.0) {
            // Flicker: each torch has a unique phase based on its position
            float phase = torches[i].x * 3.0 + torches[i].y * 7.0;
            float flicker = 0.8 + 0.2 * sin(elapsedTime * 8.0 + phase);
            light += 1.2 * flicker / (1.0 + distSq * 0.8);
        }
    }
    return min(light, 1.5f);
}

// MARK: - Floor/Ceiling kernel
// Each thread handles one pixel (x, y) where y > halfH (floor) or y < halfH (ceiling)
kernel void floorCeilingKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    device const uint* texAtlas [[buffer(0)]],
    device const RaycastUniforms& uniforms [[buffer(1)]],
    device const TorchData* torches [[buffer(2)]],
    device const int* worldTiles [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    int x = int(gid.x);
    int y = int(gid.y);
    int w = uniforms.renderWidth;
    int h = uniforms.renderHeight;
    if (x >= w || y >= h) return;

    int halfH = h / 2;
    int texSize = uniforms.texSize;
    int texMask = texSize - 1;
    int ppt = texSize * texSize;
    int floorOff = 4 * ppt;   // TextureAtlas.floor = 4
    int ceilOff = 5 * ppt;    // TextureAtlas.ceiling = 5

    // Horizon rows (halfH and halfH-1) are not covered by floor/ceiling mirroring.
    // Fill them with fog color.
    if (y == halfH || y == halfH - 1) {
        float4 fogColor = float4(uniforms.fogR / 255.0, uniforms.fogG / 255.0, uniforms.fogB / 255.0, 1.0);
        outTexture.write(fogColor, uint2(x, y));
        return;
    }

    // Only process floor rows (y > halfH)
    if (y < halfH) {
        // Ceiling rows are written by corresponding floor rows via mirroring
        return;
    }

    float rayDirX0 = uniforms.dirX - uniforms.planeX;
    float rayDirY0 = uniforms.dirY - uniforms.planeY;
    float rdxDiff = (uniforms.dirX + uniforms.planeX) - rayDirX0;
    float rdyDiff = (uniforms.dirY + uniforms.planeY) - rayDirY0;
    float invW = 1.0 / float(w);
    float dHalfH = float(halfH);

    float rowDist = dHalfH / float(y - halfH);

    float fStepX = rowDist * rdxDiff * invW;
    float fStepY = rowDist * rdyDiff * invW;
    float floorX = uniforms.playerX + rowDist * rayDirX0 + float(x) * fStepX;
    float floorY = uniforms.playerY + rowDist * rayDirY0 + float(x) * fStepY;

    float3 lighting = getLighting(rowDist);
    float fog = lighting.y;
    // Torches light the floor and ceiling around them like they light the walls
    float tb = torchLight(floorX, floorY, torches, uniforms.torchCount, uniforms.elapsedTime);
    float floorShade = min(1.0f, lighting.x + tb * 0.35f);
    float ceilShade = min(1.0f, lighting.z + tb * 0.25f);

    int tx = int(floorX * float(texSize)) & texMask;
    int ty = int(floorY * float(texSize)) & texMask;
    int texOff = ty * texSize + tx;

    // Check tile type for damage floor
    int tileX = int(floorX);
    int tileY = int(floorY);
    int worldW = uniforms.worldWidth;
    int worldH = uniforms.worldHeight;
    int actualFloorOff = floorOff;
    if (tileX >= 0 && tileX < worldW && tileY >= 0 && tileY < worldH) {
        int tileVal = worldTiles[tileY * worldW + tileX];
        if (tileVal == 10) {  // damageFloor
            actualFloorOff = 11 * ppt;  // TextureAtlas.damageFloor = 11
        }
    }

    // Floor pixel
    uint floorColor = texAtlas[actualFloorOff + texOff];
    float4 floorPixel = shadeThenFog(floorColor, floorShade, fog,
                                      uniforms.fogR, uniforms.fogG, uniforms.fogB);
    outTexture.write(floorPixel, uint2(x, y));

    // Ceiling pixel (mirrored)
    int ceilY = h - 1 - y;
    if (ceilY >= 0 && ceilY < h) {
        uint ceilColor = texAtlas[ceilOff + texOff];
        float4 ceilPixel = shadeThenFog(ceilColor, ceilShade, fog,
                                         uniforms.fogR, uniforms.fogG, uniforms.fogB);
        outTexture.write(ceilPixel, uint2(x, ceilY));
    }
}

// MARK: - Wall raycasting kernel
// Each thread handles one screen column (x)
kernel void wallKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    device const uint* texAtlas [[buffer(0)]],
    device const RaycastUniforms& uniforms [[buffer(1)]],
    device const TorchData* torches [[buffer(2)]],
    device const int* worldTiles [[buffer(3)]],
    device float* zBuffer [[buffer(4)]],
    device const float* doorOpenAmounts [[buffer(5)]],
    uint gid [[thread_position_in_grid]]
) {
    int x = int(gid);
    int w = uniforms.renderWidth;
    int h = uniforms.renderHeight;
    if (x >= w) return;

    int halfH = h / 2;
    int texSize = uniforms.texSize;
    int ppt = texSize * texSize;

    float invW = 2.0 / float(w);
    float cameraX = float(x) * invW - 1.0;
    float rayDirX = uniforms.dirX + uniforms.planeX * cameraX;
    float rayDirY = uniforms.dirY + uniforms.planeY * cameraX;

    int mapX = int(uniforms.playerX);
    int mapY = int(uniforms.playerY);

    float deltaDistX = abs(rayDirX) < 1e-10 ? 1e10 : abs(1.0 / rayDirX);
    float deltaDistY = abs(rayDirY) < 1e-10 ? 1e10 : abs(1.0 / rayDirY);

    int stepX, stepY;
    float sideDistX, sideDistY;

    if (rayDirX < 0) {
        stepX = -1;
        sideDistX = (uniforms.playerX - float(mapX)) * deltaDistX;
    } else {
        stepX = 1;
        sideDistX = (float(mapX) + 1.0 - uniforms.playerX) * deltaDistX;
    }
    if (rayDirY < 0) {
        stepY = -1;
        sideDistY = (uniforms.playerY - float(mapY)) * deltaDistY;
    } else {
        stepY = 1;
        sideDistY = (float(mapY) + 1.0 - uniforms.playerY) * deltaDistY;
    }

    bool hit = false;
    int side = 0;
    int tileVal = 0;

    int worldW = uniforms.worldWidth;
    int worldH = uniforms.worldHeight;

    for (int i = 0; i < 64; i++) {  // Max 64 DDA steps
        if (sideDistX < sideDistY) {
            sideDistX += deltaDistX;
            mapX += stepX;
            side = 0;
        } else {
            sideDistY += deltaDistY;
            mapY += stepY;
            side = 1;
        }

        // Bounds check
        if (mapX < 0 || mapX >= worldW || mapY < 0 || mapY >= worldH) {
            tileVal = 1; // Treat as brick wall
            hit = true;
            break;
        }

        tileVal = worldTiles[mapY * worldW + mapX];

        if (tileVal == 4 || tileVal == 7 || tileVal == 8 || tileVal == 9 || tileVal >= 11) {
            // All door types (regular, locked and secret)
            float openAmt = doorOpenAmounts[mapY * worldW + mapX];
            if (openAmt >= 0.99) {
                // Fully open — ray passes through
            } else {
                // Door renders at tile boundary. Check if ray hits solid or gap.
                float perpDist = side == 0 ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY);
                float hitWallX = side == 0
                    ? (uniforms.playerY + perpDist * rayDirY)
                    : (uniforms.playerX + perpDist * rayDirX);
                hitWallX -= floor(hitWallX);
                // Flip so gap opens from consistent side
                if ((side == 0 && rayDirX > 0) || (side == 1 && rayDirY > 0)) {
                    hitWallX = 1.0 - hitWallX;
                }
                if (hitWallX > openAmt) {
                    hit = true;
                    break;
                }
                // else: ray passes through the open gap
            }
        } else if (tileVal != 0 && tileVal != 10) {
            // Solid wall
            hit = true;
            break;
        }

        float pd = side == 0 ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY);
        if (pd > uniforms.maxRenderDist) break;
    }

    // Default z to infinity
    zBuffer[x] = 1e10;
    if (!hit) return;

    float perpWallDist = side == 0 ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY);
    float wallX = side == 0
        ? (uniforms.playerY + perpWallDist * rayDirY)
        : (uniforms.playerX + perpWallDist * rayDirX);
    wallX -= floor(wallX);
    // Offset door texture for sliding effect
    if (tileVal == 4 || tileVal == 7 || tileVal == 8 || tileVal == 9 || tileVal >= 11) {
        float openAmt = doorOpenAmounts[mapY * worldW + mapX];
        // Flip wallX consistent with gap detection
        if ((side == 0 && rayDirX > 0) || (side == 1 && rayDirY > 0)) {
            wallX = 1.0 - wallX;
        }
        wallX += openAmt;
        if (wallX >= 1.0) wallX -= 1.0;
        // Flip back
        if ((side == 0 && rayDirX > 0) || (side == 1 && rayDirY > 0)) {
            wallX = 1.0 - wallX;
        }
    }
    if (perpWallDist <= 0) return;

    zBuffer[x] = perpWallDist;

    int lineHeight = int(float(h) / perpWallDist);
    if (lineHeight <= 0) return;
    int drawStart = max(0, halfH - lineHeight / 2);
    int drawEnd = min(h - 1, halfH + lineHeight / 2);
    if (drawEnd < drawStart) return;
    int texX = int(wallX * float(texSize));
    texX = clamp(texX, 0, texSize - 1);

    // Texture index mapping (matches TileType.textureIndex)
    int texIndex;
    switch (tileVal) {
        case 1: texIndex = 0; break;  // brick
        case 2: texIndex = 1; break;  // metal
        case 3: texIndex = 2; break;  // tech
        case 4: texIndex = 3; break;  // door
        case 5: texIndex = 6; break;  // brickTorch
        case 6: texIndex = uniforms.texCount + uniforms.portalFrame; break;  // exitPortal (animated)
        case 7: texIndex = 8; break;  // lockedDoorRed
        case 8: texIndex = 9; break;  // lockedDoorBlue
        case 9: texIndex = 10; break; // lockedDoorYellow
        case 11: texIndex = 0; break; // secret door, brick
        case 12: texIndex = 1; break; // secret door, metal
        case 13: texIndex = 2; break; // secret door, tech
        default: texIndex = 0; break;
    }
    int texBase = texIndex * ppt;

    // Lighting
    float baseAtten = max(0.12f, 1.0f / (1.0f + 0.15f * perpWallDist * perpWallDist));
    float sideFactor = side == 1 ? 0.72f : 1.0f;
    float wallWorldX = uniforms.playerX + perpWallDist * rayDirX;
    float wallWorldY = uniforms.playerY + perpWallDist * rayDirY;
    float tb = torchLight(wallWorldX, wallWorldY, torches, uniforms.torchCount, uniforms.elapsedTime);
    float shade = min(1.0f, baseAtten * sideFactor + tb * 0.35f);

    float3 lighting = getLighting(perpWallDist);
    float fog = lighting.y;

    int drawTop = halfH - lineHeight / 2;

    for (int y = drawStart; y <= drawEnd; y++) {
        int texY = clamp((y - drawTop) * texSize / lineHeight, 0, texSize - 1);
        uint color = texAtlas[texBase + texY * texSize + texX];
        float4 pixel = shadeThenFog(color, shade, fog,
                                     uniforms.fogR, uniforms.fogG, uniforms.fogB);
        outTexture.write(pixel, uint2(x, y));
    }
}

// MARK: - Sprite kernel
// One thread per scene pixel. Sprites arrive sorted nearest first (the weapon
// overlay at index 0), so the first opaque texel that passes the z test wins —
// the same result as painting them back to front.
kernel void spriteKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    device const uint* spriteAtlas [[buffer(0)]],
    device const RaycastUniforms& uniforms [[buffer(1)]],
    device const SpriteInstance* sprites [[buffer(2)]],
    constant int& spriteCount [[buffer(3)]],
    device const float* zBuffer [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    int x = int(gid.x);
    int y = int(gid.y);
    if (x >= uniforms.renderWidth || y >= uniforms.renderHeight) return;

    float wallDepth = zBuffer[x];

    for (int i = 0; i < spriteCount; i++) {
        SpriteInstance s = sprites[i];
        if (x < s.x0 || x > s.x1 || y < s.y0 || y > s.y1) continue;
        if ((s.flags & kSpriteDepthTest) && s.depth >= wallDepth) continue;

        int texX = (x - s.leftX) * s.srcW / s.sW;
        int texY = (y - s.topY) * s.srcH / s.sH;
        if (texX < 0 || texX >= s.srcW || texY < 0 || texY >= s.srcH) continue;
        if (s.flags & kSpriteFlipX) texX = s.srcW - 1 - texX;

        uint pixel = spriteAtlas[s.atlasOffset + texY * s.srcW + texX];
        if ((pixel >> 24) == 0) continue;  // transparent

        float4 color;
        if (s.flags & kSpriteShaded) {
            color = shadeThenFog(pixel, s.shade, s.fog, uniforms.fogR, uniforms.fogG, uniforms.fogB);
        } else {
            color = float4(float((pixel >> 16) & 0xFF) / 255.0,
                           float((pixel >> 8) & 0xFF) / 255.0,
                           float(pixel & 0xFF) / 255.0, 1.0);
        }
        outTexture.write(color, uint2(x, y));
        return;
    }
}

// MARK: - Post kernel
// One thread per drawable pixel: letterbox + upscale of the low-res scene, then
// the screen effects in the same order as the CPU path (muzzle tint, directional
// damage, pickup tint, berserk tint, death camera, hit marker, fade to black).
//
// The upscale is "sharp bilinear": each scene pixel stays a flat block, and only
// the one-drawable-pixel-wide seam between blocks is blended. At an integer scale
// with aligned pixels no seam falls inside a block, so it is exactly nearest
// neighbour; at fractional scales it removes the uneven 2-px/3-px columns nearest
// neighbour would produce without blurring the pixel art.
inline float3 applyTint(float3 c, float4 tint) {
    float a = tint.w;
    if (a <= 0.0) return c;
    return min(float3(1.0), c * (1.0 - a) + (tint.xyz / 255.0) * a);
}

// The scene pixel that ends up at scene coordinate (sx, sy) after the death
// camera, with the per-pixel effects that the CPU path applies before the death
// camera (muzzle tint, directional damage, pickup tint, berserk tint).
inline float3 scenePixel(texture2d<float, access::read> scene, constant PostUniforms& post,
                         int sx, int sy) {
    int srcW = post.srcW;
    int srcH = post.srcH;
    sx = clamp(sx, 0, srcW - 1);
    sy = clamp(sy, 0, srcH - 1);

    // Death camera: the scene slides down and tilts. Gather the source pixel that
    // ends up at (sx, sy); pixels that slide in from outside are dark red.
    const float3 darkRed = float3(40.0, 5.0, 5.0) / 255.0;
    int fx = sx;
    int fy = sy;
    if (post.deathProgress > 0.0) {
        int tiltPixels = int(post.deathProgress * 8.0 * float(post.pixelScale));
        int rowTilt = tiltPixels * (srcW / 2 - abs(sy - srcH / 2)) / (srcH / 2);
        if (rowTilt > 0) {
            if (sx < srcW - rowTilt) fx = sx + rowTilt;
            else return darkRed;
        }
        int shiftAmount = int(post.deathProgress * float(srcH) * 0.35);
        if (shiftAmount > 0) {
            if (sy >= shiftAmount) fy = sy - shiftAmount;
            else return darkRed;
        }
    }

    float3 c = scene.read(uint2(fx, fy)).rgb;

    // Muzzle flash
    c = applyTint(c, post.tints[0]);

    // Directional damage: red gradient from the edge nearest the hit
    if (post.damageIntensity > 0.0) {
        float nx = float(fx) / float(srcW);
        float ny = float(fy) / float(srcH);
        float a = post.damageAngle;
        const float fadeDepth = 0.20;
        float edgeDist = 1.0;
        if (a > 0.5 && a < 2.0) edgeDist = min(edgeDist, nx / fadeDepth);
        if (a > 4.3 && a < 5.8) edgeDist = min(edgeDist, (1.0 - nx) / fadeDepth);
        if (a > 2.0 && a < 4.3) edgeDist = min(edgeDist, ny / fadeDepth);
        if (a < 0.5 || a > 5.8) edgeDist = min(edgeDist, (1.0 - ny) / fadeDepth);
        float alpha = max(0.0, 1.0 - edgeDist) * post.damageIntensity;
        if (alpha > 0.01) {
            c = float3(min(1.0, c.r * (1.0 - alpha) + alpha), c.g * (1.0 - alpha), c.b * (1.0 - alpha));
        }
    }

    // Pickup flash, berserk
    c = applyTint(c, post.tints[1]);
    c = applyTint(c, post.tints[2]);
    return c;
}

kernel void postKernel(
    texture2d<float, access::read> scene [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant PostUniforms& post [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    int dstW = int(outTexture.get_width());
    int dstH = int(outTexture.get_height());
    if (int(gid.x) >= dstW || int(gid.y) >= dstH) return;

    int srcW = post.srcW;
    int srcH = post.srcH;

    // Aspect-fit the render target inside the drawable, black bars around it
    float scale = min(float(dstW) / float(srcW), float(dstH) / float(srcH));
    float offX = (float(dstW) - float(srcW) * scale) * 0.5;
    float offY = (float(dstH) - float(srcH) * scale) * 0.5;
    float2 texel = (float2(gid) + 0.5 - float2(offX, offY)) / scale;  // scene pixel units
    int sx = int(floor(texel.x));
    int sy = int(floor(texel.y));
    if (sx < 0 || sx >= srcW || sy < 0 || sy >= srcH) {
        outTexture.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }

    // Sharp bilinear: move the sample point toward the texel centre except within
    // half a drawable pixel of a texel boundary, then blend the four neighbours.
    float2 texelFloor = floor(texel);
    float2 s = texel - texelFloor;
    float regionRange = 0.5 - 0.5 / scale;
    float2 centerDist = s - 0.5;
    float2 f = (centerDist - clamp(centerDist, -regionRange, regionRange)) * scale + 0.5;
    float2 p = texelFloor + f - 0.5;        // sample position between texel centres
    float2 p0 = floor(p);
    float2 t = p - p0;
    int x0 = int(p0.x), y0 = int(p0.y);
    float3 c00 = scenePixel(scene, post, x0, y0);
    float3 c10 = scenePixel(scene, post, x0 + 1, y0);
    float3 c01 = scenePixel(scene, post, x0, y0 + 1);
    float3 c11 = scenePixel(scene, post, x0 + 1, y0 + 1);
    float3 c = mix(mix(c00, c10, t.x), mix(c01, c11, t.x), t.y);

    // Death red tint, intensifying as the camera falls
    if (post.deathProgress > 0.0) {
        float tt = post.deathProgress * 0.5;
        float inv = 1.0 - tt;
        c = float3(min(1.0, c.r * inv + (180.0 / 255.0) * tt), c.g * inv * 0.7, c.b * inv * 0.5);
    }

    // Hit marker: an X at the centre, one design pixel thick, four design pixels long
    if (post.hitMarkerAlpha >= 0.5) {
        int ps = max(1, post.pixelScale);
        int adx = abs(sx - srcW / 2);
        int ady = abs(sy - srcH / 2);
        if (abs(adx - ady) < ps && adx >= ps && adx <= 4 * ps) {
            c = float3(1.0);
        }
    }

    // Fade to black between levels
    c = applyTint(c, post.tints[3]);

    outTexture.write(float4(c, 1.0), gid);
}
