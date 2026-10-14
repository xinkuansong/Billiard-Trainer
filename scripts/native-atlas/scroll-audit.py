#!/usr/bin/env python3
"""Flag viewport jumps using repeated native AX text anchors. Read-only evidence audit."""
import argparse, collections, json, re, statistics
from pathlib import Path

def anchors(path):
    result=collections.defaultdict(list)
    pattern=r"StaticText,.*?\{\{[-\d.]+, ([-\d.]+)\}, \{[-\d.]+, [-\d.]+\}\}.*?label: '(.+)'"
    for line in path.read_text().splitlines():
        match=re.search(pattern,line)
        if match:result[match[2]].append(float(match[1]))
    return {key:values[0] for key,values in result.items() if len(values)==1}

def audit(coverage):
    record=json.loads(coverage.read_text());pairs=[]
    for first,second in zip(record['names'],record['names'][1:]):
        x=anchors(coverage.parent/(first+'.ax.txt'));y=anchors(coverage.parent/(second+'.ax.txt'))
        shifts=[x[k]-y[k] for k in x.keys()&y.keys() if x[k]-y[k]>2]
        window=json.loads((coverage.parent/(first+'.json')).read_text())['window']
        common=collections.Counter(round(v/4)*4 for v in shifts)
        mode,count=common.most_common(1)[0] if common else (0,0)
        candidates=[v for v in shifts if abs(v-mode)<6]
        shift=statistics.median(candidates) if len(candidates)>=3 else None
        pairs.append({'first':first,'second':second,'textAnchors':len(candidates),'contentShiftPt':shift,'maxSafeShiftPt':window['height']*.6,'status':'GAP_RISK' if shift is not None and shift>window['height']*.6 else 'WITHIN_BOUND' if shift is not None else 'NEEDS_VISUAL_OVERLAP_CHECK'})
    return {'coverage':str(coverage),'reachedEnd':record.get('reachedEnd'), 'pairs':pairs,'gapRisk':any(p['status']=='GAP_RISK' for p in pairs), 'note':'AX translation bound detects excessive jumps; it does not replace visual content/end checks.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    records=[audit(c) for c in sorted(a.run.glob('*/*/*.coverage.json'))]
    a.output.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'covers':len(records),'gapRisk':sum(r['gapRisk'] for r in records)}))
