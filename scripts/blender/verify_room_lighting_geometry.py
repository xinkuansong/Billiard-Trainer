"""Reject lighting-only candidates that change the bundled room geometry or UVs."""
import argparse, hashlib, json, pathlib, sys
import bpy
import numpy as np

p=argparse.ArgumentParser();p.add_argument('--candidate',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
candidate=pathlib.Path(a.candidate).resolve()
baseline=pathlib.Path(__file__).resolve().parents[2]/'QiuJi/Resources/TrainingRoom'
def signature(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.usd_import(filepath=str(path),import_textures_mode='IMPORT_PACK')
    assert not any(o.type in ('LIGHT','CAMERA') for o in bpy.data.objects)
    meshes=[o for o in bpy.data.objects if o.type=='MESH'];assert len(meshes)==1
    o=meshes[0];m=o.data;assert m.uv_layers.active
    h=hashlib.sha256()
    # Include authored transforms as well as positions, topology and UV mapping.
    h.update(np.asarray(o.matrix_world,dtype='<f4').tobytes())
    for collection,attribute,width,dtype in [(m.vertices,'co',3,'<f4'),(m.loops,'vertex_index',1,'<i4'),(m.uv_layers.active.data,'uv',2,'<f4')]:
        values=np.empty(len(collection)*width,dtype=dtype);collection.foreach_get(attribute,values);h.update(values.tobytes())
    return dict(hash=h.hexdigest(),vertices=len(m.vertices),polygons=len(m.polygons))
rows=[]
for path in sorted(candidate.glob('Room_*_*.usdz')):
    before=signature(baseline/path.name);after=signature(path)
    assert before==after,(path.name,before,after)
    rows.append(dict(file=path.name,**after))
assert rows,'No completed exports'
(candidate/'geometry-audit.json').write_text(json.dumps(rows,indent=2))
print('UNCHANGED_GEOMETRY_AND_UV',len(rows))
