"""Read native R7 attachments; all timing groups and image bins are retained."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--evidence', type=Path, required=True)
args = parser.parse_args()
args.evidence.mkdir(parents=True, exist_ok=True)
attachments = args.source / 'attachments'
manifest = json.loads((attachments / 'manifest.json').read_text())
files = {a['suggestedHumanReadableName'].split('_0_')[0]: attachments / a['exportedFileName'] for row in manifest for a in row['attachments']}
summary = {'source': str(args.source), 'reports': {}, 'timing': {}, 'images': {}, 'scope': 'Native Mac scene; not presented FPS or phone energy'}
for key in ['h18-r7a', 'h18-r7b']:
    if key not in files:
        continue
    p = files[key]; report = json.loads(p.read_text())
    summary['reports'][key] = {'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'completed': report['completed']}
    if key == 'h18-r7a':
        summary['resources'] = {name: report[name] for name in ['lookupBytes', 'preparationMS', 'sourceSHA']}
        for row in report['rows']:
            result = {'reference': row.get('reference', 'C1/H9'), 'maximum': row['maximum'], 'changedPixels': row['changedPixels'], 'metrics': {}}
            for metric in ['gpuSpanMS', 'cpuEncodeMS']:
                result['metrics'][metric] = {}
                for kind in ['AA', 'AB']:
                    groups = []
                    for cycle in range(6):
                        arms = {arm: [f[metric] for t in row['times'] if t['kind'] == kind and t['cycle'] == cycle and t['arm'] == arm for f in t['frames']] for arm in ['A', 'B']}
                        assert all(len(values) == 64 for values in arms.values())
                        av, bv = statistics.median(arms['A']), statistics.median(arms['B'])
                        groups.append({'cycle': cycle, 'aMS': av, 'bMS': bv, 'decreasePercent': (av-bv)/av*100})
                    result['metrics'][metric][kind] = {'groups': groups, 'medianDecreasePercent': statistics.median(g['decreasePercent'] for g in groups), 'positiveGroups': sum(g['decreasePercent'] > 0 for g in groups)}
            summary['timing'][row['pose']] = result
    else:
        summary['quality'] = report['rows']

def paired(name):
    a = Image.open(files[name+'-A']).convert('RGB'); b = Image.open(files[name+'-B']).convert('RGB')
    assert a.size == b.size
    w,h = a.size
    result = Image.new('RGB', (w*2,h+28), (22,22,22));result.paste(a,(0,28));result.paste(b,(w,28))
    draw = ImageDraw.Draw(result);draw.text((8,8),'A: C1/H9 reference',fill='white');draw.text((w+8,8),'B: shared LTC',fill='white')
    return result

for name in ['h18-r7a-near', 'h18-r7a-low-fallback', 'h18-r7b-camel-charcoal']:
    if name+'-A' in files:
        p = args.evidence / (name+'.png');paired(name).save(p);summary['images'][name]=str(p)
for segment in range(5):
    names = [f'h18-r7b-motion-{frame}' for frame in range(segment*24,(segment+1)*24)]
    if all(name+'-A' in files for name in names):
        frames = [paired(name) for name in names]
        p = args.evidence/f'boundary-{segment}.webp'
        frames[0].save(p,save_all=True,append_images=frames[1:],duration=80,loop=0,lossless=True,method=4)
        summary['images'][f'boundary-{segment}']=str(p)
(args.evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for pose,row in summary['timing'].items():
    print(pose, 'max',row['maximum'], {kind: round(row['metrics']['gpuSpanMS'][kind]['medianDecreasePercent'],3) for kind in ['AA','AB']})
print(args.evidence/'summary.json')
