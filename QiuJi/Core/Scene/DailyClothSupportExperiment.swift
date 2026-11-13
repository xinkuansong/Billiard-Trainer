import Foundation
import CryptoKit

/// Shared cloth optimization for the reference rendering recipe. The original
/// generator remains the exact fallback for unsupported configurations.
enum DailyClothSupportExperiment {
    static let algorithmVersion = "height-safe-below-r3-signbit-finite-rig-20261113"
    static let guardAlgorithmVersion = "legacy-cone-plus-safe-hoisted-finite-domain-guard-r1-20261113"
    static let emitterSHA256 = "65c4665f3e1221ee507eefe9fd4e3e6513de2581fa9818a253e67e190ef3db42"
    static let referenceCoreSHA256 = "8f2753a642a9e0da466389406a374fdc25fc47f0026b0dccff91efa9f8fd3495"

    enum Request: String, CaseIterable {
        case off, plainSafe = "plain-safe", guardCombo = "guard-combo", conflict

        var algorithmIdentity: String {
            switch self {
            case .off: return "off"
            case .plainSafe: return algorithmVersion
            case .guardCombo: return guardAlgorithmVersion
            case .conflict: return "conflicting-support-flags"
            }
        }

        static func resolve(arguments: [String]) -> Request {
            let reference = arguments.contains("-rendering.referenceCloth")
            let plain = arguments.contains("-daily3D.safeClothSupport")
            let guarded = arguments.contains("-daily3D.guardClothSupport")
            if [reference, plain, guarded].filter({ $0 }).count > 1 { return .conflict }
            if reference { return .off }
            return plain ? .plainSafe : .guardCombo
        }

        /// Release never consumes diagnostic process arguments. All production
        /// entry points share this default; DEBUG keeps explicit A/B controls.
        static var configuredDefault: Request {
            #if DEBUG
            resolve(arguments: ProcessInfo.processInfo.arguments)
            #else
            .guardCombo
            #endif
        }
    }

    struct State: Hashable {
        let request: Request
        let requested: Bool
        let effective: Bool
        let variant: String
        let fallbackReason: String?
        let capacity: Int
        let profile: String
        let sampling: String
        var requestedVariant: String { request.rawValue }

        var probeCacheIdentity: String {
            guard requested else { return "off" }
            return "\(request.algorithmIdentity)|\(variant)|\(capacity)|\(profile)|\(sampling)|\(fallbackReason ?? "applied")"
        }

        func fallingBack(_ reason: String) -> State {
            State(request: request, requested: requested, effective: false, variant: "off", fallbackReason: reason,
                  capacity: capacity, profile: profile, sampling: sampling)
        }
    }

    struct Program {
        let source: String
        let declaration: String
        let declarationSuffix: String
        let state: State
    }

    private struct GuardText: Sendable {
        let source: String
        let declarationSuffix: String
    }

    /// One immutable text payload, not a scene/material/program cache. Callers
    /// must still pass every input gate below; output SHA checks also run on hits.
    private final class GuardTextCache: @unchecked Sendable {
        private let lock = NSLock()
        private var text: GuardText?

        func validatedText(reference: String) -> GuardText? {
            lock.lock(); defer { lock.unlock() }
            guard let candidate = text?.source ?? DailyClothSupportExperiment.guardedCore(reference),
                  DailyClothSupportExperiment.sha256(candidate) == DailyClothSupportExperiment.guardCoreSHA256,
                  DailyClothSupportExperiment.sha256(DailyClothSupportExperiment.guardHelperFunctions)
                    == DailyClothSupportExperiment.guardHelperSHA256 else { return nil }
            if let text { return text }
            let validated = GuardText(source: candidate,
                declarationSuffix: "\n" + DailyClothSupportExperiment.guardHelperFunctions + "\n")
            text = validated
            return validated
        }
    }
    private static let guardTextCache = GuardTextCache()

    static func pending(requested: Bool, profile: MobileReferenceLighting.SpecializedProfile,
                        capacity: Int = 0) -> State {
        pending(request: requested ? .plainSafe : .off, profile: profile, capacity: capacity)
    }

    static func pending(request: Request, profile: MobileReferenceLighting.SpecializedProfile,
                        capacity: Int = 0) -> State {
        State(request: request, requested: request != .off, effective: false, variant: "off",
              fallbackReason: request == .off ? "not-requested" : "not-installed", capacity: capacity,
              profile: profile.rawValue, sampling: "not-installed")
    }

    static func cacheIdentity(requested: Bool) -> String {
        requested ? algorithmVersion : "off"
    }

    static func cacheIdentity(request: Request) -> String { request.algorithmIdentity }

    /// Called only when a cloth program is built/refreshed, never per frame.
    /// The source is supplied by the unchanged production generator.
    static func resolve(reference: String, emitter: String, requested: Bool,
                        capacity: Int, profile: MobileReferenceLighting.SpecializedProfile,
                        sampling: MobileReferenceLighting.SamplingProfile,
                        usesMask: Bool, specialized: Bool, mergesSupport: Bool,
                        factorsBRDF: Bool, prototype: Bool, balanceTrial: Bool,
                        supportRequest: Request? = nil) -> Program {
        let request = supportRequest ?? (requested ? .plainSafe : .off)
        let state = State(request: request, requested: request != .off, effective: false, variant: "off", fallbackReason: nil,
                          capacity: capacity, profile: profile.rawValue, sampling: String(describing: sampling))
        func fallback(_ reason: String) -> Program {
            Program(source: reference, declaration: "", declarationSuffix: "", state: state.fallingBack(reason))
        }
        guard request != .off else { return fallback("not-requested") }
        guard request != .conflict else { return fallback("conflicting-support-flags") }
        guard profile == .reflection else { return fallback("unsupported-profile") }
        guard sampling == .reference else { return fallback("unsupported-sampling") }
        guard usesMask else { return fallback("mask-disabled") }
        guard specialized else { return fallback("specialization-disabled") }
        guard capacity == 16 else { return fallback("unsupported-capacity") }
        guard !mergesSupport else { return fallback("merged-support-conflict") }
        guard !factorsBRDF else { return fallback("factored-brdf-conflict") }
        guard !prototype else { return fallback("cloth-prototype-conflict") }
        guard !balanceTrial else { return fallback("balance-trial-conflict") }
        guard sha256(emitter) == emitterSHA256 else { return fallback("emitter-source-drift") }
        guard sha256(reference) == referenceCoreSHA256,
              reference.contains("int samplesX=shadowPossible?8:2;"),
              reference.contains("int samplesZ=shadowPossible?4:2;"),
              reference.contains("float3 center=float3(shadowBall.x,0.8+shadowBall.z,shadowBall.y);"),
              reference.contains("max(0.000001,lightCellRadius*t/sqrt(r2))") else {
            return fallback("reference-source-drift")
        }
        if request == .guardCombo {
            guard let text = guardTextCache.validatedText(reference: reference) else {
                return fallback("guard-source-drift")
            }
            return Program(source: text.source, declaration: "",
                           declarationSuffix: text.declarationSuffix,
                           state: State(request: request, requested: true, effective: true,
                                        variant: guardAlgorithmVersion, fallbackReason: nil, capacity: capacity,
                                        profile: profile.rawValue, sampling: String(describing: sampling)))
        }
        var candidate = reference
        for index in 0..<capacity {
            let tail = "top>=2.2 || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<\(index));"
            let anchor = "if(p.y<0.8 || " + tail
            guard candidate.components(separatedBy: anchor).count == 2 else {
                return fallback("mask-anchor-drift")
            }
            candidate = candidate.replacingOccurrences(of: anchor,
                with: "if((p.y<0.8 && height_safe_below_mask(p,contactBall\(index))) || " + tail)
        }
        return Program(source: candidate, declaration: heightSafeBelow + "\n", declarationSuffix: "",
                       state: State(request: request, requested: true, effective: true, variant: algorithmVersion,
                                    fallbackReason: nil, capacity: capacity, profile: profile.rawValue,
                                    sampling: String(describing: sampling)))
    }

    static func sha256(_ source: String) -> String {
        SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Reproduce the audited single-transport guard program. The original near
    /// decision, 64/8 samples, visibility arithmetic and full emission tail stay
    /// in their original path; no duplicate referenceAt early return is added.
    private static func guardedCore(_ reference: String) -> String? {
        func one(_ source: String, _ anchor: String, _ replacement: String) -> String? {
            guard source.components(separatedBy: anchor).count == 2 else { return nil }
            return source.replacingOccurrences(of: anchor, with: replacement)
        }
        var candidate = reference
        for index in 0..<16 {
            let original = "if(p.y<0.8 || top>=2.2 || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<\(index));"
            let replacement = "if(top>=2.2 || dot(offset,offset)<=bound*bound || (belowBed && (!diagnosticConeEligible || !receiverCanPrune || height_safe_ball_mask(p,contactBall\(index))))) shadowMask |= (1u<<\(index));"
            guard let modified = one(candidate, original, replacement) else { return nil }
            candidate = modified
        }
        let mask = "uint shadowMask=0u;\n"
        let opening = "bool diagnosticConeEligible=!shadowPossible || legacyConeDomain(p,shadowBalls);\n" + mask
            + "if(shadowPossible) {\nbool belowBed=p.y<0.8;\n"
            + "bool receiverCanPrune=belowBed && (as_type<uint>(p.y)&0x80000000u)==0u && p.y>=0.0\n"
            + "    && abs(p.x)<=2.5399999618530273 && abs(p.z)<=1.2699999809265137;\n"
        guard let opened = one(candidate, mask, opening),
              let classified = one(opened, "for(int panel=0;panel<2;++panel) {",
                "\n}\n" + guardClassification + "\nfor(int panel=0;panel<2;++panel) {"),
              let gated = one(classified, "if(shadowPossible) {\nuint remainingShadowBalls=shadowMask;",
                "if(diagnosticGlobalQuality) {\nuint remainingShadowBalls=shadowMask;") else { return nil }
        return gated
    }

    // Frozen complete SceneKit source: native-scene-guardcombo-package-r2.
    // Keep declaration order, address space, finite-domain guard and margins.
    static let guardCoreSHA256 = "1ab12b0e9075e014f32c73fcf30e16126c91f1b17e045a750dd7bf9c0d899a93"
    static let guardHelperSHA256 = "dc49cdace4f9a18a16a71e3670a2c42b61fa2444d6f61956287b5c1c21054f6b"
    static let guardSurfaceSHA256 = "ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd"
    private static let guardHelperFunctions = """
    // Research-only mask predicate. KEEP original shadowPossible, 8/64 choice,
    // original above-bed mask predicate and original ball/shadow arithmetic.
    // This helper replaces only the unconditional `p.y < 0.8` OR term:
    //   (p.y < 0.8 && height_safe_below_mask(p, ball)) || originalInSupport
    // originalInSupport is top>=2.2 || dot(offset,offset)<=oldBound*oldBound.
    // Domain: current source rig footprint and y between floor and physical bed.
    // Outside domain retains old below-bed all-active behavior. No snapping.
    bool height_safe_ball_mask(float3 p, float4 ball) {
        if (!(abs(ball.x) <= 2.5399999618530273 && abs(ball.y) <= 1.2699999809265137)) return true;
        // Upper bounds from actual Float32 near (8x4 per lamp) source operations.
        const float q = 0.2533283829689026;
        const float M = 2.484830617904663;
        const float r = 0.028576001524925232; // nextUp(float(R32 + floor32))
        float centerY = 0.8 + ball.z; // same ball center expression as production
        float gap = 3.0 - centerY - r - q;
        if (!(gap > 0.0)) return true;
        float support = r + (centerY - p.y + r) / gap * (length(ball.xy) + M + q + r);
        float2 delta = p.xz - ball.xy;
        return dot(delta,delta) <= support*support;
    }
    
    // Research eligibility for the archived cone, not a universal scene guarantee.
    inline bool legacyConeDomain(float3 p,thread const float4 *balls) {
        if((as_type<uint>(p.y)&0x80000000u)!=0u) return false;
        if(!(p.y>=0.0 && p.y<=0.9 && abs(p.x)<=2.5399999618530273
             && abs(p.z)<=1.2699999809265137)) return false;
        for(int i=0;i<16;++i) {
            float4 b=balls[i];
            if(b.w>0.0 && !(abs(b.x)<=2.5399999618530273 && abs(b.y)<=1.2699999809265137
                           && b.z>=0.028575 && b.z<=2.2)) return false;
        }
        return true;
    }
    """

    private static let guardClassification = """
    bool diagnosticGlobalQuality=shadowPossible && !diagnosticConeEligible;
    for(int panel=0;panel<2;++panel) {
    // r5: bounds the ORIGINAL 8x4 sample centres plus their filtered disks.
    // For a contributing ray: v=u*delta+e, |e| < R+max(1e-6,q*u).
    // Hence u <= (v.y+R+1e-6)/(H-q), and four outward cone planes
    // cannot exclude a contributing blocker when expanded by that radius.
    bool diagnosticHighQuality=false;
    if(shadowPossible && diagnosticConeEligible) {
        float3 diagnosticLight=v62EmitterCenter(panel);
        float diagnosticH=diagnosticLight.y-p.y;
        float diagnosticQ=sqrt(v62EmitterArea(panel)/(32.0*3.14159265));
        if(diagnosticH<=diagnosticQ) {
            diagnosticHighQuality=true; // Keep original non-planar/degenerate behaviour.
        } else {
            float diagnosticX0=diagnosticLight.x-length(v62EmitterU(panel))*0.875-p.x;
            float diagnosticX1=diagnosticLight.x+length(v62EmitterU(panel))*0.875-p.x;
            float diagnosticZ0=diagnosticLight.z-length(v62EmitterV(panel))*0.75-p.z;
            float diagnosticZ1=diagnosticLight.z+length(v62EmitterV(panel))*0.75-p.z;
            float3 diagnosticPlanes[4]={normalize(float3(-diagnosticH,diagnosticX0,0.0)),
                normalize(float3(diagnosticH,-diagnosticX1,0.0)),
                normalize(float3(0.0,diagnosticZ0,-diagnosticH)),
                normalize(float3(0.0,-diagnosticZ1,diagnosticH))};
            uint diagnosticRemaining=shadowMask;
            while(diagnosticRemaining!=0u) {
                uint diagnosticIndex=ctz(diagnosticRemaining);
                diagnosticRemaining &= diagnosticRemaining-1u;
                float4 diagnosticBall=shadowBalls[diagnosticIndex];
                float3 diagnosticCenter=float3(diagnosticBall.x,0.8+diagnosticBall.z,diagnosticBall.y);
                float3 diagnosticV=diagnosticCenter-p;
                float diagnosticU=clamp((diagnosticV.y+0.028575+0.000001)/(diagnosticH-diagnosticQ),0.0,1.0);
                // Roundoff expansion is proportional to world-coordinate scale.
                float diagnosticScale=max(1.0,max(length(p),max(length(diagnosticCenter),length(diagnosticLight))));
                float diagnosticRadius=0.028575+0.000001+diagnosticQ*diagnosticU+64.0*1.1920928955078125e-7*diagnosticScale;
                bool diagnosticInside=dot(diagnosticPlanes[0],diagnosticV)<=diagnosticRadius &&
                    dot(diagnosticPlanes[1],diagnosticV)<=diagnosticRadius &&
                    dot(diagnosticPlanes[2],diagnosticV)<=diagnosticRadius &&
                    dot(diagnosticPlanes[3],diagnosticV)<=diagnosticRadius;
                diagnosticHighQuality=diagnosticHighQuality || diagnosticInside;
            }
        }
    }
    diagnosticGlobalQuality=diagnosticGlobalQuality || diagnosticHighQuality;
    }
    """


    // Verbatim plain safe-r3 predicate, including the raw sign guard for FTZ.
    // Proof: output/render-lowdim-20261113/support-height-audit/PROOF.md.
    // No near-first/hoisted organization, altered samples, or approximate light.
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
}
