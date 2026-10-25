"""Estimate only: frozen random 256-layout pilot, never the full job."""
from pathlib import Path
import json,gzip,hashlib,random,time,sys,math,subprocess,statistics
from collections import defaultdict,Counter
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]; HERE=Path(__file__).resolve().parent
OUT=ROOT/'output'/HERE.name; OUT.mkdir(exist_ok=True)
SOURCE=ROOT/'output/two-ball-block-sampled-13570-20261025'
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry
from filter_second_ball_preview import score,independent_score,independent_segment_distance
read=lambda p:json.loads(p.read_text())
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'),allow_nan=False))
index=read(SOURCE/'simulation-index.json')
candidates={r['id']:r for r in map(json.loads,(SOURCE/'second-ball-candidates.jsonl').read_text().splitlines())}
selected=random.Random(20261025605).sample(index,256)
groups=defaultdict(dict)
for item in selected:groups[item['part']][item['rowInPart']]=item['id']
dump(OUT/'pilot-index.json',selected)
allparts=set(r['part'] for r in index)
def load_part(item):
    part,wanted=item; records=[]; started=time.perf_counter()
    with gzip.open(ROOT/part,'rt') as f:
        for row,line in enumerate(f):
            if row in wanted:
                record=json.loads(line); assert record['id']==wanted[row]; records.append(record)
    assert len(records)==len(wanted)
    return records,time.perf_counter()-started
t=time.perf_counter()
with ThreadPoolExecutor(max_workers=8) as pool:loaded=list(pool.map(load_part,groups.items()))
records={r['id']:r for part,_ in loaded for r in part}
io_seconds=time.perf_counter()-t
print(json.dumps({'phase':'read','seconds':io_seconds,'layouts':len(records),'shards':len(groups)}),flush=True)
geo=read(ROOT/'output/two-ball-keypoint-top10-20261025/input.json')['geometry']
g=Geometry(**{k:geo[k] for k in ('length','width','radius')});diameter=2*g.radius
def nearest(b,path):
    return min(independent_segment_distance(b,a,c) for a,c in zip(path,path[1:])) if len(path)>1 else math.dist(b,path[0])
prepared={}; filter_times=[]; validation_checks=0; precontact_diagnostics=[]
t=time.perf_counter()
for item in selected:
    record=records[item['id']]; ts=time.perf_counter(); board=record['board']
    trials=[r for r in record['rows'] if r['status']=='success']
    assert all(r['usableForPositionMatch'] and r['simulatedElevationRadians']==0 for r in trials)
    for r in trials:
        if r['cueCushionsBeforeContact']:
            events=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and not e['afterFirstContact']]
            precontact_diagnostics.append({'id':record['id'],'comboIndex':r['comboIndex'],'count':r['cueCushionsBeforeContact'],
                'secondsBeforeContact':[r['firstContactTime']-e['time'] for e in events]})
    paths={r['comboIndex']:[p[1:] for p in r['trajectory2mm']['points']] for r in trials}
    rows=[]
    for cid,x,z,*_ in candidates[item['id']]['candidates']:
        b=[x,z]; eligible=[]; rejected=Counter()
        for r in trials:
            path=paths[r['comboIndex']]
            if nearest(b,path)<=diameter+.002:rejected['postContactCollision']+=1;continue
            if nearest(b,[board['cue'],path[0]])<=diameter:rejected['preContactChord']+=1;continue
            if math.dist(b,r['cueStop'])<diameter:rejected['endpointOverlap']+=1;continue
            options=[score(r['cueStop'],b,p,g.radius,i) for i,p in enumerate(g.anchors())]
            best=min((m for m in options if m['score'] is not None),key=lambda m:(m['score'],m['pocket']),default=None)
            if best is None:rejected['noForwardPocket']+=1;continue
            reference=min(independent_score(r['cueStop'],b,p,g.radius) for p in g.anchors())
            assert math.isclose(best['score'],reference,rel_tol=1e-9);validation_checks+=1
            eligible.append({'comboIndex':r['comboIndex'],**best})
        eligible.sort(key=lambda r:(r['score'],r['comboIndex']))
        assert len(eligible)+sum(rejected.values())==len(trials)
        rows.append({'cellID':cid,'position':b,'eligibleCount':len(eligible),'rejected':dict(rejected),'ranked':eligible})
    serial={'routes':[{'comboIndex':r['comboIndex'],'points':r['trajectory2mm']['points']} for r in trials],
            'candidates':[{'cellID':r['cellID'],'ranked':[e['comboIndex'] for e in r['ranked']]} for r in rows]}
    name=record['id'].replace(':','_');dump(OUT/(name+'.input.json'),serial)
    prepared[record['id']]={'name':name,'candidates':rows,'trials':trials}
    filter_times.append(time.perf_counter()-ts)
filter_seconds=time.perf_counter()-t
print(json.dumps({'phase':'filter-score','seconds':filter_seconds,'checks':validation_checks}),flush=True)
def native(args):
    item,workers,full=args;name=prepared[item['id']]['name'];dst=OUT/(name+f'.w{workers}'+('.full' if full else '')+'.json')
    ts=time.perf_counter();subprocess.run([str(HERE/'dedup'),str(OUT/(name+'.input.json')),str(dst)]+(['--full'] if full else []),check=True)
    result=read(dst);result['subprocessSeconds']=time.perf_counter()-ts;return result
runs={}
for workers in (8,16):
    ts=time.perf_counter()
    with ThreadPoolExecutor(max_workers=workers) as pool:results=list(pool.map(native,[(r,workers,False) for r in selected]))
    runs[str(workers)]={'wallSeconds':time.perf_counter()-ts,'sumNativeSeconds':sum(r['nativeSeconds'] for r in results),
        'pairComputations':sum(r['pairComputations'] for r in results),'cacheHits':sum(r['cacheHits'] for r in results)}
    if workers==8:baseline=results
    else:assert all(a['results']==b['results'] for a,b in zip(baseline,results))
    print(json.dumps({'phase':'dedup','workers':workers,**runs[str(workers)]}),flush=True)
# Full greedy vs exact prefix shortcut on 8 pilot layouts; these timings excluded.
with ThreadPoolExecutor(max_workers=8) as pool:full_results=list(pool.map(native,[(r,16,True) for r in selected[:8]]))
for a,b in zip(results,full_results):assert [x['top5'] for x in a['results']]==[x['top5'] for x in b['results']]
compact=[];standalone=[];counts=Counter();unique_routes=0
for item,result in zip(selected,results):
    prep=prepared[item['id']]; candidates_out=[];used=set()
    for c,rr in zip(prep['candidates'],result['results']):
        lookup={r['comboIndex']:r for r in c['ranked']}; top=[lookup[i] for i in rr['top5']];used.update(rr['top5']);counts[len(top)]+=1
        candidates_out.append({k:v for k,v in c.items() if k!='ranked'}|{'top5':top})
    row={'id':item['id'],'simulationSource':item,'candidates':candidates_out};compact.append(row)
    routekeys=('comboIndex','trialID','strokeCategory','velocity','spinX','spinY','strikeDirection','aimOffsetRadians','cueStop','cueMainRailsAfterContact','cueJawsAfterContact','cueOtherCushionsAfterContact','trajectory2mm')
    standalone.append(row|{'board':records[item['id']]['board'],'routes':[{k:r[k] for k in routekeys} for r in prep['trials'] if r['comboIndex'] in used]})
    unique_routes+=len(used)
sizes={}
for label,rows in [('index',compact),('standalone',standalone)]:
    raw=b''.join((json.dumps(r,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n').encode() for r in rows)
    (OUT/(label+'.jsonl')).write_bytes(raw); compressed=gzip.compress(raw,compresslevel=6,mtime=0);(OUT/(label+'.jsonl.gz')).write_bytes(compressed)
    sizes[label]={'rawBytes':len(raw),'gzipBytes':len(compressed),'projectedRawBytes':len(raw)*len(index)/len(selected),'projectedGzipBytes':len(compressed)*len(index)/len(selected)}
summary={'scope':'benchmark only; full processing not started','pilotSeed':20261025605,'sampleLayouts':len(selected),'sampleCandidates':sum(len(candidates[r['id']]['candidates']) for r in selected),
    'fullLayouts':len(index),'fullCandidates':173577,'algorithm':'arc1cm-rms-p2-t20-potgate-v3','threshold':60,'topK':5,
    'read':{'workers':8,'wallSeconds':io_seconds,'shards':len(groups),'compressedBytes':sum((ROOT/p).stat().st_size for p in groups),'fullShards':len(allparts),'fullCompressedBytes':sum((ROOT/p).stat().st_size for p in allparts)},
    'filterScoreSerialSeconds':filter_seconds,'nativeRuns':runs,'topCountHistogram':dict(counts),'uniqueRoutes':unique_routes,'sizes':sizes,
    'verification':{'independentScoreChecks':validation_checks,'fullGreedyPrefixLayouts':8,'parallelResultsIdentical':True,'flatShots':True},
    'precontactDiagnostics':precontact_diagnostics,
    'sourceSHA256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [SOURCE/'second-ball-candidates.jsonl',SOURCE/'simulation-index.json',ROOT/'QiuJi/Features/SeparationPractice/SeparationTrajectoryScore.swift']}}
dump(OUT/'summary.json',summary);print(json.dumps(summary,ensure_ascii=False,indent=2),flush=True)
