from pathlib import Path
import sys,json,gzip,hashlib,subprocess,os,random,math
from layout_study import ROOT,load,metrics,L,seed,definitions,positions,statistics

OUT=ROOT/'output/rack-variance-minimize-20261027';OUT.mkdir(exist_ok=True,parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(n,x):(OUT/n).write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def main(uid):
    defs=definitions();write('policies.json',defs)
    write('design.json',dict(screenSeeds=24,screenPolicies=32,confirmationSeeds=64,confirmationPolicies='E + five lowest variance eligible screen rules',holdoutSeeds=300,
        holdoutPolicies='B,E,one frozen confirmation winner',selection='minimum mean variance5 among mean energy5 >=99% of paired E; E retained as fallback at final selection',
        primary='within-rack population variance of speed magnitudes among all 15 object balls at 5ms after first ball contact',
        secondary=['variance20','variance100','strict/meaningful paired wins/losses','energy','corners','final neighbors','spin tail','scratch'],
        physicalParametersFrozen=True,engineFrozen=True,nominalGapM=.0002,jitterRadiusM=.00009,preserved='apex and per-ball original offset magnitudes; same seed actual initial cue velocity; tip10',
        changedSlots=[10,11,12,13,14],seedPrefix='variance-minimize-{cohort}-20261027',runtimeOutcomeSelection=False))
    before={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'QiuJi').rglob('*.swift')};write('production-before.json',before)
    build=load('minimize_build',ROOT/'research/rack-front-core-20261027/build.py');build.OUT=OUT
    sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
    workerlib=load('native_worker_minimize',ROOT/'research/multi-ball-full-20261026/run.py')
    freeze=json.loads((ROOT/'output/rack-front-core-20261027/engine-freeze.json').read_text());write('engine-freeze.json',freeze)
    assert all(sha(build.HERE/k)==h for k,h in freeze.items())
    sources=[Path(__file__),Path(__file__).with_name('layout_study.py')]
    write('research-source-before.json',{str(p.relative_to(ROOT)):sha(p) for p in sources})
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
            for line in gzip.open(ROOT/'output/rack-variance-stability-20261027/stage2/raw.jsonl.gz','rt'):
                ref=json.loads(line);q=ref['input']
                if q['cohort']!='holdout' or q['rackID']!=93000 or q['policy'] not in ['B','C_back90'] or q['condition']!='original':continue
                r=run(dict(q,cohort='replay',saveFrames=False));fields=['rack','board','contacts','duration','spinTail','samples','eventTrace','initialCueVelocity','parameters']
                assert all(r[k]==ref[k] for k in fields);replay.append(dict(policy=q['policy'],exactFields=fields))
            assert len(replay)==2;write('replay.json',replay)
            for cohort,total,start in [('screen',24,100000),('confirmation',64,101000),('holdout',300,102000)]:
                if cohort=='screen':selected=list(defs)
                else:
                    previous='screen' if cohort=='confirmation' else 'confirmation'
                    rank=statistics([r for r in allrows if r['cohort']==previous]);write(previous+'-ranking.json',rank)
                    eligible=[r for r in rank if r['energyRatio']>=.99]
                    if cohort=='confirmation':selected=['E']+[r['policy'] for r in eligible if r['policy']!='E'][:5];assert len(selected)==6
                    else:
                        winner=eligible[0]['policy'];selected=list(dict.fromkeys(['B','E',winner]));defs['B']=dict(kind='B')
                    write(cohort+'-selection.json',dict(selected=selected,ranking=rank,selectionUsesDestinationCohort=False));print('SELECTED',cohort,selected,flush=True)
                for k in range(total):
                    rid=start+k;ss=seed(f'variance-minimize-{cohort}-20261027:{k}')
                    inp=dict(n=15,seed=str(ss),rackID=rid,id=f'{cohort}-{rid}',x=L/4,z=0,power=10,mode=2,toleranceM=.00025,mirror=False,reverse=False,condition='original',experiment='variance-minimize',diagnostic=False,policy='E',cohort=cohort,saveFrames=False)
                    g=worker.run(dict(inp,layoutOnly=True));assert g['status']=='layout';layoutCount+=1
                    layouts.write(json.dumps(g,separators=(',',':'))+'\n');layouts.flush()
                    order=list(selected);random.Random(rid).shuffle(order)
                    for p in order:
                        pos=positions(g,defs[p]);job=dict(inp,policy=p,rackXZ=pos,exactCueVelocity=g['initialCueVelocity'])
                        r=run(job);assert r['initialCueVelocity']==g['initialCueVelocity'] and [[b['x'],b['z']] for b in r['rack']]==pos
                        if cohort=='holdout' and p==winner and k<5:
                            for cond in ['reverse','shuffle','mirror']:
                                alt=dict(job,cohort='invariance',condition=cond)
                                if cond=='reverse':alt['reverse']=True
                                if cond=='shuffle':perm=list(range(15));random.Random(rid).shuffle(perm);alt['permutation']=perm
                                if cond=='mirror':alt['mirror']=True;alt['exactCueVelocity']=[g['initialCueVelocity'][0],g['initialCueVelocity'][1],-g['initialCueVelocity'][2]]
                                rr=run(alt);assert set(rr['board'])==set(r['board'])
                                err=max(math.dist(q,[rr['board'][n][0],.5-rr['board'][n][1]] if cond=='mirror' else rr['board'][n])*L for n,q in r['board'].items())
                                assert err<=1e-6 and rr['duration']==r['duration'];invariance.append(dict(id=rid,condition=cond,maxBoardErrorM=err))
                    write('scalars.json',allrows)
                    if k%8==0:print(cohort,k+1,'runs',count,flush=True)
            write('invariance.json',invariance)
        assert all(sha(build.HERE/k)==h for k,h in freeze.items())
        binding=json.loads((OUT/'source-binding.json').read_text());assert all(sha(ROOT/x['path'])==x['sha256'] for x in binding['production'])
        original=json.loads((OUT/'research-source-before.json').read_text());assert all(sha(ROOT/p)==h for p,h in original.items())
        changes=[p for p,h in before.items() if sha(ROOT/p)!=h]
        write('source-review.json',dict(productionChangesDuringRun=changes,physicsAndRackBindingsUnchanged=True,researchEngineUnchanged=True,runEvidence=os.environ['QIUJI_TEST_EVIDENCE']))
        success=True
    finally:
        code=worker.close() if worker else None;shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
        write('closure.json',dict(success=success,runs=count,layoutOnlyRequests=layoutCount,workerExit=code,shutdownExit=None if shut is None else shut.returncode))
        if success:assert code==0 and shut.returncode==0
if __name__=='__main__':main(sys.argv[1])
