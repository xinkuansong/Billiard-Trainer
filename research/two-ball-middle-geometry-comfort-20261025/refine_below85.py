"""Five frozen original recommendations: minimal-change comfort >=85 experiment."""
from pathlib import Path
import collections,copy,gzip,hashlib,importlib.util,itertools,json,math,subprocess,sys,time,traceback
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/two-ball-comfort-refine-five-20261025'
SOURCE=ROOT/'output/two-ball-middle-geometry-comfort-20261025'
sys.path.insert(0,str(ROOT/'research/two-ball-middle-grid18-20261025'))
import pipeline as P
C=P.C
spec=importlib.util.spec_from_file_location('comfort',ROOT/'research/two-ball-comfort-full-20261025/run.py');F=importlib.util.module_from_spec(spec);spec.loader.exec_module(F)
read=lambda p:json.loads(p.read_text())
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def metric(r,root):
    d=[(r['velocity']-root['velocity'])/.3,(r['spinY']-root['spinY'])/.15,(r['spinX']-root['spinX'])/.1]
    return sum(round(x,5)**2 for x in d)
def main(uid):
    OUT.mkdir(exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
    assert not (OUT/'results.json').exists(),'Completed experiment is immutable'
    data=read(SOURCE/'below85-five/data.json');index={x['stem']:x for x in read(SOURCE/'parts-index.json')}
    frozen={str(SOURCE/'below85-five/data.json'):sha(SOURCE/'below85-five/data.json'),str(Path(__file__)):sha(Path(__file__)),str(P.HERE/'Worker.app/Worker'):sha(P.HERE/'Worker.app/Worker'),str(ROOT/'research/two-ball-comfort-full-20261025/run.py'):sha(ROOT/'research/two-ball-comfort-full-20261025/run.py')}
    entry={e['key']:e for e in read(SOURCE/'entry-decisions.json')}
    write(OUT/'manifest.json',dict(sourceHashes=frozen,policy=dict(threshold=85,comparison='unrounded >=85',grid=P.POLICY['grid'],angleHardCap=None,pocketFixed=True,railCountAndSequenceFixed=True,zeroRailSideSpin=0,selection='Among qualifying: minimum sum of squared parameter changes normalized by max ranges; ties: less absolute side, then higher comfort; otherwise best legal score, explicitly not qualified',scope='exact five recommendations, no corpus mutation; no top5 union/dedup because one replacement per original route',geometry='world XZ meters; screen right +X, down +Z; measured geometry from source'),device=uid))
    P.common.OUT=OUT;P.common.APP=P.HERE/'Worker.app/Worker'
    w=None;boot=False;start=time.perf_counter();results=[];alltrials=[]
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        w=P.common.Worker(uid,0);compute=time.perf_counter()
        for s in data['samples']:
            t=time.perf_counter();root=s['route'];pocket=s['score']['pocket'];b=s['position'];expected=P.seq(root)
            fp=SOURCE/'final'/(s['stem']+'.jsonl.gz');assert sha(fp)==index[s['stem']]['finalSHA256'];frozen[str(fp)]=sha(fp)
            row=next(json.loads(l) for l in gzip.decompress(fp.read_bytes()).splitlines() if json.loads(l)['id']==s['id'])
            assert root==next(r for r in row['routes'] if r['comboIndex']==root['comboIndex'])
            assert s['recommendation'] in next(c for c in row['candidates'] if c['cellID']==s['cellID'])['top5']
            if pocket in (4,5):
                k=hashlib.sha256(json.dumps([*b,pocket],separators=(',',':')).encode()).hexdigest();assert entry[k]['passed']
            assert math.dist(b,root['cueStop'])>=C.diameter
            keys,prune=P.grid(root);trials=[];valid=[];rejected=collections.Counter(prune)
            for off in range(0,len(keys),32):
                ks=keys[off:off+32];cs=[dict(comboIndex=100000+off+j,tipID=0,speedID=0,velocity=k[0],spinX=k[1],spinY=k[2]) for j,k in enumerate(ks)]
                rr=w.run(s['board'],cs)['rows']
                for k,r in zip(ks,rr,strict=True):
                    C.normalize(r);r['strokeCategory']=C.category(r['spinX'],r['spinY'])
                    if k==C.params(root):
                        assert r['cueStop']==root['cueStop'] and r['trajectory2mm']==root['trajectory2mm'];replay=True
                    why=C.reason(r)
                    if why is None and P.seq(r)!=expected:why='railStateChanged'
                    if why is None:
                        path=[v[1:] for v in r['trajectory2mm']['points']]
                        if C.nearest(b,path)<=C.diameter+.002 or C.nearest(b,[s['board']['cue'],path[0]])<=C.diameter:why='collisionB'
                        elif C.independent_angle(r['cueStop'],b,F.ANCHORS[pocket])>=90:why='secondCutNotForward'
                    rec=dict(parameters=list(k),route=r,reject=why)
                    if why:rejected[why]+=1
                    else:
                        q=F.score(r['cueStop'],b,pocket);q.update(stop=r['cueStop'],pocket=pocket)
                        rec.update(scores=q,change=metric(r,root));valid.append(rec)
                    trials.append(rec)
            assert replay and len(trials)+sum(prune.values())==245
            qualified=[q for q in valid if q['scores']['totalScore']>=85]
            chosen=min(qualified,key=lambda q:(q['change'],abs(q['route']['spinX']),-q['scores']['totalScore'],q['parameters'])) if qualified else max(valid,key=lambda q:(q['scores']['totalScore'],-q['change']))
            assert P.seq(chosen['route'])==expected
            result=dict(sample=s,after=chosen,qualified=bool(qualified),gridPoints=245,simulated=len(trials),legal=len(valid),qualifying=len(qualified),rejected=dict(rejected),expectedRails=list(expected),zeroSideRequired=not expected and root['spinX']!=0,replayExact=True,seconds=time.perf_counter()-t)
            results.append(result);alltrials.append(dict(sample=s['number'],trials=trials,parameterPrune=prune))
            write(OUT/'progress.json',dict(completed=len(results),total=5,seconds=time.perf_counter()-compute))
            print('SAMPLE',s['number'],s['score']['totalScore'],chosen['scores']['totalScore'],len(qualified),dict(rejected),flush=True)
        for p,h in frozen.items():assert sha(Path(p))==h
        with gzip.open(OUT/'trials.json.gz','wt',compresslevel=6) as f:json.dump(alltrials,f,ensure_ascii=False,separators=(',',':'),allow_nan=False)
        write(OUT/'results.json',dict(geometry=data['geometry'],samples=results,computeSeconds=time.perf_counter()-compute,elapsedSeconds=time.perf_counter()-start,sourceHashes=frozen))
    except BaseException:
        write(OUT/'failure.json',dict(traceback=traceback.format_exc()));raise
    finally:
        if w:w.close()
        if boot:
            r=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True)
            write(OUT/'cleanup.json',dict(device=uid,workerExitCode=w.p.returncode if w else None,shutdownExitCode=r.returncode,stderr=r.stderr));assert r.returncode==0
if __name__=='__main__':main(sys.argv[1])
