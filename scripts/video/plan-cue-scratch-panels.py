from pathlib import Path
import json,math
r=Path('/Users/song/projects/13.billiard_trainer/output/cue-scratch-selection-20261005')
m=json.loads((r/'topdown-r4-rail-labels/manifest.json').read_text())
ppm=2400/3.48
placements={}
for c in m['cases']:
 def project(p):return (720+p[2]*ppm,1200-p[0]*ppm)
 paths=[c['cuePath'],c['objectPath']]
 cue=c['cueXYZ'];ax,az=c['aimXZ']
 paths.append([cue,[cue[0]-ax*1.6,cue[1],cue[2]-az*1.6]])
 pts=[project(p) for p in [cue,c['objectXYZ'],c['ghostXYZ']]]
 for path in paths:
  for a,b in zip(path,path[1:]):
   a,b=project(a),project(b);n=max(1,math.ceil(math.dist(a,b)/5))
   pts.extend((a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n) for i in range(n+1))
 candidates=[]
 for x in [308,812]:
  for y in range(620,1381,10):
   w,h=320,590
   clearance=min(math.hypot(max(x-px,0,px-(x+w)),max(y-py,0,py-(y+h))) for px,py in pts)
   if clearance<55:continue
   # Favor a central panel with generous trajectory clearance, capped to avoid corner drift.
   score=min(clearance,120)-.20*abs((y+h/2)-1200)
   candidates.append((score,clearance,x,y,w,h))
 best=max(candidates)
 placements[c['id']]={'rect':list(best[2:]),'clearance':best[1]}

print(json.dumps(placements,indent=2))
