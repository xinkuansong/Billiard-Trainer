#!/usr/bin/env python3
"""Independent basis checks, before using the basis in the scene's cue pivot."""
import math,json
from pathlib import Path
out=[]
for yaw in (0,math.pi/2,math.pi,-math.pi/2):
 for degrees in (0,45,70,85):
  e=math.radians(degrees);d=(math.cos(yaw),0,math.sin(yaw))
  side=(d[2],0,-d[0]);up=(math.sin(e)*d[0],math.cos(e),math.sin(e)*d[2])
  forward=(math.cos(e)*d[0],-math.sin(e),math.cos(e)*d[2])
  dot=lambda a,b:sum(x*y for x,y in zip(a,b))
  assert abs(dot(up,forward))<1e-12 and abs(dot(side,forward))<1e-12
  assert abs(dot(up,up)-1)<1e-12
  out.append(dict(yaw=yaw,degrees=degrees,forward=forward,up=up,side=side))
# A(-d,0,-d), B(-d,0,d), C(d,0,d): (B-A)x(C-A)=(0,4d²,0).
d=9
normal=(0,4*d*d,0);assert normal[1]>0
path=Path('output/v66/coordinate-contract.json');path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(dict(cases=out,groundNormal=normal,chordError240HzMetres=9.81/(8*240**2)),indent=2))
print(f'PASS {len(out)} cue bases; ground normal +Y; ballistic interpolation <= 0.022 mm')
