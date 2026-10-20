#!/usr/bin/env python3
"""Independent spatial-duplicate and declared proof-grid audit; not a physics solver."""
import argparse
import collections
import itertools
import json
import math
from pathlib import Path

POCKET_REFLECTIONS = {
    (1, 1): [0, 1, 2, 3, 4, 5],
    (-1, 1): [1, 0, 3, 2, 4, 5],
    (1, -1): [2, 3, 0, 1, 5, 4],
    (-1, -1): [3, 2, 1, 0, 5, 4],
}


def audit(bank, separation=0.03):
    spatial = collections.defaultdict(list)
    neighbours = list(itertools.product((-1, 0, 1), repeat=4))
    duplicates = []
    for b in bank['boards']:
        p = (b['cue']['x'], b['cue']['z'], b['target']['x'], b['target']['z'])
        for (sx, sz), pockets in POCKET_REFLECTIONS.items():
            q = (p[0]*sx, p[1]*sz, p[2]*sx, p[3]*sz)
            cell = tuple(math.floor(v/separation) for v in q)
            for delta in neighbours:
                key = (pockets[b['pocketIndex']], *(a+d for a,d in zip(cell,delta)))
                for other_id, other in spatial.get(key, []):
                    if max(math.hypot(q[0]-other[0],q[1]-other[1]), math.hypot(q[2]-other[2],q[3]-other[3])) < separation:
                        duplicates.append({'a':other_id,'b':b['id'],'mirror':[sx,sz]})
        cell = tuple(math.floor(v/separation) for v in p)
        spatial[(b['pocketIndex'],*cell)].append((b['id'],p))
    proofs = {p['id']:p for p in bank['proofs']}
    bad = []
    for v in bank['variants']:
        p = proofs[v['proofID']]
        grid={(round(s['angleDeltaDegrees'],5),round(s['velocityDelta'],5)) for s in p['samples']}
        expected=set(itertools.product((-.025,0,.025),(-.05,0,.05)))
        if not (p['boardID']==v['boardID'] and p['tip']==v['tip'] and p['settled'] and p['specifiedPocket']
                and p['outcome']=='success' and len(p['samples'])==9 and grid==expected
                and all(s['outcome']=='success' for s in p['samples'])):
            bad.append(v['proofID'])
    return {'boards':len(bank['boards']), 'accuracyBoards':len({v['boardID'] for v in bank['variants']}),
            'variants':len(bank['variants']), 'spatialSeparationMetres':separation,
            'reflectionAwareNearDuplicates':duplicates,'invalidDeclaredGrids':bad,
            'tipCounts':dict(collections.Counter(v['tip'] for v in bank['variants'])),
            'note':'Independent geometry/serialized evidence audit. Actual physics evidence is the Swift production run.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bank',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    result=audit(json.loads(args.bank.read_text()))
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k not in ('tipCounts','note')},ensure_ascii=False))
    if result['reflectionAwareNearDuplicates'] or result['invalidDeclaredGrids']:
        raise SystemExit(1)

if __name__=='__main__': main()
