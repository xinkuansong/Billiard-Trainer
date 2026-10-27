from pathlib import Path
import sys, json, gzip, hashlib, subprocess, os, random, statistics as st
from study import ROOT,load,metrics,L,seed
from global_study import positions,POLICIES

OUT=ROOT/'output/rack-variance-stability-20261027/stage2'
OUT.mkdir(exist_ok=True,parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(n,x):(OUT/n).write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def main(uid):
    before={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'QiuJi').rglob('*.swift')};write('production-before.json',before)
    build=load('stability_build',ROOT/'research/rack-front-core-20261027/build.py');build.OUT=OUT
    sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
    workerlib=load('native_worker_stability',ROOT/'research/multi-ball-full-20261026/run.py')
    freeze=json.loads((ROOT/'output/rack-front-core-20261027/engine-freeze.json').read_text());write('engine-freeze.json',freeze)
    assert all(sha(build.HERE/k)==h for k,h in freeze.items())
    write('design.json',dict(screenSeeds=48,screenPolicies=POLICIES,holdoutSeeds=200,holdoutPolicies='B,C,one frozen screen selection',
        objective='population variance of speed magnitudes among all 15 objects at 5ms',
        selection='mean energy5 >=99% B; maximize fraction of paired variance reductions >0.01 (m/s)^2, then minimize mean variance',
        stability='report strict wins AND changes >0.01; require majority meaningful improvement and negative paired median; no success guarantee',
        geometryObjective='compare coordinated entry gates or back-row offsets; exact definitions in global_study.py',
        gateTargetM=20e-6,entryWeights=[.5,1],angleGridDegrees=10,sweeps=3,changedSlots='see global_study.py',
        seedPrefix='variance-global-{cohort}-20261027',newSeeds=True,physicsFrozen=True,productionUnchanged=True))
    binary=build.build();worker=None;boot=False;success=False;allrows=[];count=0;layoutCount=0;invariance=[];replay=[];params=None
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        folder=OUT/'worker';folder.mkdir(exist_ok=True);worker=workerlib.Worker(uid,binary,folder);write('metadata.json',worker.ready)
        with gzip.open(OUT/'raw.jsonl.gz','wt',compresslevel=3) as raw,gzip.open(OUT/'layouts.jsonl.gz','wt',compresslevel=3) as layouts:
            def run(inp):
                nonlocal params,count
                row=worker.run(inp);assert row['input']==inp and row['backend']=='repair'
                if params is None:params=row['parameters']
                assert row['parameters']==params
                raw.write(json.dumps(row,separators=(',',':'))+'\n');raw.flush();count+=1
                m=metrics(row);allrows.append(m)
                assert m['nonApproaching']==m['gapOutsideBudget']==m['energyGain']==0
                write('progress.json',dict(runs=count,cohort=inp['cohort'],id=inp['rackID'],policy=inp['policy']))
                return row
            # Replay exact original B/C before admitting new experiments.
            for line in gzip.open(ROOT/'output/rack-front-core-20261027/raw.jsonl.gz','rt'):
                ref=json.loads(line);q=ref['input']
                if q['cohort']!='holdout' or q['rackID']!=80000 or q['policy'] not in ['parentB','exit_-30'] or q['condition']!='original':continue
                r=run(dict(q,cohort='replay',saveFrames=False))
                fields=['rack','board','contacts','duration','spinTail','samples','eventTrace','initialCueVelocity','parameters']
                assert all(r[k]==ref[k] for k in fields)
                replay.append(dict(policy=q['policy'],exactFields=fields))
            write('replay.json',replay);assert len(replay)==2
            for cohort,total,start in [('screen',48,92000),('holdout',200,93000)]:
                if cohort=='screen':selected=POLICIES
                else:
                    a=[r for r in allrows if r['cohort']=='screen'];base={r['id']:r for r in a if r['policy']=='B'};rank=[]
                    for p in POLICIES[2:]:
                        rs=[r for r in a if r['policy']==p];ds=[r['variance5']-base[r['id']]['variance5'] for r in rs]
                        rank.append(dict(policy=p,mean=st.mean(r['variance5'] for r in rs),wins=sum(d<-.01 for d in ds),losses=sum(d>.01 for d in ds),median=st.median(ds),energyRatio=st.mean(r['energy5'] for r in rs)/st.mean(r['energy5'] for r in base.values())))
                    rank.sort(key=lambda x:(-x['wins'],x['mean']))
                    eligible=[r for r in rank if r['energyRatio']>=.99];assert eligible
                    winner=eligible[0]['policy'];selected=['B','C',winner]
                    write('selection.json',dict(selected=selected,ranking=rank,selectionUsesHoldout=False));print('SELECTED',selected,flush=True)
                for k in range(total):
                    rid=start+k;ss=seed(f'variance-global-{cohort}-20261027:{k}')
                    inp=dict(n=15,seed=str(ss),rackID=rid,id=f'{cohort}-{rid}',x=L/4,z=0,power=10,mode=2,toleranceM=.00025,mirror=False,reverse=False,condition='original',experiment='variance-stability',diagnostic=False,policy='B',cohort=cohort,saveFrames=False)
                    g=worker.run(dict(inp,layoutOnly=True));assert g['status']=='layout';layoutCount+=1
                    layouts.write(json.dumps(g,separators=(',',':'))+'\n');layouts.flush()
                    order=list(selected);random.Random(rid).shuffle(order)
                    for p in order:
                        pos=positions(g,p);job=dict(inp,policy=p,rackXZ=pos,exactCueVelocity=g['initialCueVelocity'])
                        r=run(job);assert r['initialCueVelocity']==g['initialCueVelocity'] and [[b['x'],b['z']] for b in r['rack']]==pos
                        if cohort=='holdout' and p==winner and k<5:
                            for cond in ['reverse','shuffle','mirror']:
                                alt=dict(job,cohort='invariance',condition=cond)
                                if cond=='reverse':alt['reverse']=True
                                if cond=='shuffle':perm=list(range(15));random.Random(rid).shuffle(perm);alt['permutation']=perm
                                if cond=='mirror':alt['mirror']=True;alt['exactCueVelocity']=[g['initialCueVelocity'][0],g['initialCueVelocity'][1],-g['initialCueVelocity'][2]]
                                rr=run(alt);assert set(rr['board'])==set(r['board'])
                                import math
                                err=max(math.dist(q,[rr['board'][n][0],.5-rr['board'][n][1]] if cond=='mirror' else rr['board'][n])*L for n,q in r['board'].items())
                                assert err<=1e-6 and rr['duration']==r['duration']
                                invariance.append(dict(id=rid,condition=cond,maxBoardErrorM=err))
                    write('scalars.json',allrows)
                    if k%8==0:print(cohort,k+1,'runs',count,flush=True)
            write('invariance.json',invariance)
        assert all(sha(build.HERE/k)==h for k,h in freeze.items())
        changes=[p for p,h in before.items() if sha(ROOT/p)!=h]
        binding=json.loads((OUT/'source-binding.json').read_text());assert all(sha(ROOT/x['path'])==x['sha256'] for x in binding['production'])
        write('source-review.json',dict(productionChangesDuringRun=changes,physicsAndRackBindingsUnchanged=True,researchEngineUnchanged=True,runEvidence=os.environ['QIUJI_TEST_EVIDENCE']))
        success=True
    finally:
        code=worker.close() if worker else None
        shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
        write('closure.json',dict(success=success,runs=count,layoutOnlyRequests=layoutCount,workerExit=code,shutdownExit=None if shut is None else shut.returncode))
        if success:assert code==0 and shut.returncode==0
if __name__=='__main__':main(sys.argv[1])
