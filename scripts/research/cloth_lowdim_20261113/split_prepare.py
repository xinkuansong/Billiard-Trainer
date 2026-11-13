"""Append classified/indirect kernels to a pinned production-derived math source."""
import argparse,hashlib,json
from pathlib import Path


def prepare(source_path,out):
    source=source_path.read_text()
    start=source.index('kernel void evaluateCandidate(')
    candidate=source[start:]
    assert candidate.count('kernel void ')==1
    candidate=candidate.replace('kernel void evaluateCandidate(', 'kernel void evaluateSplitCandidate(',1)
    old='                              uint index [[thread_position_in_grid]]) {\n    if (index >= count) return;'
    assert candidate.count(old)==1
    candidate=candidate.replace(old,'''                              device const uint *indices [[buffer(6)]],
                              device const uint *counts [[buffer(7)]],
                              uint slot [[thread_position_in_grid]]) {
    if(slot>=counts[0]) return;
    uint index=indices[slot];''',1)
    old='    if(moments[base].w==0.0) { results[index]=referenceAt(inputs[index],balls); return; }\n'
    assert candidate.count(old)==1
    candidate=candidate.replace(old,'',1)
    additions='''
// Counts and indices are temporary per dispatch; no CPU count readback.
kernel void classifyRecords(device const float4 *moments [[buffer(0)]],
                            device atomic_uint *counts [[buffer(1)]],
                            device uint *eligible [[buffer(2)]],
                            device uint *fallback [[buffer(3)]],
                            constant uint &count [[buffer(4)]],
                            constant uint &groups [[buffer(5)]],
                            uint i [[thread_position_in_grid]]) {
    if(i>=count) return;
    bool use=moments[i*(groups+2)].w!=0.0;
    uint slot=atomic_fetch_add_explicit(&counts[use?0:1],1u,memory_order_relaxed);
    if(use) eligible[slot]=i; else fallback[slot]=i;
}
kernel void makeIndirectArguments(device const uint *counts [[buffer(0)]],
                                  device uint *arguments [[buffer(1)]],
                                  uint i [[thread_position_in_grid]]) {
    if(i>=2) return;
    arguments[i*3]=max(1u,(counts[i]+127u)/128u);
    arguments[i*3+1]=1u; arguments[i*3+2]=1u;
}
kernel void evaluateSplitFallback(device const Input *inputs [[buffer(0)]],
                                 constant float4 *balls [[buffer(1)]],
                                 device Result *results [[buffer(2)]],
                                 device const uint *indices [[buffer(6)]],
                                 device const uint *counts [[buffer(7)]],
                                 uint slot [[thread_position_in_grid]]) {
    if(slot>=counts[1]) return;
    uint index=indices[slot];
    results[index]=referenceAt(inputs[index],balls);
}
'''
    result=source+additions+candidate
    out.parent.mkdir(parents=True,exist_ok=True)
    if out.exists():raise FileExistsError(out)
    out.write_text(result)
    out.with_suffix('.manifest.json').write_text(json.dumps({'input':str(source_path),'input_sha256':hashlib.sha256(source.encode()).hexdigest(),
        'output_sha256':hashlib.sha256(result.encode()).hexdigest(),
        'changes':['Append atomic index classification by immutable precomputed enabled flag','Append indirect argument generation','Append exact reference fallback dispatch','Clone original candidate consumer, remove fallback branch after classification'],
        'limits':'No moment production or eligibility calculation cost. Includes runtime list construction and indirect dispatch in benchmark.'},indent=2)+'\n')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('source',type=Path);ap.add_argument('out',type=Path);a=ap.parse_args();prepare(a.source,a.out)
