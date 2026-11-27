"""CAD-backed geometric table; original bank coordinates and physical ball radius."""
from pathlib import Path
import hashlib,json,math,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon,FancyBboxPatch
from matplotlib.font_manager import FontProperties

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-fixed-opponent-examples-20261105'
source=ROOT/'output/defense-approved-filter-20261104'
geo=json.loads((source/'geometry.json').read_text())
manifest=json.loads((source/'source-manifest.json').read_text())
checked={}
for name in ['QiuJi/Core/Physics/BTPhysicsConstants.swift','QiuJi/Core/Physics/TableGeometry.swift','QiuJi/Core/Physics/TableGeometry+QiuJi.swift']:
    h=hashlib.sha256((ROOT/name).read_bytes()).hexdigest();assert h==manifest[name],name;checked[name]=h
shutil.copy2(source/'geometry.json',OUT/'table-geometry.json')
# Use today's exact production rail endpoints rather than rounded historical analytic rails.
rails=json.loads((ROOT/'output/defense-region-adaptive-20261105/geometry.json').read_text())['rails']
pieces=[np.array(r) for r in rails];max_arc_join=0
for p in geo['pockets']:
    for j in p['jaws']:
        a=j['angleA'];delta=math.atan2(math.sin(j['angleB']-a),math.cos(j['angleB']-a))
        angles=a+delta*np.linspace(0,1,65)
        arc=np.array(j['center'])+j['radius']*np.column_stack([np.cos(angles),np.sin(angles)])
        max_arc_join=max(max_arc_join,float(np.linalg.norm(arc[-1]-j['lineA'])))
        pieces.append(np.vstack([arc,j['lineA'],j['lineB']]))
    pieces.append(np.array([j['lineB'] for j in p['jaws']]))
chain=list(pieces.pop(0));joins=[]
while pieces:
    candidates=[(np.linalg.norm(chain[-1]-p[k]),i,k) for i,p in enumerate(pieces) for k in [0,-1]]
    dist,i,k=min(candidates);assert dist<.00003,(dist,i,k)
    joins.append(float(dist));p=pieces.pop(i);p=p if k==0 else p[::-1];chain.extend(p[1:])
assert np.linalg.norm(chain[-1]-chain[0])<.00003
assert max_arc_join<.000003,max_arc_join
outline=np.array(chain)
items=json.loads((OUT/'selected.json').read_text())['examples']
font=FontProperties(fname='/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
plt.rcParams.update({'font.family':font.get_name(),'axes.unicode_minus':False})
R=geo['radius'];hx=geo['length']/2;hz=geo['width']/2

def table(ax):
    ax.add_patch(FancyBboxPatch((-1.43,-.795),2.86,1.59,boxstyle='round,pad=0,rounding_size=.065',facecolor='#2a3036',edgecolor='#151b20',linewidth=2,zorder=0))
    # CAD contour defines the usable cloth perimeter; the outer frame is decorative.
    ax.add_patch(Polygon(outline,closed=True,facecolor='#087f58',edgecolor='#53b68b',linewidth=1.1,zorder=2))
    for p in geo['pockets']:
        radius=.042 if abs(p['center'][0])>.1 else .043
        ax.add_patch(Circle(p['center'],radius+.009,facecolor='#c9b78a',edgecolor='#807554',linewidth=.6,zorder=3))
        ax.add_patch(Circle(p['center'],radius,facecolor='#101d1b',edgecolor='#081110',linewidth=.6,zorder=4))
    for x in [-.9525,-.635,-.3175,.3175,.635,.9525]:
        for z in [-.745,.745]:ax.add_patch(Polygon([(x,z-.008),(x+.005,z),(x,z+.008),(x-.005,z)],facecolor='#d9d7c8',zorder=5))
    for z in [-.3175,0,.3175]:
        for x in [-1.38,1.38]:ax.add_patch(Polygon([(x,z-.008),(x+.005,z),(x,z+.008),(x-.005,z)],facecolor='#d9d7c8',zorder=5))
    ax.set(xlim=(-1.47,1.47),ylim=(.83,-.83),aspect='equal');ax.axis('off')

def ball(ax,p,n):
    x,z=p
    ax.add_patch(Circle((x+.004,z+.005),R,facecolor='#002e23',alpha=.65,zorder=7))
    face=Circle((x,z),R,facecolor='#f9f8ed' if n!=8 else '#202528',edgecolor='#0a352d',linewidth=.6,zorder=8);ax.add_patch(face)
    if n==9:
        band=Rectangle((x-R,z-R*.63),2*R,1.26*R,facecolor='#e5af15',zorder=9);band.set_clip_path(face);ax.add_patch(band)
    if n:
        ax.add_patch(Circle((x,z),R*.64,facecolor='#faf9ed',zorder=10))
        ax.text(x,z,str(n),ha='center',va='center',color='#151a1c',fontsize=6.5,fontweight='bold',zorder=11)
    else:ax.add_patch(Circle((x,z),R*.12,facecolor='#ec4f47',zorder=10))
    ax.add_patch(Circle((x-R*.34,z-R*.4),R*.17,facecolor='white',alpha=.42,zorder=12))

def draw(ax,item,detail=True):
    table(ax);q=item['question']
    ball(ax,q['cue'],0)
    for b in q['balls']:ball(ax,b['position'],b['number'])
    ax.set_title(item['label']+'  '+item['title'],loc='left',fontsize=16,color='#173c32',pad=9,fontweight='bold')
    if detail:
        d=item['measurements']['cueTo8Meters']
        ax.text(0,-.055,f'母球—8号距离 {d:.2f}米  ·  题库ID {q["id"].split(":")[1][:12]}',transform=ax.transAxes,fontsize=10,color='#5b6b64')

fig,axes=plt.subplots(2,2,figsize=(16,10.6));fig.patch.set_facecolor('#f4f5f0')
fig.subplots_adjust(left=.035,right=.965,bottom=.12,top=.86,wspace=.07,hspace=.26)
for ax,item in zip(axes.flat,items):draw(ax,item)
fig.text(.035,.955,'我方打8号，对方剩9号：先看这4个初始球形',fontsize=24,fontweight='bold',color='#163b31')
fig.text(.035,.905,'白球＝母球  ·  黑8＝我方本杆先击打的球  ·  黄白9＝对方目标球',fontsize=13,color='#52665b')
fig.text(.035,.045,'生产CAD几何球桌：真实库线、袋角圆弧、袋口与57.15毫米球径。球位原样来自正式题库。\n这里只展示初态；对方9号不动依据已有参考记录，本轮未重放、未绘制防守答案或重新评分。',fontsize=11,color='#596a61')
fig.savefig(OUT/'examples-overview.png',dpi=180,facecolor=fig.get_facecolor());fig.savefig(OUT/'examples-overview.pdf',facecolor=fig.get_facecolor());plt.close(fig)
for item in items:
    fig,ax=plt.subplots(figsize=(12,7.5));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.04,right=.96,bottom=.16,top=.9)
    draw(ax,item)
    fig.text(.04,.035,'初始球形 · 我方8号／对方9号 · 生产CAD几何 · 保留题库原坐标',fontsize=12,color='#52665b')
    fig.savefig(OUT/f'{item["label"]}.png',dpi=180,facecolor=fig.get_facecolor());plt.close(fig)
(OUT/'geometry-validation.json').write_text(json.dumps({'productionGeometryHashesMatch':checked,
    'geometryExportSHA256':hashlib.sha256((source/'geometry.json').read_bytes()).hexdigest(),
    'maxContourJoinGapMeters':max(joins),'maxArcToJawGapMeters':max_arc_join,
    'ballDiameterMeters':2*R,'scaleIsEqualXZ':True,'orientation':'landscape +X right +Z down',
    'scope':'CAD-based geometric illustration, not a native App screenshot or USDZ render. Outer frame finish is decorative.'},indent=2))
print('Rendered four original layouts with the shared CAD contour.')
