"""Independent XZ section of S04-01-53, using recorded balls and production lip."""
from pathlib import Path
import json, math, re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Circle, Polygon

root=Path(__file__).resolve().parents[2]
out=root/'output/defense-pipe-always-scored-20261105'
row=next(x for x in json.loads((root/'output/defense-score-gallery-20261105/cases.json').read_text()) if x['id']=='S04-01-53')
ball=row['positions']['_9'];eight=row['positions']['_8'];r=.028575
source=(root/'QiuJi/Core/Physics/TableGeometry+QiuJi.swift').read_text()
section=source.split('private static let measuredCornerLip: [SIMD2<Double>] = [',1)[1].split('\n    ]',1)[0]
lip=[(-float(x),float(z)) for x,z in re.findall(r'SIMD2\(([-\d.]+), ([-\d.]+)\)',section)][::-1]
center=(-1.312,.677);pocket_radius=.042
rails=[((-1.27,-.5321),(-1.27,.5321)),((-1.1671,.635),(-.073,.635))]

def sub(a,b):return (a[0]-b[0],a[1]-b[1])
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def dot(a,b):return a[0]*b[0]+a[1]*b[1]
def dist(p,a,b):
    v=sub(b,a);den=dot(v,v);t=max(0,min(1,dot(sub(p,a),v)/den)) if den else 0
    return math.hypot(p[0]-a[0]-t*v[0],p[1]-a[1]-t*v[1])
def segment(a,b,c,d):
    u=sub(b,a);v=sub(d,c);den=cross(u,v)
    if den and 0<=cross(sub(c,a),v)/den<=1 and 0<=cross(sub(c,a),u)/den<=1:return 0
    return min(dist(a,c,d),dist(b,c,d),dist(c,a,b),dist(d,a,b))
def entry(theta):
    n=(math.cos(theta),math.sin(theta));v=sub(center,ball);b=dot(v,n);disc=b*b-dot(v,v)+pocket_radius**2
    candidates=[]
    if disc>=0:
        candidates += [x for x in (b-math.sqrt(disc),b+math.sqrt(disc)) if x>0]
    for a,c in zip(lip,lip[1:]+lip[:1]):
        edge=sub(c,a);den=cross(n,edge)
        if not den:continue
        t=cross(sub(a,ball),edge)/den;u=cross(sub(a,ball),n)/den
        if t>=0 and 0<=u<=1:candidates.append(t)
    if not candidates:return None
    t=min(candidates);return (ball[0]+t*n[0],ball[1]+t*n[1])

delta=sub(center,ball);base=math.atan2(delta[1],delta[0]);half=math.asin(pocket_radius/math.hypot(*delta))
angles=[math.atan2(z-ball[1],x-ball[0]) for x,z in lip]+[base-half,base+half]
lo,hi=min(angles),max(angles)
samples=[]
for i in range(10001):
    a=lo+(hi-lo)*i/10000;end=entry(a)
    if end is None:continue
    ball_gap=dist(eight,ball,end)-2*r;rail_gap=min(segment(ball,end,*rail) for rail in rails)-r
    samples.append(dict(angle=math.degrees(a),end=end,ballGapMM=ball_gap*1000,railGapMM=rail_gap*1000))
assert samples and all(s['ballGapMM']<0 or s['railGapMM']<0 for s in samples)
ball_only=[s for s in samples if s['railGapMM']>=0]
rail_only=[s for s in samples if s['ballGapMM']>=0]
assert ball_only and rail_only
summary=dict(case='S04-01-53',sampleCount=len(samples),unblockedCount=0,
    railClearCount=len(ball_only),railClearBestBallGapMM=max(s['ballGapMM'] for s in ball_only),
    ballClearCount=len(rail_only),ballClearBestRailGapMM=max(s['railGapMM'] for s in rail_only),
    anglesDegrees=[math.degrees(lo),math.degrees(hi)],ball=ball,eight=eight,lip=lip)
(out/'corner-geometry.json').write_text(json.dumps(summary,indent=2))

font=FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc')
fig,axes=plt.subplots(1,2,figsize=(11,6),gridspec_kw={'width_ratios':[1,1.6]})
ax=axes[0]
ax.set_facecolor('#e7f1ed')
for a,b in rails:ax.plot([a[0],b[0]],[a[1],b[1]],color='#50473e',linewidth=6)
ax.add_patch(Polygon(lip,color='#bbb',alpha=.5))
ax.add_patch(Circle(center,pocket_radius,color='#333',alpha=.5))
for point,color,label in [(ball,'#f4ca52','9'),(eight,'#222','8')]:
    ax.add_patch(Circle(point,r,color=color,zorder=4));ax.text(*point,label,ha='center',va='center',color='white' if label=='8' else '#222',zorder=5)
for s,color in [(ball_only[len(ball_only)//2],'#2589b5'),(rail_only[len(rail_only)//2],'#d05b44')]:
    theta=math.radians(s['angle']);n=(math.cos(theta),math.sin(theta));side=(-n[1]*r,n[0]*r);end=s['end']
    ax.add_patch(Polygon([(ball[0]+side[0],ball[1]+side[1]),(end[0]+side[0],end[1]+side[1]),(end[0]-side[0],end[1]-side[1]),(ball[0]-side[0],ball[1]-side[1])],color=color,alpha=.22))
    ax.plot([ball[0],end[0]],[ball[1],end[1]],color=color,lw=1.2)
ax.set_xlim(-1.4,-1.04);ax.set_ylim(.74,.02);ax.set_aspect('equal')
ax.set_title('实测球位 · 左侧角袋局部',fontproperties=font,fontsize=15)
ax.set_xlabel('X (m)');ax.set_ylabel('Z (m)，向下增大',fontproperties=font)
ax=axes[1]
ax.plot([s['angle'] for s in samples],[s['ballGapMM'] for s in samples],label='进球管道与8号球净空',color='#2589b5')
ax.plot([s['angle'] for s in samples],[s['railGapMM'] for s in samples],label='进球管道与主库净空',color='#d05b44')
ax.axhline(0,color='#333',linestyle='--');ax.fill_between([s['angle'] for s in samples],-30,0,color='#e9dddd',alpha=.4)
ax.set_xlabel('目标球进球方向（度）',fontproperties=font);ax.set_ylabel('净空（mm）；负数表示侵入',fontproperties=font)
ax.set_title('避开主库的方向被8号挡；避开8号则先碰库',fontproperties=font,fontsize=14)
ax.legend(prop=font);ax.grid(alpha=.2);ax.set_ylim(-30,15)
fig.suptitle('S04-01-53：没有两处都畅通的直线进球管道',fontproperties=font,fontsize=18)
fig.text(.5,.025,'球位来自实测终态；袋口外形来自生产几何。曲线为独立密采验证，最终评分另由原生连续证明确认。',fontproperties=font,ha='center',fontsize=10)
fig.tight_layout(rect=(0,.05,1,.94));fig.savefig(out/'corner-pipe-explanation.png',dpi=180)
print(json.dumps(summary,ensure_ascii=False))
