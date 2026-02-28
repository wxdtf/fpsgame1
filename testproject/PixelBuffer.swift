//
//  PixelBuffer.swift
//  testproject
//

import AppKit
import CoreGraphics
import Accelerate

final class PixelBuffer {
    let width: Int
    let height: Int
    let count: Int
    /// Raw pixel storage — direct pointer for zero-overhead access in hot loops
    let rawPixels: UnsafeMutablePointer<UInt32>

    // Reusable color space (avoid re-creating each frame)
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()
    private static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.count = width * height
        self.rawPixels = .allocate(capacity: width * height)
        rawPixels.initialize(repeating: 0xFF000000, count: width * height)
    }

    deinit {
        rawPixels.deallocate()
    }

    @inline(__always)
    static func makeColor(r: UInt8, g: UInt8, b: UInt8) -> UInt32 {
        (0xFF << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }

    @inline(__always)
    static func makeColor(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> UInt32 {
        (UInt32(a) << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }

    @inline(__always)
    static func getRed(_ color: UInt32) -> UInt8 { UInt8((color >> 16) & 0xFF) }

    @inline(__always)
    static func getGreen(_ color: UInt32) -> UInt8 { UInt8((color >> 8) & 0xFF) }

    @inline(__always)
    static func getBlue(_ color: UInt32) -> UInt8 { UInt8(color & 0xFF) }

    @inline(__always)
    static func applyShade(_ color: UInt32, shade: Double) -> UInt32 {
        let r = UInt8(Double((color >> 16) & 0xFF) * shade)
        let g = UInt8(Double((color >> 8) & 0xFF) * shade)
        let b = UInt8(Double(color & 0xFF) * shade)
        return (0xFF << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }

    @inline(__always)
    func setPixel(x: Int, y: Int, color: UInt32) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        rawPixels[y * width + x] = color
    }

    func fill(color: UInt32) {
        // memset-style fill
        for i in 0..<count {
            rawPixels[i] = color
        }
    }

    func drawSprite(srcPixels: [UInt32], srcWidth: Int, srcHeight: Int,
                    destX: Int, destY: Int, destWidth: Int, destHeight: Int) {
        let w = width
        let h = height
        let buf = rawPixels
        srcPixels.withUnsafeBufferPointer { src in
            for dy in 0..<destHeight {
                let screenY = destY + dy
                guard screenY >= 0, screenY < h else { continue }
                let srcY = dy * srcHeight / destHeight
                let rowOff = screenY * w
                for dx in 0..<destWidth {
                    let screenX = destX + dx
                    guard screenX >= 0, screenX < w else { continue }
                    let srcX = dx * srcWidth / destWidth
                    let srcIdx = srcY * srcWidth + srcX
                    guard srcIdx >= 0, srcIdx < src.count else { continue }
                    let pixel = src[srcIdx]
                    if (pixel >> 24) == 0 { continue }
                    buf[rowOff + screenX] = pixel
                }
            }
        }
    }

    func applyTint(color: UInt32, intensity: Double) {
        let tintR = Float((color >> 16) & 0xFF)
        let tintG = Float((color >> 8) & 0xFF)
        let tintB = Float(color & 0xFF)
        let inv = Float(1.0 - intensity)
        let tR = tintR * Float(intensity)
        let tG = tintG * Float(intensity)
        let tB = tintB * Float(intensity)
        let buf = rawPixels
        let n = count

        for i in 0..<n {
            let p = buf[i]
            let r = Float((p >> 16) & 0xFF) * inv + tR
            let g = Float((p >> 8) & 0xFF) * inv + tG
            let b = Float(p & 0xFF) * inv + tB
            buf[i] = (0xFF << 24)
                | (UInt32(min(255.0, r)) << 16)
                | (UInt32(min(255.0, g)) << 8)
                | UInt32(min(255.0, b))
        }
    }

    /// Directional damage indicator — red gradient from the edge nearest the damage source
    func applyDirectionalDamage(intensity: Double, direction: Double, playerAngle: Double) {
        let relAngle = direction - playerAngle + .pi // offset so 0 = behind, pi = front
        let normAngle = relAngle - floor(relAngle / (2 * .pi)) * 2 * .pi

        let buf = rawPixels
        let w = width
        let h = height
        let fadeDepth = 0.20 // percentage of screen for gradient

        let tintR: Float = 255.0 * Float(intensity)
        let tintMul = Float(intensity)

        for y in 0..<h {
            for x in 0..<w {
                // Calculate how close this pixel is to the damage edge
                let nx = Double(x) / Double(w)
                let ny = Double(y) / Double(h)

                var edgeDist = 1.0 // 0 = at the edge, 1 = far from edge

                // Left edge (damage from left: angle ~= pi/2)
                if normAngle > 0.5 && normAngle < 2.0 {
                    edgeDist = min(edgeDist, nx / fadeDepth)
                }
                // Right edge (damage from right: angle ~= 3*pi/2)
                if normAngle > 4.3 && normAngle < 5.8 {
                    edgeDist = min(edgeDist, (1.0 - nx) / fadeDepth)
                }
                // Top edge (damage from front: angle ~= pi)
                if normAngle > 2.0 && normAngle < 4.3 {
                    edgeDist = min(edgeDist, ny / fadeDepth)
                }
                // Bottom edge (damage from behind: angle ~= 0 or 2pi)
                if normAngle < 0.5 || normAngle > 5.8 {
                    edgeDist = min(edgeDist, (1.0 - ny) / fadeDepth)
                }

                let alpha = Float(max(0.0, 1.0 - edgeDist)) * tintMul
                if alpha > 0.01 {
                    let p = buf[y * w + x]
                    let inv = 1.0 - alpha
                    let r = Float((p >> 16) & 0xFF) * inv + tintR * alpha
                    let g = Float((p >> 8) & 0xFF) * inv
                    let b = Float(p & 0xFF) * inv
                    buf[y * w + x] = (0xFF << 24)
                        | (UInt32(min(255.0, r)) << 16)
                        | (UInt32(min(255.0, g)) << 8)
                        | UInt32(min(255.0, b))
                }
            }
        }
    }

    /// Death screen effect — shift pixels down and fill top with dark red
    func applyDeathEffect(progress: Double) {
        let buf = rawPixels
        let w = width
        let h = height
        let shiftAmount = Int(progress * Double(h) * 0.3)
        let darkRed = PixelBuffer.makeColor(r: 40, g: 5, b: 5)

        // Shift pixels down
        if shiftAmount > 0 {
            for y in stride(from: h - 1, through: shiftAmount, by: -1) {
                let srcRow = y - shiftAmount
                for x in 0..<w {
                    buf[y * w + x] = buf[srcRow * w + x]
                }
            }
            // Fill top rows with dark red
            for y in 0..<shiftAmount {
                for x in 0..<w {
                    buf[y * w + x] = darkRed
                }
            }
        }

        // Red tint overlay
        let tintIntensity = Float(progress * 0.4)
        let inv = 1.0 - tintIntensity
        for i in 0..<(w * h) {
            let p = buf[i]
            let r = Float((p >> 16) & 0xFF) * inv + 180.0 * tintIntensity
            let g = Float((p >> 8) & 0xFF) * inv
            let b = Float(p & 0xFF) * inv
            buf[i] = (0xFF << 24)
                | (UInt32(min(255.0, r)) << 16)
                | (UInt32(min(255.0, g)) << 8)
                | UInt32(min(255.0, b))
        }
    }

    /// Zero-copy CGImage creation — the pixel data is referenced directly, not copied
    func toCGImage() -> CGImage? {
        let byteCount = count * 4
        // Create a data provider that references our raw memory directly (no copy)
        guard let provider = CGDataProvider(dataInfo: nil,
                                            data: rawPixels,
                                            size: byteCount,
                                            releaseData: { _, _, _ in }) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: Self.colorSpace,
            bitmapInfo: Self.bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    func toNSImage() -> NSImage? {
        guard let cgImage = toCGImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}
