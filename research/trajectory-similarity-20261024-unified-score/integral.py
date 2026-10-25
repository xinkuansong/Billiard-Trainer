
import json,math,bisect
from pathlib import Path
HERE=Path(__file__).resolve().parent
base=json.loads((HERE/'results.json').read_text());source=json.loads(Path(base['source']).read_text())
def prep(points):
 s=[0.]
 for a,b in zip(points,points[1:]):s.append(s[-1]+math.dist(a,b))
 return points,s

def at(line,s):
 p,ls=line
 if s>=ls[-1]:return p[-1]
 j=bisect.bisect_right(ls,s)-1;u=(s-ls[j])/(ls[j+1]-ls[j])
 return tuple(p[j][k]+u*(p[j+1][k]-p[j][k]) for k in [0,1])

def calc(a,b,h=1,sigma=20):
 L=max(a[1][-1],b[1][-1])
 if L==0:return 100*2**(-math.dist(a[0][0],b[0][0])/sigma)
 total=0
 for i in range(math.ceil(L/h)):
  lo=i*h;hi=min((i+1)*h,L);s=(lo+hi)/2
  total+=(hi-lo)*2**(-math.dist(at(a,s),at(b,s))/sigma)
 return 100*total/L
lines={r['comboIndex']:prep([(q['position']['x']*100,q['position']['z']*100) for q in r['comparisonLine']]) for r in source['rows']}
for p in base['allPairs']:p['arcIntegral']=calc(lines[p['a']],lines[p['b']])
lookup={tuple(sorted([p['a'],p['b']])):p for p in base['allPairs']}
kept=[]
for i in lines:
 if all(lookup[tuple(sorted([i,j]))]['arcIntegral']<75 for j in kept):kept.append(i)
focus=[]
for a,b in [(237,235),(398,287),(237,236),(287,525),(493,507)]:
 q=dict(lookup[tuple(sorted([a,b]))]);q['convergence']={str(h):calc(lines[a],lines[b],h) for h in [2,1,.5,.25]};focus.append(q)
cases={
 'identical':([(0,0),(200,0)],[(0,0),(200,0)]),
 'half_missing':([(0,0),(200,0)],[(0,0),(100,0)]),
 'ten_percent_extension':([(0,0),(200,0)],[(0,0),(220,0)]),
 'parallel_offset_20cm':([(0,0),(200,0)],[(0,20),(200,20)]),
 'reverse_200cm':([(0,0),(200,0)],[(200,0),(0,0)]),
 'same_start_opposite':([(0,0),(200,0)],[(0,0),(-200,0)]),
 'mid_detour_100cm':([(0,0),(200,0)],[(0,0),(100,0),(100,50),(100,0),(200,0)]),
 'return_same_endpoint':([(0,0),(200,0)],[(0,0),(200,0),(0,0),(200,0)]),
 'same_shape_insert_20cm_excursion':([(0,0),(400,0)],[(0,0),(100,0),(100,10),(100,0),(400,0)])}
synthetic={k:calc(prep(a),prep(b),.25) for k,(a,b) in cases.items()}
assert abs(synthetic['identical']-100)<1e-9
assert abs(synthetic['parallel_offset_20cm']-50)<1e-9
out=dict(formula='100/Lmax * integral_0^Lmax 2^(-distance(P(min(s,Lp)),Q(min(s,Lq)))/20cm) ds; zero-length pair uses continuous limit kernel(start distance)',focus=focus,synthetic=synthetic,dedup=dict(count=len(kept),top10=kept[:10]),allPairs=base['allPairs'])
(HERE/'integral-results.json').write_text(json.dumps(out,indent=2))
print(json.dumps({k:v for k,v in out.items() if k!='allPairs'},indent=2))
