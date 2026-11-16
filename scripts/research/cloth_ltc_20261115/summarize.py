"""Compact quality and all-cycle timing summaries, with evidence hashes."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics


def main():
    p=argparse.ArgumentParser();p.add_argument('results',type=Path);p.add_argument('--out',type=Path);a=p.parse_args()
    data=json.loads(a.results.read_text());summary=[]
    for row in data:
        cases=row['comparisons'];result={k:row[k] for k in ['pose','variant','width','height','lutAllocatedBytes']}
        result.update(pairs=len(cases),maximum=max(c['delta']['maximumChannelDifference'] for c in cases),
                      aaMaximum=max(c['aa']['maximumChannelDifference'] for c in cases),restoreMaximum=max(c['restore']['maximumChannelDifference'] for c in cases),
                      failures=[{'frame':c['frame'],'shadows':c['shadows'],'maximum':c['delta']['maximumChannelDifference']} for c in cases if c['delta']['maximumChannelDifference']>1])
        result['timing']={}
        for kind in sorted(set(t['kind'] for t in row['times'])):
            cycles=[]
            for cycle in sorted(set(t['cycle'] for t in row['times'] if t['kind']==kind)):
                arms={arm:[v for t in row['times'] if t['kind']==kind and t['cycle']==cycle and t['arm']==arm for v in t['gpuMS']] for arm in ['A','B']}
                av,bv=statistics.median(arms['A']),statistics.median(arms['B'])
                cycles.append({'cycle':cycle,'aMS':av,'bMS':bv,'gpuDecreasePercent':(av-bv)/av*100})
            values=[c['gpuDecreasePercent'] for c in cycles]
            result['timing'][kind]={'cycles':cycles,'medianDecreasePercent':statistics.median(values),'min':min(values),'max':max(values),'positiveCycles':sum(v>0 for v in values)}
        summary.append(result)
    report={'evidence':str(a.results),'sha256':hashlib.sha256(a.results.read_bytes()).hexdigest(),'rows':summary}
    text=json.dumps(report,indent=2)+'\n'
    if a.out:a.out.write_text(text)
    else:print(text)


if __name__=='__main__':main()
