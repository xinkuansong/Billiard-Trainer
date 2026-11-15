"""Exercise the live shared material refresh and retain its generated shaders.

Native macOS contract harness, not a full App or performance benchmark.
Unrelated scene state and the unreachable prototype path use explicit shims.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--work', type=Path, required=True)
p.add_argument('--evidence', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[3]
scene = root / 'QiuJi/Core/Scene'
lighting = (scene / 'MobileReferenceLighting.swift').read_text()
contact = (scene / 'MobileTableRendering.swift').read_text()


def between(text, start, end):
    assert text.count(start) == 1, start
    first = text.index(start)
    return text[first:text.index(end, first)]


pieces = [
    between(lighting, '    struct Panel {', '    /// Same gate'),
    between(lighting, '    static var balanceTrialRequested:', '    static let environment:'),
    between(lighting, '    enum SamplingProfile {', '    static func filteredBallShader('),
    between(lighting, '    static func refreshClothLighting(', '    /// Cull provably irrelevant'),
    between(lighting, '    static func directShadowShader(', '    /// Cue varnish,'),
    between(lighting, '    private static let clothShader = rig.shader("""', '\n}\n\n\n#if DEBUG'),
]
uniforms = between(contact, '    static func uniformDeclarations(', '    init(scene:')
contact_body = between(contact, '        var shader = "#pragma arguments', '        var targets:')
constants = (root / 'QiuJi/Core/Physics/BTPhysicsConstants.swift').read_text()
dimensions = [re.findall(r'^    static let ' + key + r': Float = [0-9.]+$', constants, re.M)[0]
              for key in ['innerLength', 'innerWidth']]
calculator = (scene / 'AngleSceneCalculator.swift').read_text()
calculator_sizes = '\n'.join(re.findall(r'^    static let (?:innerLength|innerWidth|ballRadius):.*$', calculator, re.M))
assert len(calculator_sizes.splitlines()) == 3
opacity = re.findall(r'^    static let encodedOpacityScale: Float = .+$', contact, re.M)
assert len(opacity) == 1
generated = '''import Foundation
import SceneKit
import Metal
import CryptoKit
import simd
enum TablePhysics {
''' + '\n'.join(dimensions) + '\n}\nenum AngleSceneCalculator {\n' + calculator_sizes + '''
}
enum MobileTableRendering { static let railOcclusion: Any? = true }
enum MobileContactOcclusion {
''' + opacity[0] + '\n' + uniforms + '''
 static func source(capacity: Int) -> String {
 let balls = Array(repeating: 0, count: capacity), batchesUniforms = true
 let radius = AngleSceneCalculator.ballRadius, surfaceY: Float = 0.8
''' + contact_body + '''
 return shader
 }
}
final class AngleTrainingScene {
 var usesClothLightingPrototype = false
 var renderingProfile: MobileReferenceLighting.SpecializedProfile = .reflection
 var mergesDailyClothSupport = false, factorsDailyClothBRDF = false, safeClothSupportRequested = false
 var clothSupportRequest = DailyClothSupportExperiment.Request.configuredDefault
 var staticClothIrradiance: StaticClothIrradiance?
 var tableNode: SCNNode? = SCNNode()
 var recordedState: DailyClothSupportExperiment.State?
 func recordSafeClothSupportState(_ state: DailyClothSupportExperiment.State) { recordedState = state }
}
enum MobileReferenceLighting {
''' + '\n'.join(pieces) + '''
 static func applyClothLightingPrototype(to material: SCNMaterial) throws { fatalError("Unreachable prototype") }
}
''' + Path(__file__).with_name('integration_main.swift').read_text()
files = [scene / n for n in ['StaticClothIrradiance.swift', 'MobileReferenceLighting.swift',
                              'MobileTableRendering.swift', 'DailyClothSupportExperiment.swift', 'AngleSceneCalculator.swift']]
files += [root / 'QiuJi/Core/Physics/BTPhysicsConstants.swift', Path(__file__), Path(__file__).with_name('integration_main.swift')]
identity = lambda: {str(f.relative_to(root)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
before = identity()
(a.evidence / 'source-identity.json').write_text(json.dumps(before, indent=2) + '\n')
(a.work / 'main.swift').write_text(generated)
(a.evidence / 'main.swift').write_text(generated)
for name in ['StaticClothIrradiance.swift', 'DailyClothSupportExperiment.swift']:
    shutil.copy2(scene / name, a.evidence)
for variant, flags in [('debug', ['-D', 'DEBUG']), ('nondebug', [])]:
    with (a.evidence / (variant + '-compile.log')).open('w') as log:
        subprocess.run(['xcrun', 'swiftc', '-O', *flags, str(scene / 'StaticClothIrradiance.swift'),
                        str(scene / 'DailyClothSupportExperiment.swift'), str(a.work / 'main.swift'),
                        '-o', str(a.work / 'probe')], check=True, stdout=log, stderr=subprocess.STDOUT)
    for mode, args in [('default', []), ('c1', ['-rendering.noConstantClothBalls']),
                       ('original', ['-rendering.referenceCloth']), ('no-field', ['-rendering.noStaticClothField'])]:
        output = a.evidence / variant / mode
        with (a.evidence / (variant + '-' + mode + '.log')).open('w') as log:
            subprocess.run([str(a.work / 'probe'), str(root), str(output), mode, *args],
                           check=True, stdout=log, stderr=subprocess.STDOUT)
assert identity() == before, 'Source drift'
print('Live shared refresh: Debug/non-DEBUG, default and three diagnostic modes passed')
