from pathlib import Path
import json,hashlib,tarfile
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-heatmap-20261104/r2';HERE=Path(__file__).parent
sha=lambda b:hashlib.sha256(b).hexdigest()
d=json.loads((OUT/'grid.json').read_text());nx,nz=d['nx'],d['nz'];assert(nx,nz)==(101,51);assert len(d['cells'])==nx*nz
v=np.full((nx,nz,6),np.nan);coarse=v.copy();zero=tied=0
for i,c in enumerate(d['cells']):
 assert (c['ix'],c['iz'])==divmod(i,nz)
 if not c['valid']:continue
 a=np.array(c['widths']);b=np.array(c['coarseWidths']);assert a.shape==(6,) and np.isfinite(a).all() and (a>=0).all() and (a<=360).all()
 v[c['ix'],c['iz']]=a;coarse[c['ix'],c['iz']]=b;m=float(a.max());assert abs(c['maxDegrees']-m)<1e-12
 if m>0:
  assert c['bestPocket']==int(a.argmax());assert c['ties']==[p for p in range(6) if m-a[p]<=.001];assert abs(c['bestInterval']['widthDegrees']-m)<1e-12;tied+=len(c['ties'])>1
 else:assert c['bestPocket']==-1 and not c['ties'];zero+=1
assert abs(d['x'][0]+d['length']/2-d['radius'])<1e-10 and abs(d['z'][0]+d['width']/2-d['radius'])<1e-10
sx=np.nanmax(np.abs(v-v[::-1,:, :][:,:,[1,0,3,2,4,5]]));sz=np.nanmax(np.abs(v-v[:,::-1, :][:,:,[2,3,0,1,5,4]]))
selected_diff=float(np.nanmax(np.abs(np.nanmax(v,axis=2)-np.nanmax(coarse,axis=2))))
all_diff=float(np.nanmax(np.abs(v-coarse)))
assert selected_diff<.001,selected_diff
assert sx<.001 and sz<.001,(sx,sz)
summary=json.loads((OUT/'summary.json').read_text());assert summary['searchEdgeHits']==0
manifest=json.loads((OUT/'source-manifest.json').read_text());patch=json.loads((OUT/'research-patch.json').read_text())
extension=(HERE/'PipeWindow.swift').read_bytes();assert extension.split(b'    static func researchWindow')[0]==(ROOT/'research/pocket-window-20261103/PipeWindow.swift').read_bytes().split(b'    static func researchWindow')[0]
with tarfile.open(OUT/'source-snapshot.tar.gz') as t:
 for name,h in manifest.items():
  raw=t.extractfile('sources/'+name.removeprefix('QiuJi/')).read()
  if name.endswith('/AngleSceneCalculator.swift'):
   assert sha(raw)==patch['patchedSHA256'];assert sha(extension)==patch['extensionSHA256'];assert raw.endswith(b'\n'+extension);raw=raw[:-(len(extension)+1)]
  if name.endswith('/QiuJiApp.swift'):raw=raw.replace(b'// Research worker supplies main',b'@main')
  assert sha(raw)==h
 assert t.extractfile('main.swift').read()==(HERE/'main.swift').read_bytes()
not_nearest=[]
for c in d['cells']:
 if not c['valid'] or c['bestPocket']<0:continue
 p=np.array([d['x'][c['ix']],d['z'][c['iz']]]);nearest=min(range(6),key=lambda k:np.linalg.norm(np.array(d['pockets'][k]['center'])-p))
 if nearest not in c['ties']:
  not_nearest.append({'ix':c['ix'],'iz':c['iz'],'nearest':nearest,'best':c['bestPocket'],'nearestDegrees':c['widths'][nearest],'maxDegrees':c['maxDegrees']})
report={'passed':True,'gridSHA256':sha((OUT/'grid.json').read_bytes()),'points':nx*nz,'zeroCells':zero,'tiedCells':tied,'allPocketsCoarseFineMaxDegrees':all_diff,'selectedMaxCoarseFineMaxDegrees':selected_diff,'xMirrorMaxDegrees':float(sx),'zMirrorMaxDegrees':float(sz),'bestNotNearestCount':len(not_nearest),'examplesBestNotNearest':not_nearest[::max(1,len(not_nearest)//8)][:8],'sourceFilesVerified':len(manifest),'scope':'Full-grid aggregation, finite two-step convergence, mirror invariance, provenance. Not full continuous-angle proof, cue accessibility, or real-table validation.'}
(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
