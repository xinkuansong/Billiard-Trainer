"""Read-only source audit. Run in Blender background; outputs stay outside the app."""
import bpy
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/table-materials-v64/W0/blender'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'QiuJi/Resources/TaiQiuZhuo.usdz'
before = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
options = bpy.ops.wm.usd_import.get_rna_type().properties['import_textures_mode'].enum_items.keys()
assert 'IMPORT_PACK' in options
bpy.ops.wm.usd_import(filepath=str(SOURCE), import_textures_mode='IMPORT_PACK')
report = {'blender': bpy.app.version_string, 'source_sha256': before,
          'unit_scale': bpy.context.scene.unit_settings.scale_length,
          'materials': [], 'regions': [], 'textures': [], 'uv_groups': []}
names = {'Leather', 'Wood', 'BlackWood', 'TaiNi', 'MG_Gold', 'White', 'Gold', 'Black'}
for mat in bpy.data.materials:
    if mat.name not in names:
        continue
    report['materials'].append({'name': mat.name, 'nodes': [
        {'name': n.name, 'type': n.type,
         'image': n.image.name if n.type == 'TEX_IMAGE' and n.image else None}
        for n in mat.node_tree.nodes] if mat.use_nodes else []})
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    mesh = obj.data
    uv = mesh.uv_layers.active
    mesh.calc_loop_triangles()
    for slot, mat in enumerate(mesh.materials):
        if mat is None or mat.name not in names:
            continue
        samples, verts, uv_values = [], [], []
        groups = {}
        area_world = area_uv = 0.0
        for tri in mesh.loop_triangles:
            if tri.material_index != slot:
                continue
            xyz = [obj.matrix_world @ mesh.vertices[i].co for i in tri.vertices]
            world = (xyz[1]-xyz[0]).cross(xyz[2]-xyz[0]).length / 2
            verts.extend([list(p) for p in xyz])
            area_world += world
            if uv:
                tex = [uv.data[i].uv for i in tri.loops]
                uv_values.extend([list(t) for t in tex])
                a, b = tex[1]-tex[0], tex[2]-tex[0]
                size = abs(a.x*b.y-a.y*b.x) / 2
                area_uv += size
                if size > 1e-12 and world > 1e-12:
                    scale = (world / size) ** 0.5
                    samples.append(scale)
                    center = sum(xyz, xyz[0]*0) / 3
                    normal = (xyz[1]-xyz[0]).cross(xyz[2]-xyz[0]).normalized()
                    group = 'top' if abs(normal.z) > .8 else 'side_or_bevel'
                    if mat.name == 'Leather':
                        group = ('left' if center.x < -.7 else 'right' if center.x > .7 else 'middle') + ('_front_' if center.y < 0 else '_back_') + group
                    edges = np.array([list(xyz[1]-xyz[0]), list(xyz[2]-xyz[0])]).T
                    tex_edges = np.array([list(a),list(b)]).T
                    singular = np.linalg.svd(edges @ np.linalg.inv(tex_edges), compute_uv=False)
                    groups.setdefault(group, []).append([scale, world, float(singular[0]/singular[1])])
        for group, rows in groups.items():
            values = np.array(rows)
            def weighted_quantiles(column):
                ordered = values[values[:,column].argsort()]
                cumulative = np.cumsum(ordered[:,1]); cumulative /= cumulative[-1]
                return np.interp([.1,.5,.9], cumulative, ordered[:,column]).tolist()
            report['uv_groups'].append({'object':obj.name, 'material':mat.name, 'group':group,
                'triangles':len(rows), 'area':float(values[:,1].sum()),
                'area_weighted_meters_per_uv':weighted_quantiles(0),
                'area_weighted_anisotropy':weighted_quantiles(2)})
        if not verts:
            continue
        v = np.array(verts)
        t = np.array(uv_values)
        report['regions'].append({'object': obj.name, 'material': mat.name,
            'triangles': len(verts)//3, 'world_bounds': [v.min(0).tolist(), v.max(0).tolist()],
            'uv_bounds': [t.min(0).tolist(), t.max(0).tolist()] if len(t) else None,
            'world_area': area_world, 'uv_area': area_uv,
            'world_units_per_uv_quantiles': np.quantile(samples, [.1,.5,.9]).tolist() if samples else None})
for image in bpy.data.images:
    if not any(image.name.startswith(n+'_') for n in names) or image.size[0] == 0:
        continue
    values = np.empty(len(image.pixels), dtype=np.float32)
    image.pixels.foreach_get(values)
    values = values.reshape(-1, image.channels)
    report['textures'].append({'name': image.name, 'size': list(image.size),
        'channels': image.channels, 'color_space': image.colorspace_settings.name,
        'min': values.min(0).tolist(), 'max': values.max(0).tolist(),
        'mean': values.mean(0, dtype=np.float64).tolist(), 'std': values.std(0, dtype=np.float64).tolist()})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source-audit.blend'))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == before
(OUT/'audit.json').write_text(json.dumps(report, indent=2))
print('MATERIAL_AUDIT_COMPLETE',len(report['regions']),len(report['textures']))
