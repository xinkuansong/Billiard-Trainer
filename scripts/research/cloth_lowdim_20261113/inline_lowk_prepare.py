"""K2/K4/K8 local moments with one domain branch before fixed candidate loops.

Production near/mask and BRDF expressions are copied from the extracted source.
Fallback reuses the original arithmetic body with precomputed near/mask values.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
from inline_prepare import one


def build(original):
    start = original.index('inline Result referenceAt(')
    end = original.index('\ninline float groupBRDF(', start)
    core = original[start:end]
    first = core.index('bool shadowPossible=false;')
    last = core.index('for(int panel=0;panel<2;++panel) {', first)
    classify = core[first:last]
    signature = 'inline Result referenceAt(Input input, constant float4 *balls)'
    prepared = one(core, signature, 'inline Result referencePrepared(Input input, constant float4 *balls, bool shadowPossible, uint shadowMask)')
    prepared = one(prepared, classify, '')
    additions = [prepared]
    for k,nx,nz in [(2,2,1),(4,2,2),(8,4,2)]:
        body = one(prepared, 'inline Result referencePrepared(Input input, constant float4 *balls, bool shadowPossible, uint shadowMask)',
                   f'inline Result grouped{k}Prepared(Input input, constant float4 *balls, uint shadowMask)')
        body = one(body, 'float3 p=input.position.xyz;', f'bool shadowPossible=true;\nfloat3 moments[{2*k}];for(int q=0;q<{2*k};q++)moments[q]=float3(0);\nfloat3 p=input.position.xyz;')
        body = one(body, 'int samplesX=shadowPossible?8:2;', 'int samplesX=8;')
        body = one(body, 'int samplesZ=shadowPossible?4:2;', 'int samplesZ=4;')
        body = one(body, 'if(shadowPossible) {', '{')
        begin = body.index('float nl=max(0.001,dot(n,l));')
        finish = body.index('float3 weighted=', begin)
        brdf = body[begin:finish]
        body = one(body, brdf, '')
        radiance = re.findall(r'float3\(1,0.985,0.96\)\*\(([^/]+)/3.14159265\)', body)
        if len(radiance) != 1:
            raise ValueError('Production radiance ambiguous')
        body = one(body, 'unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);', f'''
unoccludedE+=weighted; E+=weighted*visibility;
int group=panel*{k}+(ix/{8//nx})*{nz}+(iz/{4//nz});
float a=({radiance[0]}/3.14159265)*(max(0.0,dot(v62EmitterNormal(panel),-l))/r2)*(v62EmitterArea(panel)/32.0)*v62EmitterGain(panel);
moments[group]+=a*visibility*l;
''')
        consume = f'''
for(int g=0;g<{2*k};g++) {{
    float3 m=moments[g];float len2=dot(m,m);
    if(len2>0.0) {{ float3 l=m/sqrt(len2);
        {brdf}
        S+=float3(1.0,0.985,0.96)*max(0.0,dot(n,m))*D*G*F/(4.0*nv*nl);
    }}
}}
'''
        body = one(body, 'float3 sampledE=E;', consume+'float3 sampledE=E;')
        body = one(body, 'float4(E,0),float4(S,0)', 'float4(E,1),float4(S,0)')
        wrapper = f'''
inline Result grouped{k}At(Input input, constant float4 *balls) {{
    float3 p=input.position.xyz;
    {classify}
    if(!shadowPossible) return referencePrepared(input,balls,shadowPossible,shadowMask);
    float3 n=normalize(input.normal.xyz);
    bool valid=true;
    for(int ax=0;ax<2;ax++)for(int az=0;az<3;az++) {{
        float3 corner=float3(ax==0?-2.54:2.54,3.0,float(az-1)*1.27);
        valid=valid&&dot(n,corner-p)>=0.0;
    }}
    if(!valid) return referencePrepared(input,balls,shadowPossible,shadowMask);
    return grouped{k}Prepared(input,balls,shadowMask);
}}
kernel void evaluateGrouped{k}(device const Input *inputs [[buffer(0)]],
                              constant float4 *balls [[buffer(1)]],
                              device Result *results [[buffer(2)]],
                              constant uint &count [[buffer(3)]],
                              uint index [[thread_position_in_grid]]) {{
    if(index<count)results[index]=grouped{k}At(inputs[index],balls);
}}
'''
        additions.extend([body,wrapper])
    return original+'\n'+'\n'.join(additions)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('reference',type=Path)
    ap.add_argument('output',type=Path)
    args=ap.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    original=args.reference.read_text()
    result=build(original)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(result)
    manifest={'scope':__doc__,'reference_sha256':hashlib.sha256(original.encode()).hexdigest(),
              'generated_sha256':hashlib.sha256(result.encode()).hexdigest(),
              'groups_per_panel':{'2':[2,1],'4':[2,2],'8':[4,2]},
              'guard':'Original near; all emitter corners in positive hemisphere',
              'fallback':'Original arithmetic body with identical precomputed near/mask values',
              'transport_expression':'Explicit parenthesized unprojected scalar with area/32; same near-cell area. Earlier left-associated cellArea expression failed CPU check; retained in pixel-lowk-r2.',
              'output':'Original Result except corrected.w enabled flag for grouped kernels'}
    args.output.with_suffix('.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    main()
