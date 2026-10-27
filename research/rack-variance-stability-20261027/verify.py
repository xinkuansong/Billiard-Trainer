from pathlib import Path
import json,gzip,hashlib,datetime,math

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-stability-20261027';M=.17000000178813934
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def main():
    checks=0;maxerr=0.;runs=0;contacts=0;newseeds=set();stage_evidence=[]
    for folder in [OUT,OUT/'stage2']:
        closure=json.loads((folder/'closure.json').read_text());assert closure['success'] and closure['workerExit']==closure['shutdownExit']==0
        rows=json.loads((folder/'scalars.json').read_text());assert len(rows)==closure['runs']==953;runs+=len(rows)
        for r in rows:
            assert r['nonApproaching']==r['gapOutsideBudget']==r['energyGain']==0;contacts+=r['contacts']
            for ms in [5,20,100]:
                err=abs(r[f'variance{ms}']+r[f'allMeanSpeed{ms}']**2-2*r[f'energy{ms}']/(15*M));assert err<1e-10
                maxerr=max(maxerr,err);checks+=1
        inv=json.loads((folder/'invariance.json').read_text());assert len(inv)==15 and max(r['maxBoardErrorM'] for r in inv)<=1e-6
        replay=json.loads((folder/'replay.json').read_text());assert len(replay)==2
        freeze=json.loads((folder/'engine-freeze.json').read_text())
        assert all(sha(ROOT/'research/rack-front-core-20261027'/p)==h for p,h in freeze.items())
        binding=json.loads((folder/'source-binding.json').read_text());assert all(sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
        n=0
        for line in gzip.open(folder/'layouts.jsonl.gz','rt'):
            g=json.loads(line);seed=g['input']['seed'];assert seed not in newseeds;newseeds.add(seed);n+=1
        assert n==248
        chosen=json.loads((folder/'gated-selections.json').read_text());assert len(chosen)==200
        stage_evidence.append(dict(folder=str(folder.relative_to(ROOT)),nativeRuns=len(rows),layouts=n,replays=len(replay),invarianceRuns=len(inv),physicsAndRackSourceBindings=len(binding['production']),productionChangesDuringRun=json.loads((folder/'source-review.json').read_text())['productionChangesDuringRun']))
    oldseeds={json.loads(line)['input']['seed'] for line in gzip.open(ROOT/'output/rack-front-core-20261027/layouts.jsonl.gz','rt')};assert not oldseeds.intersection(newseeds)
    rule=json.loads((OUT/'gated-rule-frozen.json').read_text());frozen=datetime.datetime.fromisoformat(rule['frozenAtUTC']).timestamp()
    assert (OUT/'stage2/selection.json').stat().st_mtime>frozen
    sourcefiles=list((ROOT/'research/rack-variance-stability-20261027').glob('*.py'))
    outputs=[p for p in OUT.rglob('*') if p.is_file() and p.name not in ['verification.json','native.log']]
    result=dict(nativeRuns=runs,layoutOnlyRequests=len(newseeds),identityChecks=checks,maxIdentityError=maxerr,auditedBallResponses=contacts,
        invalidResponses=0,positiveGapOutsideEnvelopeResponses=0,energyGainOver1MicrojouleResponses=0,
        gatedRowsAreSelectedAlreadySimulatedCounterfactuals=True,gatedPolicyNativeRunsAdded=0,
        ruleFrozenBeforeStage2HoldoutSelection=True,stages=stage_evidence,
        sourceSHA={str(p.relative_to(ROOT)):sha(p) for p in sourcefiles},artifactSHA={str(p.relative_to(ROOT)):sha(p) for p in outputs})
    (OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print({k:v for k,v in result.items() if k not in ['sourceSHA','artifactSHA','stages']})
if __name__=='__main__':main()
