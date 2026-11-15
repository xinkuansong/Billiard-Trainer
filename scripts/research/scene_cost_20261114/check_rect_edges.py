#!/usr/bin/env python3
"""Independent double-precision polygon vs streaming edge check, not a GPU proof."""
import json
import math
import random
import sys
from pathlib import Path

def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def scale(a,s): return tuple(x*s for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def norm(a): return scale(a,1/math.sqrt(dot(a,a)))
def edge(a,b,n):
    a,b=norm(a),norm(b)
    c=cross(a,b); length=math.sqrt(dot(c,c))
    return math.atan2(length,dot(a,b))*dot(c,n)/length if length>1e-7 else 0.

def compare(v,n):
    clipped=[]
    for a,b in zip(v,v[1:]+v[:1]):
        da,db=dot(a,n),dot(b,n)
        if da>=0: clipped.append(a)
        if (da>=0)!=(db>=0): clipped.append(add(a,scale(sub(b,a),da/(da-db))))
    reference=abs(sum(edge(a,b,n) for a,b in zip(clipped,clipped[1:]+clipped[:1])))*.5 if len(clipped)>=3 else 0.
    total=0.; enter=leave=None
    for a,b in zip(v,v[1:]+v[:1]):
        da,db=dot(a,n),dot(b,n)
        if da>=0:
            if db>=0: total+=edge(a,b,n)
            else:
                leave=add(a,scale(sub(b,a),da/(da-db)))
                total+=edge(a,leave,n)
        elif db>=0:
            enter=add(a,scale(sub(b,a),da/(da-db)))
            total+=edge(enter,b,n)
    if leave is not None:
        assert enter is not None
        total+=edge(leave,enter,n)
    return reference,abs(total)*.5,len(clipped)

randomizer=random.Random(131403)
cases=[]
for _ in range(12000):
    p=(randomizer.uniform(-1.7,1.7),randomizer.uniform(-.1,1.15),randomizer.uniform(-1,1))
    cases.append((p,norm(tuple(randomizer.uniform(-1,1) for _ in range(3)))))
for p in [(0,.8,0),(1.27,.8,.635),(-1.4,0,-.7),(0,1.15,0)]:
    for n in [(0,1,0),(0,-1,0),(1,0,0),(-1,0,0),(0,0,1),(0,0,-1)]:
        cases.append((p,n))
maximum=0.; worst=None; counts={}
for p,n in cases:
    for offset in (-.635,.635):
        vertices=[sub((x,3,z+offset),p) for x,z in [(-2.54,-.635),(-2.54,.635),(2.54,.635),(2.54,-.635)]]
        normals=[n]
        # Explicit grazing through a corner, plus either side of that horizon.
        if p==(0,.8,0):
            grazing=norm(cross(vertices[0],(0,1,0)))
            normals += [norm(add(grazing,scale(norm(vertices[0]),epsilon))) for epsilon in (-1e-8,0,1e-8)]
        for normal in normals:
            a,b,count=compare(vertices,normal)
            counts[count]=counts.get(count,0)+1
            error=abs(a-b)
            if error>maximum: maximum=error;worst={'p':p,'n':normal,'offset':offset,'reference':a,'candidate':b}
assert maximum<1e-10,(maximum,worst)
Path(sys.argv[1]).write_text(json.dumps({'seed':131403,'precision':'Python double; GPU Float checked separately by native image comparison',
    'checked':sum(counts.values()),'clippedVertexCounts':counts,'maxAbsoluteDifference':maximum,'worst':worst,
    'passed':True},indent=2)+'\n')
print('edge topology check:',sum(counts.values()),'cases; max error',maximum)
