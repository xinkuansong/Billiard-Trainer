"""Independent numeric/visual check of the sub-grid blocker counterexample."""
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Polygon

out = Path(__file__).resolve().parents[2] / 'output/defense-pipe-blocking-20261105'
out.mkdir(parents=True, exist_ok=True)
r = 0.028575
d = 2*r
angle = 0.001234
n = (math.cos(angle), math.sin(angle))
side = (-n[1], n[0])
obstacles = [(.5*n[0]+s*(d+3e-6)*side[0], .5*n[1]+s*(d+3e-6)*side[1]) for s in [-1, 1]]

def distance(point, a, b):
    v = (b[0]-a[0], b[1]-a[1])
    t = max(0, min(1, ((point[0]-a[0])*v[0]+(point[1]-a[1])*v[1])/(v[0]**2+v[1]**2)))
    return math.hypot(point[0]-a[0]-t*v[0], point[1]-a[1]-t*v[1])

def clearance(theta):
    n = (math.cos(theta), math.sin(theta))
    ghost = (-d*n[0], -d*n[1])
    travel = n[0]-math.sqrt(.08**2-n[1]**2)
    end = (n[0]*travel, n[1]*travel)
    return min(min(distance(o, (-.8, 0), ghost), distance(o, (0, 0), end))-d for o in obstacles)

count = math.ceil(.04*180/math.pi/.01)
result = dict(old_grid_count=count+1,
              old_grid_has_route=any(clearance(-.02+.04*i/count) >= 0 for i in range(count+1)),
              opening_angle_degrees=angle*180/math.pi,
              opening_clearance_m=clearance(angle), blockers=obstacles)
assert not result['old_grid_has_route'] and result['opening_clearance_m'] > 0
(out/'geometry-check.json').write_text(json.dumps(result, indent=2))

fig, axes = plt.subplots(1, 2, figsize=(12, 4))
for ax in axes:
    for x, z in obstacles:
        ax.add_patch(Circle((x, z), r, color='#e2a022'))
    for theta, color in [(-.02, '#d33'), (.02, '#d33'), (angle, '#16a085')]:
        n = (math.cos(theta), math.sin(theta))
        s = (-n[1], n[0])
        ax.add_patch(Polygon([(s[0]*r, s[1]*r), (n[0]+s[0]*r, n[1]+s[1]*r),
                             (n[0]-s[0]*r, n[1]-s[1]*r), (-s[0]*r, -s[1]*r)], color=color, alpha=.12))
        ax.plot([0, n[0]], [0, n[1]], color=color, lw=.8)
    ax.set_aspect('equal')
    ax.grid(alpha=.2)
    ax.set_xlabel('X (m)')
    ax.set_ylabel('Z (m)')
axes[0].set_xlim(-.05, 1.05)
axes[0].set_ylim(-.16, .16)
axes[0].set_title('Ball-width paths: blocked limits, open interior')
axes[1].set_xlim(.47, .53)
axes[1].set_ylim(-.1, .1)
axes[1].set_title('Green witness: 3 micrometre minimum clearance')
fig.tight_layout()
fig.savefig(out/'geometry-check.png', dpi=180)
print(json.dumps(result))
