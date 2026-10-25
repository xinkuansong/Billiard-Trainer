"""Independent scalar score readback using the frozen native geometry precision."""
import json,math,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'output/two-ball-comfort-score-five-v2-20261025'
d=json.loads((p/'data.json').read_text());v=json.loads((p/'verification.json').read_text())
hx=d['geometry']['length']/2;hz=d['geometry']['width']/2;r=d['geometry']['radius']
for s in d['samples']:
 for q in s['routes']:
  x,z=q['stop'];bx,bz=q['backx'],q['backz'];a,b=q['preferred'];dist=math.dist(q['stop'],s['position'])
  D=100*math.exp(-(max(a-dist,0)/(.8*a))**2-(max(dist-b,0)/.75)**2)
  penalties=[(45+15*max(t,0)**2)*math.exp(-(max(g,0)*100/8)**1.2) for g,t in [(hx-x-r,bx),(hx+x-r,-bx),(hz-z-r,bz),(hz+z-r,-bz)]]
  i=max(range(4),key=lambda k:penalties[k]);neighbor=max(penalties[2:]) if i<2 else max(penalties[:2]);S=100-penalties[i]-min(8,.25*neighbor)
  A=100*math.exp(-(max(abs(q['angle'])-15,0)/30)**2)
  for key,value in [('distance',D),('space',S),('angle',A),('total',(D*S*A)**(1/3))]:assert abs(q['latestScores'][key]-value)<1e-8
 assert s['latestOrderOriginalRanks']==[q['rank'] for q in sorted(s['routes'],key=lambda q:(-q['latestScores']['total'],q['rank']))]
files=['index.html','data.json']+[f'sample-{n}.png' for n in range(1,6)]
for f in files:assert urllib.request.urlopen('http://127.0.0.1:51240/comfort-score-five-v2/'+f).read()==(p/f).read_bytes()
v.update(independent22ComponentAndTotalChecks=True,rankOrderingVerified=True,httpByteEqualFiles=files)
(p/'verification.json').write_text(json.dumps(v,ensure_ascii=False,indent=2))
print('22 independent component/total checks; sorting and 7 HTTP assets passed')
