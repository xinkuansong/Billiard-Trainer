import Foundation
import CryptoKit
@testable import QiuJi

/// Research only. The production renderer never imports this builder.
enum ClothResearchShaders {
    static let identity = "height-safe-below-r3-signbit-finite-rig-20261113"
    static let emitterSHA256 = "65c4665f3e1221ee507eefe9fd4e3e6513de2581fa9818a253e67e190ef3db42"
    static let referenceCoreSHA256 = "8f2753a642a9e0da466389406a374fdc25fc47f0026b0dccff91efa9f8fd3495"

    // Verbatim predicate from scripts/research/cloth_lowdim_20261113/support_height_safe.metal.
    // Proof and bounded Float32 pressure evidence live in support-height-audit / support-height-bounded.
    static let heightSafeBelow = """
    bool height_safe_below_mask(float3 p, float4 ball) {
        if (p.y >= 0.8) return false;
        if ((as_type<uint>(p.y) & 0x80000000u) != 0u) return true;
        if (!(p.y >= 0.0 && abs(p.x) <= 2.5399999618530273 && abs(p.z) <= 1.2699999809265137
              && abs(ball.x) <= 2.5399999618530273 && abs(ball.y) <= 1.2699999809265137)) return true;
        const float q = 0.2533283829689026;
        const float M = 2.484830617904663;
        const float r = 0.028576001524925232;
        float centerY = 0.8 + ball.z;
        float gap = 3.0 - centerY - r - q;
        if (!(gap > 0.0)) return true;
        float support = r + (centerY - p.y + r) / gap * (length(ball.xy) + M + q + r);
        float2 delta = p.xz - ball.xy;
        return dot(delta,delta) <= support*support;
    }
    """

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func one(_ source: String, _ anchor: String, _ replacement: String) throws -> String {
        guard source.components(separatedBy: anchor).count == 2 else {
            throw error("Shader anchor missing or nonunique: \(anchor)")
        }
        return source.replacingOccurrences(of: anchor, with: replacement)
    }

    static func heightSafeSurface(_ source: String, ballCount: Int) throws -> String {
        guard ballCount == 16 else { throw error("This audited fixture requires 16 production contact slots") }
        guard sha256(MobileReferenceLighting.emitterGeometry) == emitterSHA256 else {
            throw error("Emitter rig drift: height-safe constants must be re-audited")
        }
        let reference = MobileReferenceLighting.directShadowShader(ballCount: ballCount, profile: .reflection)
        guard sha256(reference) == referenceCoreSHA256,
              reference.contains("int samplesX=shadowPossible?8:2;"),
              reference.contains("int samplesZ=shadowPossible?4:2;"),
              reference.contains("float3 center=float3(shadowBall.x,0.8+shadowBall.z,shadowBall.y);"),
              reference.contains("max(0.000001,lightCellRadius*t/sqrt(r2))"),
              !reference.contains("daily3DMergedSupport"),
              !reference.contains("daily3DFactoredBRDF") else {
            throw error("Production R quadrature, center, filter or support source drift")
        }
        var candidate = reference
        for index in 0..<ballCount {
            let tail = "top>=2.2 || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<\(index));"
            candidate = try one(candidate, "if(p.y<0.8 || " + tail,
                "if((p.y<0.8 && height_safe_below_mask(p,contactBall\(index))) || " + tail)
        }
        // Inserting beside the existing helper preserves SceneKit's declaration/body boundary.
        var full = try one(source, reference, candidate)
        full = try one(full, MobileReferenceLighting.analyticPanelDiffuse,
                       heightSafeBelow + "\n" + MobileReferenceLighting.analyticPanelDiffuse)
        return full
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ClothResearchShaders", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
