"""Blender contact sheet using the actual per-cue renders; no model changes."""
import bpy,sys,pathlib
sys.path.insert(0,str(pathlib.Path(__file__).parent))
from cue_finish_patterns import DESIGNS
from mathutils import Vector
root=pathlib.Path.cwd();assets=root/'QiuJi/Resources/CueStyles'
details='--theme-details' in sys.argv
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8
s.world=bpy.data.worlds.new('Gallery');s.world.use_nodes=True
s.world.node_tree.nodes['Background'].inputs[0].default_value=(.027,.035,.039,1)
s.world.node_tree.nodes['Background'].inputs[1].default_value=1
s.view_settings.view_transform='Standard'
font=bpy.data.fonts.load('/System/Library/Fonts/Supplemental/Songti.ttc')
def emission(color):
 m=bpy.data.materials.new('Label');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links
 e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*color,1);l.new(e.outputs[0],n.get('Material Output').inputs[0]);return m
white=emission((.82,.83,.76));muted=emission((.42,.48,.48))
def label(body,x,y,size=.25,material=white):
 d=bpy.data.curves.new('Text','FONT');d.body=body;d.font=font;d.size=size
 o=bpy.data.objects.new(body,d);s.collection.objects.link(o);o.location=(x,y,.05);o.data.materials.append(material)
def panel(path,x,y,width):
 img=bpy.data.images.load(str(path));w,h=img.size
 bpy.ops.mesh.primitive_plane_add(size=2,location=(x,y,.01 if 'detail' in path.stem else .02));o=bpy.context.object;o.scale=(width/2,width*h/w/2,1)
 m=bpy.data.materials.new(path.stem);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links
 t=n.new('ShaderNodeTexImage');t.image=img;e=n.new('ShaderNodeEmission');l.new(t.outputs[0],e.inputs[0])
 transparent=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(t.outputs['Alpha'],mix.inputs[0]);l.new(transparent.outputs[0],mix.inputs[1]);l.new(e.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],n.get('Material Output').inputs[0]);o.data.materials.append(m)
label('球杆外观 · '+('主题近景' if details else '十款主题贴图'),-9,7.5,.47)
label('小头杆风格',-9,6.65,.3);label('大头杆风格',.8,6.65,.3)
for i,d in enumerate(DESIGNS):
 col=i//5;row=i%5;x=-4.8+col*9.8;y=5.6-row*2.55
 label(f'{row+1:02d}  {d[2]}',x-4.2,y,.27)
 if details:
  panel(root/'output/cue-stickers'/(d[0]+'_theme.png'),x,y-.85,8.4)
 else:
  panel(assets/('Cue_'+d[0]+'_preview.png'),x,y-.4,8.4)
  panel(assets/('Cue_'+d[0]+'_detail.png'),x,y-1.12,8.4)
label('原主题图案 · Blender实际球杆近景 · 前节剑纹和球杆尺寸保持。' if details else '同一球杆尺寸，保留木纹与握把，融入原主题图案。上：整杆；下：后把近景。',-9,-7.4,.22,muted)
d=bpy.data.cameras.new('Camera');c=bpy.data.objects.new('Camera',d);s.collection.objects.link(c);c.location=(0,0,10);d.type='ORTHO';d.ortho_scale=20;s.camera=c
s.render.resolution_x=2400;s.render.resolution_y=1920;s.render.resolution_percentage=100
s.render.filepath=str(root/'output/cue-stickers'/('theme-details.png' if details else 'catalog.png'));s.render.image_settings.file_format='PNG';bpy.ops.render.render(write_still=True)
