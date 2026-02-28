//
//  Raycaster.metal
//  testproject
//
//  Metal compute shader for GPU-accelerated raycasting (walls, floor, ceiling).
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
};

struct TorchData {
    float x;
    float y;
};

// Shade + fog in one step
// Output format: BGRA8Unorm texture but CPU pixel buffer uses 0xAARRGGBB (byteOrder32Little + noneSkipFirst)
// In memory: [B, G, R, A]. Metal float4 for bgra8Unorm: (B, G, R, A)
// Our UInt32 color is 0xAARRGGBB — in little-endian memory: [BB, GG, RR, AA]
// bgra8Unorm float4(b, g, r, a) → memory [b, g, r, a] — matches!
inline float4 shadeThenFog(uint color, float shade, float fog, float fogR, float fogG, float fogB) {
    float r = float((color >> 16) & 0xFF) * shade;
    float g = float((color >> 8) & 0xFF) * shade;
    float b = float(color & 0xFF) * shade;
    float invFog = 1.0 - fog;
    r = r * fog + fogR * invFog;
    g = g * fog + fogG * invFog;
    b = b * fog + fogB * invFog;
    // bgra8Unorm: float4 maps to (Blue, Green, Red, Alpha) in memory
    return float4(b / 255.0, g / 255.0, r / 255.0, 1.0);
}

// Distance-based shade/fog LUT equivalent
inline float3 getLighting(float distance) {
    float shade = max(0.08f, 1.0f / (1.0f + 0.2f * distance * distance));
    float density = 0.08f;
    float fog = max(0.0f, min(1.0f, exp(-density * distance * distance)));
    float ceilShade = shade * 0.65f;
    return float3(shade, fog, ceilShade);
}

// Torch light contribution
inline float torchLight(float worldX, float worldY,
                        device const TorchData* torches,
                        int torchCount) {
    float light = 0.0;
    for (int i = 0; i < torchCount; i++) {
        float dx = worldX - torches[i].x;
        float dy = worldY - torches[i].y;
        float distSq = dx * dx + dy * dy;
        if (distSq < 16.0) {
            light += 1.2 / (1.0 + distSq * 0.8);
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
        float4 fogColor = float4(uniforms.fogB / 255.0, uniforms.fogG / 255.0, uniforms.fogR / 255.0, 1.0);
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
    float floorShade = lighting.x;
    float fog = lighting.y;
    float ceilShade = lighting.z;

    int tx = int(floorX * float(texSize)) & texMask;
    int ty = int(floorY * float(texSize)) & texMask;
    int texOff = ty * texSize + tx;

    // Floor pixel
    uint floorColor = texAtlas[floorOff + texOff];
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

        if (tileVal == 4) {
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
        } else if (tileVal != 0) {
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
    if (tileVal == 4) {
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
        case 1: texIndex = 0; break; // brick
        case 2: texIndex = 1; break; // metal
        case 3: texIndex = 2; break; // tech
        case 4: texIndex = 3; break; // door
        case 5: texIndex = 6; break; // brickTorch
        case 6: texIndex = 7; break; // exitPortal
        default: texIndex = 0; break;
    }
    int texBase = texIndex * ppt;

    // Lighting
    float baseAtten = max(0.12f, 1.0f / (1.0f + 0.15f * perpWallDist * perpWallDist));
    float sideFactor = side == 1 ? 0.72f : 1.0f;
    float wallWorldX = uniforms.playerX + perpWallDist * rayDirX;
    float wallWorldY = uniforms.playerY + perpWallDist * rayDirY;
    float tb = torchLight(wallWorldX, wallWorldY, torches, uniforms.torchCount);
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
