"""Compare completed deep results against the same 697 quick-search inputs."""
import collections
import gzip
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
QUICK=HERE.parents[1]/'output'/HERE.name
DEEP=QUICK/'deep'

def load(path):
    return json.loads(gzip.decompress(path.read_bytes()))

def count_evidence(routes):
    totals=collections.Counter()
    for r in routes:
        flags=[]
        for a in [r,*r['probes']]:
            e=a['effect']
            flags.append(bool(e.get('estimateReason') or (e.get('pipeRoute') or {}).get('zeroWidthEstimate')))
        totals['nominalConfirmed']+=int(not flags[0])
        totals['fiveConfirmed']+=int(not any(flags))
    return totals

def main():
    status=json.loads((DEEP/'status.json').read_bytes())
    assert status['total']==status['processed']==697
    groups=collections.Counter()
    counts=collections.Counter()
    confirmed_duals=[]
    for f in sorted((DEEP/'records').glob('*.json.gz')):
        before=load(QUICK/'records'/f.name)
        after=load(f)
        assert before['question']==after['question']
        n,m=len(before['routes']),len(after['routes'])
        assert m>=n
        groups[f'{n}to{m}']+=1
        if m==2:
            evidence=count_evidence(after['routes'])
            counts.update(evidence)
            counts['routes']+=m
            counts['questions']+=1
            counts['bothFiveConfirmed']+=int(evidence['fiveConfirmed']==2)
            if evidence['fiveConfirmed']==2:
                question=after['question']
                confirmed_duals.append(dict(id=question['id'],sourceID=question['sourceFormationID'],record='records/'+f.name))
            counts['atLeastOneFiveConfirmed']+=int(evidence['fiveConfirmed']>=1)
    assert sum(groups.values())==697 and counts['routes']==status['admittedRoutes']
    (DEEP/'confirmed-duals.json').write_text(json.dumps(confirmed_duals,indent=2))
    summary=dict(transitions=groups,admitted=counts)
    (DEEP/'comparison.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary))
if __name__=='__main__':main()
