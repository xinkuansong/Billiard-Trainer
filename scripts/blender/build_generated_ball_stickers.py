"""Bake image_gen artwork onto two antipodal caps of original ball meshes.

The generated atlas supplies the numeral ink. Blender nodes impose production
circle/stripe geometry and an ink ramp, removing atlas background/lighting drift.
Only EMIT (albedo) is baked, never BSDF lighting. Runtime meshes remain untouched.
"""
import bpy
import pathlib
import json
import hashlib
import math

ROOT = pathlib.Path.cwd()
OUT = ROOT / 'output/ball-stickers-20260913-v2'
ASSETS = OUT / 'assets'
STYLES = ['modern', 'minimal', 'american', 'badge', 'broadcast', 'vintage']
COLORS = ['f5c719', '1a52b8', 'd62924', '66338c', 'eb7314', '1a854d', '8c2121', '191919']
# Measured circle centers/radii in the original image_gen atlases, top-left pixels.
ATLAS = {
    'modern': ([129, 377, 626, 874, 1123], [348, 631, 912], 110),
    'minimal': ([171, 488, 809, 1130, 1450], [178, 487, 798], 145),
    'american': ([166, 488, 809, 1132, 1455], [160, 474, 790], 114),
    'badge': ([178, 489, 808, 1128, 1442], [186, 491, 795], 146),
    'broadcast': ([171, 490, 809, 1130, 1454], [171, 487, 804], 148),
    'vintage': ([175, 494, 811, 1129, 1444], [169, 485, 798], 144),
}

def rgba(value):
    v = [int(value[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in v) + (1,)

def make_material(style, number):
    mat = bpy.data.materials.new(f'GeneratedAlbedo_{style}_{number}')
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    def bind(value, socket):
        if isinstance(value, bpy.types.NodeSocket): links.new(value, socket)
        else: socket.default_value = value
    def mathnode(op, a, b=0):
        n = nodes.new('ShaderNodeMath'); n.operation = op
        bind(a,n.inputs[0]); bind(b,n.inputs[1]); return n.outputs[0]
    def mix(factor, a, b):
        n = nodes.new('ShaderNodeMixRGB'); n.blend_type = 'MIX'
        bind(factor,n.inputs[0]); bind(a,n.inputs[1]); bind(b,n.inputs[2]); return n.outputs[0]
    coord = nodes.new('ShaderNodeTexCoord')
    separate = nodes.new('ShaderNodeSeparateXYZ'); links.new(coord.outputs['UV'],separate.inputs[0])
    longitude=mathnode('MULTIPLY',mathnode('SUBTRACT',separate.outputs[0],.5),2*math.pi)
    latitude=mathnode('MULTIPLY',mathnode('SUBTRACT',separate.outputs[1],.5),math.pi)
    x=mathnode('MULTIPLY',mathnode('COSINE',latitude),mathnode('COSINE',longitude))
    y=mathnode('SINE',latitude)
    z=mathnode('MULTIPLY',mathnode('COSINE',latitude),mathnode('SINE',longitude))
    # Back side reverses tangent X so it reads normally when viewed from -Z.
    xx = mathnode('MULTIPLY',x,mathnode('SIGN',z))
    radius = .51 if style != 'badge' else .54
    rr = mathnode('ADD',mathnode('MULTIPLY',x,x),mathnode('MULTIPLY',y,y))
    cap = mathnode('LESS_THAN',rr,radius*radius)
    white = rgba('f7f5ee' if style not in ('american','vintage') else 'f0e8d5')
    ink = rgba('101214')
    base = rgba(COLORS[(number-1)%8])
    if number > 8:
        stripe = mathnode('LESS_THAN',mathnode('ABSOLUTE',y),.55)
        base = mix(stripe,white,base)
    atlas = bpy.data.images.load(str(OUT/'sources'/f'{style}.png'),check_existing=True)
    atlas.colorspace_settings.name='sRGB'
    cx,cy,r = ATLAS[style]; cx=cx[(number-1)%5]; cy=cy[(number-1)//5]
    uv = nodes.new('ShaderNodeCombineXYZ')
    bind(mathnode('ADD',mathnode('MULTIPLY',xx,r/radius/atlas.size[0]),cx/atlas.size[0]),uv.inputs[0])
    bind(mathnode('ADD',mathnode('MULTIPLY',y,r/radius/atlas.size[1]),1-cy/atlas.size[1]),uv.inputs[1])
    texture = nodes.new('ShaderNodeTexImage'); texture.image=atlas
    links.new(uv.outputs[0],texture.inputs['Vector'])
    # Ink separation: generated off-white/noise never becomes ball shading.
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.015
    ramp.color_ramp.elements[0].color=(0,0,0,1)
    ramp.color_ramp.elements[1].position=.50
    ramp.color_ramp.elements[1].color=(1,1,1,1)
    links.new(texture.outputs['Color'],ramp.inputs[0])
    disc = mix(ramp.outputs[0],ink,white)
    # Discard outer atlas edge/alpha artifacts; precise rings are authored here.
    glyph_limit = .79 if style=='badge' else .87
    disc = mix(mathnode('LESS_THAN',rr,(radius*glyph_limit)**2),white,disc)
    if style in ('modern','vintage','badge'):
        ranges = {'modern':[(.957,.976)],'vintage':[(.925,.942),(.976,.986)],'badge':[(.82,1)]}[style]
        for lo,hi in ranges:
            ring = mathnode('MULTIPLY',mathnode('GREATER_THAN',rr,(radius*lo)**2),mathnode('LESS_THAN',rr,(radius*hi)**2))
            disc = mix(ring,disc,ink)
    if style=='american':
        ax = mathnode('ABSOLUTE',x)
        # Small opposing inward-facing arrows, outside the number disc.
        triangle = mathnode('MULTIPLY',mathnode('GREATER_THAN',ax,.59),mathnode('LESS_THAN',ax,.79))
        triangle = mathnode('MULTIPLY',triangle,mathnode('LESS_THAN',mathnode('ABSOLUTE',y),mathnode('MULTIPLY',mathnode('SUBTRACT',ax,.59),.55)))
        base = mix(triangle,base,white)
    color = mix(cap,base,disc)
    emission=nodes.new('ShaderNodeEmission'); links.new(color,emission.inputs[0])
    output=nodes.new('ShaderNodeOutputMaterial'); links.new(emission.outputs[0],output.inputs['Surface'])
    return mat

bpy.ops.wm.open_mainfile(filepath=str(ROOT/'output/ball-stickers-20260913/BallStickerLibrary.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.bake.margin=8;scene.render.bake.use_clear=True
source=ROOT/'QiuJi/Resources/TaiQiuZhuo.usdz'
sha=hashlib.sha256(source.read_bytes()).hexdigest()
original_geometry={o.name:([tuple(v.co) for v in o.data.vertices],[tuple(v.uv) for v in o.data.uv_layers.active.data]) for o in bpy.data.objects if o.type=='MESH'}
# Repair only UVs. Seam is placed at -X, away from both ±Z number caps.
# Original unwrap folds near the back and cannot carry a readable second badge.
for o in [o for o in bpy.data.objects if o.type=='MESH']:
    m=o.data
    for face in m.polygons:
        pairs=[]
        for loop in face.loop_indices:
            p=m.vertices[m.loops[loop].vertex_index].co.normalized()
            pairs.append([math.atan2(p.z,p.x)/(2*math.pi)+.5, math.asin(max(-1,min(1,p.y)))/math.pi+.5, abs(p.y)>.9999])
        ordinary=[p[0] for p in pairs if not p[2]]
        if max(ordinary)-min(ordinary)>.5:
            for p in pairs:
                if p[0]<.5:p[0]+=1
        mean=sum(p[0] for p in pairs if not p[2])/len(ordinary)
        for loop,p in zip(face.loop_indices,pairs):
            m.uv_layers.active.data[loop].uv=(mean if p[2] else p[0],p[1])
for c in STYLES:bpy.data.collections[c].hide_render=False
for o in scene.objects:o.hide_render=False
# A full-tile UV plane bakes the analytic spherical domain. Baking low-poly
# sphere triangles leaves uncovered texels at longitude wrap and the poles.
bpy.ops.mesh.primitive_plane_add(size=2,location=(0,0,-30))
bake_plane=bpy.context.object;bake_plane.name='AlbedoBakeDomain'
for style in STYLES:
    for number in range(1,16):
        o=bpy.data.objects[f'{style}_{number}']
        mat=make_material(style,number)
        bake_plane.data.materials.clear();bake_plane.data.materials.append(mat)
        target=bpy.data.images.new(f'BallSticker_{style}_{number}_v2',width=1024,height=512,alpha=False)
        target.colorspace_settings.name='sRGB'
        target.filepath_raw=str(ASSETS/f'BallSticker_{style}_{number}.png');target.file_format='PNG'
        bake=mat.node_tree.nodes.new('ShaderNodeTexImage');bake.image=target
        mat.node_tree.nodes.active=bake
        bpy.ops.object.select_all(action='DESELECT');bake_plane.select_set(True);bpy.context.view_layer.objects.active=bake_plane
        bpy.ops.object.bake(type='EMIT')
        target.save()
        # Keep the editable projected material as a fake-user authoring source.
        mat.use_fake_user=True
        runtime=bpy.data.materials.new(f'BallSticker_{style}_{number}_v2');runtime.use_nodes=True
        p=runtime.node_tree.nodes.get('Principled BSDF')
        p.inputs['Roughness'].default_value=.16;p.inputs['Metallic'].default_value=0
        t=runtime.node_tree.nodes.new('ShaderNodeTexImage');t.image=target
        runtime.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
        o.data.materials.clear();o.data.materials.append(runtime)
        assert original_geometry[o.name][0]==[tuple(v.co) for v in o.data.vertices]
        print('BAKED',style,number,flush=True)
    if '--pilot' in __import__('sys').argv: break

bpy.data.objects.remove(bake_plane,do_unlink=True)
scene.cycles.samples=48
scene.view_settings.view_transform='AgX'
# Single broad key and weaker fill produce credible polish without giant glare.
for light in bpy.data.lights:
    light.energy=550 if light.name=='Key' else 160
    light.size=3 if light.name=='Key' else 4
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
cam=scene.camera;cam.data.type='ORTHO';cam.location=(0,0,20);cam.rotation_euler=(0,0,0)
for c in STYLES:bpy.data.collections[c].hide_render=True
for style in STYLES:
    collection=bpy.data.collections[style];collection.hide_render=False
    scene.render.resolution_x=1500;scene.render.resolution_y=960;cam.data.ortho_scale=12.2
    scene.render.filepath=str(OUT/f'{style}-all.png');bpy.ops.render.render(write_still=True)
    positions={o.name:o.location.copy() for o in collection.objects}
    for o in collection.objects:
        n=int(o.name.rsplit('_',1)[1]);o.hide_render=n not in [1,8,10]
        if n in [1,8,10]:o.location=(([1,8,10].index(n)-1)*2.3,0,0)
    scene.render.resolution_x=840;scene.render.resolution_y=290;cam.data.ortho_scale=7
    scene.render.filepath=str(ASSETS/f'BallSticker_{style}_preview.png');bpy.ops.render.render(write_still=True)
    # Same objects turned 180 degrees, proving actual back surfaces carry numbers.
    for o in collection.objects:o.rotation_euler.y=math.pi
    scene.render.filepath=str(OUT/f'{style}-back.png');bpy.ops.render.render(write_still=True)
    for o in collection.objects:o.location=positions[o.name];o.hide_render=False;o.rotation_euler.y=0
    collection.hide_render=True
    if '--pilot' in __import__('sys').argv: break
bpy.data.collections['modern'].hide_render=False
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'BallStickerLibrary-v2.blend'))
assert sha==hashlib.sha256(source.read_bytes()).hexdigest()
(OUT/'manifest.json').write_text(json.dumps({'sourceSHA256':sha,'generator':'built-in image_gen','styles':STYLES,'textureSize':[1024,512],'bake':'EMIT only','antipodalCenters':[[0,0,1],[0,0,-1]],'centerDotProduct':-1,'verticesUnchanged':True,'uvRepair':'spherical seam at -X','atlasCoordinates':ATLAS},indent=2))
print('GENERATED_BALL_STICKERS_COMPLETE',flush=True)
