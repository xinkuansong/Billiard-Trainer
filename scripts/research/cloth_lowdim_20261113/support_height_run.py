#!/usr/bin/env python3
"""Probe receiver-height-aware conservative shadow support without snapping Y.

Keeps the original near/far quadrature predicate, transport, BRDF and all light
outputs. Only the conservative blocker mask is narrowed below the bed, using
the receiver-to-sphere-top height. This is a research hypothesis, not production.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np


def once(text, old, new):
    assert text.count(old) == 1, (old[:80], text.count(old))
    return text.replace(old, new)


def prepare(reference, out, mode='safe'):
    source = reference.read_text()
    start = source.index('inline Result referenceAt(')
    end = source.index('inline float groupBRDF(', start)
    original = source[start:end]
    a = original.index('uint shadowMask=0u;')
    b = original.index('for(int panel=0;', a)
    mask = original[a:b]
    helper = ''
    if mode == 'exploratory':
        # Retained only to reproduce the independently falsified first attempt.
        old = 'float bound=0.028575+top/max(0.01,2.2-top)'
        new = 'float bound=0.028575+(top+max(0.0,0.8-p.y))/max(0.01,2.2-top)'
        assert mask.count(old) == 16
        assert mask.count('p.y<0.8 || ') == 16
        mask = mask.replace(old, new).replace('p.y<0.8 || ', '')
    elif mode != 'near-only':
        helper = Path(__file__).with_name('support_height_safe.metal').read_text()
        for i in range(16):
            old = f'if(p.y<0.8 || top>=2.2 || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<{i});'
            new = f'if((p.y<0.8 && height_safe_below_mask(p,balls[{i}])) || top>=2.2 || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<{i});'
            mask = once(mask, old, new)
    if mode in ['safe-near-first', 'safe-hoisted', 'near-only']:
        # The direct shader only consumes the mask when shadowPossible is true.
        # Keep original near selection, skip all unused far-region mask work.
        if mode in ['safe-near-first', 'safe-hoisted']:
            for i in range(16):
                old = f'if((p.y<0.8 && height_safe_below_mask(p,balls[{i}])) || top>=2.2 || dot(offset,offset)<=bound*bound)'
                new = f'if(top>=2.2 || dot(offset,offset)<=bound*bound || (p.y<0.8 && height_safe_below_mask(p,balls[{i}])))'
                mask = once(mask, old, new)
        mask = once(mask, 'uint shadowMask=0u;', 'uint shadowMask=0u;\nif(shadowPossible) {')+'\n}\n'
    if mode == 'safe-hoisted':
        # Hoist only the receiver-domain predicate; keep all floating-point
        # center/gap/support arithmetic in its original evaluation order.
        a_helper = helper.index('    if (p.y >= 0.8)')
        b_helper = helper.index('    // Upper bounds', a_helper)
        helper = helper[:a_helper]+'''    if (!(abs(ball.x) <= 2.5399999618530273 && abs(ball.y) <= 1.2699999809265137)) return true;
'''+helper[b_helper:]
        helper = once(helper, 'bool height_safe_below_mask(', 'bool height_safe_ball_mask(')
        mask = once(mask, 'if(shadowPossible) {', '''if(shadowPossible) {
bool belowBed=p.y<0.8;
bool receiverCanPrune=belowBed && (as_type<uint>(p.y)&0x80000000u)==0u && p.y>=0.0
    && abs(p.x)<=2.5399999618530273 && abs(p.z)<=1.2699999809265137;''')
        for i in range(16):
            mask = once(mask, f'(p.y<0.8 && height_safe_below_mask(p,balls[{i}]))',
                        f'(belowBed && (!receiverCanPrune || height_safe_ball_mask(p,balls[{i}])))')
    candidate = original[:a]+mask+original[b:]
    candidate = once(candidate, 'referenceAt(', 'heightSupportAt(')
    metal = source+helper+candidate+'''
kernel void evaluateHeightSupport(device const Input *inputs [[buffer(0)]],
                                 constant float4 *balls [[buffer(1)]],
                                 device Result *results [[buffer(2)]],
                                 constant uint &count [[buffer(3)]],
                                 uint index [[thread_position_in_grid]]) {
    if(index<count) results[index]=heightSupportAt(inputs[index],balls);
}
'''
    (out/'height-support.metal').write_text(metal)
    (out/'source-manifest.json').write_text(json.dumps({
        'referenceSHA256': hashlib.sha256(source.encode()).hexdigest(),
        'candidateSHA256': hashlib.sha256(metal.encode()).hexdigest(),
        'mode': mode,
        'transforms': ['Original referenceAt unchanged',
                       'Original near/far predicate and subsequent transport/BRDF/emission unchanged',
                       'Below-bed mask narrowed by declared support predicate' if mode != 'near-only' else 'No blocker pruning',
                       'Unused far-region diagnostic mask is zero; near old-domain mask preserved' if mode in ['safe-near-first', 'safe-hoisted', 'near-only'] else 'Far diagnostic mask retained',
                       'Receiver-domain predicate hoisted without reassociating bound arithmetic' if mode == 'safe-hoisted' else 'No receiver predicate hoist'],
        'scope': __doc__}, indent=2)+'\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--reference', type=Path, required=True)
    ap.add_argument('--visual', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--mode', choices=['safe', 'safe-near-first', 'safe-hoisted', 'near-only', 'exploratory'], default='safe')
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    prepare(args.reference, args.out, args.mode)
    (args.out/'source').mkdir()
    for name in ['support_height_run.py', 'support_height_evaluate.swift', 'support_height_safe.metal']:
        (args.out/'source'/name).write_bytes(Path(__file__).with_name(name).read_bytes())
    swift = Path(__file__).with_name('support_height_evaluate.swift')
    binary = args.out/'evaluate'
    build = subprocess.run(['xcrun', 'swiftc', '-O', str(swift), '-o', str(binary)], capture_output=True, text=True)
    (args.out/'build.log').write_text(build.stdout+build.stderr)
    if build.returncode:
        raise RuntimeError(build.stderr)
    fixtures = json.loads((args.visual/'pixel-fixtures.json').read_text())['records']
    rows = []
    for fixture in fixtures:
        name = fixture['id']
        case = args.out/name
        case.mkdir()
        actual = np.load(args.visual/f'{name}-actual-inputs.npy')
        samples = np.zeros((len(actual), 12), dtype='<f4')
        samples[:, :3], samples[:, 4:7], samples[:, 8:11], samples[:, 11] = actual[:, :3], actual[:, 3:6], actual[:, 6:9], actual[:, 9]
        balls = np.array(fixture['packedBalls'], dtype='<f4')
        samples.tofile(case/'samples.bin')
        balls.tofile(case/'balls.bin')
        proc = subprocess.run([str(binary), str(args.out/'height-support.metal'), str(case/'samples.bin'),
                               str(case/'balls.bin'), str(case/'gpu'), '8'], capture_output=True, text=True)
        (case/'run.log').write_text(proc.stdout+proc.stderr)
        if proc.returncode:
            raise RuntimeError(proc.stdout+proc.stderr)
        row = json.loads((case/'gpu/result.json').read_text())
        row['pose'] = name
        rows.append(row)
        print(name, row['samples'], row['validation'], row['pairedChangeMedianPercent'], flush=True)
        (args.out/'results.json').write_text(json.dumps({'scope': __doc__, 'rows': rows}, indent=2)+'\n')


if __name__ == '__main__':
    main()
