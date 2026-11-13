"""Derive an in-invocation K8/lamp experiment from the exact native reference.

No cache or spatial field. Original 64/8 transport, masks and diffuse accumulation
remain; only eligible near receivers replace 64 BRDFs with 16 moment BRDFs.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re


def one(text, old, new):
    if text.count(old) != 1:
        raise ValueError((old, text.count(old)))
    return text.replace(old, new)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('reference', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--stream-moments', action='store_true')
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    original = args.reference.read_text()
    start = original.index('inline Result referenceAt(')
    end = original.index('\ninline float groupBRDF(', start)
    core = original[start:end]
    core = one(core, 'inline Result referenceAt(', 'inline Result inlineAt(')
    accum = 'float3 E=float3(0.0);float3 unoccludedE=float3(0.0);float3 S=float3(0.0);'
    core = one(core, accum, accum + '''
float3 moments[16];for(int q=0;q<16;q++) moments[q]=float3(0);
bool momentValid=true;
for(int ax=0;ax<2;ax++)for(int az=0;az<3;az++) {
    float3 corner=float3(ax==0?-2.54:2.54,3.0,float(az-1)*1.27);
    momentValid=momentValid&&dot(n,corner-p)>=0.0;
}
''')
    core = one(core, 'for(int panel=0;panel<2;++panel) {',
               'bool useMoments=momentValid&&shadowPossible;\nfor(int panel=0;panel<2;++panel) {')
    begin = core.index('float nl=max(0.001,dot(n,l));')
    finish = core.index('float3 weighted=', begin)
    brdf = core[begin:finish]
    core = one(core, brdf, '')
    radiance = re.findall(r'float3\(1,0.985,0.96\)\*\(([^/]+)/3.14159265\)', core)
    if len(radiance) != 1:
        raise ValueError('Expected one production radiance')
    core = one(core, 'unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);', '''
unoccludedE+=weighted; E+=weighted*visibility;
if(useMoments) {
    int group=panel*8+(ix/2)*2+(iz/2);
    float a=RADIANCE/3.14159265*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea*v62EmitterGain(panel);
    moments[group]+=a*visibility*l;
} else { BRDF S+=weighted*visibility*D*G*F/(4.0*nv*nl); }
'''.replace('RADIANCE', radiance[0]).replace('BRDF', brdf))
    marker = 'float3 sampledE=E;'
    consume = '''
if(useMoments) { for(int g=0;g<16;g++) {
    float3 m=moments[g];float len2=dot(m,m);
    if(len2>0.0) { float3 l=m/sqrt(len2);
        BRDF
        S+=float3(1.0,0.985,0.96)*max(0.0,dot(n,m))*D*G*F/(4.0*nv*nl);
    }
}}
'''.replace('BRDF', brdf)
    core = one(core, marker, consume + marker)
    core = one(core, 'float4(E,0),float4(S,0)', 'float4(E,float(useMoments)),float4(S,0)')
    if args.stream_moments:
        # Same original ix/iz order and same within-group addition order. At the
        # end of each adjacent ix pair only two Z-bin moments are live, and their
        # BRDFs are consumed in the same order as the original 16-element loop.
        core = one(core, 'float3 moments[16];for(int q=0;q<16;q++) moments[q]=float3(0);', '')
        core = one(core, 'for(int ix=0;ix<samplesX;++ix) {', '''
 float3 moments[2];
 for(int ix=0;ix<samplesX;++ix) {
  if(ix%2==0) {moments[0]=float3(0);moments[1]=float3(0);}
''')
        core = one(core, 'int group=panel*8+(ix/2)*2+(iz/2);', 'int group=iz/2;')
        core = one(core, consume, '')
        streamed = consume.replace('if(useMoments)', 'if(useMoments&&ix%2==1)').replace('g<16', 'g<2')
        core = one(core, '\n  }\n }\n}\n', '\n  }\n'+streamed+'\n }\n}\n')
    kernel = '''
kernel void evaluateInline(device const Input *inputs [[buffer(0)]],
                           constant float4 *balls [[buffer(1)]],
                           device Result *results [[buffer(2)]],
                           constant uint &count [[buffer(3)]],
                           uint index [[thread_position_in_grid]]) {
    if(index<count) results[index]=inlineAt(inputs[index],balls);
}
'''
    result = original + '\n' + core + kernel
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(result)
    manifest = {'reference_sha256': hashlib.sha256(original.encode()).hexdigest(),
                'output_sha256': hashlib.sha256(result.encode()).hexdigest(),
                'method': __doc__, 'radiance_from_production': radiance[0],
                'K_per_panel': 8, 'groups': 16,
                'local_moment_slots': 2 if args.stream_moments else 16,
                'diffuse': 'original per-direction sampled/unoccluded sums unchanged',
                'fallback': 'same original transport and BRDF branch when far or corner guard fails',
                'output': 'same Result protocol except corrected.w is candidate enabled flag'}
    args.output.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')


if __name__ == '__main__':
    main()
