"""Six editable Blender ball libraries + UV-compatible diffuse PNGs.

Run from repository root with Blender 4.5 --background --python this_file.
Pillow is used only to rasterize typography; the original imported meshes,
UVs, material assignment, library and product renders are authored in Blender.
No lighting is baked into the diffuse textures. Original USDZ stays untouched.
"""
import bpy, pathlib, sys, math, json, hashlib
import numpy as np
from mathutils import Vector, Matrix
from pxr import Usd, UsdShade

if '--legacy-archive' not in sys.argv:
    raise SystemExit('Legacy single-sided authoring is archived. Use build_generated_ball_stickers.py for production.')

ROOT = pathlib.Path.cwd()
OUT = ROOT / 'output/ball-stickers-20260913'
sys.path.insert(0, str(OUT / 'python'))
from PIL import Image, ImageDraw, ImageFont
ASSETS = ROOT / 'QiuJi/Resources/BallStickers'
ASSETS.mkdir(parents=True, exist_ok=True)
FONT = pathlib.Path('/System/Library/Fonts/Supplemental')
STYLES = {
    'modern': ('现代赛事', 'DIN Alternate Bold.ttf', 100, 80),
    'minimal': ('极简现代', 'Arial Bold.ttf', 108, 85),
    'american': ('经典美式', 'Impact.ttf', 106, 80),
    'badge': ('粗描边徽章', 'Arial Black.ttf', 94, 87),
    'broadcast': ('电视竞技', 'Arial Bold Italic.ttf', 102, 84),
    'vintage': ('复古怀旧', 'Times New Roman Italic.ttf', 100, 80),
}
# Same number/color families as PoolBallStyle. Every stripe n shares n-8.
COLORS = ['#f5c719','#1a52b8','#d62924','#66338c','#eb7314','#1a854d','#8c2121','#191919']

def texture(style, number):
    title, fontname, height, radius = STYLES[style]
    ss = 3
    w,h = 1024*ss,512*ss
    white = '#f7f5ed' if style not in ('american','vintage') else ('#f3efdd' if style=='american' else '#eee5ce')
    ink = '#111417'
    base = COLORS[(number-1)%8]
    im=Image.new('RGB',(w,h), white if number>8 else base)
    d=ImageDraw.Draw(im)
    if number>8: d.rectangle((0, h*.29, w, h*.71), fill=base)
    cx,cy=w/2,h/2
    r=radius*ss
    if style=='american':
        for sign in (-1,1):
            d.polygon([(cx+sign*(r+12*ss),cy-15*ss), (cx+sign*(r+12*ss),cy+15*ss), (cx+sign*(r+59*ss),cy)],fill=white)
    d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=ink if style=='badge' else white)
    if style=='badge':
        rr=r-12*ss;d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),fill=white)
    if style=='modern':
        # Precise single keyline, less decorative than the bold badge.
        rr=r-4*ss;d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),outline=ink,width=2*ss)
    if style=='vintage':
        for rr in (r-3*ss,r-7*ss):d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),outline='#8b7957',width=ss)
    font=ImageFont.truetype(str(FONT/fontname),180*ss)
    box=font.getbbox(str(number))
    glyph=Image.new('L',(box[2]-box[0]+12*ss,box[3]-box[1]+12*ss))
    ImageDraw.Draw(glyph).text((6*ss-box[0],6*ss-box[1]),str(number),font=font,fill=255)
    glyph=glyph.crop(glyph.getbbox())
    target_h=height*ss
    target_w=round(glyph.width*target_h/glyph.height)
    max_w=(103 if style=='badge' else 109)*ss
    if target_w>max_w:
        target_h=round(target_h*max_w/target_w);target_w=max_w
    glyph=glyph.resize((target_w,target_h),Image.Resampling.LANCZOS)
    yy=round(cy-target_h/2-(7*ss if number in (6,9) else 0))
    im.paste(ink,(round(cx-target_w/2),yy),glyph)
    if number in (6,9):
        d.rounded_rectangle((cx-16*ss,cy+54*ss,cx+16*ss,cy+58*ss),radius=2*ss,fill=ink)
    im=im.resize((1024,512),Image.Resampling.LANCZOS)
    path=ASSETS/f'BallSticker_{style}_{number}.png'
    im.save(path,optimize=True)
    return path

bpy.ops.wm.read_factory_settings(use_empty=True)
source = ROOT / 'QiuJi/Resources/TaiQiuZhuo.usdz'
sha = hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.usd_import(filepath=str(source), import_textures_mode='IMPORT_PACK')
stage=Usd.Stage.Open(str(source))
mapping={}
for p in stage.Traverse():
    if p.GetTypeName()=='Mesh' and p.GetParent().GetName().startswith('_') and p.GetParent().GetName()[1:].isdigit():
        mapping[int(p.GetParent().GetName()[1:])]=p.GetName()
assert sorted(mapping)==list(range(1,16))
originals={n:bpy.data.objects[name] for n,name in mapping.items()}
# Preview-only coordinates: normalized sphere centered at origin, front +Z,
# image right +X, image up +Y. Original source positions and UVs are retained
# in source-inspection.blend; runtime geometry is never exported or changed.
def preview_mesh(n):
    src=originals[n]
    mesh=src.data.copy()
    verts=np.array([v.co[:] for v in mesh.vertices])
    center=(verts.min(axis=0)+verts.max(axis=0))/2
    radius=np.linalg.norm(verts-center,axis=1).mean()
    uv=mesh.uv_layers.active.data
    samples=[]
    for loop in mesh.loops:
        u,v=uv[loop.index].uv
        if abs(u-.5)<.12 and abs(v-.5)<.15:
            samples.append((u,v,*((verts[loop.vertex_index]-center)/radius)))
    a=np.array(samples)
    assert len(a)>5,(n,len(a))
    fit=np.linalg.lstsq(np.column_stack([a[:,0]-.5,a[:,1]-.5,np.ones(len(a))]),a[:,2:],rcond=None)[0]
    right=Vector(fit[0]).normalized();up=Vector(fit[1]);up=(up-right*up.dot(right)).normalized()
    front=right.cross(up)
    assert front.dot(Vector(fit[2]))>0,('Mirrored UV',n)
    rotation=Matrix((right,up,front))
    for vertex in mesh.vertices:vertex.co=rotation @ Vector((verts[vertex.index]-center)/radius)
    return mesh

meshes={n:preview_mesh(n) for n in range(1,16)}
for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.world=bpy.data.worlds.new('Neutral studio')
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.32,.32,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
scene.render.resolution_percentage=100
def area(name,position,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=position
    o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
area('Key',(-5,5,8),1800,5)
area('Fill',(6,2,6),1000,4)
camdata=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camdata);scene.collection.objects.link(cam)
cam.location=(0,0,20);camdata.type='ORTHO';scene.camera=cam
collections=[]
for style in STYLES:
    collection=bpy.data.collections.new(style);scene.collection.children.link(collection);collections.append(collection)
    for n in range(1,16):
        path=texture(style,n)
        mesh=meshes[n].copy();o=bpy.data.objects.new(f'{style}_{n}',mesh);collection.objects.link(o)
        o.visible_glossy=False
        o.location=((n-1)%5*2.3-4.6, 2.3-((n-1)//5)*2.3,0)
        mat=bpy.data.materials.new(f'BallSticker_{style}_{n}');mat.use_nodes=True
        p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.10;p.inputs['Metallic'].default_value=0
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path));tex.image.colorspace_settings.name='sRGB'
        mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        mesh.materials.clear();mesh.materials.append(mat)
    print('AUTHORED',style,flush=True)

for c in collections:c.hide_render=True
for collection in collections:
    collection.hide_render=False
    scene.render.resolution_x=1500;scene.render.resolution_y=960;camdata.ortho_scale=12.2
    scene.render.filepath=str(OUT/f'{collection.name}-all.png');bpy.ops.render.render(write_still=True)
    # Actual Blender-rendered selection thumbnail, showing solid, black and stripe.
    positions={o.name:o.location.copy() for o in collection.objects}
    selected=[1,8,10]
    for o in collection.objects:
        n=int(o.name.rsplit('_',1)[1]);o.hide_render=n not in selected
        if n in selected:o.location=((selected.index(n)-1)*2.3,0,0)
    scene.render.resolution_x=840;scene.render.resolution_y=290;camdata.ortho_scale=7
    scene.render.filepath=str(ASSETS/f'BallSticker_{collection.name}_preview.png');bpy.ops.render.render(write_still=True)
    for o in collection.objects:o.location=positions[o.name];o.hide_render=False
    collection.hide_render=True
collections[0].hide_render=False
scene.render.resolution_x=1500;scene.render.resolution_y=960;camdata.ortho_scale=12.2
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'BallStickerLibrary.blend'))
manifest={'blender':bpy.app.version_string,'sourceSHA256':sha,'sourceMapping':mapping,'styles':list(STYLES),'size':[1024,512], 'colorSpace':'sRGB','lightingBaked':False,'runtimeGeometryChanged':False,'fonts':{k:v[1] for k,v in STYLES.items()}}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
assert hashlib.sha256(source.read_bytes()).hexdigest()==sha
print('BALL_STICKERS_COMPLETE',flush=True)
