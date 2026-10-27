"""Mirror the source-bound middle-pocket region; native full-source oracle checks it."""
from pathlib import Path
import re,struct,hashlib
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'QiuJi/Core/PositionPlay/MiddlePocketRegion.swift'
TEXT=SOURCE.read_text()
INSET=float(re.search(r'inset: ([0-9.]+), slope:',TEXT)[1])
SLOPE=float(re.search(r'inset: [0-9.]+, slope: ([0-9.]+)',TEXT)[1])
def f32(x):return struct.unpack('f',struct.pack('f',float(x)))[0]
HALF_WIDTH=f32(1.27)/2
ROUND=4*2**-23
VERSION=re.search(r'let version = "([^"]+)"',TEXT)[1]
def allowed(ball,pocket):
    if pocket not in (4,5):return True
    x,z=map(f32,ball);side=-1 if pocket==4 else 1
    return HALF_WIDTH-side*z+ROUND>=INSET+SLOPE*abs(x)
def pockets(ball):return [p for p in range(6) if allowed(ball,p)]
def oracle_points(candidates):
    points=list(candidates)
    for side in [-1,1]:
        for x in [-1.2,-.8,-.1,0,.1,.8,1.2]:
            for offset in [-.001,-.000001,0,.000001,.001]:
                points.append([x,side*(HALF_WIDTH-(INSET+SLOPE*abs(x)+offset))])
    return points
