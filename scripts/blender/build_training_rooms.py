import bpy, math, os, sys, json
from mathutils import Vector
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--style',choices=['tournament','walnut','eastern'],required=True)
parser.add_argument('--output',required=True)
parser.add_argument('--table-shadow-obj',help='App world mesh exported as Blender Z-up metres; bake-only occluder')
parser.add_argument('--panel-calibration',help='Measured reference-panel JSON; replaces legacy ceiling lights, keeps architectural wall wash')
parser.add_argument('--world-strength',type=float,default=.22,help='Offline room ambient strength; independently recorded, not a runtime ball-light gain')
parser.add_argument('--wall-wash-watts',type=float,default=32,help='Offline architectural wall wash per fixture')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT=os.path.abspath(args.output);os.makedirs(OUT,exist_ok=True)
STYLE=args.style
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=192;s.cycles.use_denoising=True
s.world=bpy.data.worlds.new('RoomWorld');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.42,.48,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.22
s.world.node_tree.nodes['Background'].inputs[1].default_value=args.world_strength
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
parts=[]
def mat(name,color,rough=.7,kind=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 if kind:
  tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=2 if kind=='plaster' else 6;tex.inputs['Detail'].default_value=3
  coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(4,4,.09) if kind=='wood' else (1,1,1)
  m.node_tree.links.new(coord.outputs['Object'],mapping.inputs[0]);m.node_tree.links.new(mapping.outputs[0],tex.inputs['Vector'])
  ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[1].position=.85
  for e,f in zip(ramp.color_ramp.elements,[.78,1.10] if kind=='wood' else [.98,1.02]):e.color=(*(min(1,c*f) for c in color),1)
  m.node_tree.links.new(tex.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],p.inputs['Base Color'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=0;bump.inputs['Distance'].default_value=.0008;m.node_tree.links.new(tex.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs[0],p.inputs['Normal'])
 return m
palette={'tournament':((.29,.30,.30),(.065,.071,.075),(.075,.08,.085)), 'walnut':((.46,.42,.35),(.25,.16,.085),(.14,.12,.095)), 'eastern':((.34,.33,.30),(.095,.06,.035),(.11,.10,.085))}[STYLE]
wallmat=mat('mineral_plaster',palette[0],kind='plaster');wood=mat('joinery',palette[1],kind='wood' if STYLE!='tournament' else None);fabric=mat('woven_upholstery',palette[2],kind='plaster');black=mat('blackened_metal',(.018,.021,.023),.5);brass=mat('brushed_bronze',(.19,.135,.065),.5);ivory=mat('warm_paper',(.54,.51,.44));cue=mat('maple',(.42,.27,.12),kind='wood')
rackwood=mat('rack_oiled_walnut',(.075,.047,.028),.78,kind='wood')
rubber=mat('rack_felt_and_rubber',(.012,.015,.014),.96)
ferrule=mat('cue_ivory_ferrule',(.62,.58,.47),.65)
tipmat=mat('cue_chalked_tip',(.035,.095,.09),.96)
shafts=[mat('ash_shaft_'+str(i),c,.7,kind='wood') for i,c in enumerate([(.42,.31,.18),(.49,.38,.24),(.37,.27,.16),(.46,.34,.21)])]
butts=[mat('butt_'+str(i),c,.65,kind='wood') for i,c in enumerate([(.028,.018,.013),(.11,.042,.019),(.045,.033,.023),(.095,.065,.035)])]
# All helper dimensions/positions use App X,Y-up,Z coordinates. Blender is Z-up.
def cv(p):return (p[0],-p[2],p[1])
def box(name,pos,size,m,bevel=.005,group=True):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(pos));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bevel:
  b=o.modifiers.new('real_edge_radius','BEVEL');b.width=bevel;b.segments=3;bpy.ops.object.modifier_apply(modifier=b.name)
  for p in o.data.polygons:p.use_smooth=True
  n=o.modifiers.new('weighted_normals','WEIGHTED_NORMAL');n.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=n.name)
 if group:parts.append(o)
 return o
# wall local coordinates x horizontal, y up, z inward
walls=[(0,-4,0,10),(0,4,math.pi,10),(-5,0,math.pi/2,8),(5,0,-math.pi/2,8)]
for wi,(wx,wz,yaw,width) in enumerate(walls):
 def wb(name,p,dim,m,bevel=.005):
  x,y,z=p;c=math.cos(yaw);ss=math.sin(yaw);o=box(name,(wx+c*x+ss*z,y,wz-ss*x+c*z),dim,m,bevel);o.rotation_euler.z=-yaw;return o
 wb('wall_%d'%wi,(0,1.8,-.10),(width+.16,3.6,.20),wallmat,.008)
 wb('skirting',(0,.065,.025),(width,.13,.05),black)
 if STYLE=='tournament':
  for i in range(int(width)):
   wb('acoustic_panel',(-width/2+i+.5,2.04,.018),(.982,3.08,.035),wallmat,.009)
  wb('charcoal_dado',(0,.32,.028),(width,.45,.05),wood,.006)
 else:
  wb('wood_dado',(0,.43,.024),(width,.66,.05),wood,.008)
  # Terminate the dado cap cleanly at the rack uprights, instead of intersecting
  # them on the two furnished walls.
  if wi<2:wb('cap_rail',(0,.78,.055),(width,.045,.08),wood)
  else:
   rack_rx=-1.8 if wi==2 else 1.8
   edges=[-width/2,rack_rx-.385-.026,rack_rx-.385+.026,rack_rx+.385-.026,rack_rx+.385+.026,width/2]
   for lo,hi in zip(edges[::2],edges[1::2]):wb('cap_rail',((lo+hi)/2,.78,.055),(hi-lo,.045,.08),wood)
  if STYLE=='eastern':
   for x in [-width/2+.08,width/2-.08]:wb('elm_post',(x,1.8,.07),(.10,3.6,.12),wood,.008)
   wb('elm_header',(0,3.35,.07),(width,.13,.12),wood,.008)
 if wi<2: continue
 bx=1.8 if wi==2 else -1.8;rx=-bx
 # Proper bench: separate curved cushion, seam bead, frame, legs.
 wb('bench_frame',(bx,.34,.41),(2.16,.09,.61),wood,.016)
 for dx in [-.88,.88]:
  for z in [.20,.62]:wb('bench_leg',(bx+dx,.17,z),(.045,.34,.045),black,.008)
 for dx in [-.70,0,.70]:
  wb('cushion_piping',(bx+dx,.405,.42),(.684,.024,.565),black,.009)
  wb('seat_cushion',(bx+dx,.466,.42),(.68,.13,.56),fabric,.042)
  wb('back_cushion',(bx+dx,.74,.125),(.68,.43,.14),fabric,.042)
 if STYLE=='eastern':
  for i in range(15):wb('elm_screen',(rx-.68+i*.097,1.64,.065),(.025,2.6,.085),wood,.003)
 # The two rails carry the cues: bottom felt seats and open upper retaining clips.
 # Four separate, gently tapered segmented cues, with their bumpers on the seats.
 for dx in [-.385,.385]:wb('rack_mount',(rx+dx,.93,.055),(.045,1.42,.085),rackwood,.008)
 wb('cue_rack_base',(rx,.31,.145),(.86,.065,.22),rackwood,.009)
 wb('cue_rack_upper',(rx,1.51,.075),(.86,.055,.085),rackwood,.008)
 def localpoint(x,y,z):
  return Vector(cv((wx+math.cos(yaw)*x+math.sin(yaw)*z,y,wz-math.sin(yaw)*x+math.cos(yaw)*z)))
 def rod(name,x,y0,y1,z,r0,r1,m):
  p0=localpoint(x,y0,z);p1=localpoint(x,y1,z)
  bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r0,radius2=r1,depth=(p1-p0).length,location=(p0+p1)/2)
  o=bpy.context.object;o.name=name;o.rotation_euler=(p1-p0).to_track_quat('Z','Y').to_euler();o.data.materials.append(m)
  for poly in o.data.polygons:poly.use_smooth=len(poly.vertices)==4
  parts.append(o);return o
 for i,height in enumerate([1.45,1.475,1.44,1.46]):
  x=rx-.27+i*.18;z=.155;base=.3465
  rod('felt_seat',x,.3425,base,z,.024,.024,rubber)
  # Fractions keep joints contiguous, preserve taper and avoid floating sections.
  levels=[0,.008,.15,.36,.50,.508,.979,.995,1]
  finishes=[rubber,butts[i],rubber,butts[i],ferrule,shafts[i],ferrule,tipmat]
  for j,(lo,hi,m) in enumerate(zip(levels,levels[1:],finishes)):
   radius=lambda t:.015-(.015-.0057)*t
   rod('rack_cue_%d_section_%d'%(i,j),x,base+lo*height,base+hi*height,z,radius(lo),radius(hi),m)
  # C-shaped rubber clip opens towards the room, seated on a short bracket.
  wb('clip_bracket',(x,1.51,.129),(.029,.018,.045),black,.004)
  curve=bpy.data.curves.new('retaining_clip','CURVE');curve.dimensions='3D';curve.bevel_depth=.0035;curve.bevel_resolution=1
  spline=curve.splines.new('POLY');spline.points.add(12)
  for point,angle in zip(spline.points,[math.radians(50+k*260/12) for k in range(13)]):
   p=localpoint(x+.011*math.sin(angle),1.51,z+.011*math.cos(angle));point.co=(*p,1)
  o=bpy.data.objects.new('retaining_clip',curve);s.collection.objects.link(o);o.data.materials.append(rubber)
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');parts.append(bpy.context.object)
  assert base+height>1.51 and abs(base-(.31+.065/2+.004))<1e-6
 # Art with actual frame, recessed mount, graphic inlay. Deliberately quiet.
 wb('art_frame',(bx,1.7,.055),(1.36,.71,.075),wood if STYLE!='tournament' else black,.012)
 wb('art_mount',(bx,1.7,.098),(1.29,.64,.018),ivory,.001)
 if STYLE=='eastern':
  for dx,h in [(-.35,.12),(-.13,.21),(.09,.32),(.30,.15)]:wb('ink_composition',(bx+dx,1.6+h/2,.109),(.13,h,.002),black,.001)
 else:
  for dx in [-.32,.32]:
   wb('graphic',(bx+dx,1.7,.109),(.24,.012,.002),black,.001)
   wb('graphic',(bx+dx,1.7,.109),(.012,.26,.002),black,.001)
 # Wall lights have physical housing and offline area emitters.
 for x in [-3,0,3]:
  wb('wall_light',(x,2.55,.10),(.085,.28,.13),black,.01)
  world=(wx+math.cos(yaw)*x+math.sin(yaw)*.32,2.70,wz-math.sin(yaw)*x+math.cos(yaw)*.32)
  data=bpy.data.lights.new('wall_wash','AREA');data.energy=args.wall_wash_watts;data.shape='DISK';data.size=.32;data.color=(1,.89,.73)
  light=bpy.data.objects.new('wall_wash',data);s.collection.objects.link(light);light.location=cv(world);target=Vector(cv((wx+math.cos(yaw)*x,2.0,wz-math.sin(yaw)*x)));light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
# Carpet full low-frequency illumination bake. Fine yarn is independently tiled in App.
floormat=mat('carpet_base',(.075,.077,.078) if STYLE=='tournament' else (.11,.103,.088),.95)
bpy.ops.mesh.primitive_plane_add(size=2,location=(0,0,0))
floor=bpy.context.object;floor.name='baked_floor';floor.scale=(5,4,1);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);floor.data.materials.append(floormat)
if args.panel_calibration:
 import hashlib,pathlib
 calibration=json.loads(pathlib.Path(args.panel_calibration).read_text())
 source=pathlib.Path(__file__).resolve().parents[2]/'QiuJi/Core/Scene/MobileReferenceLighting.swift'
 if hashlib.sha256(source.read_bytes()).hexdigest()!=calibration['source_sha256']:
  raise ValueError('Reference shader changed; rerun panel calibration before baking')
 rig=calibration['rig']
 calibration['room_world_strength']=args.world_strength
 calibration['room_world_color']=[.38,.42,.48]
 calibration['wall_wash_watts']=args.wall_wash_watts
 for sign in [-1,1]:
  data=bpy.data.lights.new('reference_table_panel','AREA');data.energy=calibration['watts_per_panel'];data.shape='RECTANGLE'
  data.size=rig['panelWidth'];data.size_y=rig['panelDepth'];data.color=calibration['panel_color']
  light=bpy.data.objects.new(data.name,data);s.collection.objects.link(light);light.location=cv((0,rig['panelHeight'],sign*rig['panelOffset']))
 pathlib.Path(OUT,STYLE+'_lighting.json').write_text(json.dumps(calibration,indent=2))
else:
 for x in [-2.8,0,2.8]:
  for z in [-2,2]:
   data=bpy.data.lights.new('ceiling_softbox','AREA');data.energy=180;data.shape='RECTANGLE';data.size=2.4;data.size_y=1.2
   light=bpy.data.objects.new('ceiling_softbox',data);s.collection.objects.link(light);light.location=cv((x,3.45,z))
# Match App geometry: (X,Y,Z) -> (X,-Z,Y), metres, floor Z=0.
# This object affects offline visibility only and is never added to export parts.
if args.table_shadow_obj:
 bpy.ops.wm.obj_import(filepath=os.path.abspath(args.table_shadow_obj),forward_axis='NEGATIVE_Y',up_axis='Z')
 occluder_mat=mat('table_shadow_only',(.07,.045,.025),.8)
 for o in bpy.context.selected_objects:
  o.name='table_shadow_only';o.data.materials.clear();o.data.materials.append(occluder_mat)
# Real diffuse interreflection is baked; no runtime lights are exported.
def bake(objects,label,res):
 # Preserve the established one-join normal pipeline. Give thin rack islands
 # higher texel density, then pack isotropically into the existing atlas.
 if label=='perimeter':
  for o in objects:
   is_rack=int(o.name.startswith(('rack_','cue_rack_','retaining_clip','clip_bracket','felt_seat')))
   tag=o.data.attributes.new('rack_uv_priority','INT','FACE')
   for value in tag.data:value.value=is_rack
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=label
 if label=='perimeter':
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
  tag=o.data.attributes['rack_uv_priority']
  for poly in o.data.polygons:
   if tag.data[poly.index].value:
    for index in poly.loop_indices:o.data.uv_layers.active.data[index].uv*=5
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.select_all(action='SELECT');bpy.ops.uv.pack_islands(rotate=True,margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
  o.data.attributes.remove(o.data.attributes['rack_uv_priority'])
 image=bpy.data.images.new(label+'_light',width=res,height=res,alpha=False);image.filepath_raw=os.path.join(OUT,STYLE+'_'+label+'.png');image.file_format='PNG'
 for m in o.data.materials:
  node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;m.node_tree.nodes.active=node
 s.render.bake.use_pass_direct=True;s.render.bake.use_pass_indirect=True;s.render.bake.use_pass_color=True;s.render.bake.margin=8
 bpy.ops.object.bake(type='DIFFUSE');image.save()
 return o,image
room,room_image=bake(parts,'perimeter',2048)
floor,floor_image=bake([floor],'floor',1024)
# Denoise baked radiance in Blender's compositor (no runtime cost).
s.use_nodes=True;nodes=s.node_tree.nodes;nodes.clear()
source=nodes.new('CompositorNodeImage');denoise=nodes.new('CompositorNodeDenoise');dest=nodes.new('CompositorNodeOutputFile');dest.base_path=OUT;dest.format.file_format='PNG';dest.format.color_mode='RGB'
s.node_tree.links.new(source.outputs['Image'],denoise.inputs['Image']);s.node_tree.links.new(denoise.outputs['Image'],dest.inputs[0])
cam_data=bpy.data.cameras.new('bake_compositor_camera');cam=bpy.data.objects.new('bake_compositor_camera',cam_data);s.collection.objects.link(cam);cam.location=(0,0,10);s.camera=cam;s.render.resolution_x=4;s.render.resolution_y=4;s.render.resolution_percentage=100;s.cycles.samples=1
for label,image in [('perimeter',room_image),('floor',floor_image)]:
 source.image=image;dest.file_slots[0].path=STYLE+'_'+label+'_clean';bpy.ops.render.render()
 clean=os.path.join(OUT,STYLE+'_'+label+'_clean0001.png');os.replace(clean,image.filepath_raw);image.reload()
s.use_nodes=False
# Replace shaders only after both bakes so the floor uses original diffuse bounce.
for o,image in [(room,room_image),(floor,floor_image)]:
 m=bpy.data.materials.new(o.name+'_baked');m.use_nodes=True;n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=1
 tex=n.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 o.data.materials.clear();o.data.materials.append(m)
 for poly in o.data.polygons:poly.material_index=0
# Export perimeter and floor separately; runtime floor receives tiled yarn independently.
for o in [room,floor]:
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.wm.usd_export(filepath=os.path.join(OUT,'Room_'+STYLE+'_'+o.name+'.usdz'),selected_objects_only=True,export_lights=False,export_cameras=False,export_materials=False,export_textures=False,generate_preview_surface=False,generate_materialx_network=False,convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',triangulate_meshes=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'Room_'+STYLE+'.blend'))
print('ROOM_DONE',STYLE,len(room.data.vertices),len(room.data.polygons),flush=True)
