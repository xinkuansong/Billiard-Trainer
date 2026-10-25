from pathlib import Path
import json,math,zipfile,hashlib
OUT=Path(__file__).resolve().parent
req=json.loads((OUT/'request.json').read_text());rows=json.loads((OUT/'results.json').read_text())['rows']
assert len(rows)==13 and [r['v'] for r in rows]==req['speeds']
assert all(r['sx']==r['sy']==0 and r['direction']==req['direction'] and r['settled'] for r in rows)
def finite(v):
    if isinstance(v,dict):return all(finite(x) for x in v.values())
    if isinstance(v,list):return all(finite(x) for x in v)
    return not isinstance(v,(int,float)) or math.isfinite(v)
assert finite(rows)
original=json.loads((OUT.parent/'r2-max45/scan.json').read_text())
ref=next(r for r in original['rows'] if r['sx']==r['sy']==0 and r['v']==2.625)
now=rows[6];delta=math.dist(ref['stop'],now['stop']);assert delta<.0001
geom=json.loads((OUT.parent/'sample.json').read_text())['geometry']
def roundall(v):
    if isinstance(v,dict):return {k:roundall(x) for k,x in v.items()}
    if isinstance(v,list):return [roundall(x) for x in v]
    if isinstance(v,float):return round(v,6)
    return v
data={**req,'rows':[{k:v for k,v in r.items() if k!='cueTimes'} for r in rows],'geometry':geom}
text=(OUT/'visual-template.html').read_text().replace('__DATA__',json.dumps(roundall(data),ensure_ascii=False,separators=(',',':')))
dest=Path('/Users/song/.codex/visualizations/2026/10/21/01a15f02-cbf1-70b2-adb0-199936e10fc6/center-speed-thirteen.html')
dest.write_text(text);(OUT/'center-speed-thirteen.html').write_text(text)
assert dest.stat().st_size<1000000
hashes=json.loads((OUT/'source-hashes.json').read_text())
with zipfile.ZipFile(OUT.parent/'source-snapshot.zip') as z:
    same={n:hashes[n]==hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.startswith('QiuJi/Core/Physics/') and n.endswith('.swift')}
assert all(same.values())
report=dict(samples=13,allFixed=True,sourcePhysicsParity=same,baselineStopDeltaMetres=delta,pots=sum(r['pot'] for r in rows),scratches=sum(r['scratch'] for r in rows),rows=[{k:r[k] for k in ['v','rails','pot','scratch','length','stop']} for r in rows],fragment=str(dest),bytes=dest.stat().st_size)
(OUT/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False))
