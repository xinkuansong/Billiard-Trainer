"""Original seamless leather micro-surface, authored and baked in Blender.

Blender --background --python-exit-code 1 --python scripts/blender/bake_table_leather.py
Defaults reproduce the approved r4: 65 cells, 220 micrometres, rounded crowns.
Outputs are candidates only. Never writes the production USDZ or resource directory.
"""
import bpy
import hashlib
import json
import math
import argparse
import sys
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--leaf', default='blender-approved-r4')
parser.add_argument('--height', type=float, default=.00022)
parser.add_argument('--cells', type=float, default=65)
parser.add_argument('--rounded', action=argparse.BooleanOptionalAction, default=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = ROOT / 'output/table-materials-v64/W1' / args.leaf
OUT.mkdir(parents=True, exist_ok=False)
SOURCE = ROOT / 'QiuJi/Resources/TaiQiuZhuo.usdz'
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_plane_add(size=.151)
plane = bpy.context.object
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 1
scene.render.bake.margin = 0
scene.view_settings.view_transform = 'Standard'
mat = bpy.data.materials.new('LeatherMicro_OriginalProcedural')
mat.use_nodes = True
plane.data.materials.append(mat)
nodes, links = mat.node_tree.nodes, mat.node_tree.links
nodes.clear()

def math_node(operation, a, b=None):
    node = nodes.new('ShaderNodeMath'); node.operation = operation
    for i, value in enumerate([a, b]):
        if value is None: continue
        if isinstance(value, (int, float)): node.inputs[i].default_value = value
        else: links.new(value, node.inputs[i])
    return node.outputs[0]

uv = nodes.new('ShaderNodeTexCoord')
separate = nodes.new('ShaderNodeSeparateXYZ'); links.new(uv.outputs['UV'], separate.inputs[0])
u = math_node('MULTIPLY', separate.outputs['X'], 2*math.pi)
v = math_node('MULTIPLY', separate.outputs['Y'], 2*math.pi)
# Unit-speed periodic embedding: derivative length in UV space is exactly one.
coords = [math_node('MULTIPLY', math_node(op, angle), 1/(2*math.pi))
          for angle, op in [(u,'COSINE'), (u,'SINE'), (v,'COSINE'), (v,'SINE')]]
vector = nodes.new('ShaderNodeCombineXYZ')
for i in range(3): links.new(coords[i], vector.inputs[i])
grain = nodes.new('ShaderNodeTexVoronoi')
grain.voronoi_dimensions = '4D'; grain.feature = 'DISTANCE_TO_EDGE'
grain.inputs['Scale'].default_value = args.cells
links.new(vector.outputs[0], grain.inputs['Vector']); links.new(coords[3], grain.inputs['W'])
shape = nodes.new('ShaderNodeMapRange'); shape.interpolation_type = 'SMOOTHERSTEP'
shape.inputs['From Min'].default_value = .015; shape.inputs['From Max'].default_value = .19
shape.inputs['To Min'].default_value = .05; shape.inputs['To Max'].default_value = .95
links.new(grain.outputs['Distance'], shape.inputs['Value'])
noise = nodes.new('ShaderNodeTexNoise'); noise.noise_dimensions = '4D'
noise.inputs['Scale'].default_value = args.cells * 2; noise.inputs['Detail'].default_value = 2
links.new(vector.outputs[0], noise.inputs['Vector']); links.new(coords[3], noise.inputs['W'])
if args.rounded:
    # Rounded pebble crowns instead of flat polygonal plateaus. Reuse the same
    # periodic sites so crowns, valleys and the roughness remain aligned.
    centers = nodes.new('ShaderNodeTexVoronoi')
    centers.voronoi_dimensions = '4D'; centers.feature = 'F1'
    centers.inputs['Scale'].default_value = args.cells
    links.new(vector.outputs[0], centers.inputs['Vector']); links.new(coords[3], centers.inputs['W'])
    crown = nodes.new('ShaderNodeMapRange'); crown.interpolation_type = 'SMOOTHERSTEP'
    crown.inputs['From Min'].default_value = .1; crown.inputs['From Max'].default_value = .85
    crown.inputs['To Min'].default_value = .95; crown.inputs['To Max'].default_value = .05
    links.new(centers.outputs['Distance'], crown.inputs['Value'])
    height = math_node('ADD', math_node('ADD', math_node('MULTIPLY',crown.outputs[0],.60),
                       math_node('MULTIPLY',shape.outputs[0],.28)), math_node('MULTIPLY',noise.outputs['Fac'],.12))
else:
    height = math_node('ADD', math_node('MULTIPLY',shape.outputs[0], .82), math_node('MULTIPLY',noise.outputs['Fac'], .18))
bump = nodes.new('ShaderNodeBump'); bump.inputs['Distance'].default_value = args.height
bump.inputs['Strength'].default_value = 1
links.new(height, bump.inputs['Height'])
encode = nodes.new('ShaderNodeVectorMath'); encode.operation = 'MULTIPLY_ADD'
links.new(bump.outputs['Normal'], encode.inputs[0])
encode.inputs[1].default_value = (.5,.5,.5); encode.inputs[2].default_value = (.5,.5,.5)
rough = math_node('SUBTRACT', .76, math_node('MULTIPLY',height,.16))
emission = nodes.new('ShaderNodeEmission')
output = nodes.new('ShaderNodeOutputMaterial'); links.new(emission.outputs[0], output.inputs['Surface'])
manifest = {'blender':bpy.app.version_string, 'sourceSHA256':source_hash,
            'tileMeters':.151, 'cellsPerTile':args.cells, 'bumpMeters':args.height, 'rounded':args.rounded,
            'colorSpace':'Non-Color', 'origin':'Original Blender procedural nodes; no external texture pixels', 'textures':[]}
for name, socket in [('normal',encode.outputs[0]), ('roughness',rough)]:
    image = bpy.data.images.new('LeatherMicro_'+name, width=1024,height=1024,alpha=False)
    image.colorspace_settings.name = 'Non-Color'
    target = nodes.new('ShaderNodeTexImage'); target.image = image; nodes.active = target
    links.new(socket,emission.inputs['Color'])
    bpy.ops.object.bake(type='EMIT',margin=0,use_clear=True)
    path = OUT / (image.name+'.png'); image.filepath_raw=str(path); image.file_format='PNG';image.save()
    pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
    pixels=pixels.reshape(-1,4)
    manifest['textures'].append({'name':path.name,'bytes':path.stat().st_size,
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'mean':pixels.mean(0,dtype=np.float64).tolist(),'std':pixels.std(0,dtype=np.float64).tolist()})
bsdf=nodes.new('ShaderNodeBsdfPrincipled');bsdf.inputs['Base Color'].default_value=(.40,.34,.24,1)
links.new(bump.outputs['Normal'],bsdf.inputs['Normal']);links.new(rough,bsdf.inputs['Roughness'])
links.new(bsdf.outputs[0],output.inputs['Surface'])
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'leather-authoring.blend'))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('LEATHER_BAKE_COMPLETE',flush=True)
