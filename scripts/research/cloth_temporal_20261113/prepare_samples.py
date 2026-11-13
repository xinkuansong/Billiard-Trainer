"""Precompute immutable lamp sample positions, preserving Float32 operations."""
from pathlib import Path
import struct
import json
import hashlib
root=Path(__file__).resolve().parents[3]
out=root/'output/render-activity-20261113/c1-samples'
out.mkdir(parents=True,exist_ok=True)
b3=root/'output/render-activity-20261113/b3'
base=(b3/'aa.metal').read_text()
rig=json.loads((b3/'current-reference/manifest.json').read_text())['rig']
f=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
values={}
for name,nx,nz in [('Near',8,4),('Far',2,2)]:
    rows=[]
    for panel in rig['panels']:
        c,u,v=([f(x) for x in panel[k]] for k in ['center','u','v'])
        for ix in range(nx):
            for iz in range(nz):
                a=f(f(f(2*f(ix+.5))/nx)-1)
                b=f(f(f(2*f(iz+.5))/nz)-1)
                rows.append([f(f(c[k]+f(u[k]*a))+f(v[k]*b)) for k in range(3)])
    values[name]=rows
decl=''.join('constant float3 temporal'+name+'Samples['+str(len(rows))+']={\n'+',\n'.join('float3('+','.join(format(x,'.17g') for x in row)+')' for row in rows)+'\n};\n' for name,rows in values.items())
old='float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/float(samplesX)-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/float(samplesZ)-1.0);'
new='float3 lp=shadowPossible?temporalNearSamples[panel*32+ix*4+iz]:temporalFarSamples[panel*4+ix*2+iz];'
start=base.index('inline Result referenceAt(');end=base.index('inline float groupBRDF(',start)
reference=base[start:end]
assert reference.count(old)==1
candidate=reference.replace('referenceAt(','heightSupportAt(',1).replace(old,new)
wrappers='''
kernel void evaluateReference(device const Input *input [[buffer(0)]],constant float4 *balls [[buffer(1)]],device Result *output [[buffer(2)]],constant uint &count [[buffer(3)]],uint i [[thread_position_in_grid]]) {if(i<count) output[i]=referenceAt(input[i],balls);}
kernel void evaluateHeightSupport(device const Input *input [[buffer(0)]],constant float4 *balls [[buffer(1)]],device Result *output [[buffer(2)]],constant uint &count [[buffer(3)]],uint i [[thread_position_in_grid]]) {if(i<count) output[i]=heightSupportAt(input[i],balls);}
'''
(out/'candidate.metal').write_text(base[:end]+decl+candidate+wrappers)
(out/'aa.metal').write_text(base[:end]+reference.replace('referenceAt(','heightSupportAt(',1)+wrappers)
surface=(root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2/candidate.surface').read_text()
assert surface.count(old)==1
(out/'baseline.surface').write_text(surface)
(out/'candidate.surface').write_text('#pragma declaration\n'+decl+surface.replace(old,new))
(out/'manifest.json').write_text(json.dumps({'identity':'fixed-lamp-sample-position-v1','samples':values,'sampleCount':72,'constantStorageBytesMSLFloat3Stride':72*16,'extraRuntimeBuffers':0,'extraPasses':0,'quality':'strict/fast radiometric bit equality and real native pixel equality','benefit':'precompute lamp positions once at shader source generation instead of reconstructing at every pixel and frame','sourceSHA256':hashlib.sha256((out/'candidate.metal').read_bytes()).hexdigest()},indent=2)+'\n')
print(out)
