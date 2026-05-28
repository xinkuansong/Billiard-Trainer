import SceneKit
import UIKit

/// PBR material factory for the angle-training scene.
///
/// `applyBallMaterial` is always available (used by every page). The
/// `enhance*Materials` family is opt-in for the studio-look 3D pipeline
/// — they should only be invoked when `AngleTrainingScene.enhancedRendering`
/// is on.  Logic ported from
/// `01.billiard_app/BilliardTrainer/Core/Scene/MaterialFactory.swift`,
/// stripped of `RenderQualityManager` references (always-on path).
final class MaterialFactory {

    // MARK: - Texture cache (pure functions of size, safe to cache indefinitely)

    private static var feltNormalMapCache: [Int: UIImage] = [:]
    private static var woodNormalMapCache: [Int: UIImage] = [:]

    // MARK: - Tuning constants

    /// USDZ-baked cloth normal — boost intensity slightly to keep micro structure visible
    /// after ToneMapping/Bloom darken the highs.
    private static let normalIntensityUSDZClothOverride: CGFloat = 1.2
    private static let normalIntensityFeltFallback: CGFloat = 0.055
    private static let normalIntensityWoodFallback: CGFloat = 0.35
    /// Override scalar applied on top of the USDZ cloth roughness texture to subdue gloss.
    private static let roughnessUSDZClothOverride: CGFloat = 0.88

    // MARK: - Ball material

    /// Apply low-roughness PBR + clearcoat fragment shader to every geometry under `node`.
    /// Always-on path; safe to call from both enhanced and plain pipelines.
    /// - Parameter diffuseOverride: when non-nil, replaces the USDZ-baked
    ///   diffuse contents (texture or colour) with this colour. Used for
    ///   the cue ball, whose USDZ texture carries scuff / fingerprint
    ///   decorations that read as "dirt" under the studio lighting; the
    ///   model stays clean white instead.
    static func applyBallMaterial(to node: SCNNode, diffuseOverride: UIColor? = nil) {
        applyBallMaterialRecursive(node, diffuseOverride: diffuseOverride)
    }

    private static func applyBallMaterialRecursive(_ node: SCNNode, diffuseOverride: UIColor?) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                material.lightingModel = .physicallyBased
                material.roughness.contents = Float(0.045)
                material.metalness.contents = Float(0.0)
                material.normal.contents = nil
                material.normal.intensity = 0
                material.isDoubleSided = false
                material.transparency = 1.0
                material.shaderModifiers = [.fragment: clearcoatFragmentShader]
                if let diffuseOverride {
                    material.diffuse.contents = diffuseOverride
                    // Multiply channel must also be neutral white, otherwise
                    // a stale USDZ multiply (e.g. an off-white tint) tints
                    // the override.
                    material.multiply.contents = UIColor.white
                }
            }
        }
        for child in node.childNodes {
            applyBallMaterialRecursive(child, diffuseOverride: diffuseOverride)
        }
    }

    /// Schlick Fresnel clearcoat on top of PBR base (simulates polyester ball coat).
    private static let clearcoatFragmentShader = """
    float3 n = normalize(_surface.normal);
    float3 v = normalize(-_surface.position);
    float NdotV = saturate(dot(n, v));
    float ccF0 = 0.04;
    float fresnel = ccF0 + (1.0 - ccF0) * pow(1.0 - NdotV, 5.0);
    _output.color.rgb = _output.color.rgb * (1.0 - fresnel * 0.30) + float3(fresnel * 0.22);
    """

    // MARK: - Cloth (felt)

    /// Enhance every cloth/felt material in the table tree: adjust roughness,
    /// install a fine-fiber normal-map fallback when none baked in, slightly
    /// desaturate the diffuse via the multiply channel.
    static func enhanceClothMaterials(in tableNode: SCNNode) {
        let normalMap = cachedFeltNormalMap(size: 512)

        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isClothMaterial(material, nodeName: nodeName) else { return }

            material.lightingModel = .physicallyBased

            if hasTextureContents(material.roughness.contents) {
                material.roughness.contents = Float(roughnessUSDZClothOverride)
            } else {
                material.roughness.contents = Float(0.89)
            }

            if !hasTextureContents(material.metalness.contents) {
                material.metalness.contents = Float(0.0)
            }

            if hasTextureContents(material.normal.contents) {
                material.normal.intensity = normalIntensityUSDZClothOverride
            } else {
                material.normal.contents = normalMap
                material.normal.intensity = normalIntensityFeltFallback
                material.normal.wrapS = .repeat
                material.normal.wrapT = .repeat
                material.normal.contentsTransform = SCNMatrix4MakeScale(14, 14, 1)
            }

            // Idempotent ~8% desaturation via multiply channel (writing diffuse
            // directly would compound with each call).
            if material.diffuse.contents is UIColor || extractImage(from: material.diffuse.contents) != nil {
                material.multiply.contents = UIColor(red: 0.90, green: 0.93, blue: 0.90, alpha: 1.0)
            }
        }
    }

    private static func isClothMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let combined = normalizeIdentifier(nodeName ?? "") + " " + normalizeIdentifier(material.name ?? "")
        let clothKeywords = ["cloth", "felt", "surface", "taibu", "taini",
                             "泥", "布", "green", "baize", "playing"]
        for keyword in clothKeywords {
            if combined.contains(keyword) { return true }
        }
        if let color = material.diffuse.contents as? UIColor {
            return isGreenish(color)
        }
        if let image = extractImage(from: material.diffuse.contents) {
            return isGreenishImage(image)
        }
        return false
    }

    // MARK: - Rail (wood frame)

    /// Enhance wood-rail materials: lower roughness for clearcoat sheen, install
    /// a procedural wood-grain normal fallback when none baked in.
    static func enhanceRailMaterials(in tableNode: SCNNode) {
        let woodNormal = cachedWoodGrainNormalMap(size: 256)

        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isRailMaterial(material, nodeName: nodeName) else { return }

            material.lightingModel = .physicallyBased

            if !hasTextureContents(material.roughness.contents) {
                material.roughness.contents = Float(0.30)
            }

            if !hasTextureContents(material.metalness.contents) {
                material.metalness.contents = Float(0.0)
            }

            if !hasTextureContents(material.normal.contents) {
                material.normal.contents = woodNormal
                material.normal.intensity = normalIntensityWoodFallback
                material.normal.wrapS = .repeat
                material.normal.wrapT = .repeat
                material.normal.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
            }
        }
    }

    private static func isRailMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let combined = normalizeIdentifier(nodeName ?? "") + " " + normalizeIdentifier(material.name ?? "")
        if combined.contains("rail") || combined.contains("wood") || combined.contains("frame")
            || combined.contains("mu") || combined.contains("框") || combined.contains("边") {
            return true
        }
        // Warm-brown diffuse heuristic, but exclude metals (e.g. gold accents).
        if let color = material.diffuse.contents as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            if r > 0.3 && r > b && g < r && g > 0.15 {
                let metalVal = material.metalness.contents
                if let f = metalVal as? Float, f > 0.5 { return false }
                if let n = metalVal as? NSNumber, n.floatValue > 0.5 { return false }
                return true
            }
        }
        return false
    }

    // MARK: - Pocket (leather)

    /// Pocket leather: rough PBR with no metalness.
    static func enhancePocketMaterials(in tableNode: SCNNode) {
        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isPocketMaterial(material, nodeName: nodeName) else { return }
            material.lightingModel = .physicallyBased
            material.roughness.contents = Float(0.85)
            material.metalness.contents = Float(0.0)
        }
    }

    private static func isPocketMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let combined = normalizeIdentifier(nodeName ?? "") + " " + normalizeIdentifier(material.name ?? "")
        if combined.contains("pocket") || combined.contains("dai") || combined.contains("袋") {
            return true
        }
        if let color = material.diffuse.contents as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            if r < 0.1 && g < 0.1 && b < 0.1 { return true }
        }
        return false
    }

    // MARK: - Procedural normal maps (cached)

    static func cachedFeltNormalMap(size: Int) -> UIImage {
        if let cached = feltNormalMapCache[size] { return cached }
        let image = generateFeltNormalMap(size: size)
        feltNormalMapCache[size] = image
        return image
    }

    static func cachedWoodGrainNormalMap(size: Int) -> UIImage {
        if let cached = woodNormalMapCache[size] { return cached }
        let image = generateWoodGrainNormalMap(size: size)
        woodNormalMapCache[size] = image
        return image
    }

    /// Fine directional silk-like fibers (warp + weft + micro noise) for felt.
    static func generateFeltNormalMap(size: Int) -> UIImage {
        let s = size
        var pixels = [UInt8](repeating: 128, count: s * s * 4)
        for y in 0..<s {
            for x in 0..<s {
                let idx = (y * s + x) * 4
                let nx = Float(x) / Float(s)
                let ny = Float(y) / Float(s)

                let warpFiber = sin(ny * 200.0 + fbm(x: nx * 60, y: ny * 20, octaves: 2) * 2.0)
                let weftFiber = sin(nx * 180.0 + fbm(x: nx * 20, y: ny * 60, octaves: 2) * 1.5) * 0.4
                let micro = fbm(x: nx * 120, y: ny * 120, octaves: 2)

                let dx = (warpFiber * 0.6 + weftFiber + micro * 0.3) * 18.0
                let dy = (warpFiber * 0.3 + weftFiber * 0.8 + micro * 0.3) * 18.0

                pixels[idx + 0] = UInt8(clamping: Int(128 + dx))
                pixels[idx + 1] = UInt8(clamping: Int(128 + dy))
                pixels[idx + 2] = 255
                pixels[idx + 3] = 255
            }
        }
        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    /// Long horizontal grain strokes for wood rail material.
    static func generateWoodGrainNormalMap(size: Int) -> UIImage {
        let s = size
        var pixels = [UInt8](repeating: 128, count: s * s * 4)
        for y in 0..<s {
            for x in 0..<s {
                let idx = (y * s + x) * 4
                let nx = Float(x) / Float(s)
                let ny = Float(y) / Float(s)
                let grain = sin(ny * 40.0 + fbm(x: nx * 8, y: ny * 8, octaves: 2) * 3.0) * 15.0
                pixels[idx + 0] = 128
                pixels[idx + 1] = UInt8(clamping: Int(128 + grain))
                pixels[idx + 2] = 255
                pixels[idx + 3] = 255
            }
        }
        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    // MARK: - Image helpers

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

    // MARK: - Detection helpers

    private static func normalizeIdentifier(_ s: String) -> String {
        s.lowercased()
         .replacingOccurrences(of: "_", with: "")
         .replacingOccurrences(of: "-", with: "")
         .replacingOccurrences(of: " ", with: "")
    }

    private static func isGreenish(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return g > 0.2 && g > r && g > b * 0.8
    }

    private static func isGreenishImage(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = min(cgImage.width, 32)
        let height = min(cgImage.height, 32)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR = 0, totalG = 0, totalB = 0
        let count = width * height
        for i in 0..<count {
            totalR += Int(pixelData[i * 4])
            totalG += Int(pixelData[i * 4 + 1])
            totalB += Int(pixelData[i * 4 + 2])
        }
        let avgR = Float(totalR) / Float(count)
        let avgG = Float(totalG) / Float(count)
        let avgB = Float(totalB) / Float(count)
        return avgG > 60 && avgG > avgR * 1.2 && avgG > avgB * 1.1
    }

    private static func extractImage(from contents: Any?) -> UIImage? {
        if let image = contents as? UIImage { return image }
        let obj = contents as AnyObject
        if CFGetTypeID(obj) == CGImage.typeID {
            return UIImage(cgImage: obj as! CGImage)
        }
        return nil
    }

    /// Distinguishes a real texture (image / URL / CGImage) from a scalar/colour scalar.
    private static func hasTextureContents(_ contents: Any?) -> Bool {
        guard let contents else { return false }
        if contents is UIImage { return true }
        if contents is URL { return true }
        let obj = contents as AnyObject
        if CFGetTypeID(obj) == CGImage.typeID { return true }
        return false
    }

    // MARK: - Material enumeration

    private static func enumerateMaterials(in node: SCNNode, handler: (SCNMaterial, String?) -> Void) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                handler(material, node.name)
            }
        }
        for child in node.childNodes {
            enumerateMaterials(in: child, handler: handler)
        }
    }

    // MARK: - Noise helpers

    private static func hash2D(_ x: Int, _ y: Int) -> Float {
        var h = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        return Float(h & 0x7FFFFFFF) / Float(0x7FFFFFFF)
    }

    private static func smoothNoise(x: Float, y: Float) -> Float {
        let ix = Int(floor(x))
        let iy = Int(floor(y))
        let fx = x - Float(ix)
        let fy = y - Float(iy)
        let sx = fx * fx * (3 - 2 * fx)
        let sy = fy * fy * (3 - 2 * fy)
        let n00 = hash2D(ix, iy)
        let n10 = hash2D(ix + 1, iy)
        let n01 = hash2D(ix, iy + 1)
        let n11 = hash2D(ix + 1, iy + 1)
        let nx0 = n00 + (n10 - n00) * sx
        let nx1 = n01 + (n11 - n01) * sx
        return nx0 + (nx1 - nx0) * sy
    }

    private static func fbm(x: Float, y: Float, octaves: Int) -> Float {
        var value: Float = 0
        var amplitude: Float = 1
        var frequency: Float = 1
        var maxAmp: Float = 0
        for _ in 0..<octaves {
            value += smoothNoise(x: x * frequency, y: y * frequency) * amplitude
            maxAmp += amplitude
            amplitude *= 0.5
            frequency *= 2
        }
        return value / maxAmp - 0.5
    }
}
