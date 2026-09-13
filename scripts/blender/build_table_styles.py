"""Bake four albedo variants from the original wood grain; never rewrite the USDZ.

Run with Blender --background --python-exit-code 1 --python this_file.
The .blend authoring file stays under output; only four PNGs enter the app.
"""
import bpy
import pathlib
import json
import hashlib
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/table-styles-20260913'
DEST = ROOT / 'QiuJi/Resources/TableStyles'
OUT.mkdir(parents=True, exist_ok=True)
DEST.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'QiuJi/Resources/TaiQiuZhuo.usdz'
before = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=str(SOURCE), import_textures_mode='IMPORT_PACK')
source = bpy.data.images['Wood_basecolor.png']
pixels = np.empty(len(source.pixels), dtype=np.float32)
source.pixels.foreach_get(pixels)
rgb = pixels.reshape(-1, 4)[:, :3]
# PNG image buffers use encoded values; shader sampling decodes sRGB.
linear = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
luma = linear @ np.array([.2126, .7152, .0722])
low, high = [float(x) for x in np.quantile(luma, [.02, .98])]

def color(hex_value):
    v = [int(hex_value[i:i+2], 16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)

styles = {
    'walnut': ('38241C', '77503C'),
    'charcoal': ('202125', '414248'),
    'ivory': ('CDBFA2', 'F3E9D2'),
    'blossom': ('CD849C', 'F3B9CA'),
}
# Bake a UV plane, keeping the existing table UV mapping untouched at runtime.
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.object
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 1
scene.render.bake.margin = 0
scene.view_settings.view_transform = 'Standard'
report = {'blender': bpy.app.version_string, 'source_sha256': before,
          'source_luminance_range': [low, high], 'textures': []}
for style, (dark, light) in styles.items():
    material = bpy.data.materials.new('TableStyle_' + style)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    links = material.node_tree.links
    tex = nodes.new('ShaderNodeTexImage'); tex.image = source
    bw = nodes.new('ShaderNodeRGBToBW'); links.new(tex.outputs['Color'], bw.inputs[0])
    remap = nodes.new('ShaderNodeMapRange')
    remap.inputs['From Min'].default_value = low
    remap.inputs['From Max'].default_value = high
    links.new(bw.outputs[0], remap.inputs['Value'])
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = color(dark)
    ramp.color_ramp.elements[1].color = color(light)
    links.new(remap.outputs[0], ramp.inputs[0])
    emission = nodes.new('ShaderNodeEmission'); links.new(ramp.outputs[0], emission.inputs['Color'])
    output = nodes.new('ShaderNodeOutputMaterial'); links.new(emission.outputs[0], output.inputs['Surface'])
    image = bpy.data.images.new('TableWood_' + style, width=1024, height=1024, alpha=False)
    image.colorspace_settings.name = 'sRGB'
    target = nodes.new('ShaderNodeTexImage'); target.image = image
    nodes.active = target
    plane.data.materials.clear(); plane.data.materials.append(material)
    bpy.ops.object.bake(type='EMIT')
    path = DEST / (image.name + '.png')
    image.filepath_raw = str(path); image.file_format = 'PNG'; image.save()
    report['textures'].append({'style': style, 'dark_srgb': dark, 'light_srgb': light,
        'path': str(path.relative_to(ROOT)), 'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'table-style-materials.blend'))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == before
(OUT / 'bake-manifest.json').write_text(json.dumps(report, indent=2))
