
import json,math,ctypes,subprocess,hashlib,bisect
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=Path('/Users/song/projects/13.billiard_trainer')
source=ROOT/'output/two-ball-b42-dedup75-20261024/native-result.json'
d=json.loads(source.read_text())
subprocess.run(['xcrun','clang++','-O3','-std=c++17','-dynamiclib',str(HERE/'metric.cpp'),'-o',str(HERE/'metric.dylib')],check=True)
lib=ctypes.CDLL(str(HERE/'metric.dylib'));fn=lib.similarity
fn.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.c_int,ctypes.POINTER(ctypes.c_double),ctypes.c_int,ctypes.c_double];fn.restype=ctypes.c_double
# Fixed physical arc cells, last cell has its actual mass. Positions are source-polyline midpoint evaluations.
# No segment joins across an omitted source vertex; source cumulative arc includes every vertex.
def sample(points,h):
 lengths=[0.]
 for a,b in zip(points,points[1:]):lengths.append(lengths[-1]+math.dist(a,b))
 L=lengths[-1]
 assert L>0,'Stationary paths are outside this draft experiment'
 flat=[]
 for i in range(math.ceil(L/h)):
  lo=i*h;hi=min((i+1)*h,L);s=(lo+hi)/2
  j=bisect.bisect_right(lengths,s)-1
  u=(s-lengths[j])/(lengths[j+1]-lengths[j])
  xy=[points[j][k]+u*(points[j+1][k]-points[j][k]) for k in (0,1)]
  flat.extend([*xy,hi-lo])
 return (ctypes.c_double*len(flat))(*flat),L

def calc(a,b,sigma=20):return fn(a[0],len(a[0])//3,b[0],len(b[0])//3,sigma)
points={r['comboIndex']:[(p['position']['x']*100,p['position']['z']*100) for p in r['comparisonLine']] for r in d['rows']}
ids=list(points);cache={i:sample(p,1) for i,p in points.items()}
assert all(abs(calc(a,a)-100)<1e-9 for a in cache.values())
pairs=[]
for p in d['pairs']:
 a,b=cache[p['a']],cache[p['b']]
 s=calc(a,b);assert 0<=s<=100+1e-9
 pairs.append(dict(a=p['a'],b=p['b'],old=p['score'],dtwOnly=100*2**(-p['meanDTWCM']/20),candidate=s))
lookup={tuple(sorted([p['a'],p['b']])):p for p in pairs}
def dedup(field):
 kept=[]
 for i in ids:
  if all(lookup[tuple(sorted([i,j]))][field]<75 for j in kept):kept.append(i)
 return kept
cases={
 'identical':([(0,0),(200,0)],[(0,0),(200,0)]),
 'half_missing':([(0,0),(200,0)],[(0,0),(100,0)]),
 'ten_percent_extension':([(0,0),(200,0)],[(0,0),(220,0)]),
 'parallel_offset_20cm':([(0,0),(200,0)],[(0,20),(200,20)]),
 'reverse_200cm':([(0,0),(200,0)],[(200,0),(0,0)]),
 'same_start_opposite':([(0,0),(200,0)],[(0,0),(-200,0)]),
 'mid_detour_100cm':([(0,0),(200,0)],[(0,0),(100,0),(100,50),(100,0),(200,0)]),
 'return_same_endpoint':([(0,0),(200,0)],[(0,0),(200,0),(0,0),(200,0)])}
synthetic={k:calc(sample(a,.5),sample(b,.5)) for k,(a,b) in cases.items()}
assert abs(synthetic['identical']-100)<1e-9
assert abs(synthetic['half_missing']-50)<1e-9
assert abs(synthetic['parallel_offset_20cm']-50)<1e-9
assert abs(synthetic['ten_percent_extension']-100/1.1)<1e-9
focus=[(237,235),(398,287),(237,236),(287,525)]
convergence=[]
for a,b in focus:
 row=dict(a=a,b=b,old=lookup[tuple(sorted([a,b]))]['old'])
 for h in [2,1,.5,.25]:
  pa,pb=sample(points[a],h),sample(points[b],h)
  row[str(h)]=calc(pa,pb)
  assert abs(calc(pa,pb)-calc(pb,pa))<1e-9
 row['sigma10']=calc(sample(points[a],.5),sample(points[b],.5),10)
 convergence.append(row)
bydiff=sorted(pairs,key=lambda p:p['candidate']-p['old'],reverse=True)
result=dict(source=str(source),sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),coordinate='physical XZ centimetres, no individual alignment or scaling',candidate='maximum ordered one-to-one arc-cell reward min(cell lengths)*2^(-distanceCM/sigmaCM), divided by max(total lengths), times 100',sigmaCM=20,stepCM=1,rows=len(ids),pairs=len(pairs),lengthRangeCM=[min(a[1] for a in cache.values()),max(a[1] for a in cache.values())],focus=convergence,synthetic=synthetic,dedup={field:dict(count=len(dedup(field)),top10=dedup(field)[:10]) for field in ['old','dtwOnly','candidate']},largestIncreases=bydiff[:10],largestDecreases=bydiff[-10:],allPairs=pairs,limitations=['one initial layout, B42 filtering; no perceptual ground truth','fixed-step cell DP is a discretized prototype, not a continuous optimal-transport implementation','stationary path not defined in this prototype','no production code modified'])
(HERE/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ['allPairs','largestIncreases','largestDecreases']},ensure_ascii=False,indent=2))
