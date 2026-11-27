"""Audit full coverage and source provenance, then export four role-specific catalogs."""
from pathlib import Path
from collections import Counter,defaultdict
import csv,gzip,hashlib,json,math,sys,zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-approved-filter-20261104'
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda name,obj:(OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2,allow_nan=False))
manifest=read(OUT/'input-manifest.json');policy=read(OUT/'protocol.json');summary=read(OUT/'summary.json')
assert summary['complete'] and summary['searchEdgeHits']==0
geometryAudit=read(OUT/'geometry-audit.json');assert geometryAudit['complete']
geometryQuarantine=[]
# The original global gate failed and remains recorded. Apply the same strict
# convergence requirement to each target using the complete replay ledger;
# unresolved targets are quarantined, never declared to have passed that gate.
windowAudit=read(OUT/'window-convergence-audit.json')
assert windowAudit['complete'] and windowAudit['limitDegrees']==.001 and windowAudit['replayMetricsMatched']
for p,h in windowAudit['evidence'].items():assert sha(ROOT/p)==h,p
for p,h in read(OUT/'algorithm.json').items():assert sha(ROOT/p)==h,p
fingerprint=sha(OUT/'algorithm.json')
for p,h in manifest['sourceFiles'].items():assert sha(ROOT/p)==h,p
assert read(OUT/'controls-audit.json')['passed']
counts=Counter();bybank=defaultdict(Counter);accepted=[];previous=-1;evals=0;boardcount=0
pilot=read(ROOT/'output/defense-reuse-20261104/evaluated.json')
samples=read(ROOT/'output/defense-t02-expand-20261104/samples.json')
sampleKeys={({'one':'one','two_black':'two','two_own':'two','three':'three'}[q['kind']],q['sourceID'],q['own']) for q in samples}
sampleDecisions={}
expected={}
for q in pilot:
 bank={'one':'one','two_black':'two','two_own':'two','three':'three'}[q['kind']]
 w=q['ownAttack']['best']['cueWidth'];c=max(o.get('comfort',{}).get('total',0) for o in q['ownAttack']['options'])
 key=(bank,q['sourceID'],q['own']);value=1e-6<w<=policy['cueWidthLimitDegrees'] and c<policy['maxRepresentativeComfortLimit']
 if key in expected:assert expected[key]==value
 expected[key]=value
seencontrols=set();convergence=[]
for chunk in manifest['chunks']:
 path=OUT/chunk['file'];assert sha(path)==chunk['sha256'];rows=read(path);stem=path.stem
 done=read(OUT/f'results/{stem}-done.json')
 assert done['fingerprint']==fingerprint and done['inputSHA256']==chunk['sha256']
 for p,h in done['outputs'].items():assert sha(OUT/p)==h,p
 lookup={r['ordinal']:r for r in rows};wanted={(r['ordinal'],i) for r in rows for i in range(len(r['positions']))}
 decisions=read(OUT/f'results/{stem}-decisions.json');dec={(r['ordinal'],r['own']):r for r in decisions}
 assert set(dec)==wanted and len(dec)==len(decisions)==chunk['evaluations']
 cc=Counter(d['status'] for d in decisions);assert dict(cc)==done['counts']
 counts.update(cc);bybank[chunk['bank']].update(cc);evals+=len(dec);boardcount+=len(rows)
 for r in rows:
  assert r['ordinal']==previous+1;previous=r['ordinal']
  for own in range(len(r['positions'])):
   key=(r['bank'],r['sourceID'],own)
   if key in sampleKeys:sampleDecisions[key]=dec[(r['ordinal'],own)]
   if key in expected:
    status=dec[(r['ordinal'],own)]['status']
    assert (status in ['accepted','unresolved_endpoint','unresolved_convergence'])==expected[key],(key,status,expected[key])
    seencontrols.add(key)
 passing=read(OUT/f'results/{stem}-accepted.json');unresolved=read(OUT/f'results/{stem}-unresolved.json')
 assert {(r['ordinal'],r['own']) for r in passing}=={k for k,d in dec.items() if d['status']=='accepted'}
 assert len(passing)==cc['accepted'] and len(unresolved)==cc['unresolved_convergence']+cc['unresolved_endpoint']
 for r in passing+unresolved:
  for k,v in lookup[r['ordinal']].items():assert r[k]==v,(r['sourceID'],k)
  a=r['ownAttack'];assert sorted(o['pocket'] for o in a['options'])==list(range(6))
  assert a['best']['cueWidth']==max(o['cueWidth'] for o in a['options'])
  assert r['maxPocketComfort']==max(o.get('comfort',{}).get('total',0) for o in a['options'])
  assert 1e-6<a['best']['cueWidth']<=policy['cueWidthLimitDegrees'] and r['maxPocketComfort']<policy['maxRepresentativeComfortLimit']
 for r in passing:assert r['mappingDifferenceDegrees']<=1e-7
 ga=read(OUT/'geometry-chunks'/f'{stem}.json')
 assert ga['inputSHA256']==sha(OUT/f'results/{stem}-accepted.json')
 assert ga['auditorSHA256']==geometryAudit['auditorSHA256']==sha(Path(__file__).parent/'audit_chunks.py')
 good={tuple(k) for k in ga['passing']};bad={(q['ordinal'],q['own']) for q in ga['quarantine']}
 assert not good & bad and good | bad == {(q['ordinal'],q['own']) for q in passing}
 accepted.extend(q for q in passing if (q['ordinal'],q['own']) in good)
 geometryQuarantine.extend(ga['quarantine']);convergence.extend(unresolved)
assert seencontrols==set(expected)
assert evals==manifest['targetEvaluations']==summary['targetEvaluations'] and boardcount==manifest['boards']==summary['boards']
assert dict(counts)==summary['counts'] and len(accepted)+len(geometryQuarantine)==counts['accepted']
assert len(accepted)==geometryAudit['passedTargets']
write('geometry-quarantine.json',geometryQuarantine)
windowPassing={tuple(k) for k in windowAudit['passing']}
windowBad={(q['ordinal'],q['own']) for q in windowAudit['quarantine']}
allMetricKeys={(q['ordinal'],q['own']) for c in manifest['chunks'] for q in read(OUT/f'results/{Path(c["file"]).stem}-accepted.json')}
assert not windowPassing & windowBad and windowPassing | windowBad == allMetricKeys
windowQuarantine=[q for q in accepted if (q['ordinal'],q['own']) in windowBad]
accepted=[q for q in accepted if (q['ordinal'],q['own']) in windowPassing]
write('window-quarantine.json',windowAudit['quarantine'])
acceptedKeys={(q['bank'],q['sourceID'],q['own']) for q in accepted}
sampleReport=[]
assert set(sampleDecisions)==sampleKeys
for q in samples:
 bank={'one':'one','two_black':'two','two_own':'two','three':'three'}[q['kind']]
 key=(bank,q['sourceID'],q['own']);decision=sampleDecisions[key]
 exported=key in acceptedKeys
 if not exported:
  assert decision['status'] in ['unresolved_endpoint','unresolved_convergence'] or (decision['ordinal'],q['own']) in windowBad or any(r['ordinal']==decision['ordinal'] and r['own']==q['own'] for r in geometryQuarantine),('Unexplained approved example loss',q['sampleID'])
 sampleReport.append(dict(sampleID=q['sampleID'],sourceID=q['sourceID'],own=q['own'],exported=exported,decision=decision))
write('approved-sample-dispositions.json',sampleReport)
# Resolve all passing coordinates independently from the original bank resources.
want={(r['bank'],r['sourceID']) for r in accepted};sources={}
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import layouts
for lid,c,o,p,a in layouts(read(ROOT/'QiuJi/Resources/training-grid-bank.json')):
 if ('one',lid) in want:sources[('one',lid)]=(list(c),[list(o)])
for p in manifest['sourceFiles']:
 if not p.endswith('.gz'):continue
 raw=gzip.decompress((ROOT/p).read_bytes())
 if '/TwoBallBank/' in p:
  for row in map(json.loads,raw.splitlines()):
   for q in row['questions']:
    key=('two',str(row['id'])+'/'+str(q['id']))
    if key in want:sources[key]=(row['board']['cue'],[row['board']['object'],q['p']])
 else:
  for row in json.loads(raw):
   key=('three',row['id'])
   if key in want:sources[key]=(row['board']['cue'],[row['board']['object'],row['second'],row['third']])
assert set(sources)==want
for r in accepted:assert (r['cue'],r['positions'])==sources[(r['bank'],r['sourceID'])]
# Exact mirror equivalence only; near-identical float coordinates are intentionally retained.
def canon(cue,positions,numbers,kind):
 forms=[]
 for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)]:
  def pt(p):return tuple(0.0 if x==0 else x for x in (p[0]*sx,p[1]*sz))
  forms.append((pt(cue),tuple(sorted((n,*pt(p)) for n,p in zip(numbers,positions)))))
 raw=json.dumps([kind,min(forms)],separators=(',',':'))
 return hashlib.sha256(raw.encode()).hexdigest()
def expand(r):
 n=len(r['positions']);own=r['own']
 if n==1:yield 'one',[8],own
 elif n==2:
  for kind,ob,en in [('two_black',8,9),('two_own',1,8)]:
   nums=[en]*2;nums[own]=ob;yield kind,nums,1-own
 else:
  for enemy in range(3):
   if enemy==own:continue
   nums=[8]*3;nums[own]=1;nums[enemy]=9;yield 'three',nums,enemy
names={'one':'一颗黑八','two_black':'两颗球·我方打黑八','two_own':'两颗球·对方打黑八','three':'三颗球·双方各剩一颗加黑八'}
groups={k:{} for k in names};rawcounts=Counter()
for r in accepted:
 for kind,nums,enemy in expand(r):
  rawcounts[kind]+=1;key=canon(r['cue'],r['positions'],nums,kind)
  alias={k:r[k] for k in ['bank','sourceID','ordinal','own','originalAngle','originalPocket']}
  alias.update(numbers=nums,cue=r['cue'],positions=r['positions'],cueWidth=r['ownAttack']['best']['cueWidth'],maxRepresentativeComfort=r['maxPocketComfort'])
  if key not in groups[kind]:
   record=dict(r);record.update(kind=kind,numbers=nums,enemy=enemy,formationID=key,aliases=[])
   groups[kind][key]=record
  groups[kind][key]['aliases'].append(alias)
exportdir=OUT/'catalogs';exportdir.mkdir(exist_ok=True)
fields=['formationID','kind','sourceID','own','enemy','numbers','cue','positions','cueWidthDegrees','maxRepresentativeComfort','sourceAliases']
for kind,records in groups.items():
 ordered=sorted(records.values(),key=lambda r:(r['maxPocketComfort'],r['ownAttack']['best']['cueWidth'],r['formationID']))
 with gzip.open(exportdir/f'{kind}.jsonl.gz','wt',encoding='utf-8') as f:
  for r in ordered:f.write(json.dumps(r,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n')
 with (exportdir/f'{kind}.csv').open('w',newline='',encoding='utf-8-sig') as f:
  writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
  for r in ordered:
   row={k:r[k] for k in fields if k in r};row.update(cueWidthDegrees=r['ownAttack']['best']['cueWidth'],maxRepresentativeComfort=r['maxPocketComfort'],sourceAliases=len(r['aliases']))
   for k in ['numbers','cue','positions']:row[k]=json.dumps(row[k],separators=(',',':'))
   writer.writerow(row)
report=dict(passed=True,sourceFilesVerified=len(manifest['sourceFiles']),sourceBoards=boardcount,targetEvaluations=evals,chunkCount=len(manifest['chunks']),pilotTargetControls=len(seencontrols),metricAcceptedTargets=counts['accepted'],acceptedTargets=len(accepted),geometryPassedTargets=geometryAudit['passedTargets'],geometryQuarantinedTargets=len(geometryQuarantine),windowQuarantinedTargets=len(windowQuarantine),originalGlobalWindowGatePassed=False,approvedSampleControls=24,approvedSamplesExported=sum(r["exported"] for r in sampleReport),counts=counts,byBank=bybank,rawRoleCounts=rawcounts,uniqueRoleCounts={k:len(v) for k,v in groups.items()},uniqueSourceBoards=len(want),dedup=policy['dedup'],defenseStrokesVerified=False,appIntegrated=False)
write('catalog-summary.json',report)
write('export-source-manifest.json',{str(p.relative_to(ROOT)):sha(p) for p in Path(__file__).parent.glob('*.py')})
lines=['# 防守开局球形全量筛选','', '采用用户看图认可的 T02 上限（更难的 T01 也保留）：六袋中最大母球瞄准容错角 ≤ %.15f°，六袋代表路线中的最高旧舒适分 < %.15f；角度须 > 0.000001°。'%(policy['cueWidthLimitDegrees'],policy['maxRepresentativeComfortLimit']), '', '| 类别 | 通过球权分配 | 精确坐标及镜像去重后 |','|---|---:|---:|']
for k in names:lines.append(f'| {names[k]} | {rawcounts[k]} | {len(groups[k])} |')
lines+=['',f'完整扫描 {boardcount:,} 个源球形、{evals:,} 次己方目标球评估；检查 {len(manifest["sourceFiles"])} 个源文件哈希，分片全覆盖。','', 'catalogs 下 CSV 便于查看坐标和指标；JSONL.gz 包含六袋路线数据、球号、来源和所有通过门槛的重复来源。球数不含母球。坐标为 XZ 米制，+X 为图上方、+Z 为右方；数组顺序和源库一致。own/enemy 是 positions 的零基下标。', '', '同一个两球目标评估展开为“我方打8/对方打9”和“我方打1/对方打8”；三球中其余两球各尝试对方9/黑8。球权不同分别保留。只合并精确坐标及 X/Z 镜像，不将浮点近似球形强行归并；aliases 保留各原始坐标、角色及指标。', '', '这些是开局进攻足够困难的候选球形，并非已验证的防守题或参考答案。尚未验证可行防守击球、犯规、下一杆局面和对方进攻风险。舒适分只检查每袋最大窗口的代表路线，并非连续路线最优值；未建立总分或真实命中率。原球库的生成分布和过滤仍保留，不能视为穷尽所有球形。','', '没有直接窗口、低于数值分辨率、初始摆位不合法、边界端点不完整、收敛不一致和独立几何未通过的评估分别记录在 summary.json / catalog-summary.json 与 results 分片中；均不混入通过集合。', '', '复现：先 python3 research/defense-approved-filter-20261104/prepare.py；通过 local_test_lifecycle.py 托管执行 run.py（DEFENSE_FROZEN_FROM 指向 output/defense-bank-2500-20261103）；执行 audit_chunks.py 完成独立几何审计后，再执行 export.py 和 package.py。已有分片仅在输入和算法哈希一致时可续跑。','', '算法、输入及生产源快照哈希：algorithm.json、input-manifest.json、source-manifest.json。数值回归：controls-audit.json。']
lines += ['', f'首次全局角域收敛检查未通过；已按相同0.001°门槛逐一重放所有入选位置的六袋角域，另隔离 {len(windowQuarantine)} 个目标评估（window-quarantine.json）。原失败记录保留在 initial-export-gate.json。', '', '补查执行 research/defense-window-audit-20261104/run.py 后，运行 verify_windows.py，再 export.py / package.py。approved-sample-dispositions.json 记录24道认可样题的导出状态；数值回归通过不覆盖全部端点数据质量。']
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
