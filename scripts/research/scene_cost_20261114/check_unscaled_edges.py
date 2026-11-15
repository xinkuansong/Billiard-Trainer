#!/usr/bin/env python3
"""H14: independently check homogeneous edge-angle identity on original clipped polygon."""
import json
import math
import random
from pathlib import Path

def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,k): return tuple(x*k for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a): return mul(a,1/math.sqrt(dot(a,a)))

def edge(a,b,n,raw):
    if not raw: a,b=norm(a),norm(b)
    c=cross(a,b); c2=dot(c,c)
    threshold=1e-14*dot(a,a)*dot(b,b) if raw else 1e-14
    if c2<=threshold: return 0.0
    length=math.sqrt(c2)
    return math.atan2(length,dot(a,b))*dot(c,n)/length

def integral(vertices,n,raw):
    clipped=[]
    for a,b in zip(vertices,vertices[1:]+vertices[:1]):
        da,db=dot(a,n),dot(b,n)
        if da>=0: clipped.append(a)
        if (da>=0)!=(db>=0): clipped.append(add(a,mul(sub(b,a),da/(da-db))))
    return abs(sum(edge(a,b,n,raw) for a,b in zip(clipped,clipped[1:]+clipped[:1])))*.5 if len(clipped)>=3 else 0.

randomizer=random.Random(141404)
cases=[]
for _ in range(12000):
    p=(randomizer.uniform(-1.7,1.7),randomizer.uniform(-.1,1.15),randomizer.uniform(-1,1))
    cases.append((p,norm(tuple(randomizer.uniform(-1,1) for _ in range(3)))))
for p in [(0,.8,0),(1.27,.8,.635),(-1.4,0,-.7),(0,1.15,0)]:
    for n in [(0,1,0),(0,-1,0),(1,0,0),(-1,0,0),(0,0,1),(0,0,-1)]: cases.append((p,n))
maximum=0.0; checked=0; worst=None
for p,n in cases:
    for offset in [-.635,.635]:
        vertices=[sub((x,3,z+offset),p) for x,z in [(-2.54,-.635),(-2.54,.635),(2.54,.635),(2.54,-.635)]]
        normals=[n]
        if p==(0,.8,0):
            grazing=norm(cross(vertices[0],(0,1,0)))
            normals += [norm(add(grazing,mul(norm(vertices[0]),epsilon))) for epsilon in [-1e-8,0,1e-8]]
        for normal in normals:
            a,b=integral(vertices,normal,False),integral(vertices,normal,True)
            checked+=1
            if abs(a-b)>maximum: maximum=abs(a-b);worst={'p':p,'n':normal,'reference':a,'candidate':b}
assert maximum<1e-10,(maximum,worst)
out=Path(__file__).resolve().parents[3]/'tasks/render-highlight-20261114/H14-unscaled-numeric.json'
out.write_text(json.dumps({'cases':checked,'maxAbsoluteDifference':maximum,'worst':worst,
    'scope':'Independent double check; no GPU or image conclusion','passed':True},indent=2)+'\n')
print(checked,'clipped polygons, max integral difference',maximum)
