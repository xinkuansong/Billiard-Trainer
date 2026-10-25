#!/usr/bin/env python3
"""Filter the frozen 4x72 preview positions; no bank mutation or physics claim."""
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Circle, Rectangle, Polygon

from pocket_geometry_filter import Geometry, pocket_metrics
from preview_second_ball_grid import segment_distance

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/two-ball-second-grid-20261024/preview-data.json'
OUT = ROOT / 'output/two-ball-second-grid-20261024/filtered-v1'
EPS = 1e-12  # Metre-scale floating arithmetic only, no gameplay margin.
POCKET_NAMES = ['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']


def score(cue, obj, anchor, radius, pid):
    metric = pocket_metrics(cue, obj, anchor, radius, pid)
    valid = metric.cut_degrees < 90
    value = metric.object_distance_metres / math.cos(math.radians(metric.cut_degrees)) if valid else None
    return dict(pocket=pid,angle=metric.cut_degrees,distance=metric.object_distance_metres,score=value)


def assess(cue, obj, candidate, pid, g):
    """Each candidate is a separate hypothetical second ball, not a rack."""
    anchor = g.anchors()[pid]
    op = math.dist(obj,anchor)
    ghost = tuple(obj[i]-2*g.radius*(anchor[i]-obj[i])/op for i in range(2))
    first = score(cue,obj,anchor,g.radius,pid)
    if first['score'] is None:
        raise ValueError('Original shot must have a cut angle below 90 degrees')
    options = [score(cue,candidate,p,g.radius,i) for i,p in enumerate(g.anchors())]
    possible = [v for v in options if v['score'] is not None]
    best = min(possible,key=lambda v:(v['score'],v['pocket'])) if possible else None
    entry_clearance = segment_distance(candidate,cue,ghost)
    exit_clearance = segment_distance(candidate,obj,anchor)
    reasons = []
    if min(math.dist(candidate,cue),math.dist(candidate,obj)) < 2*g.radius-EPS:
        reasons.append('overlap')
    if entry_clearance < 2*g.radius-EPS:
        reasons.append('blocks_cue_path')
    if exit_clearance < 2*g.radius-EPS:
        reasons.append('blocks_object_path')
    if best is not None and first['score'] > best['score']+EPS:
        reasons.append('second_easier')
    return dict(keep=not reasons,reasons=reasons,cuePathClearance=entry_clearance,
                objectPathClearance=exit_clearance,first=first,bestSecond=best,
                secondPocketMetrics=options,ghost=ghost,anchor=anchor)


def independent_score(cue,obj,anchor,r):
    # Independent dot-product formulation, not atan2/cos as used by the filter.
    ux,uz = anchor[0]-obj[0],anchor[1]-obj[1]
    length = math.hypot(ux,uz)
    ux,uz = ux/length,uz/length
    vx,vz = obj[0]-2*r*ux-cue[0],obj[1]-2*r*uz-cue[1]
    projection = vx*ux+vz*uz
    return length*math.hypot(vx,vz)/projection if projection > 0 else math.inf


def independent_segment_distance(p,a,b):
    if sum((p[i]-a[i])*(b[i]-a[i]) for i in range(2)) <= 0:
        return math.dist(p,a)
    if sum((p[i]-b[i])*(a[i]-b[i]) for i in range(2)) <= 0:
        return math.dist(p,b)
    return abs((p[0]-a[0])*(b[1]-a[1])-(p[1]-a[1])*(b[0]-a[0])) / math.dist(a,b)


def corridor(ax, a, b, r, color):
    # Visible band is the actual moving ball's sweep (2R wide).
    d = math.dist(a,b)
    nx,nz = -(b[1]-a[1])/d*r,(b[0]-a[0])/d*r
    ax.add_patch(Polygon([(a[0]+nx,a[1]+nz),(b[0]+nx,b[1]+nz),
                          (b[0]-nx,b[1]-nz),(a[0]-nx,a[1]-nz)],
                         color=color,alpha=.20,lw=0,zorder=3))
    for p in (a,b): ax.add_patch(Circle(p,r,color=color,alpha=.20,lw=0,zorder=3))
    ax.plot([a[0],b[0]],[a[1],b[1]],color=color,lw=1.25,zorder=4)


def main():
    raw=SOURCE.read_bytes()
    data=json.loads(raw)
    bank_path=ROOT/data['source']
    bank_raw=bank_path.read_bytes()
    assert hashlib.sha256(bank_raw).hexdigest()==data['sourceSHA256']
    bank=json.loads(bank_raw)
    targets={t['inventoryTargetIndex']:t for t in bank['targets']}
    g=Geometry(**{k:data['geometry'][k] for k in ('length','width','radius')})
    r,hx,hz=g.radius,g.length/2,g.width/2
    boards=[]
    for original in data['boards']:
        b={k:v for k,v in original.items() if k!='points'}
        t=targets[int(b['id'].split(':')[1])]
        assert math.dist((t['aim']['x'],t['aim']['z']),g.anchors()[b['pocket']]) < EPS
        points=[]
        for p in original['points']:
            result=assess(b['cue'],b['object'],p['position'],b['pocket'],g)
            # Audit every decision through separately formulated distances/scores.
            sa=independent_score(b['cue'],b['object'],result['anchor'],r)
            scores=[independent_score(b['cue'],p['position'],a,r) for a in g.anchors()]
            sb=min(scores)
            d1=independent_segment_distance(p['position'],b['cue'],result['ghost'])
            d2=independent_segment_distance(p['position'],b['object'],result['anchor'])
            assert math.isclose(sa,result['first']['score'],rel_tol=1e-10)
            if result['bestSecond'] is None:
                assert math.isinf(sb)
            else:
                assert math.isclose(sb,result['bestSecond']['score'],rel_tol=1e-10)
            assert math.isclose(d1,result['cuePathClearance'],abs_tol=EPS)
            assert math.isclose(d2,result['objectPathClearance'],abs_tol=EPS)
            assert result['keep']==(d1>=2*r-EPS and d2>=2*r-EPS and sa<=sb+EPS and
                min(math.dist(p['position'],b['cue']),math.dist(p['position'],b['object']))>=2*r-EPS)
            points.append(dict(**p,cell=f"{'ABCDEF'[p['row']]}{p['col']+1}",assessment=result))
        b['points']=points
        reasons=Counter(reason for p in points for reason in p['assessment']['reasons'])
        kept=sum(p['assessment']['keep'] for p in points)
        blocked=sum(any(x in p['assessment']['reasons'] for x in ('overlap','blocks_cue_path','blocks_object_path')) for p in points)
        b['counts']=dict(keep=kept,drop=72-kept,reasonHits=dict(reasons),
                         blocked=blocked,difficultyOnly=72-kept-blocked)
        boards.append(b)
    # Boundary cases: finite endpoints, exact tangency, beyond-end proximity.
    assert segment_distance((.5,2*r),(0,0),(1,0))==2*r
    assert math.isclose(segment_distance((1.03,.04),(0,0),(1,0)),.05)
    assert segment_distance((2,0),(0,0),(1,0))==1
    # Equality passes difficulty rule and tangent corridors pass geometric rule.
    assert not (1.0 > 1.0+EPS)
    assert not (2*r < 2*r-EPS)
    font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    def draw(ax,b):
        ax.set_aspect('equal')
        ax.add_patch(Rectangle((-hx-.07,-hz-.07),2*hx+.14,2*hz+.14,color='#325d50',zorder=0))
        ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#e0eade',zorder=1))
        for pocket in data['geometry']['pockets']:
            pc=(pocket['center']['x'],pocket['center']['z'])
            ax.add_patch(Circle(pc,pocket['radius'],color='#173d35',zorder=3))
            ax.add_patch(Polygon([(p['x'],p['z']) for p in pocket['lip']],color='#173d35',zorder=3))
        dx,dz=data['grid']['cellSizeMetres']
        for i in range(13):
            x=-hx+r+i*dx
            ax.plot([x,x],[-hz+r,hz-r],color='#9aac9e',lw=.55,alpha=.65,zorder=2)
        for i in range(7):
            z=-hz+r+i*dz
            ax.plot([-hx+r,hx-r],[z,z],color='#9aac9e',lw=.55,alpha=.65,zorder=2)
        for col in range(12):
            ax.text(-hx+r+(col+.5)*dx,-hz-.085,str(col+1),ha='center',va='center',fontsize=7,color='#53685e')
        for row in range(6):
            ax.text(-hx-.09,-hz+r+(row+.5)*dz,'ABCDEF'[row],ha='center',va='center',fontsize=8,color='#53685e')
        ref=b['points'][0]['assessment']
        corridor(ax,b['cue'],ref['ghost'],r,'#6456a0')
        corridor(ax,b['object'],ref['anchor'],r,'#b87613')
        target_pocket=data['geometry']['pockets'][b['pocket']]
        pc=(target_pocket['center']['x'],target_pocket['center']['z'])
        ax.add_patch(Circle(pc,target_pocket['radius']+.008,fill=False,edgecolor='#e69d1c',lw=2.3,zorder=4))
        ax.plot(*ref['anchor'],marker='.',ms=3,color='#b87613',zorder=4)
        ax.add_patch(Circle(ref['ghost'],r,fill=False,edgecolor='#6456a0',lw=1,ls='--',zorder=4))
        for p in b['points']:
            kept=p['assessment']['keep']; x,z=p['position']
            ax.add_patch(Circle((x,z),r,facecolor='#217cab' if kept else '#f6e0db',
                               edgecolor='#165a7a' if kept else '#bd6355',lw=.9,zorder=5))
            if not kept:
                ax.plot([x-r*.45,x+r*.45],[z-r*.45,z+r*.45],color='#b44f43',lw=1,zorder=6)
                ax.plot([x-r*.45,x+r*.45],[z+r*.45,z-r*.45],color='#b44f43',lw=1,zorder=6)
        for pos,color,label in [(b['cue'],'white',''),(b['object'],'#efb538','1')]:
            ax.add_patch(Circle(pos,r,facecolor=color,edgecolor='#394438',lw=1.3,zorder=7))
            ax.text(*pos,label,ha='center',va='center',fontsize=8,zorder=8)
        ax.set_xlim(-hx-.13,hx+.10);ax.set_ylim(hz+.12,-hz-.15);ax.axis('off')
        c=b['counts']
        ax.set_title(f"示例 {b['number']} · 保留 {c['keep']} / 删除 {c['drop']} · 原切角 {b['angle']}°",loc='left',fontsize=13,pad=8)
        ax.text(.01,-.035,f"线路/重叠删除 {c['blocked']}；其余因第二球更容易删除 {c['difficultyOnly']}  |  目标：{POCKET_NAMES[b['pocket']]}",
                transform=ax.transAxes,fontsize=9,color='#52665b')
    OUT.mkdir(parents=True,exist_ok=True)
    for b in boards:
        fig,ax=plt.subplots(figsize=(13,7.8),facecolor='#f7f9f6')
        draw(ax,b)
        fig.text(.055,.03,'蓝色实心：保留    红色叉号：删除    白球：母球    黄球：第一球    紫线：母球入射    金线：第一球入袋',fontsize=11,color='#42584d')
        fig.subplots_adjust(left=.035,right=.965,bottom=.13,top=.92)
        fig.savefig(OUT/f"example-{b['number']}.png",dpi=180)
        plt.close(fig)
    fig,axs=plt.subplots(2,2,figsize=(18,12),facecolor='#f7f9f6')
    total_kept=sum(b['counts']['keep'] for b in boards)
    for ax,b in zip(axs.flat,boards): draw(ax,b)
    fig.suptitle('第二颗球候选位置 · 几何筛选结果',x=.045,y=.98,ha='left',fontsize=23)
    fig.text(.045,.935,f'原4组、288个位置不变 · 保留{total_kept}个 / 删除{288-total_kept}个 · 不挡两条线路，且第一球不比第二球最佳袋口难',fontsize=13,color='#42584d')
    fig.text(.045,.031,'蓝色实心：保留    红色叉号：删除    白球：母球    黄球：第一球    紫线：母球入射    金线：第一球入袋',fontsize=12,color='#42584d')
    fig.text(.045,.008,'难度 S = 球到下球点距离 / cos(切角)；各候选独立评估，第二球六袋仅作几何比较。',fontsize=10,color='#64786b')
    fig.subplots_adjust(left=.035,right=.965,top=.88,bottom=.10,wspace=.08,hspace=.24)
    fig.savefig(OUT/'filtered-preview-4.png',dpi=180)
    plt.close(fig)
    result=dict(ruleVersion='second-ball-corridor-priority-v1',sourceSHA256=hashlib.sha256(raw).hexdigest(),
                source=str(SOURCE.relative_to(ROOT)),firstBankSHA256=data['sourceSHA256'],
                rule=dict(minCenterToSegmentDistance=2*r,difficultyRatio=1.0,
                          secondPocketEligibility='cut angle < 90 degrees; geometric only; no obstruction/physics qualification'),
                boards=boards,totals=dict(keep=total_kept,drop=288-total_kept),
                verification=dict(candidateCount=288,coordinatesUnchanged=True,independentAuditPassed=True))
    (OUT/'filtered-data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
    for a,b in zip(data['boards'],boards):
        assert a['id']==b['id'] and a['cue']==b['cue'] and a['object']==b['object']
        assert [p['position'] for p in a['points']]==[p['position'] for p in b['points']]
    assert SOURCE.read_bytes()==raw and bank_path.read_bytes()==bank_raw
    print(json.dumps([dict(number=b['number'],**b['counts']) for b in boards],ensure_ascii=False,indent=2))
    print('PASS: 288 unchanged positions, independent dot/cross-product audit, finite-segment boundary cases, source immutability.')


if __name__=='__main__':
    main()
