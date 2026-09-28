"""Bake r15 centered r14 grain to existing small-cue atlases.
Run from repo root with Blender --background --python-exit-code 1 --python this_file.
Requires the retained r15 authoring blend; stages results before explicit installation.
No lighting is baked into albedo; shared cue geometry/UV and large styles are untouched.
"""
import bpy, json, hashlib, shutil
from pathlib import Path
import numpy as np
ROOT=Path.cwd()
SOURCE=ROOT/'output/cue-grain-20260923/r15/inkDragon.blend'
OUT=ROOT/'output/cue-grain-20260923/r19-app'
BASE=ROOT/'output/cue-grain-20260923/integration/backup'
ASSETS=ROOT/'QiuJi/Resources/CueStyles'
STYLES=['inkDragon','porcelain','landscape','blackGold','heritage']
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'backup').mkdir(exist_ok=True)
manifest=[]
for style in STYLES:
    for suffix in ['', '_roughness','_preview','_detail']:
        name=f'Cue_{style}{suffix}.png'
        backup=OUT/'backup'/name
        if not backup.exists():shutil.copy2(ASSETS/name,backup)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene=bpy.context.scene;scene.cycles.samples=1
    obj=bpy.data.objects['Plane_025']
    import sys
    sys.path.insert(0,str(ROOT/'scripts/blender'))
    from cue_ferrule_finish import finish_ferrule
    finish_ferrule(obj)
    # Match runtime small-cue hardware colors (UIKit sRGB -> Blender linear).
    def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    copper=obj.data.materials[3].node_tree.nodes.get('Principled BSDF')
    copper.inputs['Base Color'].default_value=(*(linear(v) for v in (.78,.70,.48)),1)
    copper.inputs['Metallic'].default_value=1
    copper.inputs['Roughness'].default_value=.32
    cn=obj.data.materials[3].node_tree.nodes;cl=obj.data.materials[3].node_tree.links
    rt=cn.new('ShaderNodeTexImage');rt.image=bpy.data.images.load(str(ASSETS/'CueBrass_roughness.png'));rt.image.colorspace_settings.name='Non-Color'
    cl.new(rt.outputs['Color'],copper.inputs['Roughness'])
    tip=obj.data.materials[2];tn=tip.node_tree.nodes;tl=tip.node_tree.links;tp=tn.get('Principled BSDF')
    bt=cn.new('ShaderNodeTexImage');bt.image=bpy.data.images.load(str(ASSETS/'CueBrass_generated.png'))
    cl.new(bt.outputs['Color'],copper.inputs['Base Color'])
    tt=tn.new('ShaderNodeTexImage');tt.image=bpy.data.images.load(str(ASSETS/'CueTip_generated.png'))
    tl.new(tt.outputs['Color'],tp.inputs['Base Color'])
    for key in ['Normal','Roughness','Metallic']:
        for link in list(tp.inputs[key].links):tl.remove(link)
    tp.inputs['Roughness'].default_value=.88;tp.inputs['Metallic'].default_value=0
    authored=obj.data.materials[0].copy()
    nodes=authored.node_tree.nodes;links=authored.node_tree.links
    for name,suffix in [('Image Texture',''),('Image Texture.001','_roughness')]:
        nodes[name].image=bpy.data.images.load(str(BASE/f'Cue_{style}{suffix}.png'))
        if suffix:nodes[name].image.colorspace_settings.name='Non-Color'
    bsdf=nodes.get('Principled BSDF')
    sockets={suffix:bsdf.inputs[input_name].links[0].from_socket for suffix,input_name in [('', 'Base Color'),('_roughness','Roughness')]}
    bpy.ops.mesh.primitive_plane_add();plane=bpy.context.object;plane.data.materials.append(authored)
    emission=nodes.new('ShaderNodeEmission');links.new(emission.outputs[0],nodes.get('Material Output').inputs['Surface'])
    outputs={}
    for suffix in ['', '_roughness']:
        target=bpy.data.images.new(f'{style}{suffix}_r12',width=512,height=4096)
        target.colorspace_settings.name='Non-Color' if suffix else 'sRGB'
        dest=nodes.new('ShaderNodeTexImage');dest.image=target;nodes.active=dest
        links.new(sockets[suffix],emission.inputs['Color'])
        bpy.ops.object.bake(type='EMIT',margin=0,use_clear=True)
        target.filepath_raw=str(OUT/f'Cue_{style}{suffix}.png');target.file_format='PNG';target.save()
        # Compare decoded pixels below the material transition, including rear art.
        original=nodes['Image Texture.001' if suffix else 'Image Texture'].image
        before=np.array(original.pixels[:]).reshape(4096,512,4)
        after=np.array(target.pixels[:]).reshape(4096,512,4)
        rear_delta=float(np.max(np.abs(before[:int(.36*4096)]-after[:int(.36*4096)])))
        assert rear_delta<=1.01/255,(style,suffix,rear_delta)
        outputs[suffix]=target
        manifest.append(dict(style=style,channel=suffix or 'albedo',rearMaxDelta8Bit=rear_delta*255,sha256=hashlib.sha256(Path(target.filepath_raw).read_bytes()).hexdigest()))
    bpy.data.objects.remove(plane,do_unlink=True)
    # Inspect/render the actual baked maps through simple exportable PBR nodes.
    for mat in obj.data.materials[:2]:
        n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
        for suffix,input_name in [('', 'Base Color'),('_roughness','Roughness')]:
            tex=n.new('ShaderNodeTexImage');tex.image=outputs[suffix];l.new(tex.outputs['Color'],p.inputs[input_name])
    scene.cycles.samples=32;scene.render.film_transparent=True
    for suffix,width,height,y,scale in [('_preview',1560,180,0,1.56),('_detail',1560,300,-.40,.72)]:
        scene.render.resolution_x=width;scene.render.resolution_y=height;scene.camera.location.y=y;scene.camera.data.ortho_scale=scale
        scene.render.filepath=str(OUT/f'Cue_{style}{suffix}.png');bpy.ops.render.render(write_still=True)
    scene.render.film_transparent=False;scene.render.resolution_x=1800;scene.render.resolution_y=340
    scene.camera.location.y=.25;scene.camera.data.ortho_scale=.22
    scene.render.filepath=str(OUT/f'{style}-baked-macro.png');bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('APP_ATLASES_BAKED_AND_REAR_PRESERVED',len(STYLES),flush=True)
