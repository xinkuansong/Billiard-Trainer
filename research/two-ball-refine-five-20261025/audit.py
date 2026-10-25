from pathlib import Path
import sys,json,gzip,math,hashlib,subprocess,collections
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(HERE));import run as R
read=lambda p:json.loads(p.read_text());data=read(OUT/'data.json');s=read(OUT/'summary.json');total=0;top=0;bounds=0;zeroRestore=set();zeroTargets=set();hist=collections.Counter();nativeSeconds=0
for i,(old,new) in enumerate(zip(data['before'],data['boards']),1):
 source=ROOT/old['simulationSource']['part'];assert R.sha(source)==new['stats']['sourceSHA256'];original=json.loads(gzip.decompress(source.read_bytes()).splitlines()[old['simulationSource']['rowInPart']]);allrows={r['comboIndex']:r for r in original['rows']}
 generated=read(OUT/f'generated-{i}.json');assert len(generated['rows'])==new['stats']['newSimulationCount'];allrows.update({r['comboIndex']:r for r in generated['rows']})
 for r in generated['rows']:
  p=allrows[r['origin']['parentComboIndex']];stage=r['origin']['stage'];dv=abs(r['velocity']-p['velocity']);dx=abs(r['spinX']-p['spinX']);dy=abs(r['spinY']-p['spinY']);bounds+=1
  assert .6<=r['velocity']<=4.5 and r['spinX']**2+r['spinY']**2<=.25+1e-8
  if stage=='removeSideSpin':
   assert r['spinX']==0 and dv==dy==0 and not R.railseq(p)
   if r['status']=='success' and R.railseq(r):zeroTargets.add((i,r['comboIndex']))
  elif stage=='speed':assert 0<dv<=.200001 and dx==dy==0
  elif stage=='vertical':assert dv<=.100001 and dx==0 and 0<dy<=.060001
  elif stage=='side':assert dv<=.100001 and 0<dx<=.030001 and dy==0 and R.railseq(p)
  else:raise AssertionError(stage)
 for c,oc in zip(new['candidates'],old['candidates']):
  assert c['cellID']==oc['cellID'] and c['position']==oc['position']
  assert c['ranked']==sorted(c['ranked'],key=lambda q:(q['score'],q['comboIndex']))
  assert len({q['comboIndex'] for q in c['ranked']})==c['eligibleCount']
  for q in c['ranked']:
   r=allrows[q['comboIndex']];assert R.reason(r) is None
   metric,why=R.assess(r,c['position'],new['board']);assert why is None and metric=={k:v for k,v in q.items() if k!='comboIndex'}
   angle=R.independent_angle(r['cueStop'],c['position'],R.G.anchors()[q['pocket']]);assert abs(angle-q['angle'])<1e-7 and angle<=25+1e-8
   if 'origin' in r and (i,r['origin']['parentComboIndex']) in zeroTargets and not R.railseq(r):zeroRestore.add((i,r['origin']['parentComboIndex']))
   total+=1
  hist[len(c['top5'])]+=1;top+=len(c['top5'])
 full=OUT/f'dedup-{i}-full-check.json';subprocess.run([str(HERE/'dedup'),str(OUT/f'dedup-{i}-input.json'),str(full),'--full'],check=True)
 a=read(full);b=read(OUT/f'dedup-{i}-output.json');assert [c['top5'] for c in a['results']]==[c['top5'] for c in b['results']];nativeSeconds+=a['nativeSeconds']
assert total==s['afterEligible'] and top==s['afterTop'] and bounds==s['newSimulations']
cleanup=read(OUT/'cleanup.json');assert cleanup['workerExitCode']==cleanup['shutdownExitCode']==0
v={'passed':True,'allEligiblePairsChecked':total,'topReferences':top,'parameterBoundsChecked':bounds,'fullGreedyParityLayouts':5,'fullGreedyAuditSeconds':nativeSeconds,'sourceHashesUnchanged':True,'zeroSideChangedRailCount':len(zeroTargets),'zeroSideRootsRecoveredViaTune':len(zeroRestore),'zeroSideRecoveredRoots':sorted(zeroRestore),'workerExitedAndDeviceShutdown':True,'topHistogram':dict(hist)}
(OUT/'audit.json').write_text(json.dumps(v,indent=2));print(json.dumps(v))
