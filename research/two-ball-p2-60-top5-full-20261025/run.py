"""Frozen 13,570-layout / 173,577-B postprocessing; no physics simulations."""
from pathlib import Path
import json,gzip,hashlib,time,sys,math,subprocess,os,fcntl,traceback,io,multiprocessing
from collections import Counter,defaultdict
from concurrent.futures import ProcessPoolExecutor,as_completed
from datetime import datetime,timezone

ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
SOURCE=ROOT/'output/two-ball-block-sampled-13570-20261025'
OLD=ROOT/'output/two-ball-independent125-full-20261024'
BENCH=ROOT/'output/two-ball-p2-60-top5-benchmark-20261025'
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry
from filter_second_ball_preview import score,independent_score,independent_segment_distance
read=lambda p:json.loads(p.read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
encoded=lambda d:json.dumps(d,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()
now=lambda:datetime.now(timezone.utc).isoformat()
def atomic(p,b):
    tmp=p.with_name(p.name+'.tmp');tmp.write_bytes(b);os.replace(tmp,p)
def write(p,d):atomic(p,encoded(d))
INDEX=read(SOURCE/'simulation-index.json')
CANDIDATES={r['id']:r for r in map(json.loads,(SOURCE/'second-ball-candidates.jsonl').read_text().splitlines())}
BOARDS={r['id']:r for r in read(SOURCE/'layouts.json')}
GEO=read(ROOT/'output/two-ball-keypoint-top10-20261025/input.json')['geometry']
G=Geometry(**{k:GEO[k] for k in ('length','width','radius')});D=2*G.radius
POLICY={'schema':'two-ball-p2-60-top5-v1','workers':16,'threshold':60,'topK':5,'algorithm':'arc1cm-rms-p2-t20-potgate-v3',
    'coordinate':'world XZ metres; +X right, +Z down in landscape; Y up','geometry':{'length':G.length,'width':G.width,'radius':G.radius},
    'difficulty':'minimum generation-anchor OP/cos(cut), tie by pocket; sort score then comboIndex; no stroke-cost penalty',
    'collision':'post-contact cue polyline <=2R+0.002m; pre-contact chord <=2R; overlap <2R; no forward pocket rejected',
    'precontactException':'strictly earlier recorded cue cushion event => unresolved path, conservatively excluded and recorded; equal-time marker retained',
    'dedup':'greedy ascending difficulty; similarity>=60 merges; exact stop after fifth representative; no refill',
    'limits':'stored post-contact cue polyline plus pre-contact chord; no moving first-object path or three-ball replay; second shot geometric only'}
ROUTE_KEYS=('comboIndex','trialID','strokeCategory','velocity','spinX','spinY','strikeDirection','aimOffsetRadians','cueStop','cueMainRailsAfterContact','cueJawsAfterContact','cueOtherCushionsAfterContact','trajectory2mm')
PILOT_IDS={r['id'] for r in read(BENCH/'pilot-index.json')}
FULL_CHECK_IDS={r['id'] for r in INDEX[::max(1,len(INDEX)//16)]}

def nearest(b,path):
    return min(independent_segment_distance(b,a,c) for a,c in zip(path,path[1:])) if len(path)>1 else math.dist(b,path[0])

def process_record(record,item,temp):
    board=record['board'];lid=record['id'];assert board==BOARDS[lid]
    assert len(record['rows'])==125 and len({r['comboIndex'] for r in record['rows']})==125
    assert Counter(r['strokeCategory'] for r in record['rows'])==Counter(center=14,vertical=42,horizontal=18,mixed=51)
    trials=[r for r in record['rows'] if r['status']=='success']
    assert all(r['usableForPositionMatch'] and r['simulatedElevationRadians']==0 for r in trials)
    unavailable=set();diagnostics=[]
    for r in trials:
        assert r['trajectory2mm']['toleranceMeters']==.002
        assert r['trajectory2mm']['maxDeviationMeters']<=.002+1e-8
        assert len(r['trajectory2mm']['points'])>=1
        assert math.dist(r['trajectory2mm']['points'][-1][1:],r['cueStop'])<1e-6
        if r['cueCushionsBeforeContact']:
            events=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and not e['afterFirstContact']]
            assert len(events)==r['cueCushionsBeforeContact']
            deltas=[r['firstContactTime']-e['time'] for e in events]
            if any(t>0 for t in deltas):unavailable.add(r['comboIndex'])
            diagnostics.append({'comboIndex':r['comboIndex'],'secondsBeforeContact':deltas,'pathUnavailable':r['comboIndex'] in unavailable})
    paths={r['comboIndex']:[p[1:] for p in r['trajectory2mm']['points']] for r in trials}
    candidates=[];checks=0
    for cid,x,z,initial_p,initial_s in CANDIDATES[lid]['candidates']:
        b=[x,z];ranked=[];rejected=Counter()
        for r in trials:
            if r['comboIndex'] in unavailable:rejected['preContactPathUnavailable']+=1;continue
            path=paths[r['comboIndex']]
            if nearest(b,path)<=D+.002:rejected['postContactCollision']+=1;continue
            if nearest(b,[board['cue'],path[0]])<=D:rejected['preContactChord']+=1;continue
            if math.dist(b,r['cueStop'])<D:rejected['endpointOverlap']+=1;continue
            options=[score(r['cueStop'],b,p,G.radius,i) for i,p in enumerate(G.anchors())]
            best=min((m for m in options if m['score'] is not None),key=lambda m:(m['score'],m['pocket']),default=None)
            if best is None:rejected['noForwardPocket']+=1;continue
            ref=min(independent_score(r['cueStop'],b,p,G.radius) for p in G.anchors())
            assert math.isclose(best['score'],ref,rel_tol=1e-9);checks+=1
            ranked.append({'comboIndex':r['comboIndex'],**best})
        ranked.sort(key=lambda r:(r['score'],r['comboIndex']))
        assert len(ranked)+sum(rejected.values())==len(trials)
        candidates.append({'cellID':cid,'position':b,'initialBestPocket':initial_p,'initialBestScore':initial_s,'eligibleCount':len(ranked),'rejected':dict(rejected),'ranked':ranked})
    native_input={'routes':[{'comboIndex':r['comboIndex'],'points':r['trajectory2mm']['points']} for r in trials],
        'candidates':[{'cellID':c['cellID'],'ranked':[r['comboIndex'] for r in c['ranked']]} for c in candidates]}
    inp=temp/'input.json';dst=temp/'result.json';write(inp,native_input)
    subprocess.run([str(HERE/'dedup'),str(inp),str(dst)],check=True,capture_output=True)
    native=read(dst);assert native['algorithm']==POLICY['algorithm']
    if lid in FULL_CHECK_IDS:
        full=temp/'full.json';subprocess.run([str(HERE/'dedup'),str(inp),str(full),'--full'],check=True,capture_output=True)
        assert [x['top5'] for x in native['results']]==[x['top5'] for x in read(full)['results']]
    if lid in PILOT_IDS and not unavailable:
        baseline=read(BENCH/(lid.replace(':','_')+'.w16.json'))
        assert [x['top5'] for x in native['results']]==[x['top5'] for x in baseline['results']]
    used=set();output=[]
    for c,result in zip(candidates,native['results'],strict=True):
        assert c['cellID']==result['cellID'];lookup={r['comboIndex']:r for r in c['ranked']}
        top=[lookup[i] for i in result['top5']];used.update(result['top5'])
        output.append({k:v for k,v in c.items() if k!='ranked'}|{'top5':top})
    return {'schema':POLICY['schema'],'id':lid,'board':board,'simulationSource':item,
        'firstShotStatus':dict(Counter(r['status'] for r in record['rows'])),'validFirstShots':len(trials),
        'candidates':output,'routes':[{k:r[k] for k in ROUTE_KEYS} for r in trials if r['comboIndex'] in used],
        'precontactDiagnostics':diagnostics}, {'scoreChecks':checks,'nativePairs':native['pairComputations'],
        'verifiedTopPairs':native['verifiedTopPairs'],'pilotParity':int(lid in PILOT_IDS and not unavailable),'fullGreedyParity':int(lid in FULL_CHECK_IDS)}

def process_part(job):
    import tempfile
    part,wanted,contract=job;stem=Path(part).name.split('.')[0];dest=OUT/'parts'/(stem+'.jsonl.gz');receipt_path=OUT/'receipts'/(stem+'.json')
    if receipt_path.exists():
        receipt=read(receipt_path);assert receipt['contract']==contract and sha(dest.read_bytes())==receipt['sha256'];return receipt
    try:
        raw_source=(ROOT/part).read_bytes();source_receipt=read(OLD/'receipts'/(stem+'.json'))
        assert sha(raw_source)==source_receipt['sha256'];records=[];stats=Counter()
        with tempfile.TemporaryDirectory(prefix=stem+'-',dir=OUT/'tmp') as tmp:
            with gzip.open(io.BytesIO(raw_source),'rt') as f:
                for lineidx,line in enumerate(f):
                    if lineidx not in wanted:continue
                    record=json.loads(line);item=wanted[lineidx];assert record['id']==item['id']
                    result,checks=process_record(record,item,Path(tmp));records.append(result);stats.update(checks)
        assert len(records)==len(wanted)
        raw=b''.join(encoded(r)+b'\n' for r in records);compressed=gzip.compress(raw,compresslevel=6,mtime=0)
        atomic(dest,compressed)
        receipt={'part':str(dest.relative_to(ROOT)),'contract':contract,'source':part,'sourceSHA256':sha(raw_source),
            'sha256':sha(compressed),'bytes':len(compressed),'rawBytes':len(raw),'layouts':len(records),
            'candidates':sum(len(r['candidates']) for r in records),'checks':dict(stats),'workerPID':os.getpid()}
        write(receipt_path,receipt);return receipt
    except BaseException:
        write(OUT/'failures'/(stem+'.json'),{'source':part,'time':now(),'traceback':traceback.format_exc()});raise

def audit(receipts):
    seen=set();totals=Counter();top_hist=Counter();reasons=Counter();status=Counter();rails=Counter();categories=Counter();layout_hist=Counter();candidate_rows=[]
    for i,receipt in enumerate(receipts):
        data=(ROOT/receipt['part']).read_bytes();assert sha(data)==receipt['sha256']
        for line in gzip.decompress(data).splitlines():
            r=json.loads(line);lid=r['id'];assert lid not in seen;seen.add(lid);assert r['board']==BOARDS[lid]
            assert r['simulationSource']==next(v for v in GROUPS[receipt['source']].values() if v['id']==lid)
            routes={k['comboIndex']:k for k in r['routes']};assert len(routes)==len(r['routes'])
            used=set();status.update(r['firstShotStatus']);assert sum(r['firstShotStatus'].values())==125
            assert r['firstShotStatus'].get('success',0)==r['validFirstShots']
            originals=CANDIDATES[lid]['candidates'];assert len(r['candidates'])==len(originals)
            layout_total=0
            for c,o in zip(r['candidates'],originals,strict=True):
                assert [c['cellID'],*c['position'],c['initialBestPocket'],c['initialBestScore']]==o
                top=c['top5'];assert len(top)<=5 and len({t['comboIndex'] for t in top})==len(top)
                assert top==sorted(top,key=lambda e:(e['score'],e['comboIndex']))
                assert c['eligibleCount']+sum(c['rejected'].values())==r['validFirstShots']
                assert len(top)<=c['eligibleCount'];top_hist[len(top)]+=1;reasons.update(c['rejected'])
                totals['candidateAttemptPairs']+=r['validFirstShots'];totals['eligiblePairs']+=c['eligibleCount'];totals['routeReferences']+=len(top)
                if top:totals['nonemptyCandidates']+=1
                for t in top:
                    route=routes[t['comboIndex']];used.add(t['comboIndex']);path=[p[1:] for p in route['trajectory2mm']['points']]
                    assert nearest(c['position'],path)>D+.002
                    assert nearest(c['position'],[r['board']['cue'],path[0]])>D
                    ref=min(independent_score(route['cueStop'],c['position'],a,G.radius) for a in G.anchors())
                    assert math.isclose(ref,t['score'],rel_tol=1e-9)
                    rails[route['cueMainRailsAfterContact']]+=1;categories[route['strokeCategory']]+=1
                layout_total+=len(top)
                candidate_rows.append({'id':lid,'cellID':c['cellID'],'eligibleCount':c['eligibleCount'],'topCount':len(top)})
            assert used==set(routes)
            totals['uniqueRoutes']+=len(routes);totals['layouts']+=1;totals['candidates']+=len(originals)
            totals['layoutsWithRoutes']+=int(layout_total>0);totals['emptyInputLayouts']+=int(not originals)
            totals['precontactMarkedCombinations']+=len(r['precontactDiagnostics'])
            totals['unavailablePrecontactCombinations']+=sum(v['pathUnavailable'] for v in r['precontactDiagnostics'])
            layout_hist[layout_total]+=1
        if i%100==0:write(OUT/'audit-progress.json',{'state':'auditing','parts':i+1,'layouts':len(seen),'totalParts':len(receipts),'updated':now()})
    assert seen==set(CANDIDATES)==set(BOARDS)=={r['id'] for r in INDEX}
    assert totals['layouts']==13570 and totals['candidates']==173577
    assert sum(status.values())==13570*125
    assert sum(top_hist.values())==173577 and sum(int(k)*v for k,v in top_hist.items())==totals['routeReferences']
    assert totals['eligiblePairs']+sum(reasons.values())==totals['candidateAttemptPairs']
    atomic(OUT/'candidate-statistics.jsonl.gz',gzip.compress(b''.join(encoded(r)+b'\n' for r in candidate_rows),compresslevel=6,mtime=0))
    return {'totals':dict(totals),'topCountHistogram':dict(sorted(top_hist.items())),'rejectedPairs':dict(reasons),
        'firstShotStatus':dict(status),'topRouteRailHistogram':dict(sorted(rails.items())),'topRouteCategories':dict(categories),'routesPerLayoutHistogram':dict(sorted(layout_hist.items()))}

GROUPS=defaultdict(dict)
for item in INDEX:GROUPS[item['part']][item['rowInPart']]=item
def main():
    OUT.mkdir(exist_ok=True)
    for sub in ('parts','receipts','tmp','failures'):(OUT/sub).mkdir(exist_ok=True)
    lock=(OUT/'run.lock').open('w');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    start=time.perf_counter();started=now()
    assert len(INDEX)==13570 and len(CANDIDATES)==13570 and sum(len(r['candidates']) for r in CANDIDATES.values())==173577
    files=[SOURCE/'second-ball-candidates.jsonl',SOURCE/'simulation-index.json',SOURCE/'layouts.json',
        HERE/'run.py',HERE/'main.swift',HERE/'dedup',HERE/'SeparationTrajectoryScore.swift',
        ROOT/'scripts/training-question-bank/filter_second_ball_preview.py',ROOT/'scripts/training-question-bank/pocket_geometry_filter.py']
    hashes={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in files}
    for p,h in read(BENCH/'summary.json')['sourceSHA256'].items():assert sha((ROOT/p).read_bytes())==h
    manifest={'policy':POLICY,'sourceAndCodeSHA256':hashes};contract=sha(encoded(manifest));manifest['contract']=contract
    if (OUT/'manifest.json').exists():assert read(OUT/'manifest.json')==manifest
    else:write(OUT/'manifest.json',manifest)
    write(OUT/'launch.json',{'pid':os.getpid(),'workers':16,'started':started,'contract':contract})
    receipts=[]
    with ProcessPoolExecutor(max_workers=16,mp_context=multiprocessing.get_context('fork')) as pool:
        futures=[pool.submit(process_part,(p,w,contract)) for p,w in sorted(GROUPS.items())]
        for f in as_completed(futures):
            receipts.append(f.result())
            if len(receipts)%25==0 or len(receipts)==len(futures):
                progress={'state':'running','parts':len(receipts),'totalParts':len(futures),'layouts':sum(r['layouts'] for r in receipts),
                    'candidates':sum(r['candidates'] for r in receipts),'elapsedSeconds':time.perf_counter()-start,'updated':now()}
                write(OUT/'progress.json',progress);print(json.dumps(progress),flush=True)
    compute=time.perf_counter()-start;write(OUT/'workers-finished.json',{'time':now(),'workerPIDs':sorted({r['workerPID'] for r in receipts}),'poolShutdownJoined':True})
    receipts.sort(key=lambda r:r['part']);t=time.perf_counter();stats=audit(receipts);audit_seconds=time.perf_counter()-t
    for p,h in hashes.items():assert sha((ROOT/p).read_bytes())==h
    checks=Counter()
    for r in receipts:checks.update(r['checks'])
    assert checks['pilotParity']==256 and checks['fullGreedyParity']==len(FULL_CHECK_IDS)
    write(OUT/'parts-index.json',receipts)
    stats.update({'state':'complete','auditPassed':True,'started':started,'finished':now(),'workers':16,'policy':POLICY,'checks':dict(checks),
        'computeAndWriteSeconds':compute,'auditSeconds':audit_seconds,'elapsedSeconds':time.perf_counter()-start,
        'resultGzipBytes':sum(r['bytes'] for r in receipts),'resultRawBytes':sum(r['rawBytes'] for r in receipts),'parts':len(receipts),'contract':contract})
    write(OUT/'summary.json',stats);write(OUT/'progress.json',{'state':'complete','layouts':13570,'candidates':173577,'auditPassed':True,'updated':now()})
    print(json.dumps(stats,ensure_ascii=False),flush=True)
if __name__=='__main__':
    try:main()
    except BaseException:
        write(OUT/'failure.json',{'time':now(),'traceback':traceback.format_exc()});raise
