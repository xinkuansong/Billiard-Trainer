#!/usr/bin/env python3
"""Audit stored event routes; natively retry ambiguous/indirect proofs with a five-shot budget."""
import argparse, collections, gzip, hashlib, html, json, math, shutil, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'output/accuracy-middle-v3-20261021'
OUT=ROOT/'output/accuracy-middle-direct-v4-20261021'
BANK=ROOT/'output/accuracy-layout-bank-v3-ids-20261021/grid-layouts-with-combinations.json'
INVENTORY=ROOT/'output/accuracy-grid-staggered-v3-20261021/inventory.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,separators=(',',':')))
def owner(i):
    if 6<=i<14:return [0,2,1,3][(i-6)//2]
    if 14<=i<18:return 4+(i-14)//2
    if 18<=i<38:return [3,2,1,0][(i-18)//5]
    if 38<=i<44:return 4+(i-38)//3
    if 44<=i<52:return [0,2,1,3][(i-44)//2]
    if 52<=i<56:return 4+(i-52)//2

def event_route(r):
    """Conservative sufficient proof. Initial main-rail contact needs native recorder evidence."""
    p=r.get('proof')
    if not p:return ['no-proof']
    if not p['settled']:return ['incomplete']
    contacts=0;reasons=set();pot=False;last=-1
    for e in p['events']:
        assert e['time']>=last;last=e['time']
        if e['kind']=='pocket' and e['ball']=='object':
            pot=e['pocketID']==f"pocket_{r['pocket']}"
            break
        if e['kind']=='ballBall':
            if {e['ball'],e['otherBall']}!={'cueBall','object'}:reasons.add('other-ball')
            contacts+=1
            if contacts>1:reasons.add('second-contact')
        elif e['kind']=='ballCushion':
            if e['ball']=='cueBall' and contacts==0:reasons.add('cue-bank')
            if e['ball']=='object':
                if contacts!=1:reasons.add('contact-order')
                i=e.get('cushionIndex',-1)
                if i<6:reasons.add('main-rail-needs-recorder')
                elif owner(i)!=r['pocket']:reasons.add('other-pocket-mouth')
    if contacts!=1:reasons.add('contact-count')
    if not pot:reasons.add('no-target-pot')
    return sorted(reasons)

def old_records():
    request=json.loads((OLD/'consumed-request.json').read_text())
    for bi,b in enumerate(request['batches']):
        f=OLD/b['file'];assert sha(f)==b['sha256']
        inputs=json.loads(f.read_text())['samples'];results=json.loads((OLD/f'results-{bi:03d}.json').read_text())
        assert len(inputs)==len(results)==b['count']
        for s,r in zip(inputs,results):
            assert s['sampleIndex']==r['sampleIndex'] and s['cellID']==r['cellID'] and s['pocket']==r['pocket']
            yield s,r

def prepare():
    OUT.mkdir(exist_ok=True);assert not (OUT/'consumed-request.json').exists()
    (OUT/'review-paths').mkdir(exist_ok=True)
    oldmanifest=json.loads((OLD/'source-manifest.json').read_text())
    for name,h in oldmanifest['files'].items():
        assert sha(OLD/'source'/name)==h
        if name!='QiuJiTests/TrainingSpeedScreeningTests.swift':assert sha(ROOT/name)==h,name
    groups=collections.Counter();reasons=collections.Counter();retry=[];controls={};regression=[]
    for s,r in old_records():
        why=event_route(r)
        group='miss' if not r.get('proof') else 'retry' if why else 'reuse'
        groups[group]+=1
        if group=='retry':retry.append((s,why));reasons.update(why)
        else:
            # Spread positive controls across angle/rail/pocket/scratch; negative controls across angle.
            key=(group,s['cell']['angleIndex'],s['cell']['railIndex'],s['pocket'],r['trials'][-1]['cuePocketed']) if group=='reuse' else (group,s['cell']['angleIndex'])
            rank=zlib.crc32(f"direct-v4:{s['sampleIndex']}".encode())
            if key not in controls or rank<controls[key][0]:controls[key]=(rank,s,group)
        if s['sampleIndex'] in [229995,271595]:regression.append(s)
    assert groups=={'reuse':201466,'retry':830,'miss':70414}
    chosen=[dict(sample=s,role='retry',reasons=why) for s,why in retry]+[dict(sample=s,role=group,reasons=[]) for _,s,group in controls.values()]
    chosen.sort(key=lambda x:x['sample']['sampleIndex'])
    batches=[]
    for offset in range(0,len(chosen),250):
        chunk=chosen[offset:offset+250];file=f'inputs-{len(batches):03d}.json'
        dump(OUT/file,dict(sourceFingerprint=oldmanifest['fingerprint'],samples=[x['sample'] for x in chunk]))
        batches.append(dict(file=file,sha256=sha(OUT/file),count=len(chunk),offset=offset))
    dump(OUT/'selection.json',chosen);dump(OUT/'regression-inputs.json',dict(sourceFingerprint=oldmanifest['fingerprint'],samples=regression))
    files={n:sha(ROOT/n) for n in oldmanifest['files']}
    files['scripts/training-question-bank/middle_direct_v4.py']=sha(Path(__file__))
    fingerprint=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()
    for n in files:
        dest=OUT/'source'/n;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,dest)
    dump(OUT/'source-manifest.json',dict(fingerprint=fingerprint,files=files))
    sourcefiles={str(p.relative_to(ROOT)):sha(p) for p in sorted(OLD.glob('results-*.json'))}
    sourcefiles[str(BANK.relative_to(ROOT))]=sha(BANK)
    dump(OUT/'prior-evidence-checksums.json',sourcefiles)
    dump(OUT/'request.json',dict(sourceFingerprint=fingerprint,inventorySHA256=sha(INVENTORY),workers=18,total=len(chosen),batches=batches))
    dump(OUT/'preaudit.json',dict(groups=groups,reasons=reasons,nativeCount=len(chosen),controlCount=len(controls)))
    print(json.dumps(dict(groups=groups,reasons=reasons,nativeCount=len(chosen),controlCount=len(controls)),indent=2))



def finish():
    from layout_combination_ids import entries, classify_vectorized
    import grid_inventory_report as geom
    request=json.loads((OUT/'consumed-request.json').read_text());progress=json.loads((OUT/'progress.json').read_text())
    assert progress['complete'] and progress['done']==request['total']
    assert sha(INVENTORY)==request['inventorySHA256']
    manifest=json.loads((OUT/'source-manifest.json').read_text())
    for n,h in manifest['files'].items():
        assert sha(OUT/'source'/n)==h
        if n=='QiuJiTests/TrainingSpeedScreeningTests.swift' and sha(ROOT/n)!=h:
            # The later review-only method does not change the frozen screening implementation.
            current=(ROOT/n).read_text();start=current.index('    /// Review-only replay at a proven speed;')
            end=current.index('    @MainActor func testMiddleConcurrencyBenchmark()',start)
            assert current[:start]+current[end:]==(OUT/'source'/n).read_text()
        elif n!='scripts/training-question-bank/middle_direct_v4.py':assert sha(ROOT/n)==h,n
    for n,h in json.loads((OUT/'prior-evidence-checksums.json').read_text()).items():assert sha(ROOT/n)==h,n
    chosen=json.loads((OUT/'selection.json').read_text());native=[];feedback=collections.Counter()
    for bi,b in enumerate(request['batches']):
        assert sha(OUT/b['file'])==b['sha256']
        results=json.loads((OUT/f'results-{bi:03d}.json').read_text())
        assert len(results)==b['count']
        for r in results:
            i=len(native);s=chosen[i]['sample'];assert r['sampleIndex']==i and r['cellID']==s['cellID'] and r['pocket']==s['pocket']
            trials=r['trials'];assert 1<=len(trials)<=5
            lo,hi=.5,8
            for j,t in enumerate(trials):
                assert abs(t['speed']-(lo+hi)/2)<1e-6
                assert t['routeAccepted']==(t['routeReason']=='direct-pot')
                feedback[t['feedback']]+=1
                if t['feedback']=='short-increase':lo=t['speed']
                elif t['feedback'] in ['indirect-probe-lower','mouth-miss-decrease','deflection-probe-lower']:hi=t['speed']
                else:assert t['feedback'] in ['pot','incomplete-stop'] and j==len(trials)-1
            assert bool(r.get('proof'))==any(t['routeAccepted'] for t in trials)
            if r.get('proof'):
                assert trials[-1]['routeAccepted'] and r['proof']['spinX']==r['proof']['spinY']==0
                assert r['proof']['speed']==trials[-1]['speed']
                # Main-rail frozen-compression cases require a separate recorder audit if present.
                assert not event_route(r),event_route(r)
                path=json.loads((OUT/f'review-paths/{i}.json').read_text());assert path['route']=='direct-pot' and path['speed']==r['proof']['speed']
            native.append(r)
    assert len(native)==len(chosen)==progress['done']
    replacements={x['sample']['sampleIndex']:(i,r,x['role']) for i,(x,r) in enumerate(zip(chosen,native))}
    oldcounts=collections.Counter();newcounts=collections.Counter();kept=set();removed=[];recovered=[];controls=0;scratch=0;original_total=0
    gallerypool=[];oldproofs={};calls=0
    for s,old in old_records():
        original_total+=1;sid=s['sampleIndex'];cid=s['cellID'];oldcounts[cid]+=bool(old.get('proof'))
        if sid in replacements:
            i,r,role=replacements[sid]
            if role=='reuse':
                assert r.get('proof') and old.get('proof')
                assert [t['speed'] for t in r['trials']]==[t['speed'] for t in old['trials']]
                assert r['proof']==old['proof'],sid
                controls+=1
            elif role=='miss':
                assert not r.get('proof') and not old.get('proof')
                assert [t['speed'] for t in r['trials']]==[t['speed'] for t in old['trials']];controls+=1
            else:
                calls+=len(r['trials'])
                if r.get('proof'):recovered.append(sid)
                else:removed.append(s)
        else:
            r=old
            if r.get('proof'):assert not event_route(r)
        if r.get('proof'):
            newcounts[cid]+=1;kept.add((s['targetIndex'],s['maskIndex'],s['distanceBit']))
            scratch+=bool(r['trials'][-1]['cuePocketed'])
            if sid in replacements:
                i,_,role=replacements[sid];gallerypool.append(dict(sample=s,result=r,nativeIndex=i,role=role))
    assert original_total==272710 and sum(oldcounts.values())==202296
    assert len(kept)==201466+len(recovered) and len(removed)+len(recovered)==830
    for sid in [229995,271595]:assert sid in {s['sampleIndex'] for s in removed}
    data=json.loads(BANK.read_text());oldtargets=data['targets'];targets=[];bankcounts=collections.Counter();corners=0
    for t in oldtargets:
        oldindices=t['combinationIndices'];masks=[0]*len(t['masks']);codes=[]
        for ordinal,mi,bit in entries(t,data['distanceSamples']):
            if t['pocket']<4 or (t['inventoryTargetIndex'],mi,bit) in kept:
                masks[mi]|=1<<bit;code=oldindices[ordinal];codes.append(code);bankcounts[data['combinationTable'][code]['id']]+=1
                corners+=int(t['pocket']<4)
        if codes:
            new=dict(t,masks=masks,combinationIndices=codes)
            if t['pocket']<4:assert new==t
            targets.append(new)
    assert corners==580804
    data['targets']=targets;data['counts']['middle']=len(kept)
    data['sourceLayoutBankSHA256']=sha(BANK);data['validationSourceFingerprint']=request['sourceFingerprint']
    data['contract']='Layouts only; persisted combination IDs; no solutions or trajectories. Corners remain unverified geometry candidates. Middle: direct specified-pocket pot, no pre-contact cue bank, no object bank or other-mouth visit, no second ball collision; own-mouth and initial frozen compression allowed; cue scratch ignored. Fixed center tip/C-to-G, at most five midpoint speed trials.'
    dest=OUT/'grid-layouts-with-combinations.json';dump(dest,data)
    reloaded=json.loads(dest.read_text());assert reloaded==data
    for t in reloaded['targets']:assert t['combinationIndices']==classify_vectorized(t,reloaded)
    gz=dest.with_suffix('.json.gz');gz.write_bytes(gzip.compress(dest.read_bytes(),compresslevel=9,mtime=0));assert gzip.decompress(gz.read_bytes())==dest.read_bytes()
    inv=json.loads(INVENTORY.read_text());rows=[]
    for c in inv['cells']:
        cid=geom.cell_id(c['cell']);before=c['gridPlacement']+c['boundaryPlacement'];middle=c['cell']['pocketType']==1
        previous=oldcounts[cid] if middle else before;count=newcounts[cid] if middle else before
        assert bankcounts[cid]==count
        rows.append(dict(cellID=cid,cell=c['cell'],geometric=before,previous=previous,remaining=count,removed=previous-count,status='direct-screened' if middle else 'geometry-only'))
    middle=[r for r in rows if r['cell']['pocketType']==1]
    summary=dict(geometricMiddle=272710,previousMiddle=202296,middle=len(kept),removed=len(removed),recovered=len(recovered),reused=201466,
        scratchPasses=scratch,corner=580804,total=580804+len(kept),nativeLayouts=len(native),controlCount=controls,
        nativeCalls=sum(len(r['trials']) for r in native),retryCalls=calls,wallSeconds=progress['wallSeconds'],workers=18,
        feedback=feedback,occupied=sum(r['remaining']>0 for r in middle),atLeast500=sum(r['remaining']>=500 for r in middle),
        empty=sum(r['remaining']==0 for r in middle),jsonBytes=dest.stat().st_size,gzipBytes=gz.stat().st_size,
        rail=[dict(rail=i,previous=sum(r['previous'] for r in middle if r['cell']['railIndex']==i),remaining=sum(r['remaining'] for r in middle if r['cell']['railIndex']==i)) for i in range(3)],
        angles=[dict(angle=i,previous=sum(r['previous'] for r in middle if r['cell']['angleIndex']==i),remaining=sum(r['remaining'] for r in middle if r['cell']['angleIndex']==i)) for i in range(5)],
        scope='Stored-event audit of all 272710; native five-attempt correction of 830 plus controls; corners unchanged and unverified')
    dump(OUT/'audit.json',summary);dump(OUT/'cell-results.json',rows);dump(OUT/'removed-layouts.json',removed);dump(OUT/'recovered-indices.json',recovered);dump(OUT/'gallery-pool.json',gallerypool)
    dump(OUT/'final-checksums.json',{str(p.relative_to(OUT)):sha(p) for p in [dest,gz,OUT/'audit.json',OUT/'cell-results.json']})
    print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument("action",choices=["prepare","finish"]);args=parser.parse_args()
    prepare() if args.action=="prepare" else finish()
