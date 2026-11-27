from pathlib import Path
import json, math, sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/kick-centered-20261103'
old = json.loads((OUT / 'baseline.json').read_text())
mode = sys.argv[1] if len(sys.argv) > 1 else 'final-r2'
new = json.loads((OUT / (mode + '.json')).read_text())
rows = []
for a,b in zip(old['cases'],new['cases']):
    assert a['name'] == b['name']
    previous = {}
    for s in a['solutions']:
        previous[s['rails']] = min(previous.get(s['rails'],1),s['impact'])
    current = {s['rails']:s['impact'] for s in b['solutions']}
    assert len(current) == len(b['solutions'])
    rows.append(dict(name=a['name'],before=len(a['solutions']),after=len(b['solutions']),
                     oldRoutes=len(previous),newRoutes=len(current),
                     lost=sorted(previous.keys()-current.keys()),added=sorted(current.keys()-previous.keys()),
                     lessCentered=[dict(route=r,old=previous[r],new=current[r]) for r in previous.keys() & current.keys()
                                   if current[r] > max(.01, previous[r]) + .00001],
                     centered=sum(x<=.01 for x in current.values()),oldSeconds=a['seconds'],newSeconds=b['seconds']))
assert new['cases'][0]['solutions']
example = next(s for s in new['cases'][0]['solutions'] if s['rails']=='right')
assert example['impact'] <= .01
(OUT/(mode + '-comparison.json')).write_text(json.dumps(dict(checks=new['checks'],cases=rows),indent=2))
print(json.dumps(rows,indent=2))
if mode != 'final-r2':
    assert all(not r['lost'] for r in rows), 'Must preserve known fallback routes'
    assert all(not r['lessCentered'] for r in rows), 'Known route contact must not regress'

# Actual pre-contact physics paths, plotted in landscape axes (+X right, +Z down).
oldExample = next(s for s in old['cases'][0]['solutions'] if s['rails']=='right')
def mapped(p,rect,extent):
    x,y,w,h = rect
    xmin,xmax,zmin,zmax = extent
    return x+(p[0]-xmin)/(xmax-xmin)*w, y+(p[1]-zmin)/(zmax-zmin)*h
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="540" viewBox="0 0 1200 540">',
     '<rect width="1200" height="540" fill="white"/>',
     '<text x="36" y="35" font-family="Helvetica" font-size="22">Same lower-rail route: baseline vs centered-contact search</text>']
for rect,extent,title in [((36,100,800,400),(-1.27,1.27,-.635,.635),'Full measured route'),
                           ((870,100,290,290),(-1.17,-.93,-.39,-.15),'Target contact detail')]:
    x,y,w,h=rect
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#e6f3e8" stroke="#333"/>')
    svg.append(f'<text x="{x}" y="{y-20}" font-family="Helvetica" font-size="17">{title}</text>')
    svg.append(f'<clipPath id="clip{x}"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath><g clip-path="url(#clip{x})">')
    for sol,color,dash in [(oldExample,'#c66a20','7 4'),(example,'#0068c9','none')]:
        points=' '.join(f'{a:.3f},{b:.3f}' for a,b in [mapped(p,rect,extent) for p in sol['path']])
        svg.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.5" stroke-dasharray="{dash}"/>')
        a,b=mapped(sol['path'][-1],rect,extent)
        radius=.028575*w/(extent[1]-extent[0])
        svg.append(f'<circle cx="{a}" cy="{b}" r="{radius}" stroke="{color}" fill="none" stroke-width="1.5"/>')
    a,b=mapped((-1.07,-.27),rect,extent)
    radius=.028575*w/(extent[1]-extent[0])
    svg.append(f'<circle cx="{a}" cy="{b}" r="{radius}" fill="#222"/>')
    svg.append('</g>')
for i,(label,sol,color) in enumerate([('Baseline',oldExample,'#c66a20'),('Updated',example,'#0068c9')]):
    angle=math.degrees(math.asin(sol['impact']))
    svg.append(f'<text x="870" y="{430+i*28}" font-family="Helvetica" font-size="17" fill="{color}">{label}: cut {angle:.3f} degrees</text>')
svg.append('</svg>')
(OUT/'comparison.svg').write_text('\n'.join(svg))
