#!/usr/bin/env python3
"""Rank same-run controlled removals. Deltas overlap and are not power shares."""
import argparse,json
from pathlib import Path
from statistics import median
ORDER=['base-0','direct-shadow-off','base-1','reflection-off','base-2','ball-native','base-3','cloth-shader-off','base-4','contact-off','base-5','native-shadow-off','base-6','room-off','base-7','aa1','base-8','scale75','base-9']
NAMES={'candidate-1':'台呢保留粗糙度候选-1','candidate-2':'台呢保留粗糙度候选-2','direct-shadow-off':'台呢直接球影遮挡计算','reflection-off':'球面64次反射积分','ball-native':'整套球面自定义着色','cloth-shader-off':'台呢材质整体（自定义着色与原生光照）','cloth-pbr-off':'台呢切换constant材质（粗糙度输入同时改变）','contact-off':'接触环境遮蔽','native-shadow-off':'原生阴影通道','room-off':'房间可见几何','aa1':'MSAA4→1像素管线诊断','scale75':'线性分辨率100%→75%诊断'}
def analyze(root, combined_cloth=False, cloth_candidate=False):
 combined_cloth = combined_cloth or cloth_candidate
 order=['base-0','candidate-1','base-1','candidate-2','base-2'] if cloth_candidate else ['base-0','cloth-pbr-off','base-1','cloth-shader-off','base-2'] if combined_cloth else ORDER
 prefix='ab-rs-candidate-' if cloth_candidate else 'ab-rs-cloth-' if combined_cloth else 'ab-audit-'
 rows=[]
 for name in order:
  path=root/f'{prefix}{name}.json'
  if not path.exists(): rows.append(None);continue
  d=json.loads(path.read_text());f=d.get('frames',[]);g=[x['gpuMS'] for x in f if x.get('gpuMS',0)>0 and not x.get('error',0)]
  errs=[]
  if len(g)!=len(f) or len(g)<=10: errs.append('missing/invalid GPU samples')
  if d['thermalStart']!=0 or d['thermal']!=0: errs.append('thermal state not nominal')
  if d.get('executionEnvironment') == 'simulator' or 'simulator' in d['gpuDevice'].lower(): errs.append('simulator excluded from hardware ranking')
  if d.get('cameraMoves') or d['requestedFPS']!=60: errs.append('workload mismatch')
  evidence=root/f'{prefix}{name}-drawable.png'
  fixture=root/f'{prefix}{name}-fixture.json'
  if not evidence.exists() or not fixture.exists(): errs.append('actual drawable/fixture missing')
  keys=json.loads(fixture.read_text())['visibleBallKeys'] if fixture.exists() else []
  if not keys: errs.append('empty board')
  if cloth_candidate:
   if not d.get('clothCandidateComparison') or d.get('clothPrototype') != name.startswith('candidate-'): errs.append('candidate state mismatch')
  if combined_cloth:
   if d.get('sceneProfile') != 'RS' or not d.get('combinedClothAudit'): errs.append('not a production RS residual audit')
   if d.get('executionEnvironment') != 'physical-device': errs.append('physical-device environment not attested')
   if fixture.exists():
    fixture_data=json.loads(fixture.read_text())
    if fixture_data.get('profile') != 'RS': errs.append('fixture profile mismatch')
    changed=fixture_data.get('changedMaterialsOrLights',0)
    if (name.startswith('base-') and changed != 0) or (not name.startswith('base-') and changed <= 0): errs.append('unexpected mutation count')
  rows.append({'name':name,'gpuMS':median(g) if g else None,'cpuEncodeMS':median([x['sceneEncodeMS'] for x in f]) if f else None,'drawableAcquireMS':median([x['drawableAcquireMS'] for x in f]) if f else None,'frames':len(g),'device':d['gpuDevice'],'mode':d.get('rankingMode'),'width':d['width'],'height':d['height'],'sampleCount':d['sampleCount'],'ballKeys':keys,'errors':errs})
 pairs=[]
 for i in range(1,len(order),2):
  a,c,b=rows[i-1:i+2];errors=[]
  if any(x is None for x in [a,c,b]): pairs.append({'component':NAMES[order[i]],'valid':False,'errors':['missing segment']});continue
  errors=[e for r in [a,c,b] for e in r['errors']]
  if len({r['device'] for r in [a,c,b]})!=1 or len({r['mode'] for r in [a,c,b]})!=1:errors.append('device/mode mismatch')
  if (a['width'],a['height'],a['sampleCount'])!=(b['width'],b['height'],b['sampleCount']) or a['sampleCount']!=4:errors.append('baseline quality mismatch')
  if order[i]!='scale75' and (a['width'],a['height'])!=(c['width'],c['height']):errors.append('resolution mismatch')
  if order[i]=='scale75' and any(abs(c[k]-a[k]*.75)>1 for k in ['width','height']):errors.append('unexpected scaled resolution')
  if c['sampleCount']!=(1 if order[i]=='aa1' else 4):errors.append('unexpected MSAA')
  if a['ballKeys']!=b['ballKeys'] or a['ballKeys']!=c['ballKeys']:errors.append('different board')
  base=(a['gpuMS']+b['gpuMS'])/2 if a['gpuMS'] and b['gpuMS'] else None
  drift=abs(a['gpuMS']-b['gpuMS'])/base if base else None
  if drift is None or drift>.05:errors.append('baseline drift >5%')
  delta=base-c['gpuMS'] if base and c['gpuMS'] else None
  pairs.append({'component':NAMES[order[i]],'profile':order[i],'valid':not errors,'errors':errors,'baselineMS':base,'candidateMS':c['gpuMS'],'savedMS':delta,'savedPercent':delta/base*100 if delta is not None else None,'baselineDrift':drift})
 return {'scope':'single paired fixed-scene hardware command-buffer spans; not full app CPU or watts; nested removals must not be added','segments':rows,'pairs':pairs,'rankedValid':sorted([p for p in pairs if p['valid']],key=lambda p:p['savedMS'],reverse=True)}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--combined-cloth',action='store_true');p.add_argument('--cloth-candidate',action='store_true');a=p.parse_args();r=analyze(a.directory,a.combined_cloth,a.cloth_candidate);a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(json.dumps(r['rankedValid'],ensure_ascii=False,indent=2))
