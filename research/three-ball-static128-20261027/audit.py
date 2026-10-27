"""Independent output/subset audit, distribution-aware timing estimate, geometry contact sheet."""
from pathlib import Path
import json,gzip,hashlib,math,random,collections,sys
import numpy as np
import run as B
R,F=B.R,B.F
OUT=B.OUT

def band(a):
 a=abs(a)
 return '0–10°' if a<10 else '10–20°' if a<20 else '20–30°' if a<30 else '30–50°' if a<50 else '50°+'

def main():
 summary=json.loads((OUT/'summary.json').read_text());manifest=json.loads((B.INPUT/'manifest.json').read_text());source=B.INPUT/'selected-bank.jsonl.gz'
 assert B.sha(source)==manifest['files'][source.name]
 population={};bands=collections.Counter()
 with gzip.open(source,'rt') as f:
  for line in f:
   row=json.loads(line)
   for q in row['questions']:
    key=row['id']+'/second-cell:'+str(q['id']);population[key]=(row,q);bands[band(row['board']['angle'])]+=1
 expected=sorted(population,key=lambda key:hashlib.sha256((B.SEED+'\0'+key).encode()).digest())[:128]
 results=[json.loads((OUT/f'sample-{i:03}.json').read_text()) for i in range(1,129)]
 assert [B.identity(r['sample']) for r in results]==expected
 counts=collections.Counter();byband=collections.defaultdict(list);fullselected=[];passedgroups=0
 for result in results:
  s=result['sample'];key=B.identity(s);row,q=population[key];assert s['board']==row['board'] and s['second']==q['p'] and s['refs']==q['refs'];assert len(s['candidates'])==72
  passed=set()
  for g in result['groups']:
   eligible=[]
   for t in g['stops']:
    score=R.evaluate(t['position'],s['second'],R.ANCHORS[g['pocket']])[3]
    assert abs(score-t['score'][3])<1e-9
    if score>=85:eligible.append(t['rank'])
   assert eligible==g['eligibleRanks']
   matches=[c['candidate'] for c in g['checks'] if c['status']=='bounded_pass'];passed.update(matches)
   assert not matches or eligible
   if matches:
    passedgroups+=1;assert g['dense']['minimumMargin']>0 and g['dense']['points']>0
    assert g['dense']['comparisons']==g['dense']['points']*len(matches)
   for cid in matches:
    c=s['candidates'][cid];assert not c['reasons'] and c['nativePlacementLegal']
    assert c['bestInitial'] is None or c['bestInitial']['score']>s['firstMetric']['score']
    assert F.segment_distance(c['position'],s['second'],R.ANCHORS[g['pocket']])>=2*R.R
  block_ids=[]
  for row0 in range(0,6,2):
   for col0 in range(0,12,2):
    cells={r*12+c for r in (row0,row0+1) for c in (col0,col0+1)};group=sorted(cells&passed)
    kept=cells&set(result['blockSelectedIDs']);assert len(kept)==bool(group)
    if group:
     block=row0//2*6+col0//2;draw=B.rng('second-nonempty-2x2-preview-20261025-v1'+'\0'+key+'\0'+str(block)).choice(group);assert kept=={draw}
    block_ids.extend(kept)
  final=sorted(c['id'] for c in result['selectedPositions']);available=sorted(block_ids)
  assert final==sorted(B.rng('three-ball-after-block-random3-20261027-v1'+'\0'+key).sample(available,min(3,len(available))))
  if len(available)<3:assert final==available
  assert result['counts']['regionPassed']==len(passed)
  assert result['counts']['afterBlock']==len(available) and result['counts']['selected']==len(final)
  counts.update(result['counts']);byband[band(s['board']['angle'])].append(result['timing']['total'])
  fullselected.extend((key,c['id']) for c in result['selectedPositions'])
 assert dict(counts)==summary['counts']
 forms=json.loads((OUT/'formations.json').read_text());assert len(forms['items'])==len(fullselected)==365
 assert len({x['id'] for x in forms['items']})==len(forms['items'])
 assert all('trajectory' not in x and 'shots' not in x for x in forms['items'])
 for r in results:
  for c in r['selectedPositions']:
   item=next(x for x in forms['items'] if x['id']==B.identity(r['sample'])+'/third-cell:'+str(c['id']))
   assert item['third']==c['position'] and item['second']==r['sample']['second'] and item['pocket3Candidates']==c['legalPockets3']
 assert all(B.sha(B.ROOT/p)==h for p,h in summary['sourceHashes'].items())
 # Preserve original physics/source archive hashes; no fresh dynamics are asserted.
 assert all(B.sha(B.ROOT/p)==h for p,h in summary['input']['archiveShardSHA'].items())
 n=len(population);pool=summary['poolWallSeconds'];overhead=pool/(summary['taskSeconds']/8)
 linear=pool/128*n/3600
 weighted=sum(bands[k]*float(np.mean(ts)) for k,ts in byband.items())/8*overhead/3600
 rng=np.random.default_rng(202610270128);boot=[]
 for _ in range(3000):
  total=sum(bands[k]*float(rng.choice(ts,size=len(ts),replace=True).mean()) for k,ts in byband.items())
  boot.append(total/8*overhead/3600)
 estimate=dict(questions=n,workers=8,measuredPoolSeconds=pool,measuredEndToEndSeconds=summary['endToEndSeconds'],linearHours=linear,angleWeightedHours=weighted,bootstrapPercentileHours=np.percentile(boot,[5,95]).tolist(),bootstrapCaveat='sampling variation only, not runtime guarantee; machine load/thermal/rare hard layouts not covered',planningHours=[5,7],observedTaskSeconds=dict(p50=float(np.median([r['timing']['total'] for r in results])),p95=float(np.percentile([r['timing']['total'] for r in results],95)),maximum=max(r['timing']['total'] for r in results)),bands=[dict(band=k,population=bands[k],pilot=len(ts),meanTaskSeconds=float(np.mean(ts))) for k,ts in byband.items()],denseShare=summary['denseTaskSeconds']/summary['taskSeconds'],noFullGenerationStarted=True)
 B.write(OUT/'estimate.json',estimate)
 B.write(OUT/'output-audit.json',dict(passed=True,sourceSelectionVerified=True,all128QuestionsMatchParent=True,originalStopsNewScoreRecomputed=True,allNonemptyBlocksAndDrawsVerified=True,finalUniformDrawsReproduced=True,underThreeAllRetained=True,formations=365,passedRegionGroups=passedgroups,allFormationFieldsMatched=True,noTrajectories=True,sourceHashesUnchanged=True))
 print(json.dumps(estimate,ensure_ascii=False,indent=2))
 # Static scatter contact sheet for geometry inspection. Each panel has one independent B3.
 from PIL import Image,ImageDraw,ImageFont
 image=Image.new('RGB',(1500,1170),'#f4f6ef');draw=ImageDraw.Draw(image)
 font=ImageFont.truetype('/Library/Fonts/Arial Unicode.ttf',16);title=ImageFont.truetype('/Library/Fonts/Arial Unicode.ttf',24)
 draw.text((24,12),'128题静态筛选 · 前12个保留球形 · 无轨迹 / 未验证连续击打',fill='#163e35',font=title)
 for i,item in enumerate(forms['items'][:12]):
  x0=20+(i%3)*500;y0=88+(i//3)*270;scale=177
  draw.text((x0,y0-24),item['id'],font=font,fill='#24493f')
  draw.rectangle((x0,y0,x0+R.L*scale,y0+R.W*scale),fill='#185c50')
  for pt,col,lab in [(item['board']['cue'],'white','C'),(item['board']['object'],'#e4bc43','1'),(item['second'],'#4c95d9','2'),(item['third'],'#e18170','3')]:
   x=x0+(pt[0]+R.HX)*scale;y=y0+(pt[1]+R.HZ)*scale;r=R.R*scale
   draw.ellipse((x-r,y-r,x+r,y+r),fill=col);draw.text((x+6,y-18),lab,fill='white',font=font)
 image.save(OUT/'geometry-preview.png')

if __name__=='__main__':main()
