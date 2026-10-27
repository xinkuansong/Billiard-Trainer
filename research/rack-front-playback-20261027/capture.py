from pathlib import Path
import sys, importlib.util, json, gzip, hashlib, subprocess, os
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/rack-front-playback-20261027'
def load(name,path):
    s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main(uid):
    before={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'QiuJi').rglob('*.swift')}
    (OUT/'production-before.json').write_text(json.dumps(before))
    build=load('frontbuild',ROOT/'research/rack-front-core-20261027/build.py');build.OUT=OUT
    sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
    mod=load('nativeworker',ROOT/'research/multi-ball-full-20261026/run.py')
    freeze=json.loads((ROOT/'output/rack-front-core-20261027/engine-freeze.json').read_text())
    assert all(sha(build.HERE/k)==v for k,v in freeze.items())
    binary=build.build();worker=None;boot=False;success=False;checks=[]
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        folder=OUT/'worker';folder.mkdir(exist_ok=True);worker=mod.Worker(uid,binary,folder)
        with gzip.open(OUT/'captured.jsonl.gz','wt') as out,gzip.open(ROOT/'output/rack-front-core-20261027/raw.jsonl.gz','rt') as source:
            for line in source:
                ref=json.loads(line);q=ref['input']
                if q['cohort']!='holdout' or q['rackID'] not in [80179,80139,80067,80087] or q['policy'] not in ['parentB','exit_-30'] or q['condition']!='original':continue
                inp=dict(q,saveFrames=True);row=worker.run(inp)
                fields=['rack','board','contacts','duration','spinTail','samples','eventTrace','initialCueVelocity','parameters','status','termination','playbackEnd']
                assert all(row[k]==ref[k] for k in fields),(q['rackID'],q['policy'],[k for k in fields if row[k]!=ref[k]])
                assert row['input']==inp and len(row['frames'])==16
                out.write(json.dumps(row,separators=(',',':'))+'\n');out.flush()
                checks.append(dict(id=q['rackID'],policy=q['policy'],exactFields=fields));print('captured',q['rackID'],q['policy'],flush=True)
        assert len(checks)==8
        assert all(sha(ROOT/k)==v for k,v in before.items())
        (OUT/'capture-verification.json').write_text(json.dumps(dict(cases=checks,physicsFrozen=True,productionUnchanged=True,runEvidence=os.environ['QIUJI_TEST_EVIDENCE']),indent=2))
        success=True
    finally:
        rc=worker.close() if worker else None
        shutdown=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
        (OUT/'closure.json').write_text(json.dumps(dict(success=success,captured=len(checks),workerExit=rc,shutdownExit=shutdown.returncode if shutdown else None),indent=2))
        if success:assert rc==0 and shutdown.returncode==0
if __name__=='__main__':main(sys.argv[1])
