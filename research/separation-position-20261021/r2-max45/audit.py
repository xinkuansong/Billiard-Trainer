from pathlib import Path
import json,hashlib,collections,re,shutil
r=Path(__file__).resolve().parent;base=r.parent;snap=r/'snapshot'
s=json.loads((r/'scan.json').read_text());old=json.loads((base/'scan.json').read_text());rows=s['rows'];speeds=sorted({x['v'] for x in rows});tips=sorted({(x['sx'],x['sy']) for x in rows})
assert speeds==[.75+i*.3125 for i in range(13)]
assert len(rows)==169 and len(tips)==13
assert tips==sorted({(x['sx'],x['sy']) for x in old['rows']})
assert (r/'sample.json').read_bytes()==(base/'sample.json').read_bytes()
matched=0
for row in rows:
 if row['v'] not in [.75,4.5]:continue
 prev=next(x for x in old['rows'] if (x['v'],x['sx'],x['sy'])==(row['v'],row['sx'],row['sy']))
 assert {k:v for k,v in row.items() if k!='id'}=={k:v for k,v in prev.items() if k!='id'},row['id']
 matched+=1
assert matched==26
for path,sha in json.loads((r/'sources.json').read_text()).items():assert hashlib.sha256((snap/path).read_bytes()).hexdigest()==sha,path
runs=list((snap/'output/local-test-runs').iterdir());assert len(runs)==1
run=runs[0];meta=json.loads((run/'run.json').read_text());assert meta['state']=='reclaimed'
log=(run/'evidence/test-results.log').read_text();assert '** TEST SUCCEEDED **' in log
assert re.search(r'Executed 1 test, with 0 failures',log)
shutil.copytree(run,r/'evidence'/run.name)
good=[x for x in rows if x['accepted']]
for x in good:assert x['settled'] and x['pot'] and not x['scratch'] and x['before']==0 and x['jaw']==0 and x['contacts']==1
review={'revision':'r2-max45','supersedes':'../review.json','onlyPhysicsParameterChange':'13 equally spaced speeds from 0.75 to 4.5 m/s, step 0.3125; same 13 tips, fixed board and frozen original production source','speedLevels':speeds,'tipCount':13,'trials':169,'accepted':len(good),'mainRailCounts':dict(sorted(collections.Counter(len(x['rails']) for x in good).items())),'sharedSpeedExactParity':matched,'nativeTest':'1 test, 0 failures; iPhone13 iOS26.3','sourceSnapshot':'../source-snapshot.zip plus r2 Research.swift; source hashes verified against original scan','secondShotPhysics':'not run; regions remain geometric candidates','visualReview':json.loads((r/'visual-review.json').read_text()),'cleanup':'core simulator lease released and temporary build workspace reclaimed; evidence archived; task snapshot removed'}
(r/'review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2))
shutil.rmtree(snap)
print(json.dumps(review,ensure_ascii=False,indent=2))
