"""Summarize Xcode H8 CSV exports without treating profiler runs as A/B timing."""
from pathlib import Path
import argparse
import csv
import hashlib
import json

p = argparse.ArgumentParser()
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
a = p.parse_args()
observations = a.evidence / 'xcode-observations.json'
result = json.loads(observations.read_text())
result['evidenceSHA256'] = {observations.name: hashlib.sha256(observations.read_bytes()).hexdigest()}
keys = ['FS ALU Instructions', 'FS Invocations', 'FS Occupancy',
        'F32 Limiter', 'F32 Utilization', 'Instruction Throughput Limiter',
        'Control Flow Limiter', 'Register Pressure Influence',
        'L1 Cache Pressure Influence', 'Memory Request Stalls Influence',
        'Stack L1 Read Bandwidth', 'Stack L1 Write Bandwidth', 'L1 Stack Residency',
        'Fragment Shader Launch Limiter', 'Texture Filtering Limiter']
for variant in result['variants']:
    path = a.evidence / (variant['name'] + '-counters.csv')
    with path.open() as stream:
        reader = csv.DictReader(stream)
        # CSV has duplicate labels for some counters. Only use unique fields.
        assert all(reader.fieldnames.count(key) == 1 for key in keys)
        rows = list(reader)
    matches = [r for r in rows if r['Encoder Label'] == 'MTLRenderCommandEncoder 2']
    assert len(matches) == 1
    assert matches[0]['CommandBuffer Label'] == 'MTLCommandBuffer 3'
    variant['mainRenderEncoderCounters'] = {key: float(matches[0][key]) for key in keys}
    result['evidenceSHA256'][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
baseline = result['variants'][0]['mainRenderEncoderCounters']
assert result['variants'][0]['name'] == 'baseline'
for variant in result['variants']:
    counters = variant['mainRenderEncoderCounters']
    variant['mainEncoderInstructionChangePercent'] = 100 * (counters['FS ALU Instructions'] / baseline['FS ALU Instructions'] - 1)
    variant['instructionsPerFragmentInvocation'] = counters['FS ALU Instructions'] / counters['FS Invocations']
    variant['mainEncoderNormalizedInstructionChangePercent'] = 100 * ((counters['FS ALU Instructions'] / counters['FS Invocations']) / (baseline['FS ALU Instructions'] / baseline['FS Invocations']) - 1)
result['limitations'] = [
    'One captured native Mac near-view workload per variant; Xcode replays internally for profiling.',
    'CSV counters cover all table draws in the main render encoder, not exclusively cloth.',
    'Shader Cost is the Xcode profiler attribution, not energy or an additive wall-time breakdown.',
    'No balanced AA/AB timing here; replay GPU time must not rank candidates or replace H6/H7 timings.',
    'Limiter, utilization, occupancy and residency have different denominators and must not be summed.',
    'CSV does not include bandwidth units; preserve raw fields without assigning unverified units.',
    'Register Pressure Influence is zero in all three exports; spills alone do not prove occupancy limitation.',
    'No per-source-line attribution for the array or full H6 grouped-BRDF candidates was established.',
    'No phone, full-app or thermal validation in H8.'
]
a.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
print(json.dumps([{ 'variant': v['name'], 'instructionChangePercent': v['mainEncoderInstructionChangePercent'], 'spilledBytes': v['fragment']['spilledBytes']} for v in result['variants']], indent=2))
