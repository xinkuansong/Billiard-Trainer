from pathlib import Path
import json,gzip,sys,subprocess,importlib.util,hashlib,random,os
import build
from study import *
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def main(uid):
    policies=definitions();write('policies.json',policies)
    write('design.json',dict(screenSeeds=24,policies=len(policies),holdoutSeeds=200,
        objective='mean at5/20ms of sum(sqrt(core individual translational energy))',
        gates='mean nEff5,active5,gap20>=90% of parent; mean target energy5>=95% of parent',
        selection='two eligible highest coreObjective; no spread or spin score in selection',
        parent='inner_first from rack-energy-layout-20261027',groups=GROUPS,core=CORE,
        seedPrefix='core-energy-{cohort}-20261027',parametersFrozen=True,engineFrozen=True,
        preserved='apex; individual original offset lengths; .20mm nominal gap; .09mm radius; tip10; paired actual cue velocity'))
    binary=build.build();boot=False;worker=None;allrows=[];count=0;layoutRequests=0;success=False
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        folder=OUT/'worker';folder.mkdir();worker=mod.Worker(uid,binary,folder);write('metadata.json',worker.ready)
        params=None
        with gzip.open(OUT/'raw.jsonl.gz','wt',compresslevel=3) as raw, gzip.open(OUT/'layouts.jsonl.gz','wt',compresslevel=3) as layouts:
            def run(inp):
                nonlocal params,count
                row=worker.run(inp);assert row['backend']=='repair' and row['input']==inp
                if params is None:params=row['parameters']
                assert row['parameters']==params
                raw.write(json.dumps(row,separators=(',',':'))+'\n');raw.flush();count+=1
                s=metrics(row);allrows.append(s)
                assert s['nonApproaching']==s['gapOutsideBudget']==s['energyGain']==0
                write('progress.json',dict(runs=count,cohort=inp['cohort'],id=inp['rackID'],policy=inp['policy']))
                return row
            refs=[]
            for line in gzip.open(ROOT/'output/rack-energy-layout-20261027/raw.jsonl.gz','rt'):
                r=json.loads(line)
                if r['input']['cohort']=='holdout' and r['input']['policy']=='inner_first' and r['input']['rackID'] in [40000,40001]:refs.append(r)
            replay=[]
            for ref in refs:
                inp=dict(ref['input'],cohort='replay',policy='parent',saveFrames=False)
                r=run(inp);fields=['rack','board','contacts','duration','spinTail','samples','eventTrace','initialCueVelocity']
                assert all(r[k]==ref[k] for k in fields);replay.append(dict(id=inp['rackID'],exactFields=fields))
            write('replay.json',replay)
            selected=None;invariance=[]
            for cohort,total,start in [('screen',24,50000),('holdout',200,60000)]:
                if cohort=='holdout':
                    a=aggregate([r for r in allrows if r['cohort']=='screen']);write('screen-summary.json',a)
                    eligible=[p for p in a if p!='parent' and all(a[p][k]>=fraction*a['parent'][k] for k,fraction in [('energy5',.95),('nEff5',.9),('active5',.9),('gap20',.9)])]
                    eligible.sort(key=lambda p:a[p]['coreObjective'],reverse=True)
                    selected=['parent']+eligible[:2];assert len(selected)==3
                    write('selection.json',dict(selected=selected,ranking=eligible,selectionUsesHoldout=False))
                    print('SELECTED',selected,flush=True)
                for k in range(total):
                    rid=start+k;ss=seed(f'core-energy-{cohort}-20261027:{k}')
                    inp=dict(n=15,seed=str(ss),rackID=rid,id=f'{cohort}-{rid}',x=L/4,z=0,power=10,mode=2,toleranceM=.00025,
                        mirror=False,reverse=False,condition='original',experiment='core-layout',diagnostic=False,policy='parent',cohort=cohort,saveFrames=(cohort=='holdout' and k<3))
                    generated=worker.run(dict(inp,layoutOnly=True));assert generated['status']=='layout';layoutRequests+=1
                    layouts.write(json.dumps(generated,separators=(',',':'))+'\n');layouts.flush()
                    parentJob=dict(inp,rackXZ=positions(generated,policies['parent']),exactCueVelocity=generated['initialCueVelocity'])
                    base=run(parentJob);candidates=[p for p in (policies if cohort=='screen' else selected) if p!='parent']
                    random.Random(rid).shuffle(candidates)
                    for p in candidates:
                        pos=positions(generated,policies[p]);job=dict(inp,policy=p,rackXZ=pos,exactCueVelocity=base['initialCueVelocity'])
                        row=run(job);assert row['initialCueVelocity']==base['initialCueVelocity']
                        assert [[b['x'],b['z']] for b in row['rack']]==pos
                        if cohort=='holdout' and k<10 and p==selected[1]:
                            for condition in ['reverse','shuffle','mirror']:
                                alt=dict(job,cohort='invariance',condition=condition,saveFrames=False)
                                if condition=='reverse':alt['reverse']=True
                                if condition=='shuffle':perm=list(range(15));random.Random(rid).shuffle(perm);alt['permutation']=perm
                                if condition=='mirror':alt['mirror']=True;alt['exactCueVelocity']=[base['initialCueVelocity'][0],base['initialCueVelocity'][1],-base['initialCueVelocity'][2]]
                                rr=run(alt);same=set(rr['board'])==set(row['board'])
                                delta=max((math.dist(q,[rr['board'][n][0],.5-rr['board'][n][1]] if condition=='mirror' else rr['board'][n])*L for n,q in row['board'].items()),default=0) if same else None
                                exact=rr['duration']==row['duration'];assert same and delta<=1e-6 and exact
                                invariance.append(dict(id=rid,policy=p,condition=condition,maxBoardDeltaM=delta,durationExact=exact))
                    if k%8==0:print(cohort,k+1,'runs',count,flush=True)
                    write('scalars.json',allrows)
            write('invariance.json',invariance);write('summary.json',aggregate([r for r in allrows if r['cohort']=='holdout']))
        freeze=json.load(open(OUT/'engine-freeze.json'))
        assert all(hashlib.sha256((Path(__file__).parent/n).read_bytes()).hexdigest()==h for n,h in freeze.items())
        binding=json.load(open(OUT/'source-binding.json'));assert all(hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()==x['sha256'] for x in binding['production'])
        before=json.load(open(OUT/'production-before.json'));changed=[p for p,h in before.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
        write('source-review.json',dict(productionChangesDuringRun=changed,physicsAndRackBindingsUnchanged=True,researchEngineUnchanged=True))
        success=True
    finally:
        code=worker.close() if worker else None
        shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
        write('closure.json',dict(success=success,runs=count,layoutOnlyRequests=layoutRequests,workerExit=code,shutdownExit=None if shut is None else shut.returncode))
        if success:assert code==0 and shut.returncode==0
if __name__=='__main__':main(sys.argv[1])
