#!/usr/bin/env python3
"""Conservative cell -> blocker candidates; never cache near or light values."""
import argparse
import hashlib
import json
from pathlib import Path


def prepare(source,out):
    original=source.read_text()
    start=original.index('inline Result referenceAt(Input input, constant float4 *balls) {')
    end=original.index('inline float groupBRDF(',start)
    reference=original[start:end]
    a=reference.index('bool shadowPossible=false;')
    b=reference.index('for(int panel=0;panel<2;++panel) {',a)
    # Preserve the exact production bound expression and arithmetic spelling.
    first=reference[reference.index('    float top=balls[0].z+'):reference.index('    shadowPossible=shadowPossible ||')]
    bound_code=first.replace('balls[0]','shadowBall')
    selected='''bool shadowPossible=false;
// Preserve original below-bed behavior exactly: every active ball is in mask,
// while near/far still depends solely on the original XZ support predicate.
uint shadowMask=p.y<0.8 ? (packedCell>>16) : 0u;
uint candidates=packedCell&65535u;
while(candidates!=0u) {
    uint i=ctz(candidates);candidates&=candidates-1u;
    float4 shadowBall=balls[i];
    if(shadowBall.w>0.0) {
'''+bound_code+'''
        bool supports=top>=2.2 || dot(offset,offset)<=bound*bound;
        shadowPossible=shadowPossible || supports;
        if(p.y<0.8 || supports) shadowMask|=(1u<<i);
    }
}
'''
    candidate=reference[:a]+selected+reference[b:]
    candidate=candidate.replace('referenceAt(Input input, constant float4 *balls)',
                                 'referenceSupportAt(Input input, constant float4 *balls, uint packedCell)',1)
    generation_bound=bound_code[:bound_code.index('    float2 offset=')]
    helpers='''
inline bool supportDomain(float3 p) { return abs(p.x)<=1.27 && abs(p.z)<=0.635; }
inline uint2 supportCell(float3 p,uint width,uint height) {
    float2 t=(p.xz+float2(1.27,0.635))/float2(2.54,1.27);
    return min(uint2(max(t,float2(0.0))*float2(width,height)),uint2(width-1,height-1));
}
// Invert the Float mapping with outward rounding at every potentially rounded
// operation (power-of-two grid scale is exact). An extra neighbor accounts for
// the forward p+extent rounding before division. This deliberately overcovers.
inline float lowerCellWorld(uint cell,uint count,float span,float extent) {
    float q=nextafter(float(cell)/float(count),-INFINITY);
    float t=nextafter(q*span,-INFINITY);
    t=nextafter(t,-INFINITY);
    return nextafter(t-extent,-INFINITY);
}
inline float upperCellWorld(uint cell,uint count,float span,float extent) {
    float q=nextafter(float(cell+1)/float(count),INFINITY);
    float t=nextafter(q*span,INFINITY);
    t=nextafter(t,INFINITY);
    return nextafter(t-extent,INFINITY);
}
kernel void generateSupport(constant float4 *balls [[buffer(1)]],
                            texture2d<uint,access::write> grid [[texture(0)]],
                            uint2 cell [[thread_position_in_grid]]) {
    uint width=grid.get_width(),height=grid.get_height();
    if(cell.x>=width || cell.y>=height) return;
    float2 lo=float2(lowerCellWorld(cell.x,width,2.54,1.27),lowerCellWorld(cell.y,height,1.27,0.635));
    float2 hi=float2(upperCellWorld(cell.x,width,2.54,1.27),upperCellWorld(cell.y,height,1.27,0.635));
    uint mask=0u,active=0u;
    for(uint i=0;i<16;++i) {
        float4 shadowBall=balls[i];if(shadowBall.w<=0.0) continue;active|=(1u<<i);
'''+generation_bound+'''
        if(top>=2.2) { mask|=(1u<<i);continue; }
        float2 d=max(float2(0.0),max(lo-shadowBall.xy,shadowBall.xy-hi));
        d=max(float2(0.0),nextafter(d,float2(-INFINITY)));
        float2 d2=nextafter(d*d,float2(-INFINITY));
        float distance2=nextafter(d2.x+d2.y,-INFINITY);
        float bound2=nextafter(bound*bound,INFINITY);
        if(distance2<=bound2) mask|=(1u<<i);
    }
    grid.write(uint4(mask|(active<<16),0,0,0),cell);
}
'''
    consumer='''
kernel void evaluateSupport(device const Input *inputs [[buffer(0)]],
                            constant float4 *balls [[buffer(1)]],
                            device Result *results [[buffer(2)]],
                            constant uint &count [[buffer(3)]],
                            texture2d<uint,access::read> grid [[texture(0)]],
                            uint index [[thread_position_in_grid]]) {
    if(index>=count) return;
    Input input=inputs[index];float3 p=input.position.xyz;
    if(!supportDomain(p)) { results[index]=referenceAt(input,balls);return; }
    uint candidates=grid.read(supportCell(p,grid.get_width(),grid.get_height())).x;
    results[index]=referenceSupportAt(input,balls,candidates);
}
kernel void readSupport(texture2d<uint,access::read> grid [[texture(0)]],
                        device uint *values [[buffer(0)]],uint index [[thread_position_in_grid]]) {
    uint width=grid.get_width();if(index>=width*grid.get_height()) return;
    values[index]=grid.read(uint2(index%width,index/width)).x;
}
kernel void readSupportSamples(device const Input *inputs [[buffer(0)]],
                               device uint2 *values [[buffer(2)]],constant uint &count [[buffer(3)]],
                               texture2d<uint,access::read> grid [[texture(0)]],
                               uint index [[thread_position_in_grid]]) {
    if(index>=count) return;float3 p=inputs[index].position.xyz;
    bool inside=supportDomain(p);
    uint mask=inside?grid.read(supportCell(p,grid.get_width(),grid.get_height())).x:0u;
    values[index]=uint2(mask,uint(inside));
}
'''
    out.mkdir(parents=True,exist_ok=False)
    metal=original+helpers+candidate+consumer
    (out/'support.metal').write_text(metal)
    (out/'manifest.json').write_text(json.dumps({'source':str(source),'sourceSHA256':hashlib.sha256(original.encode()).hexdigest(),
        'metalSHA256':hashlib.sha256(metal.encode()).hexdigest(),'representation':'R32Uint: low16 conservative candidates, high16 active blockers; no light interpolation',
        'boundExpression':generation_bound,'scope':'Any receiver Y within table XZ; below .8 retains all-active shadowMask; outside XZ untouched reference',
        'transforms':['Keep original referenceAt','Extract exact bound expression','Conservative outward-rounded cell bbox vs circle',
            'Read cell bitmask; recompute original exact support for each candidate bit','Retain original 8/64 sampling, visibility, BRDF and analytic diffuse']},indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    args=p.parse_args();prepare(args.source,args.out)
