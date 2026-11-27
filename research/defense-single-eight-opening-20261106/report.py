"""Audit the six-pocket decisions, report by representative, draw cutoff and rail examples."""
import collections
import csv
import gzip
import json
import math
import sqlite3
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / (Path(__file__).resolve().parent.name + "-10cm")
sys.path.insert(0,str(ROOT / "research/defense-opening-choice-20261106"))
from report import classify
sys.path.insert(0,str(ROOT / "research/defense-threshold-comparison-20261105"))
import geometric_table as g

OPENING_THRESHOLD = 75
thresholds = (60,65,70,75,80)
rails = json.loads((ROOT/"output/defense-region-adaptive-20261105/geometry.json").read_bytes())["rails"]


def rail_info(point, aim):
    p=np.array(point)
    choices=[]
    for a,b in rails:
        v=np.subtract(b,a)
        t=np.clip((p-a)@v/(v@v),0,1)
        gap=np.linalg.norm(p-a-t*v)-g.R
        choices.append((gap,v))
    gap,axis=min(choices,key=lambda x:x[0])
    if aim is None:
        return float(gap),None
    v=np.asarray(aim)-p
    angle=math.degrees(math.acos(np.clip(abs(v@axis)/(np.linalg.norm(v)*np.linalg.norm(axis)),0,1)))
    return float(gap),angle


def panel(ax,r,title):
    g.table(ax)
    cue,ball=np.array(r['points'])
    aim=np.array(r['aim']); direction=(aim-ball)/np.linalg.norm(aim-ball); ghost=ball-2*g.R*direction
    ax.plot([cue[0],ghost[0]],[cue[1],ghost[1]],color='white',lw=1.3,zorder=6)
    ax.plot([ball[0],aim[0]],[ball[1],aim[1]],color='#ffce56',ls='--',lw=1.5,zorder=6)
    g.ball(ax,cue,0);g.ball(ax,ball,8)
    ax.set_title(f"{title}    {r['difficulty']:.2f} 分",loc="left",fontsize=13,color="#193e34")
    ax.text(0,-.02,f"切角 {r['cut']:.1f}°    进球容错角 {r['width']:.3f}°    舒适分 {r['comfort']:.1f}",transform=ax.transAxes,va="top",fontsize=10)
    ax.text(0,-.14,f"母球至 8 号 {math.dist(cue,ball):.2f} m    8 号距库 {r['gap']*100:.1f} cm",transform=ax.transAxes,va="top",fontsize=10)


def sheet(pairs,title,filename):
    fig,axes=plt.subplots(len(pairs),2,figsize=(11,4.05*len(pairs)+.75),squeeze=False)
    fig.patch.set_facecolor("#f5f5ef")
    for row,axesrow in zip(pairs,axes):
        for (caption,r),ax in zip(row,axesrow):panel(ax,r,caption)
    fig.suptitle(title,fontsize=17)
    fig.subplots_adjust(top=1-.75/fig.get_figheight(),bottom=.68/fig.get_figheight(),left=.035,right=.98,hspace=.60,wspace=.09)
    fig.savefig(OUT/filename,dpi=145,facecolor=fig.get_facecolor());plt.close(fig)


def main():
    db=sqlite3.connect(f"file:{OUT}/inputs.sqlite3?mode=ro",uri=True)
    inputs=iter(db.execute('SELECT id,points,sourceID,originalPocket,assigned FROM geom ORDER BY id'))
    grouping=json.loads((OUT/'grouping.json').read_text())
    results=[];categories=collections.Counter(); alternatives=0
    fields=['sourceID','assigned','category','difficulty','pocket','originalPocket','cut','width','comfort','gap','railAngle','unresolvedMask','cueX','cueZ','eightX','eightZ']
    with (OUT/'all-openings.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
        for path in sorted(OUT.glob('pockets-*.jsonl.gz')):
            with gzip.open(path) as stream:
                for line in stream:
                    item=json.loads(line);i,pts,src,original,n=next(inputs);assert i==item['id']
                    points=json.loads(pts)
                    tag,score,pocket,width,comfort,cut,mask=classify(item,points)
                    if tag in ('hard', 'middle'):
                        tag = 'hard' if score >= OPENING_THRESHOLD else 'middle'
                    aim=item['pockets'][pocket]['bestKnown']['aim'] if pocket is not None else None
                    original_route=item["pockets"][original].get("bestKnown")
                    if tag=="attack" and pocket!=original and original_route is not None:
                        width0=original_route["rightDegrees"]-original_route["leftDegrees"]
                        cut0=math.radians(original_route["cutDegrees"])
                        difficulty0=100*math.sqrt((1-original_route["comfort"]/100)/(1+5*width0*math.cos(cut0)**2))
                        if difficulty0>=70:
                            alternatives+=1
                    gap,railAngle=rail_info(points[1],aim)
                    r=dict(sourceID=src,assigned=n,category=tag,difficulty=score,pocket=pocket,originalPocket=original,cut=cut,width=width,comfort=comfort,gap=gap,railAngle=railAngle,unresolvedMask=mask,cueX=points[0][0],cueZ=points[0][1],eightX=points[1][0],eightZ=points[1][1])
                    writer.writerow(r);r.update(aim=aim,points=points);results.append(r);categories[tag]+=1
    assert next(inputs,None) is None and len(results)==grouping['representatives']
    assert sum(r['assigned'] for r in results)==grouping['inputs'] and categories['escape']==0
    candidates = [r for r in results if r['category'] in ('hard', 'closed')]
    with (OUT/'candidates.csv').open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(candidates)
    confirmed=[r for r in results if r['category'] in ('hard','middle')]
    ladder=[dict(threshold=t,hard=sum(r['difficulty']>=t for r in confirmed),closed=categories['closed']) for t in thresholds]
    for row in ladder:row['kept']=row['hard']+row['closed']
    with (OUT/'thresholds.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(ladder[0]));w.writeheader();w.writerows(ladder)
    pairs=[];ids={}
    for t in thresholds:
        pair=[]
        for above,offset in [(False,-.5),(True,.5)]:
            eligible=[r for r in confirmed if (r['difficulty']>=t)==above]
            if not eligible:continue
            r=min(eligible,key=lambda r:abs(r['difficulty']-(t+offset)))
            pair.append((f"{t} 分线 · "+("线上" if above else "线下"),r))
        if len(pair)==2:
            pairs.append(pair);ids[t]=[r['sourceID'] for _,r in pair]
            if t == OPENING_THRESHOLD:
                sheet([pair],f"单黑八  ·  {t} 分线两侧的起杆球形",f"threshold-{t}.png")
    if pairs:sheet(pairs,"单黑八起杆难度  ·  每个门槛两侧的实际球形","threshold-examples.png")
    near=[r for r in results if r['category'] in ('attack','middle','hard') and .01<r['gap']<=2*g.R and r['railAngle']<=15]
    for r in near: assert r['difficulty'] is not None
    semi=[r for r in results if .01<r['gap']<=2*g.R]
    if semi and not near:
        easy=[r for r in semi if r['category']=='attack']
        uncertain=[r for r in semi if r['category']=='review' and r['aim'] is not None]
        if easy and uncertain:
            a=min(easy,key=lambda r:r['railAngle'])
            b=min(uncertain,key=lambda r:r['railAngle'])
            sheet([[('有明确进攻机会',a),('待复核 · 已知袋口',b)]],"半贴库起杆对照  ·  右图分数只对应已知路线","near-rail.png")
    if len(near)>=2:
        a=min(near,key=lambda r:r['difficulty']);b=max(near,key=lambda r:r['difficulty'])
        sheet([[('顺库样本中最低',a),('顺库样本中最高',b)]],"半贴库顺库球  ·  已确认直进路线","near-rail.png")
    summary=dict(openingThreshold=OPENING_THRESHOLD,candidateCount=len(candidates),grouping=grouping,categories=categories,thresholds=ladder,examples=ids,sourcePocket70OtherAtMost40=alternatives,semiRailCategories=dict(collections.Counter(r['category'] for r in semi)),nearRail=dict(total=len(near),at70=sum(r['difficulty']>=70 for r in near),range=[min(r['difficulty'] for r in near),max(r['difficulty'] for r in near)] if near else []))
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':main()
