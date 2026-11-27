#!/usr/bin/env python3
"""Independent syntax/coordinate/interpolation preflight, not a GPU benchmark."""
import hashlib
import json
import math
import os
from pathlib import Path
import random
import struct
import subprocess
from compare_ir import wrapper

root=Path(__file__).resolve().parents[3]
work=Path(os.environ["QIUJI_TEST_WORK"]); evidence=Path(os.environ["QIUJI_TEST_EVIDENCE"])
source=(root/"output/static-cloth-20261126/static-geometry/planar-atlas.surface").read_text()
text=wrapper(source).replace("uint index [[thread_position_in_grid]]",
    "texture2d<float> staticGeometryAtlas [[texture(6)]],uint index [[thread_position_in_grid]]")
path=evidence/"candidate.metal";path.write_text(text)
command=["xcrun","-sdk","macosx","metal","-std=metal3.1","-O3","-c",str(path),"-o",str(work/"candidate.air")]
with (evidence/"compile.log").open("wb") as log:
    subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)

def geometry(x,y,z,slot):
    panel=slot//32 if slot<64 else (slot-64)//4
    index=slot%32 if slot<64 else (slot-64)%4
    nx,nz=(8,4) if slot<64 else (2,2)
    dx=2.54*(2*((index//nz)+.5)/nx-1)-x
    dz=(-.635 if panel==0 else .635)+.635*(2*((index%nz)+.5)/nz-1)-z
    dy=3-y;inv=1/math.sqrt(dx*dx+dy*dy+dz*dz)
    return (dx*inv,dy*inv,dz*inv,inv)

def half(x):return struct.unpack('e',struct.pack('e',x))[0]
rows=[]
for width in (33,65):
    height=(width+1)//2;rng=random.Random(261126);maximum=0;maxAngle=0;maxLength=0
    for _ in range(12000):
        x=rng.uniform(-1.27,1.27);z=rng.uniform(-.635,.635);y=rng.uniform(.799501,.800499);slot=rng.randrange(72)
        gx=(x+1.27)/2.54*(width-1);gy=(z+.635)/1.27*(height-1)
        ix=min(width-2,int(gx));iy=min(height-2,int(gy));tx=gx-ix;ty=gy-iy
        points=[[half(v) for v in geometry(-1.27+2.54*(ix+ox)/(width-1),.8,
                 -.635+1.27*(iy+oy)/(height-1),slot)] for oy in (0,1) for ox in (0,1)]
        actual=[(points[0][c]*(1-tx)+points[1][c]*tx)*(1-ty)+(points[2][c]*(1-tx)+points[3][c]*tx)*ty for c in range(4)]
        expected=geometry(x,y,z,slot)
        assert all(math.isfinite(v) for v in actual) and actual[1]>0 and actual[3]>0
        maximum=max(maximum,max(abs(a-b) for a,b in zip(actual,expected)))
        length=math.sqrt(sum(v*v for v in actual[:3]));maxLength=max(maxLength,abs(length-1))
        cosine=sum(a*b for a,b in zip(actual[:3],expected[:3]))/length
        maxAngle=max(maxAngle,math.degrees(math.acos(min(1,max(-1,cosine)))))
    rows.append({"grid":[width,height],"samples":12000,"maxComponentError":maximum,
        "maxDirectionErrorDegrees":maxAngle,"maxDirectionLengthError":maxLength})
report={"shaderSHA256":hashlib.sha256(source.encode()).hexdigest(),"compiler":command,"numeric":rows,
    "scope":"Independent double-precision geometry with FP16 storage and bilinear interpolation; not image quality or performance"}
(evidence/"preflight.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report))
