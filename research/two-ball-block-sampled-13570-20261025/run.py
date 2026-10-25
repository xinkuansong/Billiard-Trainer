"""Select one original candidate per occupied 2x2 block for the frozen 13,570 IDs."""
from pathlib import Path
from collections import defaultdict,Counter
import json,hashlib,random,statistics,shutil,time,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
INITIAL=ROOT/'output/two-ball-downsample-13570-quarter-20261025'
CAND=ROOT/'output/two-ball-second-candidates-20261024/second-ball-candidates.jsonl'
PREVIEW=ROOT/'output/two-ball-block-sampling-preview-20261025/comparison-data.json'
SEED='second-nonempty-2x2-preview-20261025-v1'
VERSION='second-nonempty-2x2-full-13570-v1'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def write(name,obj):
 (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def bid(cid):return (cid//12//2)*6+(cid%12//2)
def choose(lid,block,rows):
 seed=hashlib.sha256((SEED+'\0'+lid+'\0'+str(block)).encode()).digest()
 return random.Random(int.from_bytes(seed,'big')).choice(sorted(rows,key=lambda c:c[0]))
start=time.perf_counter()
paths=[CAND,PREVIEW]+[INITIAL/n for n in ['selected-ids.txt','layouts.json','simulation-index.json','sampled-initial-bank.json','second-ball-candidates.jsonl','manifest.json']]
hashes={str(p.relative_to(ROOT)):sha(p) for p in paths}
prior=json.loads((INITIAL/'manifest.json').read_text())
assert hashes[str(CAND.relative_to(ROOT))]==prior['sourceSHA256'][str(CAND.relative_to(ROOT))]
for name in ['selected-ids.txt','layouts.json','simulation-index.json','sampled-initial-bank.json','second-ball-candidates.jsonl']:
 assert sha(INITIAL/name)==prior['outputsSHA256'][name]
ids=(INITIAL/'selected-ids.txt').read_text().splitlines();assert len(ids)==len(set(ids))==13570;wanted=set(ids)
layouts=json.loads((INITIAL/'layouts.json').read_text());assert {b['id'] for b in layouts}==wanted
geometry=json.loads((INITIAL/'sampled-initial-bank.json').read_text())['geometry']
preview=json.loads(PREVIEW.read_text());assert preview['seed']==SEED
assert all(sum(bid(i)==b for i in range(72))==4 for b in range(18))
OUT.mkdir(parents=True,exist_ok=False)
policy={'version':VERSION,'seed':SEED,'scope':'frozen 13570 initial IDs; read complete original geometrically filtered candidate lists, not prior quarter subset','grid':{'columns':12,'rows':6,'blockColumns':2,'blockRows':2,'blockCount':18,'origin':'top-left in landscape; non-overlapping'},'blockID':'(cellID // 12 // 2)*6 + (cellID % 12 // 2)','selection':'one uniformly random existing candidate per nonempty block; singleton always retained; empty block omitted','random':'SHA256(seed + NUL + layoutID + NUL + decimal blockID), big-endian integer, Python Random.choice(cellID-sorted candidates)','coordinates':'source XZ metres unchanged; +X right / +Z down in landscape','quantity':'number of occupied blocks, not one-quarter quota','simulation':'reuse prior independent125 results by ID; no new simulation or postprocessing'}
write('sampling-policy.json',policy)
for n in ['selected-ids.txt','layouts.json','simulation-index.json']:shutil.copy2(INITIAL/n,OUT/n)
seen=set();old_total=new_total=0;hist=Counter();old_hist=Counter();occupancies=Counter();cells=Counter();blocks=Counter();selected_rows={};source_line_count=0
with CAND.open() as f,(OUT/'second-ball-candidates.jsonl').open('x') as out:
 for line in f:
  source_line_count+=1;r=json.loads(line);lid=r['id']
  if lid not in wanted:continue
  assert lid not in seen;seen.add(lid);groups=defaultdict(list)
  assert len({c[0] for c in r['candidates']})==len(r['candidates'])
  for c in r['candidates']:
   assert len(c)==5 and 0<=c[0]<72
   groups[bid(c[0])].append(c)
  chosen=sorted([choose(lid,b,v) for b,v in sorted(groups.items())],key=lambda c:c[0])
  assert len(chosen)==len(groups)<=18
  row={'id':lid,'candidates':chosen,'parentCandidateCount':len(r['candidates']),'sampledCandidateCount':len(chosen),'blockCandidateCounts':[len(groups[b]) for b in range(18)],'parentRejected':r['rejected'],'samplingVersion':VERSION}
  selected_rows[lid]=row;out.write(json.dumps(row,ensure_ascii=False,allow_nan=False)+'\n')
  old_total+=len(r['candidates']);new_total+=len(chosen);hist[len(chosen)]+=1;old_hist[len(r['candidates'])]+=1
  occupancies.update(row['blockCandidateCounts']);cells.update(c[0] for c in chosen);blocks.update(bid(c[0]) for c in chosen)
assert source_line_count==135700 and seen==wanted
assert old_total==442866
# Independent read-back audit: nested physical grid grouping, exact source tuples,
# every nonempty block once, coordinate cell check and deterministic draw replay.
loaded=[json.loads(line) for line in (OUT/'second-ball-candidates.jsonl').read_text().splitlines()]
assert len(loaded)==len({r['id'] for r in loaded})==13570
assert all(r==selected_rows[r['id']] for r in loaded)
verified=0;singletons=0
with CAND.open() as f:
 for line in f:
  src=json.loads(line);lid=src['id']
  if lid not in wanted:continue
  output=selected_rows[lid];actual={c[0]:c for c in output['candidates']};all_src={c[0]:c for c in src['candidates']};checked=set()
  for row in range(0,6,2):
   for col in range(0,12,2):
    block=row//2*6+col//2;slots=[(row+dr)*12+col+dc for dr in range(2) for dc in range(2)]
    available=[all_src[cid] for cid in slots if cid in all_src];picks=[cid for cid in slots if cid in actual]
    assert len(picks)==bool(available) and output['blockCandidateCounts'][block]==len(available)
    if available:
     assert actual[picks[0]]==choose(lid,block,available);checked.add(picks[0])
     if len(available)==1:assert picks[0]==available[0][0];singletons+=1
  assert checked==set(actual)
  for cid,c in actual.items():
   assert c==all_src[cid]
   g=geometry;col=int((c[1]+g['length']/2-g['radius'])/((g['length']-2*g['radius'])/12));row=int((c[2]+g['width']/2-g['radius'])/((g['width']-2*g['radius'])/6));assert row*12+col==cid
  assert output['parentRejected']==src['rejected'];verified+=1
assert verified==13570
preview_checks=[]
for c in preview['comparisons']:
 lid=c['new']['board']['id'];assert selected_rows[lid]['candidates']==c['new']['selectedCandidates']
 preview_checks.append({'id':lid,'count':len(selected_rows[lid]['candidates']),'exactMatch':True})
for p,h in hashes.items():assert sha(ROOT/p)==h
for n in ['selected-ids.txt','layouts.json','simulation-index.json']:assert (OUT/n).read_bytes()==(INITIAL/n).read_bytes()
counts=[r['sampledCandidateCount'] for r in loaded]
summary={'state':'complete','auditPassed':True,'initialCount':13570,'sourceSecondCandidates':old_total,'sampledSecondCandidates':new_total,'omittedCandidates':old_total-new_total,'retentionRate':new_total/old_total,'mean':new_total/13570,'median':statistics.median(counts),'minimum':min(counts),'maximum':max(counts),'emptyLayouts':hist[0],'nonemptyLayouts':13570-hist[0],'histogram':dict(sorted(hist.items())),'sourceHistogram':dict(sorted(old_hist.items())),'blockOccupancyHistogram':dict(sorted(occupancies.items())),'singletonBlocksRetained':singletons,'oldQuarterSampleCount':112437,'changeVersusOldQuarter':new_total-112437,'previewMatches':preview_checks,'candidateFileBytes':(OUT/'second-ball-candidates.jsonl').stat().st_size,'elapsedSeconds':time.perf_counter()-start}
write('summary.json',summary)
write('position-counts.json',{'cellCounts':[cells[i] for i in range(72)],'blockCounts':[blocks[i] for i in range(18)]})
write('verification.json',{'passed':True,'all13570InitialIDsUnchanged':True,'completeOriginalCandidateSourceUsed':True,'everyNonemptyBlockExactlyOne':True,'allSingletonsRetained':True,'allCandidateFieldsAndCoordinatesUnchanged':True,'allCoordinateCellIDsVerified':True,'allDeterministicChoicesReplayed':True,'readBackMatches':True,'sourceHashesUnchanged':True,'fivePreviewResultsExact':True,'layoutsAndSimulationIndexByteIdentical':True})
write('manifest.json',{'policy':policy,'pythonVersion':sys.version,'sourceSHA256':hashes,'scriptSHA256':sha(Path(__file__)),'initialBankReference':str((INITIAL/'sampled-initial-bank.json').relative_to(ROOT)),'initialBankReferenceNote':'Only initial shapes and stable IDs are reused; companion candidate sampling policy is replaced by this manifest, not the old quarter metadata.','outputsSHA256':{p.name:sha(p) for p in OUT.iterdir() if p.is_file()}})
print(json.dumps(summary,ensure_ascii=False,indent=2))
