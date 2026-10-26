"""Independent geometry/event audit and compact observed boundary summary."""
from pathlib import Path
from collections import defaultdict, Counter
import hashlib,json,math
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/middle-pocket-angle-20261026/mouth-plane'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def close(a,b,tol=2e-7):assert abs(a-b)<=tol,(a,b)
def main():
    meta=json.loads((OUT/'metadata.json').read_text());halfW=meta['width']/2;r=meta['radius']
    groups={};mirror={};counts=Counter();shaMap={};edge=[];traces=[]
    files=sorted(OUT.glob('*.jsonl'))
    for p in files:
        shaMap[p.name]=sha(p)
        with p.open() as f:
            for line in f:
                row=json.loads(line);x=row['input'];a=x['angle'];d=x['distance'];s=x['speed'];side=x['side'];hand=x['hand'];mode=x['mode']
                expected=(hand*d*math.sin(math.radians(a)),meta['surfaceY']+r,side*(halfW-d*math.cos(math.radians(a))))
                for lhs,rhs in zip(row['start'],expected):close(lhs,rhs)
                measured=math.degrees(math.atan2(abs(row['start'][0]),halfW-side*row['start'][2]))
                close(measured,a,3e-5)
                counts['positions']+=1
                if not row['valid']:
                    counts['outside_rectangle']+=1
                    assert abs(expected[0])>meta['length']/2-r-2e-7 or abs(expected[2])>halfW-r-2e-7
                    continue
                assert abs(expected[0])<=meta['length']/2-r+2e-7 and abs(expected[2])<=halfW-r+2e-7
                counts['valid_positions']+=1
                key=(d,s,round(a,5),mode,side,hand)
                g=groups.setdefault(key,dict(distance=d,speed=s,angle=a,mode=mode,side=side,hand=hand,
                    directOffsets=set(),cleanOffsets=set(),testedOffsets=set(),center=False,velocityAngles=[]))
                for v in row['results']:
                    counts['simulations']+=1;assert v['termination']=='settled'
                    close(v['aim'][0],v['offset']);close(v['aim'][2],side*halfW)
                    delta=[v['aim'][i]-row['start'][i] for i in range(3)];norm=math.sqrt(sum(z*z for z in delta))
                    for i in range(3):close(v['direction'][i],delta[i]/norm)
                    ev=v['events'];pockets=[e['id'] for e in ev if e['kind']=='pocket'];contacts=[e for e in ev if e['kind']!='pocket']
                    assert pockets==([] if v['pocket']=='none' else [v['pocket']])
                    clean=not any(e['kind']=='cushion' or abs(e['position'][0])>=.16 or abs(e['position'][2]-side*halfW)>=.16 for e in contacts)
                    direct=pockets==['pocket_4' if side<0 else 'pocket_5'] and clean
                    assert direct==v['direct'];assert (direct and not contacts)==v['cleanPot']
                    counts['direct']+=direct;counts['clean_pot']+=v['cleanPot']
                    o=round(v['offset']*1000,4);g['testedOffsets'].add(o)
                    if direct:
                        g['directOffsets'].add(o)
                        g['velocityAngles'].append(math.degrees(math.atan2(abs(v['direction'][0]),abs(v['direction'][2]))))
                        if abs(o)>=99:edge.append((key,o))
                    if v['cleanPot']:g['cleanOffsets'].add(o)
                    if o==0:g['center']=direct
                    # Normalize lateral offset by handedness for independently compared mirrors.
                    mk=(d,s,round(a,5),mode,round(o*hand,4))
                    mirror.setdefault(mk,{})[(side,hand)]=(direct,v['cleanPot'])
                    if 'frames' in v:
                        assert v['frames'] and all(v['frames'][i]['t']<=v['frames'][i+1]['t'] for i in range(len(v['frames'])-1))
                        traces.append(dict(input=x,start=row['start'],result=v))
    assert not edge,edge[:5]
    comparisons=0;mismatch=[]
    for key,values in mirror.items():
        if (-1,1) not in values:continue
        for orientation,v in values.items():
            if orientation==(-1,1):continue
            comparisons+=1
            if v!=values[(-1,1)]:mismatch.append(dict(key=key,orientation=orientation,reference=values[(-1,1)],mirror=v))
    summary=[]
    for d,s,mode in sorted({(g['distance'],g['speed'],g['mode']) for g in groups.values()}):
        q=[g for g in groups.values() if (g['distance'],g['speed'],g['mode'],g['side'],g['hand'])==(d,s,mode,-1,1)]
        row=dict(distance=d,speed=s,mode=mode)
        for metric in ['directOffsets','cleanOffsets','center']:
            good=[g for g in q if g[metric]]
            row[metric]=max((g['angle'] for g in good),default=None)
        summary.append(row)
    for g in groups.values():
        for k in ['directOffsets','cleanOffsets','testedOffsets']:g[k]=sorted(g[k])
    binding=json.loads((OUT/'source-binding.json').read_text())
    assert all(sha(ROOT/p['path'])==p['sha256'] for p in binding['production'])
    generation=json.loads((OUT/'generation.json').read_text());assert generation['complete'] and generation['simulations']==counts['simulations']
    assert json.loads((OUT/'replays.json').read_text())['passed']
    result=dict(passed=True,counts=dict(counts),mirrorComparisons=comparisons,mirrorMismatches=mismatch,
        successfulOffsetEdges=edge,sourceBindings=len(binding['production']),rawSHA256=shaMap,boundaries=summary)
    (OUT/'verification.json').write_text(json.dumps(result,indent=2))
    (OUT/'groups.json').write_text(json.dumps(list(groups.values()),separators=(',',':')))
    (OUT/'traces.json').write_text(json.dumps(traces,separators=(',',':')))
    print(json.dumps(result|{'rawSHA256':'see verification.json'},indent=2))
if __name__=='__main__':main()
