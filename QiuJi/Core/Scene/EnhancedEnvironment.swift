import SceneKit
import UIKit
import simd

/// Studio-look IBL + background for the 3D aiming scene.
///
/// Pure-function port of `EnvironmentLightingManager` from
/// `01.billiard_app/BilliardTrainer/Core/Scene/EnvironmentLightingManager.swift`,
/// stripped of HDRI dependencies, `RenderQualityManager` tiering, and
/// per-tier caching. One static cube-map size (256), generated on demand
/// and cached in-memory for the lifetime of the process.
enum EnhancedEnvironment {

    /// Apply the studio IBL + cold-grey background to a scene. Idempotent.
    static func apply(to scene: SCNScene) {
        scene.lightingEnvironment.contents = cachedIBL
        // Pulled down from 1.6 so the key light's real cast shadow on the cloth
        // isn't flooded out by omnidirectional IBL fill under each ball, while
        // still keeping enough ambient for the balls' PBR / clearcoat sheen.
        scene.lightingEnvironment.intensity = 1.2
        scene.lightingEnvironment.contentsTransform = SCNMatrix4MakeRotation(.pi * 0.25, 0, 1, 0)
        scene.background.contents = cachedBackground
    }

    /// Detach the IBL/background from a scene, restoring the default empty
    /// environment. Used when toggling enhanced rendering off mid-session.
    static func detach(from scene: SCNScene) {
        scene.lightingEnvironment.contents = nil
        scene.lightingEnvironment.intensity = 1.0
        scene.background.contents = nil
    }

    // MARK: - Cache

    private static let cubeMapSize: Int = 256

    private static let cachedIBL: [UIImage] = generateIBLCubeMap(size: cubeMapSize)
    private static let cachedBackground: [UIImage] = generateBackgroundCubeMap(size: cubeMapSize)

    // MARK: - Color anchors (B > G > R, cold consistent)
    // 背景天空盒颜色（仅影响可见背景，不影响 IBL 光照）。整体抬高一档，
    // 让 3D 视角顶部不再是死黑，呈淡冷灰渐变、更有影棚纵深（UR-20260529 渲染打磨）。

    private static let C0 = SIMD3<Float>(0.070, 0.085, 0.110) // ceiling / top
    private static let C1 = SIMD3<Float>(0.100, 0.115, 0.145) // wall mid-peak
    private static let C2 = SIMD3<Float>(0.085, 0.100, 0.130) // horizon band
    private static let F0 = SIMD3<Float>(0.045, 0.048, 0.060) // floor base
    private static let F1 = SIMD3<Float>(0.038, 0.040, 0.052) // floor near camera

    private static let y0: Float = 1.00
    private static let y1: Float = 0.70
    private static let y2: Float = 0.36
    private static let y3: Float = 0.16
    private static let y4: Float = 0.00

    // MARK: - Background cube map (smootherstep wall gradient + solid ceiling/floor)

    private static func generateBackgroundCubeMap(size: Int, brightness: Float = 1.0) -> [UIImage] {
        let s = size
        let wall = renderGradientFace(size: s, brightness: brightness)
        let ceiling = renderSolidFace(size: s, color: C0 * brightness)
        let floor = renderSolidFace(size: s, color: F1 * brightness)
        return [wall, wall, ceiling, floor, wall, wall]
    }

    private static func renderGradientFace(size s: Int, brightness: Float) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        for row in 0..<s {
            let y = 1.0 - Float(row) / Float(s - 1)
            let c = backgroundColor(y: y, brightness: brightness)
            let r = UInt8(clamping: Int(min(c.x, 1.0) * 255))
            let g = UInt8(clamping: Int(min(c.y, 1.0) * 255))
            let b = UInt8(clamping: Int(min(c.z, 1.0) * 255))
            for col in 0..<s {
                let idx = (row * s + col) * 4
                pixels[idx + 0] = r
                pixels[idx + 1] = g
                pixels[idx + 2] = b
                pixels[idx + 3] = 255
            }
        }
        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    private static func renderSolidFace(size s: Int, color: SIMD3<Float>) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        let r = UInt8(clamping: Int(min(color.x, 1.0) * 255))
        let g = UInt8(clamping: Int(min(color.y, 1.0) * 255))
        let b = UInt8(clamping: Int(min(color.z, 1.0) * 255))
        for i in 0..<(s * s) {
            let idx = i * 4
            pixels[idx + 0] = r
            pixels[idx + 1] = g
            pixels[idx + 2] = b
            pixels[idx + 3] = 255
        }
        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    private static func backgroundColor(y: Float, brightness: Float) -> SIMD3<Float> {
        let color: SIMD3<Float>
        if y >= y1 {
            let t = smootherstep(y1, y0, y)
            color = lerp3(C1, C0, t)
        } else if y >= y2 {
            let t = smootherstep(y2, y1, y)
            color = lerp3(C2, C1, t)
        } else if y >= y3 {
            let t = smootherstep(y3, y2, y)
            color = lerp3(F0, C2, t)
        } else {
            let t = smootherstep(y4, y3, y)
            color = lerp3(F1, F0, t)
        }
        return color * brightness
    }

    // MARK: - IBL cube map (3-strip softbox ceiling + neutral walls/floor)

    private static func generateIBLCubeMap(size: Int, brightness: Float = 1.0) -> [UIImage] {
        let s = size
        let b = brightness

        let ceiling = renderIBLCeiling(size: s, b: b)

        let wallTop = SIMD3<Float>(0.20, 0.21, 0.24) * b
        let wallBot = SIMD3<Float>(0.10, 0.10, 0.12) * b
        let wall = renderIBLWall(size: s, top: wallTop, bot: wallBot)
        let floor = renderSolidFace(size: s, color: SIMD3<Float>(0.06, 0.07, 0.08) * b)

        return [wall, wall, ceiling, floor, wall, wall]
    }

    private static func renderIBLWall(size s: Int, top: SIMD3<Float>, bot: SIMD3<Float>) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        for row in 0..<s {
            let t = Float(row) / Float(s - 1)
            let c = lerp3(top, bot, t)
            let r = UInt8(clamping: Int(min(c.x, 1.0) * 255))
            let g = UInt8(clamping: Int(min(c.y, 1.0) * 255))
            let b = UInt8(clamping: Int(min(c.z, 1.0) * 255))
            for col in 0..<s {
                let idx = (row * s + col) * 4
                pixels[idx + 0] = r
                pixels[idx + 1] = g
                pixels[idx + 2] = b
                pixels[idx + 3] = 255
            }
        }
        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    /// Triple-strip softbox ceiling: 3 capsule lamps + diffusion halos + ceiling bounce.
    private static func renderIBLCeiling(size s: Int, b: Float) -> UIImage {
        let ceilingBase = SIMD3<Float>(0.10, 0.11, 0.13) * b

        let lampW: Float = 0.72
        let lampH: Float = 0.10
        let lampR: Float = lampH * 0.5
        let lampOffsets: [Float] = [-0.12, 0.0, 0.12]
        let lampColor = SIMD3<Float>(0.86, 0.84, 0.80) * b

        let coreH: Float = lampH * 0.35
        let coreR: Float = coreH * 0.5
        let coreColor = SIMD3<Float>(0.98, 0.96, 0.92) * b

        let feather: Float = 0.015

        let haloW: Float = lampW * 1.10
        let haloH: Float = lampH * 1.80
        let haloR: Float = min(haloW, haloH) * 0.5
        let haloFeather: Float = 0.04
        let haloIntensity: Float = 0.14

        let bounceRx: Float = 0.55
        let bounceRy: Float = 0.40
        let bounceIntensity: Float = 0.08
        let bounceColor = lerp3(ceilingBase, lampColor, 0.3)

        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        let invS = 1.0 / Float(s)

        for row in 0..<s {
            let v = (Float(row) + 0.5) * invS
            for col in 0..<s {
                let u = (Float(col) + 0.5) * invS

                var color = ceilingBase

                let bdu = (u - 0.5) / bounceRx
                let bdv = (v - 0.5) / bounceRy
                let bDist = sqrt(bdu * bdu + bdv * bdv)
                let bAlpha = 1.0 - smoothstep(0.0, 1.0, bDist)
                color = color + bounceColor * (bAlpha * bounceIntensity)

                for offset in lampOffsets {
                    let cy: Float = 0.5 + offset

                    let haloDist = roundedRectSDF(px: u, py: v,
                                                  cx: 0.5, cy: cy,
                                                  hw: haloW * 0.5, hh: haloH * 0.5,
                                                  r: haloR)
                    let haloAlpha = 1.0 - smoothstep(0, haloFeather, haloDist)
                    color = color + lampColor * (haloAlpha * haloIntensity)

                    let lampDist = roundedRectSDF(px: u, py: v,
                                                  cx: 0.5, cy: cy,
                                                  hw: lampW * 0.5, hh: lampH * 0.5,
                                                  r: lampR)
                    let lampAlpha = 1.0 - smoothstep(0, feather, lampDist)
                    color = color + lampColor * lampAlpha

                    let coreDist = roundedRectSDF(px: u, py: v,
                                                  cx: 0.5, cy: cy,
                                                  hw: lampW * 0.5, hh: coreH * 0.5,
                                                  r: coreR)
                    let coreAlpha = 1.0 - smoothstep(0, feather, coreDist)
                    let coreAdd = coreColor - lampColor
                    color = color + coreAdd * coreAlpha
                }

                let idx = (row * s + col) * 4
                pixels[idx + 0] = UInt8(clamping: Int(min(color.x, 1.0) * 255))
                pixels[idx + 1] = UInt8(clamping: Int(min(color.y, 1.0) * 255))
                pixels[idx + 2] = UInt8(clamping: Int(min(color.z, 1.0) * 255))
                pixels[idx + 3] = 255
            }
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    // MARK: - Math helpers

    private static func smootherstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private static func lerp3(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }

    /// SDF for a rounded rectangle. Negative inside, 0 on boundary, positive outside.
    private static func roundedRectSDF(px: Float, py: Float,
                                       cx: Float, cy: Float,
                                       hw: Float, hh: Float,
                                       r: Float) -> Float {
        let dx = max(abs(px - cx) - hw + r, 0)
        let dy = max(abs(py - cy) - hh + r, 0)
        return sqrt(dx * dx + dy * dy) - r
    }

    // MARK: - Pixel buffer → UIImage

    private static func imageFromRGBA(pixels: [UInt8], width: Int, height: Int) -> UIImage {
        let data = Data(pixels)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil, shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}
