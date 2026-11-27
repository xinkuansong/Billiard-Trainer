from pathlib import Path
import json,hashlib,tarfile,math,os
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ.get('POCKET_OUTPUT',str(ROOT/'output/pocket-window-20261103/r3')))
sha=lambda b:hashlib.sha256(b).hexdigest()
rows=json.loads((OUT/'results.json').read_text());by={x['id']:x for x in rows};R=.028575
assert len(rows)==16
width=lambda id:by[id]['window']['totalWidthDegrees']
assert width('N')>width('M')>width('F')>0
assert width('SN')>width('SF')>0
assert abs(width('F')-width('FM'))<1e-5
assert width('L2')>width('F') and width('L3')>width('F')

def line_dist(points,a,b):
 a=np.array(a);b=np.array(b);v=b-a;t=np.clip(((points-a)*v).sum(axis=1)/(v*v).sum(),0,1)
 return np.linalg.norm(points-(a+t[:,None]*v),axis=1)
def jaw_dist(points,j):
 c=np.array(j['center']);v=points-c;ang=np.arctan2(v[:,1],v[:,0]);a=j['angleA'];d=math.atan2(math.sin(j['angleB']-a),math.cos(j['angleB']-a));off=np.arctan2(np.sin(ang-a),np.cos(ang-a));inside=(off>=-1e-10)&(off<=d+1e-10) if d>=0 else (off<=1e-10)&(off>=d-1e-10)
 ends=np.minimum(np.linalg.norm(points-(c+j['radius']*np.array([math.cos(a),math.sin(a)])),axis=1),np.linalg.norm(points-(c+j['radius']*np.array([math.cos(a+d),math.sin(a+d)])),axis=1))
 arc=np.where(inside,np.abs(np.linalg.norm(v,axis=1)-j['radius']),ends)
 return np.minimum(arc,line_dist(points,j['lineA'],j['lineB']))
checks=[];inside=[];outside=[]
for row in rows:
 w=row['window'];assert not any(w['edgeStates']);assert abs(w['totalWidthDegrees']-row['coarseWidth'])<1e-5
 assert w['stepDegrees']<=.025001
 target=np.array(w['target']);bounds=[]
 for interval in w['intervals']:
  assert interval['rightDegrees']>interval['leftDegrees']
  assert abs(interval['widthDegrees']-(interval['rightDegrees']-interval['leftDegrees']))<1e-10
  for key in ['leftEnd','midEnd','rightEnd']:
   end=np.array(interval[key]);n=int(math.ceil(np.linalg.norm(end-target)/.00001))+1
   points=np.linspace(target,end,n)
   distances=[float(jaw_dist(points,j).min()) for j in w['geometry']['jaws']]+[float(line_dist(points,seg['a'],seg['b']).min()) for seg in w['geometry']['rails']]
   minimum=min(distances);assert minimum>=R-0.000002,(row['id'],key,minimum)
   bounds.append({'side':key,'minimumClearance':minimum,'spacingMaxMeters':.00001})
 for p in row['rollingProbes']:
  assert p['cleanPot']==(p['pocket']==f"pocket_{row['pocket']}" and p['railContacts']==0)
  assert p['termination']=='settled',p['termination']
  (inside if 0<p['fraction']<1 else outside).append(p)
 search=row.get('zeroWindowSearch',[])
 if not w['intervals']:
  assert len(search)==243
  assert len({(round(p['deltaDegrees'],3),round(p['speed'],3)) for p in search})==243
  assert all(p['termination']=='settled' for p in search)
 pots=[p for p in search if p['pocket']==f"pocket_{row['pocket']}"]
 checks.append({'id':row['id'],'widthDegrees':w['totalWidthDegrees'],'denseClearanceChecks':bounds,'zeroWindowTrials':len(search),'zeroWindowPots':len(pots),'zeroWindowPotsWithCushion':sum(bool(p['cushions']) for p in pots),'examples':pots[:3]})
manifest=json.loads((OUT/'source-manifest.json').read_text());patch=json.loads((OUT/'research-patch.json').read_text());verified=0
with tarfile.open(OUT/'source-snapshot.tar.gz') as t:
 for name,h in manifest.items():
  data=t.extractfile('sources/'+name.removeprefix('QiuJi/')).read()
  if name.endswith('/AngleSceneCalculator.swift'):
   assert sha(data)==patch['patchedSHA256'];extension=(ROOT/'research/pocket-window-20261103/PipeWindow.swift').read_bytes();assert sha(extension)==patch['extensionSHA256'];assert data.endswith(b'\n'+extension);data=data[:-(len(extension)+1)]
  if name.endswith('/QiuJiApp.swift'):data=data.replace(b'// Research worker supplies main',b'@main')
  assert sha(data)==h,name;verified+=1
 assert t.extractfile('main.swift').read()==(ROOT/'research/pocket-window-20261103/main.swift').read_bytes()
report={'passed':True,'sourceFilesVerified':verified,'resultsSHA256':sha((OUT/'results.json').read_bytes()),'cases':checks,'insideClean':[sum(p['cleanPot'] for p in inside),len(inside)],'outsideClean':[sum(p['cleanPot'] for p in outside),len(outside)],'scope':'Finite two-grid convergence, independent dense spatial clearance, monotonic/mirror controls and actual rolling events. Not exhaustive continuous angular proof or human pot probability.'}
(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='cases'},ensure_ascii=False,indent=2))
