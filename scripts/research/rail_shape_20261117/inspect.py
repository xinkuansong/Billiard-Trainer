import bpy,json,hashlib
from pathlib import Path
from collections import Counter
root=Path('/Users/song/projects/13.billiard_trainer');out=root/'output/rail-shape-20261117'
source=root/'QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=str(source),import_textures_mode='IMPORT_NONE',import_cameras=False,import_lights=False)
report={'assetSHA':hashlib.sha256(source.read_bytes()).hexdigest(),'objects':[]}
for obj in bpy.data.objects:
 if obj.type!='MESH':continue
 vs=[obj.matrix_world@v.co for v in obj.data.vertices]
 mats=[m.name if m else None for m in obj.data.materials]
 row={'name':obj.name,'vertices':len(vs),'polygons':len(obj.data.polygons),'materials':mats,'min':[min(v[i] for v in vs) for i in range(3)],'max':[max(v[i] for v in vs) for i in range(3)],'hasCustomNormals':obj.data.has_custom_normals}
 if any(m and 'TaiNi' in m for m in mats):
  rows=[]
  for p in obj.data.polygons:
   if 'TaiNi' not in (mats[p.material_index] or ''):continue
   verts=[vs[i] for i in p.vertices];c=sum(verts,verts[0]*0)/len(verts)
   # Middle slice along the long axis; keep only the bed/cushion cross-section.
   if min(v.x for v in verts)<=0.6<=max(v.x for v in verts):
    rows.append({'poly':p.index,'center':list(c),'normal':list(obj.matrix_world.to_3x3()@p.normal),'smooth':p.use_smooth,'verts':[list(v) for v in verts],'cornerNormals':[list(obj.data.corner_normals[i].vector) for i in p.loop_indices]})
  row['middleSlice']=rows
 report['objects'].append(row)
(out/'mesh-slice-06.json').write_text(json.dumps(report,indent=2))
print("Mesh inspection complete")
