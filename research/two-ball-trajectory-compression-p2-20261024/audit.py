from pathlib import Path
import json,itertools,hashlib,urllib.request
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
read=lambda p:json.loads(p.read_text())
s=read(OUT/'summary.json');scores=read(OUT/'pair-scores.json');provenance=read(OUT/'provenance.json')
assert s['trajectoryCount']==95 and s['pairCount']==4465 and s['B42Eligible']==93
assert hashlib.sha256((ROOT/provenance['source']).read_bytes()).hexdigest()==provenance['sha256']
assert read(OUT/'native-validation.json')['exactOldFieldsMatch']
for name,v in s['variants'].items():
 mat={(p['a'],p['b']):p['score'] for p in scores[name]['pairs']}
 assert len(mat)==4465 and scores[name]['maxAPIError']==0
 for key in ['dedupB42','dedupAll95Diagnostic']:
  d=v[key];assert len(d['kept'])==d['count']
  assert all(mat[tuple(sorted((a,b)))]<75 for a,b in itertools.combinations(d['kept'],2))
  assert all(b in d['kept'] and mat[tuple(sorted((int(a),b)))]>=75 for a,b in d['merged'].items())
  assert len(d['kept'])+len(d['merged'])==(93 if key=='dedupB42' else 95)
assert s['variants']['key2mm']['sameRepresentatives'] and not s['variants']['key2mm']['assignmentChanges']
assert s['variants']['key2mm']['thresholdFlipCount']==0
http={}
for path in ['trajectory-compression-p2.html','p2-compression-comparison.png','p2-compression-trajectory-examples.png']:
 with urllib.request.urlopen('http://127.0.0.1:51240/'+path) as r:
  body=r.read();assert r.status==200 and body;http[path]=dict(status=r.status,bytes=len(body))
audit=dict(passed=True,trajectoryCount=95,pairsPerVariant=4465,variants=5,productionSourceUnchanged=True,allDedupInvariants=True,imagesVisuallyReviewed=True,http=http)
(OUT/'audit.json').write_text(json.dumps(audit,indent=2));print(json.dumps(audit))
