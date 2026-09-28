"""Bake generated side/crown atlas onto the existing PiTou UVs; never modify geometry."""
import bpy,bmesh,math,sys
from pathlib import Path
root=Path.cwd();out=root/'output/cue-grain-20260923/r18-app';assets=root/'QiuJi/Resources/CueStyles'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=str(assets/'CueUV.usdz'))
o=next(o for o in bpy.data.objects if o.type=='MESH')
idx=next(i for i,m in enumerate(o.data.materials) if m.name=='PiTou')
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=idx],context='FACES');bm.to_mesh(o.data);bm.free()
mesh=o.data;original=mesh.uv_layers.active;original.active_render=True
sample=mesh.uv_layers.new(name='GeneratedSource')
vs=[mesh.vertices[i] for i in {i for f in mesh.polygons for i in f.vertices}];cx=(max(v.co.x for v in vs)+min(v.co.x for v in vs))/2;cz=(max(v.co.z for v in vs)+min(v.co.z for v in vs))/2
rad=max(math.hypot(v.co.x-cx,v.co.z-cz) for v in vs);lo=min(v.co.y for v in vs);hi=max(v.co.y for v in vs)
for f in mesh.polygons:
 crown=f.normal.y>.5;coords=[]
 for li in f.loop_indices:
  v=mesh.vertices[mesh.loops[li].vertex_index].co
  if crown:uv=(.5+.44*(v.x-cx)/rad,.25+.21*(v.z-cz)/rad)
  else:uv=((math.atan2(v.z-cz,v.x-cx)/(2*math.pi)+.5)%1,.55+.4*(v.y-lo)/(hi-lo))
  coords.append(uv)
 seam=not crown and max(u for u,v in coords)-min(u for u,v in coords)>.5
 for li,(u,v) in zip(f.loop_indices,coords):sample.data[li].uv=(u+1 if seam and u<.5 else u,v)
mesh.uv_layers.active=original
mat=bpy.data.materials.new('TipGenerated');mat.use_nodes=True;mesh.materials.clear();mesh.materials.append(mat)
for f in mesh.polygons:f.material_index=0
n=mat.node_tree.nodes;l=mat.node_tree.links
uv=n.new('ShaderNodeUVMap');uv.uv_map=sample.name
tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(out/'tip-source.png'));l.new(uv.outputs[0],tex.inputs['Vector'])
e=n.new('ShaderNodeEmission');l.new(tex.outputs['Color'],e.inputs['Color']);l.new(e.outputs[0],n.get('Material Output').inputs['Surface'])
im=bpy.data.images.new('CueTip_generated',width=1024,height=1024);im.colorspace_settings.name='sRGB'
d=n.new('ShaderNodeTexImage');d.image=im;n.active=d
bpy.ops.object.select_all(action="DESELECT");bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
bpy.ops.object.bake(type='EMIT',margin=8,use_clear=True)
im.filepath_raw=str(assets/'CueTip_generated.png');im.file_format='PNG';im.save()
bpy.ops.wm.save_as_mainfile(filepath=str(out/'tip-bake.blend'))
print('TIP_BAKED_EXISTING_UV')
