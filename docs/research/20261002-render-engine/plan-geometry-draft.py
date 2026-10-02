"""Static arithmetic/illustration for the plan; no production scene or benchmark.

Axes and radii below are illustrative, not validated product parameters.
Numerical sampling corroborates algebra; it does not certify scene safety.
"""
import json
import math
from pathlib import Path

HERE = Path(__file__).parent

def radius(theta, a, b):
    return 1 / math.sqrt((math.cos(theta) / a) ** 2 + (math.sin(theta) / b) ** 2)

def rail(theta, s):
    near = radius(theta, 2.0, 1.4)
    far = radius(theta, 3.2, 2.3)
    return math.exp((1-s)*math.log(near)+s*math.log(far))

inverse_errors, periodic_errors, minimum_gap = [], [], math.inf
for i in range(721):
    theta = i * math.tau / 720
    near, far = rail(theta, 0), rail(theta, 1)
    minimum_gap = min(minimum_gap, far-near)
    for s in (0, .1, .5, .9, 1):
        r = rail(theta, s)
        inverse_errors.append(abs((math.log(r)-math.log(near))/(math.log(far)-math.log(near))-s))
        periodic_errors.append(abs(r-rail(theta+math.tau, s)))

result = {
    "scope": "illustrative static arithmetic; not production safety, HUD, comfort or performance validation",
    "coordinates": "SceneKit XZ horizontal, Y up, metres; theta zero +X, pi/2 +Z",
    "illustrative_ellipse_axes_m": {"near": [2.0,1.4], "far": [3.2,2.3]},
    "samples_are_not_a_path_certificate": True,
    "minimum_sampled_far_near_gap_m": minimum_gap,
    "max_inverse_error": max(inverse_errors),
    "max_periodic_radius_error_m": max(periodic_errors),
    "analytic_monotonic_condition": "dr/ds = r*log(rFar/rNear)>0 if 0<rNear<rFar",
    "fixed_eye_target_height_difference_example_m": .8,
    "pitch_example_degrees": [
        {"horizontal_radius_m": r, "pitch_magnitude_deg": math.degrees(math.atan2(.8,r))}
        for r in (1.5,3.0)
    ],
    "R32_capacity_example": {
        "logical_bytes": 256*128*64*4,
        "packed_with_two_texel_collar_bytes": (256+4)*8*(128+4)*8*4,
        "new_GPU_total_peak_cap_bytes": 16*1024*1024,
        "capacity_is_not_quality_or_allocatedSize": True,
    },
}
(HERE / "plan-geometry-arithmetic.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")

def point(x,z):
    return 370+x*78, 280-z*78

paths = []
for s, color in ((0,"#ca8a04"),(.5,"#2563eb"),(1,"#16a34a")):
    pts = [point(rail(t,s)*math.cos(t),rail(t,s)*math.sin(t))
           for t in [math.tau*i/180 for i in range(181)]]
    d = "M " + " L ".join(f"{x:.3f},{y:.3f}" for x,y in pts) + " Z"
    paths.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="3"/>')
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="740" height="570" viewBox="0 0 740 570">
<rect width="740" height="570" fill="#f8fafc"/>
<text x="32" y="38" font-family="sans-serif" font-size="22" fill="#0f172a">Two-parameter camera rail — illustrative top view</text>
<text x="32" y="64" font-family="sans-serif" font-size="14" fill="#475569">Fixed eye height; theta orbits the table; s controls logarithmic distance.</text>
<rect x="271" y="230.5" width="198" height="99" rx="4" fill="#bce0d2" stroke="#346b59" stroke-width="2"/>
{''.join(paths)}
<path d="M370,280 L685,280 M370,280 L370,87" stroke="#64748b" stroke-dasharray="5 5"/>
<circle cx="370" cy="280" r="4" fill="#0f172a"/>
<text x="683" y="270" font-family="sans-serif" font-size="15">+X</text>
<text x="380" y="98" font-family="sans-serif" font-size="15">+Z</text>
<text x="382" y="304" font-family="sans-serif" font-size="14">C</text>
<text x="38" y="484" font-family="sans-serif" font-size="15" fill="#ca8a04">s=0 near</text>
<text x="217" y="484" font-family="sans-serif" font-size="15" fill="#2563eb">s=0.5</text>
<text x="381" y="484" font-family="sans-serif" font-size="15" fill="#16a34a">s=1 far</text>
<text x="38" y="521" font-family="sans-serif" font-size="14" fill="#475569">Radii are examples, not product defaults. Static table/HUD safety is not certified here.</text>
<text x="38" y="546" font-family="sans-serif" font-size="14" fill="#475569">Fixed world eye height does not fix the floor or table edge at one screen pixel height.</text>
</svg>'''
(HERE / "plan-rail-diagram.svg").write_text(svg)
print(json.dumps({"inverse_error":max(inverse_errors),"periodic_error":max(periodic_errors),"diagram":"plan-rail-diagram.svg"}))
