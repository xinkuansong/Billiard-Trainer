
import ctypes,subprocess,json,math,bisect
from pathlib import Path
HERE=Path(__file__).resolve().parent
# Import only helper definitions, not the full all-pairs experiment.
s=(HERE/'integral.py').read_text();exec(s[s.index('def prep'):s.index('lines={')])
subprocess.run(['xcrun','clang++','-O3','-std=c++17','-dynamiclib',str(HERE/'mean_integral.cpp'),'-o',str(HERE/'mean_integral.dylib')],check=True)
lib=ctypes.CDLL(str(HERE/'mean_integral.dylib'));fn=lib.mean_integral
fn.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.c_int,ctypes.POINTER(ctypes.c_double),ctypes.c_int]+[ctypes.c_double]*5;fn.restype=ctypes.c_double
source=json.loads(Path(json.loads((HERE/'results.json').read_text())['source']).read_text())
lines={r['comboIndex']:prep([(q['position']['x']*100,q['position']['z']*100) for q in r['comparisonLine']]) for r in source['rows']}
def sample(line,h):
 L=line[1][-1];f=[]
 for i in range(math.ceil(L/h)):
  lo=i*h;hi=min((i+1)*h,L);f.extend([*at(line,(lo+hi)/2),*at(line,hi),hi-lo])
 return (ctypes.c_double*len(f))(*f),line[0][0]
def score(a,b,sigma=20):return fn(a[0],len(a[0])//5,b[0],len(b[0])//5,sigma,*a[1],*b[1])
cache={i:sample(l,1) for i,l in lines.items()}
for a in cache.values():assert abs(score(a,a)-100)<1e-9
base=json.loads((HERE/'integral-results.json').read_text())
for p in base['allPairs']:p['meanIntegral']=score(cache[p['a']],cache[p['b']])
lookup={tuple(sorted([p['a'],p['b']])):p for p in base['allPairs']}
focus=[]
for a,b in [(237,235),(398,287),(237,236),(287,525),(493,507)]:
 q=dict(lookup[tuple(sorted([a,b]))]);q['convergence']={str(h):score(sample(lines[a],h),sample(lines[b],h)) for h in [2,1,.5,.25]}
 q['sigma10']=score(sample(lines[a],.5),sample(lines[b],.5),10);focus.append(q)
 for h in [2,.5]:assert abs(score(sample(lines[a],h),sample(lines[b],h))-score(sample(lines[b],h),sample(lines[a],h)))<1e-9
cases={
 'identical':([(0,0),(200,0)],[(0,0),(200,0)]),
 'half_missing':([(0,0),(200,0)],[(0,0),(100,0)]),
 'ten_percent_extension':([(0,0),(200,0)],[(0,0),(220,0)]),
 'parallel_offset_20cm':([(0,0),(200,0)],[(0,20),(200,20)]),
 'reverse_200cm':([(0,0),(200,0)],[(200,0),(0,0)]),
 'same_start_opposite':([(0,0),(200,0)],[(0,0),(-200,0)]),
 'mid_detour_100cm':([(0,0),(200,0)],[(0,0),(100,0),(100,50),(100,0),(200,0)]),
 'return_same_endpoint':([(0,0),(200,0)],[(0,0),(200,0),(0,0),(200,0)]),
 'same_shape_insert_20cm_excursion':([(0,0),(400,0)],[(0,0),(100,0),(100,10),(100,0),(400,0)]),
 'stationary_same':([(0,0)],[(0,0)]),
 'stationary_offset_20cm':([(0,0)],[(0,20)]),
 'stationary_vs_200cm':([(0,0)],[(0,0),(200,0)])}
synthetic={k:score(sample(prep(a),.25),sample(prep(b),.25)) for k,(a,b) in cases.items()}
assert abs(synthetic['identical']-100)<1e-9
assert abs(synthetic['stationary_offset_20cm']-50)<1e-9
assert abs(synthetic['parallel_offset_20cm']-50)<1e-9
kept=[]
for i in lines:
 if all(lookup[tuple(sorted([i,j]))]['meanIntegral']<75 for j in kept):kept.append(i)
out=dict(formula='D = min over monotone full alignments integral distanceCM*(ds+dt)/(Lp+Lq); S=100*2^(-D/20cm)',implementation='uniform physical arc cells; midpoint quadrature; horizontal/vertical/diagonal grid paths; zero/zero uses limiting start kernel',focus=focus,synthetic=synthetic,dedup=dict(count=len(kept),top10=kept[:10]),allPairs=base['allPairs'])
(HERE/'mean-integral-results.json').write_text(json.dumps(out,indent=2))
print(json.dumps({k:v for k,v in out.items() if k!='allPairs'},indent=2))
