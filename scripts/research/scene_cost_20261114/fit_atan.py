#!/usr/bin/env python3
"""H14 bounded atan approximation, independently derived without external packages."""
import ctypes
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
fma = ctypes.CDLL('/usr/lib/libSystem.B.dylib').fmaf
fma.argtypes = [ctypes.c_float] * 3
fma.restype = ctypes.c_float
def f32(x):
    return struct.unpack('f', struct.pack('f', x))[0]

degree, count = 9, 256
# Approximate atan(sqrt(u))/sqrt(u), u in [0,1], using Chebyshev projection.
cheb = []
for k in range(degree + 1):
    total = 0.0
    for j in range(count):
        theta = math.pi * (j + .5) / count
        u = (math.cos(theta) + 1) / 2
        total += math.atan(math.sqrt(u)) / math.sqrt(u) * math.cos(k * theta)
    cheb.append(total * (1 if k == 0 else 2) / count)
bases = [[1.0], [-1.0, 2.0]]
for k in range(2, degree + 1):
    previous = bases[-1]
    new = [0.0] * (k + 1)
    for i, c in enumerate(previous):
        new[i] -= 2*c
        new[i+1] += 4*c
    for i, c in enumerate(bases[-2]):
        new[i] -= c
    bases.append(new)
coefficients = [f32(sum(cheb[k] * bases[k][i] for k in range(i, degree + 1)))
                for i in range(degree + 1)]

def approx(y, x):
    ax = abs(x)
    t = f32(min(y, ax) / max(y, ax))
    u = f32(t*t)
    value = coefficients[-1]
    for c in reversed(coefficients[:-1]):
        value = fma(value, u, c)
    angle = f32(t*value)
    if y > ax:
        angle = f32(f32(math.pi/2) - angle)
    return f32(f32(math.pi)-angle) if x < 0 else angle

maximum, worst = 0.0, None
for i in range(400001):
    theta = math.pi*i/400000
    x, y = f32(math.cos(theta)), f32(math.sin(theta))
    error = abs(approx(y,x) - math.atan2(y,x))
    if error > maximum:
        maximum, worst = error, [x,y]
assert maximum < 5e-7, maximum
lines = ['float h14PositiveAtan2(float y,float x) {',
         '    float ax=abs(x);float t=min(y,ax)/max(y,ax);float u=t*t;',
         f'    float value={coefficients[-1]:.12g};']
for c in reversed(coefficients[:-1]):
    lines.append(f'    value=fma(value,u,{c:.12g});')
lines += ['    float angle=t*value;',
          '    angle=y>ax ? 1.5707963267948966-angle : angle;',
          '    return x<0.0 ? 3.141592653589793-angle : angle;', '}']
out = ROOT / 'tasks/render-highlight-20261114'
(out / 'H14-atan-function.txt').write_text('\n'.join(lines)+'\n')
(out / 'H14-atan-numeric.json').write_text(json.dumps({
    'domain': 'y>=0, x signed, not both zero; actual call has y>1e-7',
    'method': 'degree9 Chebyshev projection in u, converted to Float32 Horner FMA',
    'coefficientsAscending': coefficients, 'samples': 400001,
    'maximumAbsoluteAngleErrorRadians': maximum, 'worstXY': worst,
    'boundary': 'host fmaf rounded Float32; not a GPU performance or image claim'
}, indent=2)+'\n')
print(f'maximum FP32 angle error = {maximum:.9g} radians across 400001 points')
