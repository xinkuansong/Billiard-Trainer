"""Extract paired production TaiNi texture parameters, not rendered pixel normals.

Uses the repository's existing NumPy/Pillow environment; no App dependency.
Default hypothetical bed basis: tangent +X, bitangent +Z, normal +Y.
Use --tangent-rotation-deg and --bitangent-sign to test other bases explicitly.
"""
from pathlib import Path
import argparse, hashlib, io, json, subprocess
import zipfile
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
ASSET = ROOT / 'QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz'
MOBILE = ROOT / 'QiuJi/Core/Scene/MobileTableRendering.swift'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def quantiles(a):
    return {str(p): float(x) for p, x in zip([0, .01, .5, .95, .99, 1],
                                            np.quantile(a, [0, .01, .5, .95, .99, 1]))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--tangent-rotation-deg', type=float, default=0.)
    ap.add_argument('--bitangent-sign', type=int, choices=(-1, 1), default=1)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    if (args.out / 'stats.json').exists():
        raise FileExistsError('Use a new output directory; previous evidence must not be overwritten')
    raw = ASSET.read_bytes()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        normal_bytes = archive.read('textures/TaiNi_normal.png')
        roughness_bytes = archive.read('textures/TaiNi_roughness.png')
    normal_image = Image.open(io.BytesIO(normal_bytes))
    roughness_image = Image.open(io.BytesIO(roughness_bytes))
    normal_rgb = np.asarray(normal_image)
    roughness_rgb = np.asarray(roughness_image)
    if normal_rgb.shape != roughness_rgb.shape or normal_rgb.shape[2] != 3:
        raise ValueError('Expected same-sized RGB inputs for paired sampling')
    binding = subprocess.run(['usdcat', '--flatten', '--mask', '/root/_materials/TaiNi', str(ASSET)],
                             capture_output=True, text=True, check=True).stdout
    for expected in ['inputs:roughness.connect = </root/_materials/TaiNi/Image_Texture_002.outputs:r>',
                     'inputs:normal.connect = </root/_materials/TaiNi/Image_Texture_003.outputs:rgb>',
                     'float4 inputs:bias = (-1, -1, -1, -1)', 'float4 inputs:scale = (2, 2, 2, 2)']:
        if expected not in binding:
            raise ValueError('USD material contract changed: ' + expected)
    if binding.count('token inputs:sourceColorSpace = "raw"') != 3:
        raise ValueError('Inspect numerical map source color spaces')
    (args.out / 'TaiNi-binding.usda').write_text(binding)
    mobile = MOBILE.read_text()
    if 'for property in [material.normal, material.roughness]' not in mobile or 'property.contentsTransform = SCNMatrix4MakeScale(2, 2, 1)' not in mobile:
        raise ValueError('Runtime texture transform contract changed')
    # This probe loads material properties only: no renderer, no screenshot or GPU draw.
    swift = '''import Foundation
import SceneKit
let s=try SCNScene(url:URL(fileURLWithPath:CommandLine.arguments[1]), options:nil)
var seen=Set<ObjectIdentifier>()
var rows=[[String:Any]]()
s.rootNode.enumerateHierarchy { n,_ in
 for m in n.geometry?.materials ?? [] where m.name == "TaiNi" && seen.insert(ObjectIdentifier(m)).inserted {
  rows.append(["material":m.name ?? "", "normalIntensity":m.normal.intensity,
  "roughnessIntensity":m.roughness.intensity,"normalMappingChannel":m.normal.mappingChannel,
  "roughnessMappingChannel":m.roughness.mappingChannel,
  "normalContents":String(describing:m.normal.contents),"roughnessContents":String(describing:m.roughness.contents)])
 }
}
let data=try JSONSerialization.data(withJSONObject:rows,options:[.sortedKeys,.prettyPrinted])
FileHandle.standardOutput.write(data)
'''
    swift_path = args.out / 'inspect_asset.swift'
    swift_path.write_text(swift)
    loaded = subprocess.run(['xcrun', 'swift', str(swift_path), str(ASSET)], capture_output=True, check=True)
    (args.out / 'scenekit-import.json').write_bytes(loaded.stdout)
    (args.out / 'scenekit-import.stderr.log').write_bytes(loaded.stderr)
    props = json.loads(loaded.stdout)
    if not props or any(x['normalIntensity'] != 1 or x['roughnessIntensity'] != 1 or x['normalMappingChannel'] != x['roughnessMappingChannel'] for x in props):
        raise ValueError('Imported intensity or paired UV contract changed')
    # Full-resolution raw parameter distribution, prior to filtering and mipmaps.
    tangent = normal_rgb.astype(np.float64) / 255 * 2 - 1
    tangent /= np.linalg.norm(tangent, axis=2, keepdims=True)
    roughness = roughness_rgb[:, :, 0].astype(np.float64) / 255
    tilt = np.rad2deg(np.arctan2(np.linalg.norm(tangent[:, :, :2], axis=2), tangent[:, :, 2]))
    height, width = roughness.shape
    rng = np.random.default_rng(20261113)
    # Paired texel samples: 24 by 16 stratification, then deterministic extrema witnesses.
    xy = np.array([(int(rng.integers(x*width//24, (x+1)*width//24)),
                    int(rng.integers(y*height//16, (y+1)*height//16)))
                   for y in range(16) for x in range(24)], dtype=np.int32)
    witnesses = [np.argmin(roughness), np.argmax(roughness), np.argmax(tilt), np.argmin(tilt)]
    for i, index in enumerate(witnesses):
        y, x = np.unravel_index(index, roughness.shape)
        xy[i] = [x, y]
    paired_tangent = tangent[xy[:, 1], xy[:, 0]]
    radians = np.deg2rad(args.tangent_rotation_deg)
    T = np.array([np.cos(radians), 0, np.sin(radians)])
    B = args.bitangent_sign * np.array([-np.sin(radians), 0, np.cos(radians)])
    N = np.array([0., 1., 0.])
    world = paired_tangent[:, :1]*T + paired_tangent[:, 1:2]*B + paired_tangent[:, 2:3]*N
    paired = np.column_stack((world, roughness[xy[:, 1], xy[:, 0]])).astype('<f4')
    np.save(args.out / 'paired.npy', paired)
    np.save(args.out / 'texel_xy.npy', xy)
    np.save(args.out / 'tangent_normals.npy', paired_tangent.astype('<f4'))
    stats = {
        'scope': 'Paired raw production texture parameter samples with an explicit hypothetical horizontal-bed tangent basis; not actual SceneKit shaded pixels or mesh UV mapping proof',
        'layout': {'paired.npy': ['normal_world_x', 'normal_world_y', 'normal_world_z', 'roughness'],
                   'texel_xy.npy': ['PNG column x', 'PNG row y (top-origin)'],
                   'sample_count': len(paired), 'sampling': '24x16 seeded stratified texels; first four replaced by roughness minimum, roughness maximum, normal tilt maximum, tilt minimum'},
        'basis': {'tangent': T.tolist(), 'bitangent': B.tolist(), 'normal': N.tolist(),
                  'rotation_deg': args.tangent_rotation_deg, 'bitangent_sign': args.bitangent_sign,
                  'handedness': float(np.dot(np.cross(T, B), N))},
        'texture': {'size': [width, height], 'roughness_raw_quantiles': quantiles(roughness),
                    'roughness_max_rgb_channel_difference_8bit': int(np.ptp(roughness_rgb.astype(np.int16), axis=2).max()),
                    'normal_tilt_degrees_quantiles': quantiles(tilt),
                    'sampled_roughness_quantiles': quantiles(paired[:, 3]),
                    'roughness_minimum_8bit': int(roughness_rgb.min()), 'roughness_maximum_8bit': int(roughness_rgb.max())},
        'bindings': {'roughness': 'raw R channel', 'normal': 'raw RGB * 2 - 1, normalized',
                     'import_probe': props, 'runtime_transform': 'normal and roughness contentsTransform scale(2,2,1); wrapS/T repeat',
                     'transform_source': str(MOBILE.relative_to(ROOT))},
        'source_sha256': {str(ASSET.relative_to(ROOT)): digest(raw), str(MOBILE.relative_to(ROOT)): digest(mobile.encode()),
                          'textures/TaiNi_normal.png': digest(normal_bytes), 'textures/TaiNi_roughness.png': digest(roughness_bytes),
                          'TaiNi-binding.usda': digest(binding.encode()), 'texture_samples.py': digest(Path(__file__).read_bytes())},
        'output_sha256': {name: digest((args.out / name).read_bytes()) for name in ['paired.npy', 'texel_xy.npy', 'tangent_normals.npy']},
        'assumptions_and_limits': ['Both channels sampled at the same stored texel; no random re-pairing.',
            'No mip, bilinear or anisotropic filtering; these are full-resolution texture values.',
            'No actual mesh tangent, bitangent, UV transform/orientation or rasterized normal was sampled.',
            'World normal conversion is an explicit configurable basis experiment, not evidence of actual per-pixel normal.',
            'macOS SceneKit asset import properties were measured; a complete iOS live scene was not built.',
            'Runtime color changes preserve normal/roughness in ClothAppearance; only the checked mobile transform is represented.']}
    (args.out / 'stats.json').write_text(json.dumps(stats, indent=2, ensure_ascii=False)+'\n')
    print(json.dumps({'output': str(args.out), 'sample_count': len(paired), 'roughness': stats['texture']['roughness_raw_quantiles'],
                      'normal_tilt': stats['texture']['normal_tilt_degrees_quantiles']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
