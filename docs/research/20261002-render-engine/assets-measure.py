"""Read-only asset inventory; writes JSON evidence only, never mutates inputs.

Run from repository root with python3. Polygon fan-equivalent counts are a
complexity measure, not an assertion about SceneKit GPU triangulation.
"""
import collections
import datetime
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).with_name('assets-evidence.json')
report = {
    'read_started': datetime.datetime.now().astimezone().isoformat(),
    'python': sys.version,
    'usdcat_version': subprocess.check_output(['/usr/bin/usdcat', '--version'], text=True).strip(),
    'method': 'zipfile + PNG IHDR + /usr/bin/usdcat read-only stdout + regex on explicit Mesh/GeomSubset arrays',
    'limitations': 'No runtime CPU/GPU residency, upload, bandwidth, actual renderer tessellation or energy measurement. RGBA8 estimates assume every listed PNG is independently resident; actual formats/use differ.',
    'files': [], 'folders': {}, 'usd_geometry': [],
}

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def png(b):
    if b[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    w, h, bits, color = struct.unpack('>IIBB', b[16:26])
    return {'width': w, 'height': h, 'bits': bits, 'png_color_type': color}

paths = [ROOT / 'QiuJi/Resources/TaiQiuZhuo.usdz']
for folder in ['TrainingRoom', 'TableMaterials', 'TableStyles', 'BallStickers']:
    folder_paths = sorted((ROOT / 'QiuJi/Resources' / folder).glob('*'))
    manifest = hashlib.sha256()
    for p in folder_paths:
        if p.is_file():
            paths.append(p)
            manifest.update((p.name + '\0' + digest(p) + '\n').encode())
    report['folders'][folder] = {'manifest_sha256': manifest.hexdigest(), 'manifest_rule': 'sorted direct files; filename + NUL + sha256 + newline'}

for p in paths:
    row = {'path': str(p.relative_to(ROOT)), 'bytes': p.stat().st_size, 'sha256_before': digest(p)}
    if p.suffix == '.png':
        row['png'] = png(p.read_bytes())
    if p.suffix == '.usdz':
        with zipfile.ZipFile(p) as z:
            row['members'] = []
            for member in z.infolist():
                entry = {'name': member.filename, 'bytes': member.file_size, 'zip_compression_type': member.compress_type}
                if member.filename.endswith('.png'):
                    entry['png'] = png(z.read(member))
                row['members'].append(entry)
        text = subprocess.check_output(['/usr/bin/usdcat', str(p)], text=True)
        result = {'path': row['path'], 'usda_stdout_bytes': len(text.encode()), 'meshes': [],
                  'up_axis': re.findall(r'upAxis = [^\n]+', text),
                  'meters_per_unit': re.findall(r'metersPerUnit = [^\n]+', text),
                  'materials': re.findall(r'\bdef Material "([^"]+)"', text)}
        meshes = list(re.finditer(r'\bdef Mesh "([^"]+)"', text))
        for i, m in enumerate(meshes):
            block = text[m.start():meshes[i + 1].start() if i + 1 < len(meshes) else len(text)]
            counts = [int(x) for x in re.search(r'int\[\] faceVertexCounts\s*=\s*\[([^\]]+)\]', block)[1].split(',')]
            points = re.search(r'point3f\[\] points\s*=\s*\[([^\]]+)\]', block)
            mesh = {'name': m[1], 'points': points[1].count('(') if points else None,
                    'polygons': len(counts), 'corners': sum(counts), 'fan_equivalent_triangles': sum(n - 2 for n in counts),
                    'max_polygon_corners': max(counts), 'polygon_histogram': dict(collections.Counter(counts)),
                    'material_subsets': []}
            subsets = list(re.finditer(r'\bdef GeomSubset "([^"]+)"', block))
            for j, s in enumerate(subsets):
                sub = block[s.start():subsets[j + 1].start() if j + 1 < len(subsets) else len(block)]
                ids = re.search(r'int\[\] indices = \[([^\]]+)\]', sub)
                mat = re.search(r'rel material:binding = <([^>]+)>', sub)
                if ids:
                    indices = [int(x) for x in ids[1].split(',')]
                    mesh['material_subsets'].append({'name': s[1], 'binding': mat[1] if mat else None,
                       'polygons': len(indices), 'fan_equivalent_triangles': sum(counts[k] - 2 for k in indices)})
            result['meshes'].append(mesh)
        for field in ['points', 'polygons', 'corners', 'fan_equivalent_triangles']:
            result[field] = sum(m[field] for m in result['meshes'])
        report['usd_geometry'].append(result)
    row['sha256_after'] = digest(p)
    row['stable_during_read'] = row['sha256_before'] == row['sha256_after']
    report['files'].append(row)

report['read_finished'] = datetime.datetime.now().astimezone().isoformat()
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'output': str(OUT), 'read_started': report['read_started'], 'read_finished': report['read_finished'],
                  'file_count': len(report['files']), 'all_stable': all(x['stable_during_read'] for x in report['files']),
                  'geometry': [{k: r[k] for k in ['path', 'polygons', 'fan_equivalent_triangles']} for r in report['usd_geometry']]}, ensure_ascii=False))
