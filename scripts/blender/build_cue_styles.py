"""Appearance ONLY: bake ten finishes onto an original-size cue with a UV-only unwrap in Blender 4.5.
No vertex position, polygon topology, transform, length, taper or tip-size changes.
Five small-head visual styles have longitudinal ash sword grain, five large-head
visual styles have pale maple grain. These names do not change cue physics.
"""
import bpy, math, pathlib, json, hashlib, sys
import numpy as np
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from cue_finish_patterns import DESIGNS, patterns
from cue_theme_art import apply_theme
from mathutils import Vector
ROOT=pathlib.Path.cwd();OUT=ROOT/'output/cue-stickers';ASSETS=ROOT/'QiuJi/Resources/CueStyles'
bpy.ops.wm.read_factory_settings(use_empty=True)
source=ROOT/'QiuJi/Resources/TaiQiuZhuo.usdz';source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.usd_import(filepath=str(source),import_textures_mode='IMPORT_PACK')
o=bpy.data.objects['Plane_025']
for other in list(bpy.data.objects):
 if other!=o:bpy.data.objects.remove(other,do_unlink=True)
original=o.data.copy();positions=[tuple(v.co) for v in original.vertices]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.5,.5,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'
# Blender source mesh coordinates: axis +Y towards tip, center Z measured below.
# UV direction is purely a material coordinate; it never changes the cue pose.
centerz=(min(v.co.z for v in original.vertices)+max(v.co.z for v in original.vertices))/2
lo=min(v.co.y for v in original.vertices);hi=max(v.co.y for v in original.vertices)

def mat(name,color,rough=.28,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m

def author(design):
 color,rough=patterns(design)
 provenance=apply_theme(color,design,ROOT)
 h,w=rough.shape
 rgba=np.ones((h,w,4),dtype=np.float32);rgba[:,:,:3]=color
 img=bpy.data.images.new(design[0]+'_author',width=w,height=h)
 img.colorspace_settings.name='Linear Rec.709';img.pixels.foreach_set(rgba.ravel())
 m=mat('Author_'+design[0],(1,1,1));n=m.node_tree.nodes;l=m.node_tree.links
 tex=n.new('ShaderNodeTexImage');tex.image=img
 emission=n.new('ShaderNodeEmission');l.new(tex.outputs[0],emission.inputs[0]);l.new(emission.outputs[0],n.get('Material Output').inputs[0])
 roughimg=bpy.data.images.new(design[0]+'_roughness',width=w,height=h)
 roughimg.colorspace_settings.name='Non-Color';rgba[:,:,:3]=rough[:,:,None]
 roughimg.pixels.foreach_set(rgba.ravel());roughimg.filepath_raw=str(ASSETS/('Cue_'+design[0]+'_roughness.png'));roughimg.file_format='PNG';roughimg.save()
 return m,roughimg,provenance

# Studio framing: actual entire original cue horizontal in the preview.
lightdata=bpy.data.lights.new('Key','AREA');lightdata.energy=22;lightdata.shape='RECTANGLE';lightdata.size=2;lightdata.size_y=1
light=bpy.data.objects.new('Key',lightdata);scene.collection.objects.link(light);light.location=(.25,0,1.2)
light.rotation_euler=(Vector((0,0,centerz))-light.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camdata);scene.collection.objects.link(cam)
cam.location=(0,0,2);cam.rotation_euler=(0,0,math.pi/2);camdata.type='ORTHO';camdata.ortho_scale=1.56;scene.camera=cam
scene.render.resolution_x=1560;scene.render.resolution_y=180;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
manifest=[]
# Preserve positions and polygon topology, replace only the first UV map on wood.
o.data=original.copy()
uv=o.data.uv_layers[0]
for face in o.data.polygons:
 if face.material_index>=2:continue
 values=[]
 for idx in face.loop_indices:
  v=o.data.vertices[o.data.loops[idx].vertex_index].co
  values.append(((math.atan2(v.z-centerz,v.x)/(2*math.pi)+.5)%1,(v.y-lo)/(hi-lo)))
 crosses=max(x[0] for x in values)-min(x[0] for x in values)>.5
 for idx,(u,v) in zip(face.loop_indices,values):uv.data[idx].uv=(u+1 if crosses and u<.5 else u,v)
uv.name='st'
assert [tuple(v.co) for v in o.data.vertices]==positions
assert [tuple(p.vertices) for p in o.data.polygons]==[tuple(p.vertices) for p in original.polygons]
# Neutral export for the shared UV-only mesh; styling is supplied as baked PNG.
if '--small-only' not in sys.argv and '--textures-only' not in sys.argv:
 material_names=[m.name for m in original.materials]
 for i,name in enumerate(material_names):
  original.materials[i].name='Source_'+name
  o.data.materials[i]=mat(name,(1,1,1))
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.wm.usd_export(filepath=str(ASSETS/'CueUV.usdz'),selected_objects_only=True,export_animation=False,export_materials=True,export_uvmaps=True,export_normals=True,export_textures=True)
 for i,name in enumerate(material_names):
  neutral=o.data.materials[i];o.data.materials[i]=original.materials[i]
  bpy.data.materials.remove(neutral);original.materials[i].name=name
if '--export-only' in sys.argv:
 print('CUE_UV_EXPORT_ONLY_OK');sys.exit(0)
for design in DESIGNS:
 style,kind=design[:2];small=kind=='small'
 if '--small-only' in sys.argv and not small:continue
 m,roughimg,provenance=author(design)
 bpy.ops.mesh.primitive_plane_add();plane=bpy.context.object
 plane.data.uv_layers[0].name='CueDesignUV';plane.data.materials.append(m)
 target=bpy.data.images.new(style+'_atlas',width=512,height=4096);target.colorspace_settings.name='sRGB'
 dest=m.node_tree.nodes.new('ShaderNodeTexImage');dest.image=target;m.node_tree.nodes.active=dest
 bpy.ops.object.bake(type='EMIT',margin=4,use_clear=True)
 target.filepath_raw=str(ASSETS/(f'Cue_{style}.png'));target.file_format='PNG';target.save()
 bpy.data.objects.remove(plane,do_unlink=True)
 for i in range(2):
  material=mat(original.materials[i].name,(1,1,1));n=material.node_tree.nodes.new('ShaderNodeTexImage');n.image=target
  material.node_tree.links.new(n.outputs[0],material.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
  r=material.node_tree.nodes.new('ShaderNodeTexImage');r.image=roughimg
  material.node_tree.links.new(r.outputs[0],material.node_tree.nodes['Principled BSDF'].inputs['Roughness']);o.data.materials[i]=material
 o.data.materials[2]=original.materials[2].copy()
 o.data.materials[3]=mat('copp',(.5,.29,.075) if small else (.88,.84,.73),.28,.7 if small else 0)
 assert [tuple(v.co) for v in o.data.vertices]==positions
 assert [tuple(p.vertices) for p in o.data.polygons]==[tuple(p.vertices) for p in original.polygons]
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(style+'.blend')))
 scene.render.resolution_x=1560;scene.render.resolution_y=180;camdata.ortho_scale=1.56;cam.location.y=0
 scene.render.filepath=str(ASSETS/('Cue_'+style+'_preview.png'));bpy.ops.render.render(write_still=True)
 # Dedicated shaft detail to inspect the requested sword grain at useful size.
 scene.render.resolution_x=1560;scene.render.resolution_y=300;camdata.ortho_scale=.6;cam.location.y=.38
 scene.render.filepath=str(OUT/(style+'_shaft.png'));bpy.ops.render.render(write_still=True)
 cam.location.y=-.40;camdata.ortho_scale=.72
 scene.render.filepath=str(ASSETS/('Cue_'+style+'_detail.png'));bpy.ops.render.render(write_still=True)
 camdata.ortho_scale=.28;cam.location.y=lo+(hi-lo)*(.108 if small else .382)
 scene.render.filepath=str(OUT/(style+'_theme.png'));bpy.ops.render.render(write_still=True)
 manifest.append(dict(style=style,kind=kind,name=design[2],vertices=len(positions),faces=len(original.polygons),positionsUnchanged=True,topologyUnchanged=True,uvOnly=True,**provenance))
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_sha
baked_count=len(manifest)
if '--small-only' in sys.argv:
 previous=json.loads((OUT/'manifest.json').read_text())['styles']
 manifest += [item for item in previous if item['kind']=='large']
(OUT/'manifest.json').write_text(json.dumps(dict(sourceSHA256=source_sha,styles=manifest),indent=2))
print('CUE_APPEARANCE_BAKE_COMPLETE',baked_count)
