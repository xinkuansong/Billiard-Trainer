"""Measure Cycles direct diffuse against the shipping analytic rectangle rig.

Run in a clean background Blender process; output is evidence, not an App asset.
App metres (X,Y,Z) map to Blender (X,-Z,Y). No exposure/tone-map fitting.
"""
import argparse, hashlib, json, math, pathlib, re, sys
import bpy
import numpy as np
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = pathlib.Path(args.output).resolve(); out.mkdir(parents=True, exist_ok=True)
source = pathlib.Path(__file__).resolve().parents[2] / 'QiuJi/Core/Scene/MobileReferenceLighting.swift'
text = source.read_text()
rig = {}
for key in ('panelHeight', 'panelWidth', 'panelDepth', 'panelOffset', 'radiance'):
    matches = re.findall(r'let\s+' + key + r'\s*=\s*([0-9.]+)', text)
    if len(matches) != 1: raise ValueError('Ambiguous rig field: ' + key)
    rig[key] = float(matches[0])

def reference(p, n):
    # Independent midpoint area quadrature of cos(receiver)*cos(emitter)/r^2.
    x = (np.arange(256)+.5)/256*rig['panelWidth']-rig['panelWidth']/2
    z = (np.arange(128)+.5)/128*rig['panelDepth']-rig['panelDepth']/2
    xx, zz = np.meshgrid(x, z)
    result = 0.
    for sign in (-1, 1):
        v = np.stack((xx-p[0], np.full_like(xx, rig['panelHeight']-p[1]),
                      zz+sign*rig['panelOffset']-p[2]), axis=-1)
        r2 = np.sum(v*v, axis=-1)
        result += np.mean(np.maximum(v@np.array(n), 0)*v[...,1]/r2**2)*rig['panelWidth']*rig['panelDepth']
    return (.18*rig['radiance']/math.pi**2*result*np.array([1,.985,.96])).tolist()

bpy.ops.wm.read_factory_settings(use_empty=True)
s = bpy.context.scene; s.render.engine='CYCLES'; s.cycles.samples=256
s.world = bpy.data.worlds.new('black'); s.world.use_nodes=True
s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=0
s.render.bake.use_pass_direct=True; s.render.bake.use_pass_indirect=False
s.render.bake.use_pass_color=True
lights=[]
for sign in (-1,1):
    data=bpy.data.lights.new('reference_panel','AREA'); data.shape='RECTANGLE'
    data.size=rig['panelWidth']; data.size_y=rig['panelDepth']
    data.energy=100; data.color=(1,.985,.96)
    obj=bpy.data.objects.new(data.name,data); s.collection.objects.link(obj)
    obj.location=(0,-sign*rig['panelOffset'],rig['panelHeight']); lights.append(data)
mat=bpy.data.materials.new('18_percent_diffuse'); mat.use_nodes=True
nodes=mat.node_tree.nodes; nodes.clear()
d=nodes.new('ShaderNodeBsdfDiffuse'); d.inputs['Color'].default_value=(.18,.18,.18,1)
dest=nodes.new('ShaderNodeOutputMaterial'); mat.node_tree.links.new(d.outputs[0],dest.inputs[0])
im=bpy.data.images.new('linear_probe',16,16,float_buffer=True)
t=nodes.new('ShaderNodeTexImage'); t.image=im; nodes.active=t
bpy.ops.mesh.primitive_plane_add(size=.005)
card=bpy.context.object; card.data.materials.append(mat)
def measure(p,n):
    card.location=(p[0],-p[2],p[1])
    card.rotation_euler=Vector((n[0],-n[2],n[1])).to_track_quat('Z','Y').to_euler()
    bpy.context.view_layer.update(); bpy.ops.object.bake(type='DIFFUSE')
    pixels=np.array(im.pixels[:]).reshape(16,16,4)
    return np.mean(pixels[4:12,4:12,:3],axis=(0,1))
p=(0,.8,0); n=(0,1,0)
first=measure(p,n); target=np.array(reference(p,n))
power=100*target[0]/first[0]
for light in lights: light.energy=power
records=[]
for p,n in [((0,.8,0),(0,1,0)),((1,.8,.5),(0,1,0)),((0,.83,0),(0,.6,.8)),((2,0,1),(0,1,0))]:
    actual=measure(p,n); expected=np.array(reference(p,n))
    records.append(dict(position=p,normal=n,expected_linear=expected.tolist(),measured_linear=actual.tolist(),relative_error=((actual-expected)/expected).tolist()))
report=dict(source_sha256=hashlib.sha256(text.encode()).hexdigest(),rig=rig,
            panel_color=[1,.985,.96],watts_per_panel=power,blender=bpy.app.version_string,
            scope='Direct diffuse only; excludes environment, bounce, specular and tone mapping.',probes=records)
(out/'calibration.json').write_text(json.dumps(report,indent=2))
assert max(abs(e) for r in records for e in r['relative_error']) < .03, report
print('CALIBRATION_PASS',power,flush=True)
