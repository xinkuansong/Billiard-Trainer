"""Independent geometry, source, native closure and sample-window audit."""
from pathlib import Path
import json,gzip,math,itertools,hashlib,statistics
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/rack-energy-separation-20261026'
R=json.loads((OUT/'paired/metadata.json').read_text())['radius']
inputs={};result={}
for mode in ['paired','control']:
    folder=OUT/mode;count=0;min_gap=math.inf;first_cushion=math.inf;max_momentum=0;max_energy_gain=-math.inf;non_pairs=0;scores={}
    derived=json.loads((OUT/(mode+'-rows.json')).read_text())
    for r in derived:scores[r['id'],r['variant']]=r['score']
    seen=set()
    for file in sorted(folder.glob('raw-*.jsonl.gz')):
        with gzip.open(file,'rt') as f:
            for line in f:
                r=json.loads(line);count+=1;k=(r['input']['rackID'],r['input']['variant'])
                assert k not in seen;seen.add(k)
                geom=(r['rack'],r['cue'],r['direction'],r['power'],r['spin'])
                if mode=='paired':inputs[k]=geom
                else:assert inputs[k]==geom
                q=[(b['x'],b['z']) for b in r['rack']]
                min_gap=min(min_gap,min(math.dist(a,b)-2*R for a,b in itertools.combinations(q,2)))
                for contact in r['contacts']:
                    if contact['kind']!='ball':first_cushion=min(first_cushion,contact['t'])
                for e in r['impulseTrace']:
                    ch=e['changed']
                    if len(ch)!=2:non_pairs+=1;continue
                    delta=[sum(c['postV'][axis]-c['preV'][axis] for c in ch)*.17 for axis in range(3)]
                    max_momentum=max(max_momentum,math.sqrt(sum(x*x for x in delta)))
                    total=sum(.085*sum(v*v-u*u for v,u in zip(c['postV'],c['preV']))+.17*R*R/5*sum(v*v-u*u for v,u in zip(c['postW'],c['preW'])) for c in ch)
                    max_energy_gain=max(max_energy_gain,total)
    assert count==3000 and min_gap>0 and first_cushion>.02
    analysis=json.loads((OUT/(mode+'-analysis.json')).read_text())
    for variant in ['baseline','toward','away']:
        values=[scores[i,variant] for i in range(2200,3200)]
        diffs=[scores[i,variant]-scores[i,'baseline'] for i in range(2200,3200)]
        reported=analysis['cohorts']['all1000'][variant]
        assert abs(statistics.fmean(values)-reported['mean'])<1e-12
        assert abs(statistics.fmean(diffs)-reported['scoreDelta']['mean'])<1e-12
    binding=json.loads((folder/'source-binding.json').read_text())
    assert all(hashlib.sha256((ROOT/b['path']).read_bytes()).hexdigest()==b['sha256'] for b in binding['production'])
    closure=json.loads((folder/'closure.json').read_text())
    assert closure['success'] and closure['shutdownExitCode']==0 and all(w['exitCode']==0 for w in closure['workers'])
    replays=[r for path in folder.glob('worker-*/replays.json') for r in json.loads(path.read_text())]
    assert len(replays)==12 and all(r['passed'] for r in replays)
    start=json.loads((folder/'run-start.json').read_text());run=Path(start['evidence']).parent
    life=json.loads((run/'run.json').read_text());assert life['state']=='reclaimed' and not Path(start['work']).exists()
    result[mode]=dict(count=count,minInitialSurfaceGapMM=min_gap*1000,earliestCushionSeconds=first_cushion,maxPairMomentumResidualKgMPS=max_momentum,maxPairTotalEnergyGainJ=max_energy_gain,nonPairVelocityJumps=non_pairs,productionSourceBindings=len(binding['production']),baselineReplays=len(json.loads((folder/'preflight/baseline-audit.json').read_text())),deterministicReplays=len(replays),closure=closure,workspaceState=life['state'],lifecycleRun=str(run.relative_to(ROOT)))
result['crossModelInputsExactlyEqual']=True
result['passed']=True
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
print(json.dumps(result,ensure_ascii=False,indent=2))
