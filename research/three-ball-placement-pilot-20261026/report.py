from pathlib import Path
import json,gzip,math,html
import experiment as E
OUT=E.OUT
DISPLAY_MAX_ERROR=0.0

def simplify(points,tol=.0005):
 if len(points)<3:return points
 a,b=points[0],points[-1];ds=[E.segment(p,a,b) for p in points];i=max(range(len(ds)),key=lambda k:ds[k])
 if ds[i]<=tol:
  global DISPLAY_MAX_ERROR
  DISPLAY_MAX_ERROR=max(DISPLAY_MAX_ERROR,ds[i]);return [a,b]
 return simplify(points[:i+1],tol)[:-1]+simplify(points[i:],tol)

def build():
 audit=E.read(OUT/'audit.json');assert audit['passed'];full={}
 with gzip.open(OUT/'all-chain-replay/chains.jsonl.gz','rt') as f:
  for line in f:
   v=json.loads(line);full[(v['sample'],v['candidate'],v['chain'])]=v
 data=[]
 for i in range(1,6):
  d=E.read(OUT/f'sample-{i}.json');s=d['sample'];s={k:v for k,v in s.items() if k not in ['candidates','routes']};candidates=[]
  for c in d['candidates']:
   cc={k:v for k,v in c.items() if k not in ['chains','routeChecks']};cc['chains']=[];cc['routeChecks']=c.get('routeChecks',[])
   for j,ch in enumerate(c['chains']):
    shots=[]
    for v in full[(i,c['id'],j)]['shots']:
     req,r=v['request'],v['result'];paths={name:simplify([p[1:] for p in path]) for name,path in r['physicalPaths'].items()}
     shots.append(dict(cue=req['cue'],object=req['object'],obstacles=req['obstacles'],pocket=req['pocket'],v=r['v'],sx=r['sx'],sy=r['sy'],stop=r['stop'],rails=r['rails'],paths=paths))
    cc['chains'].append(dict(firstRank=ch['firstRank'],pocket2=ch['pocket2'],pocket3=ch['pocket3'],comfort3=ch['comfort3'],shots=shots))
   candidates.append(cc)
  data.append(dict(sample=s,counts=d['counts'],candidates=candidates))
 payload=dict(samples=data,geometry=E.G,anchors=E.ANCHORS,summary=E.read(OUT/'generation.json'),audit={k:audit[k] for k in ['chains','maxIndependentComfortError','productionBankUnchanged']})
 E.write(OUT/'viewer-data.json',payload)
 template=(E.HERE/'viewer.html').read_text();(OUT/'index.html').write_text(template.replace('/*__DATA__*/',json.dumps(payload,ensure_ascii=False,separators=(',',':'))))
 E.write(OUT/'display-audit.json',dict(passed=DISPLAY_MAX_ERROR<=.0005,maxNativeSampleDeviationMeters=DISPLAY_MAX_ERROR,chainCount=len(full),svgCurves='physical 120Hz + event frames, target ends at pre-capture pocket entry',indexSHA=E.sha(OUT/'index.html')))
 print('Viewer bytes',(OUT/'index.html').stat().st_size)
if __name__=='__main__':build()
