"""Bake source-aligned matte wood coating roughness into candidate files only."""
import bpy, hashlib, json, argparse, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--leaf',default='blender-r1')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=ROOT/'output/table-materials-v64/W2'/args.leaf
OUT.mkdir(parents=True,exist_ok=False)
SOURCE=ROOT/'QiuJi/Resources/TaiQiuZhuo.usdz'
sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=str(SOURCE),import_textures_mode='IMPORT_PACK')
for obj in list(bpy.data.objects): bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=1)
plane=bpy.context.object
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
manifest={'sourceSHA256':sha,'blender':bpy.app.version_string,'colorSpace':'Non-Color','textures':[]}
for name,mean,gain in [('Wood',.1854958446,2.0),('BlackWood',.2179463,.5)]:
    material=bpy.data.materials.new(name+'_MatteCoat');material.use_nodes=True;material.use_fake_user=True
    plane.data.materials.clear();plane.data.materials.append(material)
    nodes=material.node_tree.nodes;links=material.node_tree.links;nodes.clear()
    source=nodes.new('ShaderNodeTexImage');source.image=bpy.data.images[name+'_roughness.png'];source.image.colorspace_settings.name='Non-Color'
    remap=nodes.new('ShaderNodeMapRange');remap.clamp=True
    remap.inputs['From Min'].default_value=mean-.06/gain;remap.inputs['From Max'].default_value=mean+.08/gain
    remap.inputs['To Min'].default_value=.58;remap.inputs['To Max'].default_value=.72
    links.new(source.outputs['Color'],remap.inputs['Value'])
    emission=nodes.new('ShaderNodeEmission');links.new(remap.outputs[0],emission.inputs['Color'])
    output=nodes.new('ShaderNodeOutputMaterial');links.new(emission.outputs[0],output.inputs[0])
    image=bpy.data.images.new('WoodCoat_'+name,width=1024,height=1024,alpha=False);image.colorspace_settings.name='Non-Color'
    target=nodes.new('ShaderNodeTexImage');target.image=image;nodes.active=target
    bpy.ops.object.bake(type='EMIT',margin=0,use_clear=True)
    path=OUT/(image.name+'.png');image.filepath_raw=str(path);image.file_format='PNG';image.save()
    manifest['textures'].append({'name':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'range':[.58,.72],'sourceMean':mean,'gain':gain})
plane.data.materials.clear();plane.data.materials.append(bpy.data.materials['Wood_MatteCoat'])
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'wood-authoring.blend'))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==sha
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
