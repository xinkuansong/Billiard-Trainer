"""Assemble retained r1 + replacement r2 without modifying either raw run."""
from pathlib import Path
import hashlib,json,shutil,sys,collections
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'output/defense-bank-2500-20261103';OUT=BASE/'review'
partial='--partial' in sys.argv
bad=json.loads((BASE/'audit-r1-joint-threshold.json').read_text());excluded={e['id'] for e in bad['rejected']}
assert len(excluded)==11
OUT.mkdir(exist_ok=True);index=[];bindings={}
for version,source,main in [('r1',BASE,'main-r1.swift')]+([] if partial else [('r2',BASE/'refill-r2','main.swift')]):
    rows=json.loads((source/'index.json').read_text());runtime=OUT/'runtime'/version;runtime.mkdir(parents=True,exist_ok=True)
    bindings[version]={'directory':str(runtime.relative_to(OUT)),'mainFile':main}
    for name in ['source-manifest.json','asset-manifest.json','frozen-assets-audit.json','source-snapshot.tar.gz','build.json','execution.json','summary.json','protocol.json','proposals.json','geometry.json','seed.json']:
        shutil.copy2(source/name,runtime/name)
    hashes={}
    for e in rows:
        data=(source/e['file']).read_bytes();hashes[e['file']]=hashlib.sha256(data).hexdigest()
        if e['id'] in excluded:continue
        dest=OUT/e['file'];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
        index.append(dict(e,runtimeVersion=version))
    (runtime/'question-hashes.json').write_text(json.dumps(hashes,indent=2))
for name in ['geometry.json','protocol.json']:shutil.copy2(BASE/name,OUT/name)
if not partial:
    assert len(index)==2500 and len({e['id'] for e in index})==2500
    assert json.loads((BASE/'source-manifest.json').read_text())==json.loads((BASE/'refill-r2/source-manifest.json').read_text())
    assert json.loads((BASE/'asset-manifest.json').read_text())==json.loads((BASE/'refill-r2/asset-manifest.json').read_text())
    assert json.loads((BASE/'refill-r2/summary.json').read_text())['complete']
counts=collections.Counter(e['family'] for e in index)
(OUT/'index.json').write_text(json.dumps(index,indent=2));(OUT/'runtime-bindings.json').write_text(json.dumps(bindings,indent=2))
(OUT/'summary.json').write_text(json.dumps({'complete':not partial,'counts':counts,'count':len(index),'r1Retained':2489,'r2Replacements':0 if partial else 11},indent=2))
(OUT/'refill-report.json').write_text(json.dumps(dict(bad,finalCandidates=len(index),repair='continuous angular exposure >5%; original strict 4097-ray audit unchanged',r1Preserved=True),indent=2))
print(json.dumps({'assembled':len(index),'partial':partial,'output':str(OUT)}))
