#!/usr/bin/env python3
"""Analyze paired render attribution. Requires Pillow for optional coverage masks.
GPU spans are whole command buffers, not additive pass costs or device power.
"""
import argparse
import json
from pathlib import Path
from statistics import median

ORDER = ['A','R','A','G','A','C','A','L','A','L','A','C','A','G','A','R','A']

def analyze(root):
    result = {'scope': 'fixed single-ball SceneKit/MTKView simulator; no whole-app or phone energy claim',
              'profiles': {'A': 'reference', 'R': 'prefiltered reflection only',
                           'G': 'reference plus unused field generation each frame',
                           'C': 'consume precomputed field, no measured generation; static only',
                           'L': 'field generation plus consumption each frame'}, 'modes': {}}
    for mode in [2, 3]:
        rows = []
        for i, profile in enumerate(ORDER):
            path = root / f'ab-specialized-{mode}d-{i}-{profile}.json'
            if not path.exists():
                rows.append(None)
                continue
            raw = json.loads(path.read_text())
            frames = raw['frames']
            gpu = [r['gpuMS'] for r in frames if r.get('gpuMS', 0) > 0 and not r.get('error', 0)]
            errors = []
            if len(gpu) != len(frames) or len(gpu) <= 10: errors.append('invalid samples')
            if raw['thermalStart'] != 0 or raw['thermal'] != 0: errors.append('non-nominal thermal')
            if raw['sampleCount'] != 4 or raw['requestedFPS'] != 60 or raw['cameraMoves']: errors.append('workload mismatch')
            rows.append({'index': i, 'profile': profile, 'samples': len(gpu),
                         'gpuMedianMS': median(gpu) if gpu else None,
                         'cpuEncodeMedianMS': median(f['sceneEncodeMS'] for f in frames),
                         'cpuDrawMedianMS': median(f['cpuMS'] for f in frames),
                         'identity': [raw['width'], raw['height'], raw['gpuDevice']], 'errors': errors})
        pairs = []
        for i in range(1, len(ORDER), 2):
            before, candidate, after = rows[i-1:i+2]
            if any(x is None for x in [before,candidate,after]): continue
            errors = [e for r in [before,candidate,after] for e in r['errors']]
            if before['identity'] != candidate['identity'] or after['identity'] != candidate['identity']: errors.append('different device/dimensions')
            base = (before['gpuMedianMS'] + after['gpuMedianMS']) / 2
            drift = abs(before['gpuMedianMS'] - after['gpuMedianMS']) / base
            if drift > .05: errors.append('baseline drift >5%')
            pairs.append({'index': i,'profile': ORDER[i], 'valid': not errors,'errors': errors,
                          'baselineMS': base,'candidateMS':candidate['gpuMedianMS'],
                          'deltaMS':candidate['gpuMedianMS']-base,
                          'reductionPercent':(1-candidate['gpuMedianMS']/base)*100,'baselineDrift':drift})
        summary = {}
        for profile in ['R','G','C','L']:
            good = [p for p in pairs if p['profile']==profile and p['valid']]
            summary[profile] = {'validPairs':len(good),'medianReductionPercent':median([p['reductionPercent'] for p in good]) if good else None,
                                'medianDeltaMS':median([p['deltaMS'] for p in good]) if good else None}
        coverage = {}
        mask = root / f'ab-specialized-{mode}d-0-A-coverage.png'
        if mask.exists():
            from PIL import Image
            im = Image.open(mask).convert('RGB')
            red = green = 0
            for r,g,b in im.getdata():
                red += r > 64 and r > 2*g and r > 2*b
                green += g > 64 and g > 2*r and g > 2*b
            area = im.width*im.height
            coverage = {'width':im.width,'height':im.height,'ballPixels':red,'clothPixels':green,
                        'ballPercent':red/area*100,'clothPercent':green/area*100,
                        'note':'constant-color visible surface mask; excludes mixed boundary pixels; not fragment invocation count'}
        result['modes'][str(mode)] = {'segments':rows,'pairs':pairs,'summary':summary,'coverage':coverage}
    return result

if __name__ == '__main__':
    p = argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();result=analyze(args.directory)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    for mode,value in result['modes'].items(): print(mode,json.dumps({'summary':value['summary'],'coverage':value['coverage']},ensure_ascii=False))
