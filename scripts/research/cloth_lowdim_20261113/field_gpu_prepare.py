#!/usr/bin/env python3
"""Derive a K8 transport-field experiment from the extracted production R core.

No production source changes. Fixed near-grid transport is material independent;
the consumer still chooses exact original fallback for noneligible receivers.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


def once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new)


def prepare(source, out):
    original = source.read_text()
    body = original.split('inline Result referenceAt(Input input, constant float4 *balls) {\n', 1)[1]
    body = body.split('    return {float4(unoccludedE', 1)[0]
    predicate = body[body.index('bool shadowPossible=false;'):body.index('uint shadowMask=0u;')]
    prefix = body[:body.index('for(int panel=0;panel<2;++panel) {')]
    prefix = prefix[:prefix.index('float3 p=input.position.xyz;')] + prefix[prefix.index('bool shadowPossible=false;'):]
    loops = body[body.index('for(int panel=0;panel<2;++panel) {'):body.index('float3 sampledE=E;')]
    loops = once(loops, 'int samplesX=shadowPossible?8:2;', 'int samplesX=8;')
    loops = once(loops, 'int samplesZ=shadowPossible?4:2;', 'int samplesZ=4;')
    begin = loops.index('   float nl=max(0.001,dot(n,l));')
    end = loops.index('\n  }\n }\n}', begin)
    weighted = loops[loops.index('float3 weighted='):loops.index('\n   unoccludedE+=weighted;')]
    # Only remove receiver-normal and RGB factors. Preserve radiance/geometry/visibility.
    scalar = once(weighted, 'float3 weighted=float3(1,0.985,0.96)*', 'float a=')
    scalar = once(scalar, '*max(0.0,dot(n,l))', '')
    accumulation = '   ' + scalar + '\n   uint group=uint(panel*8+(ix/2)*2+iz/2);\n   float3 t=a*l;\n   M[1]+=t;M[2+group]+=t*visibility;\n'
    loops = loops[:begin] + accumulation + loops[end:]
    assert not re.search(r'\b(n|v|nv|a2|E|S|unoccludedE)\b', loops)
    extra = '''
// Derived transport field: slots MV, M0, then 16 visible directional groups.
inline void fieldMomentsAt(float3 p, constant float4 *balls, thread float3 *M) {
    for(uint k=0;k<18;++k) M[k]=float3(0.0);
''' + prefix + loops + '''
    for(uint k=2;k<18;++k) M[0]+=M[k];
}
inline bool fieldEligible(float3 p,float3 n,constant float4 *balls) {
    if(p.y!=0.8 || abs(p.x)>1.27 || abs(p.z)>0.635) return false;
''' + predicate + '''
    if(!shadowPossible) return false;
    for(int panel=0;panel<2;++panel) {
        float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
        if(dot(n,c-u-w)<0.0 || dot(n,c-u+w)<0.0 || dot(n,c+u-w)<0.0 || dot(n,c+u+w)<0.0) return false;
    }
    return true;
}
inline Result fieldConsume(Input input,thread const float3 *M) {
    float3 p=input.position.xyz,n=normalize(input.normal.xyz),v=normalize(input.view.xyz);
    float3 color=float3(1.0,0.985,0.96);
    float3 sampled=color*dot(n,M[0]),unoccluded=color*dot(n,M[1]);
    float3 E=v62PanelDiffuse(p,n)*(sampled/max(unoccluded,float3(0.000001)));
    float3 S=float3(0.0);
    for(uint k=2;k<18;++k) {
        float3 m=M[k];float m2=dot(m,m);
        if(m2>0.0) S+=color*max(0.0,dot(n,m))*groupBRDF(n,v,m/sqrt(m2),input.view.w);
    }
    // corrected.w is an explicit candidate-used diagnostic flag (reference is 0).
    return {float4(unoccluded,1),float4(sampled,0),float4(E,1),float4(S,0)};
}
kernel void generateField(constant float4 *balls [[buffer(1)]],
                          texture2d_array<float,access::write> field [[texture(0)]],
                          uint2 cell [[thread_position_in_grid]]) {
    if(cell.x>=field.get_width() || cell.y>=field.get_height()) return;
    float3 p=float3(-1.27+2.54*float(cell.x)/float(field.get_width()-1),0.8,
                    -0.635+1.27*float(cell.y)/float(field.get_height()-1));
    float3 M[18];fieldMomentsAt(p,balls,M);
    for(uint k=0;k<18;++k) field.write(float4(M[k],0.0),cell,k);
}
inline float2 fieldUV(float3 p,uint width,uint height) {
    float2 t=(p.xz+float2(1.27,0.635))/float2(2.54,1.27);
    return (t*float2(width-1,height-1)+0.5)/float2(width,height);
}
kernel void evaluateField(device const Input *inputs [[buffer(0)]],
                          constant float4 *balls [[buffer(1)]],
                          device Result *results [[buffer(2)]],
                          constant uint &count [[buffer(3)]],
                          texture2d_array<float,access::sample> field [[texture(0)]],
                          uint index [[thread_position_in_grid]]) {
    if(index>=count) return;
    Input input=inputs[index];
    if(!fieldEligible(input.position.xyz,normalize(input.normal.xyz),balls)) {
        results[index]=referenceAt(input,balls);return;
    }
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 uv=fieldUV(input.position.xyz,field.get_width(),field.get_height());
    float3 M[18];
    for(uint k=0;k<18;++k) M[k]=field.sample(s,uv,k).xyz;
    results[index]=fieldConsume(input,M);
}
kernel void evaluatePoint(device const Input *inputs [[buffer(0)]],
                          constant float4 *balls [[buffer(1)]],
                          device Result *results [[buffer(2)]],
                          constant uint &count [[buffer(3)]],
                          uint index [[thread_position_in_grid]]) {
    if(index>=count) return;
    Input input=inputs[index];
    if(!fieldEligible(input.position.xyz,normalize(input.normal.xyz),balls)) {
        results[index]=referenceAt(input,balls);return;
    }
    float3 M[18];fieldMomentsAt(input.position.xyz,balls,M);
    results[index]=fieldConsume(input,M);
}
kernel void readField(texture2d_array<float,access::read> field [[texture(0)]],
                      device float4 *values [[buffer(0)]],uint index [[thread_position_in_grid]]) {
    uint width=field.get_width(),count=width*field.get_height();if(index>=count) return;
    uint2 cell=uint2(index%width,index/width);
    for(uint k=0;k<18;++k) values[index*18+k]=field.read(cell,k);
}
kernel void readSampledField(device const Input *inputs [[buffer(0)]],
                             device float4 *values [[buffer(2)]],constant uint &count [[buffer(3)]],
                             texture2d_array<float,access::sample> field [[texture(0)]],
                             uint index [[thread_position_in_grid]]) {
    if(index>=count) return;
    constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 uv=fieldUV(inputs[index].position.xyz,field.get_width(),field.get_height());
    for(uint k=0;k<18;++k) values[index*18+k]=field.sample(s,uv,k);
}
'''
    # Explicit half conversion avoids implementation-specific float->half texture
    # write conversion rounding. Keep float entry as an RGBA32F control.
    generation = extra[extra.index('kernel void generateField('):extra.index('inline float2 fieldUV(')]
    generation_half = generation.replace('void generateField(', 'void generateFieldHalf(').replace(
        'texture2d_array<float,access::write>', 'texture2d_array<half,access::write>').replace(
        'field.write(float4(M[k],0.0)', 'field.write(half4(half3(M[k]),half(0.0))')
    extra += generation_half
    out.mkdir(parents=True, exist_ok=False)
    (out / 'field.metal').write_text(original + extra)
    manifest = {'source': str(source), 'source_sha256': hashlib.sha256(original.encode()).hexdigest(),
                'field_metal_sha256': hashlib.sha256((original+extra).encode()).hexdigest(),
                'transforms':['Original referenceAt retained byte-for-byte',
                    'Extract original shadowPossible and shadowMask code; retain original visibility expression',
                    'Force samplesX=8 samplesZ=4 even for unshadowed field texels',
                    'Remove BRDF and receiver cosine/RGB from weighted transport; accumulate a*l and visibility groups',
                    'K8 per lamp groups adjacent 2x2 original samples; slots MV,M0,16 groups',
                    'Generate world Y=.8 endpoint grid on X[-1.27,1.27],Z[-.635,.635]',
                    'RGBA16Float 2D array; normalized half-texel-correct bilinear sampling',
                    'Receiver actual near predicate + original emitter corner halfspace guard + strict domain/Y check',
                    'Exact original fallback; original groupBRDF and analytic diffuse unchanged'],
                'scope':'Material-lighting core only. Generation and consumption measured; no rasterization/SceneKit/frame present.'}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    args=ap.parse_args();prepare(args.source,args.out)
