"""Actual ray-traced studio previews; uses the generated decal library, no AI photo compositing."""
import bpy,math,pathlib
from mathutils import Vector, Matrix
root=pathlib.Path.cwd();out=root/'output/ball-stickers-20260913-v2'
bpy.ops.wm.open_mainfile(filepath=str(out/'BallStickerLibrary-v2.blend'))
scene=bpy.context.scene
styles=['modern','minimal','american','badge','broadcast','vintage']
for s in styles:bpy.data.collections[s].hide_render=True
for o in list(bpy.data.objects):
 if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.09,.11,.14,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.18

def aim(o,point=(0,0,0)):o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,pos,power,sx,sy,color):
 d=bpy.data.lights.new(name,'AREA');d.shape='RECTANGLE';d.size=sx;d.size_y=sy;d.energy=power;d.color=color
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;aim(o)
# Real area emitters and dark mullions form window reflections; nothing baked.
for y in range(3):
 for z in range(3):area(f'Window-{y}-{z}',(-5,1.1+y*.85,1+z*.9),100,.67,.75,(.88,.94,1))
area('Overhead',(0,5,0),800,4,1.2,(1,.85,.65))
area('Right fill',(5,2,3),180,2,3,(1,.94,.86))
area('Front bounce',(0,1,7),95,6,4,(1,1,1))
# A real floor gives contact shadows and cloth bounce, absent from old cutouts.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,-1,0),rotation=(-math.pi/2,0,0))
floor=bpy.context.object;floor.name='StudioCloth'
m=bpy.data.materials.new('Dark green fine cloth');m.use_nodes=True
p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(.009,.050,.031,1);p.inputs['Roughness'].default_value=.92;p.inputs['Specular IOR Level'].default_value=.15
tex=m.node_tree.nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=150;tex.inputs['Detail'].default_value=2
coord=m.node_tree.nodes.new('ShaderNodeTexCoord');m.node_tree.links.new(coord.outputs['Object'],tex.inputs[0])
bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.0015
ramp=m.node_tree.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.006,.035,.020,1);ramp.color_ramp.elements[1].color=(.015,.070,.045,1)
m.node_tree.links.new(tex.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],p.inputs['Base Color'])
m.node_tree.links.new(tex.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs[0],p.inputs['Normal']);floor.data.materials.append(m)
# Dark wood panels give the camera and ball reflections a coherent environment.
wood=bpy.data.materials.new('Warm walnut studio walls');wood.use_nodes=True
wood.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.045,.020,.009,1)
wood.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.65
for x in range(-8,9,2):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(x,3,-6));o=bpy.context.object;o.scale=(1.95,8,.15);o.data.materials.append(wood)
for x in (-8,8):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(x,3,1));o=bpy.context.object;o.scale=(.15,8,14);o.data.materials.append(wood)
cam=scene.camera;cam.data.type='PERSP';cam.data.lens=55;cam.data.sensor_width=36;cam.location=(.15,.9,11.5)
forward=(Vector((0,-.1,0))-cam.location).normalized();right=forward.cross(Vector((0,1,0))).normalized();up=right.cross(forward)
cam.rotation_euler=Matrix((right,up,-forward)).transposed().to_euler()
scene.render.resolution_x=1500;scene.render.resolution_y=1000;scene.render.film_transparent=False
scene.render.engine='CYCLES';scene.cycles.samples=192;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=0
# Physical 57.15 mm diameter for macro-camera depth of field.
scale=.028575
rig=bpy.data.objects.new('Physical studio scale',None);scene.collection.objects.link(rig)
for o in list(scene.objects):
 if o!=rig and o.parent is None:o.parent=rig
rig.scale=(scale,scale,scale)
for lamp in bpy.data.lights:lamp.energy*=scale*scale
focus=bpy.data.objects.new('Number-plane focus',None);scene.collection.objects.link(focus);focus.parent=rig;focus.location=(0,0,.8)
cam.data.clip_start=.001;cam.data.dof.use_dof=True;cam.data.dof.focus_object=focus;cam.data.dof.aperture_fstop=16
for s in styles:
 c=bpy.data.collections[s];c.hide_render=False
 for o in c.objects:
  n=int(o.name.rsplit('_',1)[1]);o.hide_render=n not in [1,8,10]
  if not o.hide_render:
   o.location=(([1,8,10].index(n)-1)*2.16,0,0)
   sub=o.modifiers.new('Studio silhouette subdivision','SUBSURF');sub.levels=2;sub.render_levels=2
   cast=o.modifiers.new('Restore exact spherical radius','CAST');cast.cast_type='SPHERE';cast.factor=1;cast.radius=1;cast.size=1
   o.visible_glossy=True
   for poly in o.data.polygons:poly.use_smooth=True
   # Use editable atlas projection directly for crisp offline medallion edges.
   material=bpy.data.materials[f'GeneratedAlbedo_{s}_{n}'].copy()
   nodes=material.node_tree.nodes;links=material.node_tree.links
   emission=next(q for q in nodes if q.type=='EMISSION');color=emission.inputs[0].links[0].from_socket
   p=nodes.new('ShaderNodeBsdfPrincipled');links.new(color,p.inputs['Base Color'])
   output=next(q for q in nodes if q.type=='OUTPUT_MATERIAL');links.new(p.outputs[0],output.inputs['Surface'])
   o.data.materials.clear();o.data.materials.append(material)
   p.inputs['Roughness'].default_value=.12;p.inputs['IOR'].default_value=1.55
   p.inputs['Coat Weight'].default_value=.06;p.inputs['Coat Roughness'].default_value=.05
 scene.render.resolution_x=1500;scene.render.resolution_y=1000
 scene.render.filepath=str(out/f'photo-studio-{s}.png');bpy.ops.render.render(write_still=True)
 scene.render.resolution_x=840;scene.render.resolution_y=290
 scene.render.filepath=str(out/'assets'/f'BallSticker_{s}_preview.png');bpy.ops.render.render(write_still=True)
 c.hide_render=True
 if '--pilot' in __import__('sys').argv:break
bpy.data.collections['modern'].hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(out/'PhotographicStudio.blend'))
print('PHOTOGRAPHIC_STUDIO_COMPLETE')
