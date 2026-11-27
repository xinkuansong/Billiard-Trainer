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
OUT=ROOT/'output/defense-four-regions-20261105'
source=ROOT/'output/defense-approved-filter-20261104'
geo=json.loads((source/'geometry.json').read_text())
manifest=json.loads((source/'source-manifest.json').read_text())
checked={}
for name in ['QiuJi/Core/Physics/BTPhysicsConstants.swift','QiuJi/Core/Physics/TableGeometry.swift','QiuJi/Core/Physics/TableGeometry+QiuJi.swift']:
    h=hashlib.sha256((ROOT/name).read_bytes()).hexdigest();assert h==manifest[name],name;checked[name]=h

# Use today's exact production rail endpoints rather than rounded historical analytic rails.
rails=json.loads((OUT/'A/geometry.json').read_text())['rails']
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
items=json.loads((ROOT/'output/defense-fixed-opponent-examples-20261105/selected.json').read_text())['examples']
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
