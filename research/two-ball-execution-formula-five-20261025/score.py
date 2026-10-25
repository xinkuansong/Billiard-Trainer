"""Apply the user-requested formula to the exact prior five-question snapshot."""
from pathlib import Path
import copy, hashlib, json, math
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'output/two-ball-execution-five-20261025/data.json'
OUT=ROOT/'output/two-ball-execution-formula-five-20261025'
def main():
    OUT.mkdir(exist_ok=True)
    d=copy.deepcopy(json.loads(SOURCE.read_text()))
    d['previousModel']=d.pop('model')
    d['model']={'version':'execution-formula-preview-v1','formula':'E=2.5s+0.8h+1.2d+0.8u^2+0.12N+0.06L+0.6su+0.15Ns; D=100E/(E+1)',
        'variables':'s=abs(spinX), h=max(spinY,0), d=max(-spinY,0), u=velocity/4.5, N=post-contact main cushion count, L=post-contact 2mm-keypoint polyline length in meters',
        'tieBreak':'original source recommendation order','scope':'same-question ranking; no comfort score or perturbation simulation',
        'lengthCaveat':'polyline length is approximate; 2mm spatial deviation does not imply a 2mm bound on total length'}
    d['previousPreview']={'path':str(SOURCE.relative_to(ROOT)),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()}
    for sample in d['samples']:
        rows=[]; previous={q['comboIndex']:q for q in sample['ranking']}
        for t in sample['routes']:
            s=abs(t['spinX']);h=max(t['spinY'],0);draw=max(-t['spinY'],0)
            u=t['velocity']/4.5;n=t['cueMainRailsAfterContact']
            xy=[p[1:] for p in t['trajectory2mm']['points']]
            length=sum(math.dist(a,b) for a,b in zip(xy,xy[1:]))
            components={'stroke':2.5*s+.8*h+1.2*draw,'power':.8*u*u,'route':.12*n+.06*length,'interaction':.6*s*u+.15*n*s}
            e=sum(components.values());old=previous[t['comboIndex']]
            rows.append(dict(comboIndex=t['comboIndex'],originalRank=old['originalRank'],previousRank=old['rank'],previousEffort=old['effort'],lengthMeters=length,components=components,effort=e,difficulty=100*e/(e+1)))
        rows.sort(key=lambda q:(q['effort'],q['originalRank']))
        for i,q in enumerate(rows,1):q['rank']=i;q['rankChange']=q['previousRank']-i
        sample['newRanking']=rows
        print('SAMPLE',sample['number'],sample['title'])
        for q in rows:
            t=next(t for t in sample['routes'] if t['comboIndex']==q['comboIndex'])
            print('new',q['rank'],'prev',q['previousRank'],'route',q['originalRank'],'v',round(t['velocity'],3),'xy',round(t['spinX'],3),round(t['spinY'],3),'N',t['cueMainRailsAfterContact'],'L',round(q['lengthMeters'],3),'parts',[round(v,3) for v in q['components'].values()],'E',round(q['effort'],3),'D',round(q['difficulty'],1))
    (OUT/'data.json').write_text(json.dumps(d,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
