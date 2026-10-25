from pathlib import Path
import sys,json,hashlib,math
from collections import defaultdict,Counter
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from sample_angle_curve import records
from filter_geometric_bank import retain_target
from pocket_geometry_filter import Geometry,layouts,validate_bank
BANK=ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
CAND=ROOT/'output/two-ball-second-candidates-20261024/second-ball-candidates.jsonl'
FULL=ROOT/'output/two-ball-independent125-full-20261024'
SEED='two-ball-downsample-13570-quarter-20261025-v1'
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def rank(scope,key):return hashlib.sha256((SEED+'\0'+scope+'\0'+str(key)).encode()).hexdigest()
def write(name,value):
 (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def quarter(n):return 0 if n==0 else max(1,(n+2)//4)
source_files=[BANK,CAND,FULL/'layouts.json',FULL/'schedule.json',FULL/'summary.json']
hashes={str(p.relative_to(ROOT)):digest(p) for p in source_files}
bank=json.loads(BANK.read_text());geo=bank['geometry'];g=Geometry(**{k:geo[k] for k in ['length','width','radius']});validate_bank(bank,g)
rs=list(records(bank));assert len(rs)==135700 and len({r[0] for r in rs})==135700
strata=defaultdict(list)
for lid,angle,pid,code in rs:strata[code].append(lid)
# Proportional quotas, integer largest remainder allocation, exact 13570.
quotas={k:len(v)//10 for k,v in strata.items()}
remaining=13570-sum(quotas.values())
for k in sorted(strata,key=lambda k:(-(len(strata[k])%10),rank('quota',k),k))[:remaining]:quotas[k]+=1
selected=set()
for k,ids in strata.items():selected.update(sorted(ids,key=lambda lid:(rank('initial',lid),lid))[:quotas[k]])
assert len(selected)==13570
OUT.mkdir(parents=True,exist_ok=False)
targets=[retain_target(t,selected) for t in bank['targets']];targets=[t for t in targets if t['combinationIndices']]
counts=Counter()
for t in targets:counts['corner' if t['pocket']<4 else 'middle']+=len(t['combinationIndices'])
policy={'version':SEED,'initialCount':13570,'initialStrata':'stored combinationIndices: angle x pocket type x cue distance x object distance x rail class (270 definitions)','initialQuota':'floor(N/10) plus largest remainder; ties SHA256; total exactly 13570; no rare-stratum minimum','selection':'lowest SHA256(seed + NUL + scope + NUL + stable ID), no replacement','secondQuota':'n=0 -> 0; n>0 -> max(1, floor(n/4+0.5)); each layout separately','secondSelection':'SHA256 with scope second:<layoutID> and original cellID; original coordinates unchanged; no spatial balancing','preview':'five selected layouts with lowest independent preview hash, no picking for appearance','coordinateSystem':'world XZ metres, +X right, +Z down in landscape, Y up','notApplied':['near-duplicate grouping','symmetry grouping','new geometry filters','new physics simulation','path collision filtering','second-shot ranking','P2 route deduplication']}
result=dict(bank,targets=targets,counts=dict(counts),sourceLayoutBankSHA256=hashes[str(BANK.relative_to(ROOT))],twoBallDownsampling=policy,contract=bank['contract']+' Stratified unique-ID reduction to 13570; companion candidates sampled separately to approximately one quarter.')
write('sampled-initial-bank.json',result);validate_bank(result,g)
(OUT/'selected-ids.txt').write_text('\n'.join(sorted(selected))+'\n')
write('sampling-policy.json',policy)
write('strata.json',[{'code':k,'combination':bank['combinationTable'][k],'sourceCount':len(v),'quota':quotas[k]} for k,v in sorted(strata.items())])
boards=json.loads((FULL/'layouts.json').read_text());assert len(boards)==135700
schedule=json.loads((FULL/'schedule.json').read_text());position={idx:pos for pos,idx in enumerate(schedule)}
board_map={b['id']:b for b in boards};assert selected<=board_map.keys()
write('layouts.json',[b for b in boards if b['id'] in selected])
write('simulation-index.json',[{'id':b['id'],'part':f"output/two-ball-independent125-full-20261024/parts/{position[i]//100:05}.jsonl.gz",'rowInPart':position[i]%100} for i,b in enumerate(boards) if b['id'] in selected])
preview_ids=sorted(selected,key=lambda lid:(rank('preview',lid),lid))[:5];preview=[];before=after=0;hist_before=Counter();hist_after=Counter();seen=set();sampled={};cell_before=Counter();cell_after=Counter()
with CAND.open() as f,(OUT/'second-ball-candidates.jsonl').open('x') as out:
 for line in f:
  r=json.loads(line);lid=r['id']
  if lid not in selected:continue
  assert lid not in seen;seen.add(lid);old=r['candidates'];n=len(old);k=quarter(n)
  assert len({c[0] for c in old})==n
  chosen=sorted(old,key=lambda c:(rank('second:'+lid,c[0]),c[0]))[:k];chosen.sort(key=lambda c:c[0])
  row={'id':lid,'candidates':chosen,'parentCandidateCount':n,'sampledCandidateCount':k,'parentRejected':r['rejected'],'samplingVersion':SEED}
  out.write(json.dumps(row,ensure_ascii=False,allow_nan=False)+'\n');sampled[lid]=row
  before+=n;after+=k;hist_before[n]+=1;hist_after[k]+=1;cell_before.update(c[0] for c in old);cell_after.update(c[0] for c in chosen)
  if lid in preview_ids:preview.append({'board':board_map[lid],'originalCandidates':old,'selectedCandidates':chosen})
assert seen==selected
preview.sort(key=lambda p:preview_ids.index(p['board']['id']))
write('preview-five.json',{'geometry':geo,'samples':preview})
# Independent source traversal and subset/field-preservation checks.
decoded=json.loads((OUT/'sampled-initial-bank.json').read_text());old_records={r[0]:r[1:] for r in rs};new_records=dict((r[0],r[1:]) for r in records(decoded))
assert set(new_records)==selected and all(old_records[k]==v for k,v in new_records.items())
old_layouts={lid:(c,o,p,a) for lid,c,o,p,a in layouts(bank)}
for lid,c,o,p,a in layouts(decoded):
 assert old_layouts[lid]==(c,o,p,a)
 b=board_map[lid];assert math.dist(c,b['cue'])<1e-12 and math.dist(o,b['object'])<1e-12 and p==b['pocket'] and a==b['angle']
actual=Counter(v[-1] for v in new_records.values());assert all(actual[k]==q for k,q in quotas.items());assert sum(actual.values())==13570
for k,v in strata.items():assert abs(quotas[k]-len(v)/10)<1
persisted=[json.loads(l) for l in (OUT/'second-ball-candidates.jsonl').read_text().splitlines()];assert len(persisted)==len({r['id'] for r in persisted})==13570
assert all(r==sampled[r['id']] for r in persisted)
with CAND.open() as f:
 for line in f:
  r=json.loads(line)
  if r['id'] not in selected:continue
  actual=sampled[r['id']]['candidates'];n=len(r['candidates'])
  expected=0 if not n else max(1,math.floor(n*.25+.5));assert len(actual)==expected
  originals={c[0]:c for c in r['candidates']};assert all(c==originals[c[0]] for c in actual)
  picked={c[0] for c in actual};ranking=sorted(originals,key=lambda cid:(rank('second:'+r['id'],cid),cid));assert picked==set(ranking[:expected])
assert all(digest(ROOT/p)==h for p,h in hashes.items())
summary={'initialSourceCount':135700,'initialSampledCount':13570,'sourceCandidateTotal':4437380,'selectedInitialCandidatesBeforeQuarter':before,'sampledSecondCandidates':after,'retentionWithinSelectedInitial':after/before,'meanCandidatesPerInitial':after/13570,'emptyInitialCount':hist_after[0],'beforeHistogram':dict(sorted(hist_before.items())),'afterHistogram':dict(sorted(hist_after.items())),'pocketTypeCounts':dict(counts),'nonemptyStrataBefore':len(strata),'nonemptyStrataAfter':sum(q>0 for q in quotas.values()),'preview':[{'id':p['board']['id'],'angle':p['board']['angle'],'before':len(p['originalCandidates']),'after':len(p['selectedCandidates'])} for p in preview]}
write('summary.json',summary)
write('cell-distribution.json',[{'cellID':i,'before':cell_before[i],'after':cell_after[i]} for i in range(72)])
write('angle-distribution.json',{'before':dict(sorted(Counter(r[1] for r in rs).items())),'after':dict(sorted(Counter(v[0] for v in new_records.values()).items()))})
write('verification.json',{'passed':True,'uniqueInitialIDs':13570,'stratumQuotasWithinOneOfTenPercent':True,'candidateCountsAndSelectionsVerified':True,'sourceCoordinatesAndIDsUnchanged':True,'sourceSHAUnchanged':True,'simulationIndexIDsMatch':True,'previewIsIndependentHashSample':True})
write('manifest.json',{'policy':policy,'sourceSHA256':hashes,'scriptSHA256':digest(Path(__file__)),'outputsSHA256':{p.name:digest(p) for p in OUT.iterdir() if p.is_file()}})
print(json.dumps(summary,ensure_ascii=False,indent=2))
