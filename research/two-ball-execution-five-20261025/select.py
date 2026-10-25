"""Select five illustrative questions; only read the frozen filtered bank."""
from pathlib import Path
import gzip, hashlib, json, math

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/two-ball-middle-geometry-comfort-20261025'
OUT = ROOT / 'output/two-ball-execution-five-20261025'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def effort(t):
    return 2.5*abs(t['spinX']) + abs(t['spinY']) + .25*max(0,t['velocity']-4)

def main():
    OUT.mkdir(exist_ok=True)
    index = json.loads((SOURCE/'parts-index.json').read_text())
    buckets = [[] for _ in range(5)]
    titles = ['中杆与带旋转路线', '高杆与低杆路线', '少塞与较大侧塞', '不同杆速的取舍', '多库不直接排在后面']
    scope = []; count = 0
    for item in index[::10]:
        p=SOURCE/'final'/f'{item["stem"]}.jsonl.gz'
        assert sha(p)==item['finalSHA256']
        scope.append(dict(path=str(p.relative_to(ROOT)),sha256=item['finalSHA256']))
        for raw in gzip.decompress(p.read_bytes()).splitlines():
            x=json.loads(raw); count+=1
            routes={t['comboIndex']:t for t in x['routes']}
            for c in x['candidates']:
                if len(c['top5'])!=5: continue
                ts=[routes[q['comboIndex']] for q in c['top5']]
                ys=[t['spinY'] for t in ts]; xs=[abs(t['spinX']) for t in ts]
                vs=[t['velocity'] for t in ts]; ns=[t['cueMainRailsAfterContact'] for t in ts]
                a=x['board']['angle']
                conditions=[
                    x['board']['pocket']<4 and min(effort(t) for t in ts)<.02 and max(xs)>.15 and 5<=a<=20,
                    x['board']['pocket']<4 and any(abs(t['spinX'])<.02 and t['spinY']<-.15 for t in ts) and any(abs(t['spinX'])<.02 and t['spinY']>.15 for t in ts) and 10<=a<=30,
                    x['board']['pocket']>=4 and min(xs)<.02 and max(xs)>.30 and 20<=a<=45,
                    max(vs)>4.1 and min(vs)<2.5 and 25<=a<=55,
                    x['board']['pocket']>=4 and max(ns)>=3 and min(ns)<=1 and any(u['cueMainRailsAfterContact']>=3 and v['cueMainRailsAfterContact']<=1 and effort(u)+.08<effort(v) for u in ts for v in ts)
                ]
                targets=[10,20,30,40,15]
                for k,ok in enumerate(conditions):
                    if not ok: continue
                    # Purposeful case selection, not a random sample or frequency estimate.
                    metric=abs(a-targets[k]) + .1*max(ns)+ .001*c['cellID']
                    entry=dict(metric=metric,id=x['id'],board=x['board'],candidate=c,routes=ts,source=str(p.relative_to(ROOT)),sourceSHA256=item['finalSHA256'])
                    buckets[k].append(entry)
                    buckets[k]=sorted(buckets[k],key=lambda z:(z['metric'],z['id'],z['candidate']['cellID']))[:25]
    chosen=[]; used=set()
    for k,bucket in enumerate(buckets):
        x=next(v for v in bucket if v['id'] not in used); used.add(x['id'])
        x.update(number=k+1,title=titles[k])
        old={q['comboIndex']:i for i,q in enumerate(x['candidate']['top5'],1)}
        x['ranking']=[dict(rank=i,comboIndex=t['comboIndex'],originalRank=old[t['comboIndex']],effort=effort(t),components={'side':2.5*abs(t['spinX']),'vertical':abs(t['spinY']),'speed':.25*max(0,t['velocity']-4)}) for i,t in enumerate(sorted(x['routes'],key=lambda t:(effort(t),old[t['comboIndex']])),1)]
        chosen.append(x)
    data=dict(schema='execution-five-preview-v1',source=str(SOURCE.relative_to(ROOT)),selection=dict(method='purposeful cases from every tenth source shard; five distinct layouts, all five retained recommendations',scannedLayouts=count,scannedShards=len(scope),scope=scope),model=dict(source='QiuJi/Core/PositionPlay/DifficultyModel.swift',sha256=sha(ROOT/'QiuJi/Core/PositionPlay/DifficultyModel.swift'),formula='2.5*abs(spinX)+abs(spinY)+0.25*max(0,velocity-4)',tieBreak='original recommendation order',limitations=['not measured robustness','high and low use the same magnitude weight','no low-speed precision term','cushion count is descriptive only','no cue-clearance or environment perturbation test']),geometry=json.loads((SOURCE/'geometry.json').read_text()),samples=chosen)
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    print('scanned',count,'layouts;',len(scope),'shards')
    for s in chosen:
        print(s['number'],s['title'],s['id'],'B',s['candidate']['cellID'],'angle',s['board']['angle'],'pocket',s['board']['pocket'])
        for q in s['ranking']:
            t=next(t for t in s['routes'] if t['comboIndex']==q['comboIndex'])
            print(q['rank'],'old',q['originalRank'],'combo',q['comboIndex'],'E',round(q['effort'],3),'v',round(t['velocity'],3),'spin',round(t['spinX'],3),round(t['spinY'],3),'rails',t['cueMainRailsAfterContact'])

if __name__=='__main__': main()
