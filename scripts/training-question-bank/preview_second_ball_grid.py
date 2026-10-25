#!/usr/bin/env python3
"""Reproducible static previews of alternative second-ball positions (XZ metres)."""
import hashlib
import json
import math
from pathlib import Path
import random
import re

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Circle, Polygon, Rectangle

from pocket_geometry_filter import Geometry, layouts

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
OUT = ROOT / 'output/two-ball-second-grid-20261024'
SEED = 20261024072
JITTER = .05  # Explicit preview assumption: independent uniform +/-5 cm per axis.


def segment_distance(p, a, b):
    v = (b[0]-a[0], b[1]-a[1])
    t = max(0., min(1., sum((p[i]-a[i])*v[i] for i in range(2)) / sum(x*x for x in v)))
    return math.dist(p, (a[0]+t*v[0], a[1]+t*v[1]))


def polygon_distance(p, poly):
    inside = False
    for a, b in zip(poly, poly[1:]+poly[:1]):
        if (a[1] > p[1]) != (b[1] > p[1]):
            if p[0] < a[0] + (p[1]-a[1])*(b[0]-a[0])/(b[1]-a[1]):
                inside = not inside
    return 0. if inside else min(segment_distance(p, a, b) for a, b in zip(poly, poly[1:]+poly[:1]))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    raw = SOURCE.read_bytes()
    bank = json.loads(raw)
    g = Geometry(**{k:bank['geometry'][k] for k in ('length','width','radius')})
    r, hx, hz = g.radius, g.length/2, g.width/2
    dx, dz = (g.length-2*r)/12, (g.width-2*r)/6
    # Read calibrated production mouth polygons, rather than using target aim points.
    geom_path = ROOT / 'QiuJi/Core/Physics/TableGeometry+QiuJi.swift'
    geom_text = geom_path.read_text()
    const_path = ROOT / 'QiuJi/Core/Physics/BTPhysicsConstants.swift'
    constants = const_path.read_text()
    def const(name):
        return float(re.search(r'static let '+name+r': Float = ([0-9.]+)', constants)[1])
    def lip(name):
        block = geom_text.split('private static let '+name+':')[1].split(']')[1].split('\n    ]')[0]
        return [tuple(map(float, p)) for p in re.findall(r'SIMD2\(([-\d.]+), ([-\d.]+)\)', block)]
    corner, middle = lip('measuredCornerLip'), lip('measuredMiddleLip')
    assert len(corner) == 17 and len(middle) == 13
    polygons = [[(x*sx, z*sz) for x,z in corner] for sx,sz in [(-1,-1),(1,-1),(-1,1),(1,1)]]
    polygons += [[(x,z*sz) for x,z in middle] for sz in [-1,1]]
    rc, rm = const('cornerPocketDiameter')/2, const('sidePocketDiameter')/2
    holes = [((sx*(hx+rc),sz*(hz+rc)),rc) for sx,sz in [(-1,-1),(1,-1),(-1,1),(1,1)]]
    holes += [((0,sz*(const('sidePocketNearRimZ')+rm)),rm) for sz in [-1,1]]
    def clearances(p, cue, obj):
        return dict(rail=min(hx-abs(p[0]),hz-abs(p[1])),
                    pocket=min([polygon_distance(p, poly) for poly in polygons]+[math.dist(p,c)-rr for c,rr in holes]),
                    existing_ball=min(math.dist(p,cue), math.dist(p,obj)))
    rng = random.Random(SEED)
    all_layouts = list(layouts(bank))
    assert len(all_layouts) == 135700
    selected = rng.sample(all_layouts, 4)
    boards = []
    for n, (lid,cue,obj,pid,angle) in enumerate(selected,1):
        points = []
        for row in range(6):
            for col in range(12):
                center = (-hx+r+(col+.5)*dx, -hz+r+(row+.5)*dz)
                for attempt in range(10000):
                    p = (center[0]+rng.uniform(-JITTER,JITTER),center[1]+rng.uniform(-JITTER,JITTER))
                    cs = clearances(p,cue,obj)
                    if cs['rail'] >= r and cs['pocket'] >= r and cs['existing_ball'] >= 2*r:
                        break
                else:
                    raise RuntimeError(f'No accepted point: {lid}, {row}, {col}')
                points.append(dict(row=row,col=col,center=center,position=p,clearances=cs,attempts=attempt+1))
        boards.append(dict(number=n,id=lid,cue=cue,object=obj,pocket=pid,angle=angle,points=points))
    # Check serialized geometry independently of the rejection loop.
    assert segment_distance((.5,1),(0,0),(1,0)) == 1
    assert segment_distance((2,0),(0,0),(1,0)) == 1
    assert polygon_distance((.5,.5),[(0,0),(1,0),(1,1),(0,1)]) == 0
    for b in boards:
        assert len({(p['row'],p['col']) for p in b['points']}) == 72
        for p in b['points']:
            x,z = p['position']
            assert abs(x-p['center'][0]) <= JITTER and abs(z-p['center'][1]) <= JITTER
            assert int((x+hx-r)/dx) == p['col'] and int((z+hz-r)/dz) == p['row']
            assert all(math.isfinite(v) for v in (x,z))
            cs = clearances((x,z),b['cue'],b['object'])
            assert cs['rail'] >= r and cs['pocket'] >= r and cs['existing_ball'] >= 2*r
        # Jitter bound also leaves neighbouring alternative markers non-overlapping.
        assert min(math.dist(a['position'],b2['position']) for i,a in enumerate(b['points']) for b2 in b['points'][i+1:]) >= 2*r
    font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    def draw(ax, b):
        ax.set_aspect('equal')
        ax.add_patch(Rectangle((-hx-.07,-hz-.07),2*hx+.14,2*hz+.14,color='#325d50',zorder=0))
        ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#d3e4d5',zorder=1))
        for c,rr in holes:
            ax.add_patch(Circle(c,rr,color='#173d35',zorder=3))
        for poly in polygons:
            ax.add_patch(Polygon(poly,color='#173d35',zorder=3))
        for i in range(13):
            x=-hx+r+i*dx
            ax.plot([x,x],[-hz+r,hz-r],color='#839f91',lw=.65,zorder=2)
        for i in range(7):
            z=-hz+r+i*dz
            ax.plot([-hx+r,hx-r],[z,z],color='#839f91',lw=.65,zorder=2)
        for p in b['points']:
            ax.plot(*p['center'],marker='+',ms=3,color='#72877d',mew=.6,zorder=3)
            ax.add_patch(Circle(p['position'],r,facecolor='#277bb7',edgecolor='#15507b',lw=.7,zorder=4))
        ax.add_patch(Circle(b['cue'],r,facecolor='white',edgecolor='#253d35',lw=1.2,zorder=5))
        ax.add_patch(Circle(b['object'],r,facecolor='#edb437',edgecolor='#785015',lw=1.2,zorder=5))
        ax.text(*b['object'],'1',ha='center',va='center',fontsize=8,zorder=6)
        ax.set_xlim(-hx-.1,hx+.1);ax.set_ylim(hz+.1,-hz-.1);ax.axis('off')
        ax.set_title(f"示例 {b['number']} · 72个候选位置 · 原球形切角 {b['angle']}°",loc='left',fontsize=13,pad=12)
    for b in boards:
        fig,ax=plt.subplots(figsize=(13,7.3),facecolor='#f7f9f6')
        draw(ax,b)
        fig.text(.06,.04,'蓝球：第二颗球候选点   白球：母球   黄球：第一颗目标球   ＋：网格中心',fontsize=12,color='#41594f')
        fig.subplots_adjust(left=.035,right=.965,bottom=.10,top=.92)
        fig.savefig(OUT/f"example-{b['number']}.png",dpi=180)
        plt.close(fig)
    fig,axs=plt.subplots(2,2,figsize=(18,11),facecolor='#f7f9f6')
    for ax,b in zip(axs.flat,boards): draw(ax,b)
    fig.suptitle('第二颗球候选位置 · 12 × 6 等分随机预览',x=.045,y=.98,ha='left',fontsize=23)
    fig.text(.045,.925,'每格约20.69 × 20.21 cm；中心横纵各随机偏移±5 cm；球心距库边、袋口边界至少一个球半径。',fontsize=13,color='#41594f')
    fig.text(.045,.035,'蓝球：候选点（分别评估）    白球：原母球    黄球：第一颗目标球    ＋：网格中心',fontsize=13,color='#41594f')
    fig.subplots_adjust(left=.035,right=.965,top=.86,bottom=.08,wspace=.08,hspace=.18)
    fig.savefig(OUT/'grid-preview-4.png',dpi=180)
    plt.close(fig)
    checks = dict(boards=4,candidates=288,perBoard=72,
        minRailCenterDistanceCM=100*min(p['clearances']['rail'] for b in boards for p in b['points']),
        minPocketBoundaryDistanceCM=100*min(p['clearances']['pocket'] for b in boards for p in b['points']),
        minExistingBallCenterDistanceCM=100*min(p['clearances']['existing_ball'] for b in boards for p in b['points']),
        ballRadiusCM=100*r,allChecksPassed=True)
    result=dict(source=str(SOURCE.relative_to(ROOT)),sourceSHA256=hashlib.sha256(raw).hexdigest(),seed=SEED,
                geometry=bank['geometry'],grid=dict(columns=12,rows=6,cellSizeMetres=[dx,dz],jitterPerAxisMetres=JITTER),
                pocketGeometrySHA256=hashlib.sha256(geom_path.read_bytes()).hexdigest(),
                constantsSHA256=hashlib.sha256(const_path.read_bytes()).hexdigest(),boards=boards,checks=checks)
    (OUT/'preview-data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    assert SOURCE.read_bytes() == raw
    print(json.dumps(checks,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
