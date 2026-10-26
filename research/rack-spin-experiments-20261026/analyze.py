import gzip,json,math,statistics,collections,sys,random,zlib
from pathlib import Path
O=Path('output/rack-spin-experiments-20261026')/sys.argv[1]
cal=json.load(open('output/rack-center-mechanism-20261026/calibration.json'))
p=O/'raw.jsonl.gz';text=zlib.decompressobj(31).decompress(p.read_bytes()).decode();rows=[json.loads(l) for l in text.splitlines() if l]
R=.028574999421834946;L=2.5399999618530273;W=1.2699999809265137;M=.17000000178813934
s=[]
def energy(x):return .5*M*(sum(v*v for v in x['v'])+.4*R*R*sum(v*v for v in x['w']))
for r in rows:
 if r['input']['condition']!='original':continue
 pts=[[p[0]*L-L/2,p[1]*L-W/2] for n,p in r['board'].items() if n!='cueBall'];N=len(pts)
 score=statistics.mean(min(math.dist(a,b) for j,b in enumerate(pts) if i!=j) for i,a in enumerate(pts))/cal['reference'][str(N)]['expectedMeanM'] if N>1 else None
 cc=r['cushionTrace'];gain=[energy(c['post'])-energy(c['pre']) for c in cc]
 longest=max(r['spinTail'],key=lambda x:x['tail']);lc=[c for c in cc if c['pre']['name']==longest['name']]
 s.append(dict(id=r['input']['rackID'],label=r['input']['experiment'],status=r['status'],termination=r['termination'],score=score,tail=longest['tail'],maxSpin=max(x['peakWy'] for x in r['spinTail']),duration=r['duration'],lastTranslation=r['lastTranslation'],scratch=r['cueScratched'],cpuMS=r['cpuSeconds']*1000,cushionCount=len(cc),energyGainCount=sum(x>1e-6 for x in gain),maxEnergyGain=max(gain,default=0),fastCushions=sum(c['pre']['v'][0]**2+c['pre']['v'][2]**2>2.5**2 for c in cc),peakSpinBeforeCushion=max((abs(c['pre']['w'][1]) for c in lc),default=0),peakSpinAfterCushion=max((abs(c['post']['w'][1]) for c in lc),default=0)))
summary={}
for label in dict.fromkeys(x['label'] for x in s):
 a=[x for x in s if x['label']==label];tails=sorted(x['tail'] for x in a)
 summary[label]=dict(n=len(a),settled=sum(x['status']=='settled' for x in a),meanScore=statistics.mean(x['score'] for x in a),pass1p2=sum(x['score']>=1.2 for x in a),meanTail=statistics.mean(tails),p90Tail=tails[int(.9*(len(a)-1))],maxTail=max(tails),tailOver5=sum(t>5 for t in tails),tailOver1=sum(t>1 for t in tails),meanPeakSpin=statistics.mean(x['maxSpin'] for x in a),scratch=sum(x['scratch'] for x in a),cpuMS=statistics.mean(x['cpuMS'] for x in a),cushions=sum(x['cushionCount'] for x in a),energyGainCount=sum(x['energyGainCount'] for x in a),maxEnergyGain=max(x['maxEnergyGain'] for x in a),failures=dict(collections.Counter(x['termination'] for x in a if x['status']!='settled')))
for name,val in [('summary',summary),('scalars',s)]: (O/(name+'.json')).write_text(json.dumps(val,indent=2))
print(json.dumps(summary,indent=2))
