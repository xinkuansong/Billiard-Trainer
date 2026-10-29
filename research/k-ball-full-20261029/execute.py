"""Managed build, regression smoke, then four independent batch workers."""
from pathlib import Path
import gzip, importlib.util, json, os, sqlite3, subprocess, sys, time

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/k-ball-full-20261029'


def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('kb_build',ROOT/'research/k-ball-tolerance-20261029/build.py')
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        mod.HERE=HERE;mod.OUT=OUT
        app=mod.build()
        import tarfile
        with tarfile.open(OUT/'frozen-worker-source.tar.gz','w:gz') as tar:
            tar.add(Path(os.environ['QIUJI_TEST_WORK'])/'source',arcname='source')
        # This task already has explicit user authorization to borrow the iPhone13 for independent background calculation.
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','k-ball-full-20261029','--',sys.executable,__file__,'{udid}',str(app/'Worker')],check=True)
        return
    uid,worker=sys.argv[1:]
    state=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))
    original=next(d['state'] for ds in state['devices'].values() for d in ds if d['udid']==uid)
    if original=='Shutdown':
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
    else:assert original=='Booted'
    procs=[];logs=[]
    try:
        # Regression includes the historical scratch-only failure: it must now pass.
        old=json.loads((ROOT/'output/k-ball-tolerance-20261029/samples.json').read_text())
        ids=['K069']+[r['id'] for r in old if r['success']][:3]
        smoke=[]
        for r in old:
            if r['id'] not in ids:continue
            c=dict(id=r['id'],B=r['B'],expectedRails=len(r['railsBeforeK']))
            smoke.append(dict(key=r['id'],seed=r['seed'],referenceRailIDs=r['railsBeforeK'],groups=[dict(axis=r['axis'],candidates=[c])]))
        (OUT/'smoke-jobs.jsonl').write_text(''.join(json.dumps(j)+'\n' for j in smoke))
        # Baseline plus a complete small level is sufficient for event-order regression.
        protocol=json.loads((ROOT/'output/k-ball-tolerance-20261029/protocol.json').read_text())
        protocol['probes']=[p for p in protocol['probes'] if p['level']=='small']
        # Worker requires the same complete protocol to grade; use all levels for this tiny regression set.
        protocol=json.loads((ROOT/'output/k-ball-tolerance-20261029/protocol.json').read_text())
        (OUT/'smoke-protocol.json').write_text(json.dumps(protocol))
        with (OUT/'smoke.log').open('w') as log:
            subprocess.run(['xcrun','simctl','spawn',uid,worker,str(OUT/'smoke-jobs.jsonl'),str(OUT/'smoke-protocol.json'),str(OUT/'smoke-results.jsonl')],stdout=log,stderr=subprocess.STDOUT,check=True)
        byid={r['id']:r for r in old};report=[]
        for line in (OUT/'smoke-results.jsonl').open():
            row=json.loads(line);base=row['attempted'][0]['results'][0];prior=byid[row['key']]
            assert base['events']==prior['events'],row['key']
            assert base['success']==(base['complete'] and base['firstA'] and base['potA'] and base['laterB'])
            if row['key']=='K069':assert base['scratch'] and base['success']
            report.append(dict(id=row['key'],sameEvents=True,success=base['success'],scratch=base['scratch']))
        assert len(report)==4
        (OUT/'smoke-audit.json').write_text(json.dumps(dict(passed=True,rows=report),indent=2))
        print('SMOKE PASS',report,flush=True)
        # Geometry preparation is independent of native compilation.
        while not (OUT/'candidate-summary.json').exists():
            time.sleep(2)
        protocol=json.loads((OUT/'protocol.json').read_text())
        assert protocol['success'].endswith('scratch recorded but ignored')
        db=sqlite3.connect(OUT/'pool.sqlite')
        inputs=[(OUT/f'jobs-{i}.jsonl').open('w') for i in range(4)]
        count=0
        for count,line in enumerate((OUT/'jobs.jsonl').open(),1):
            job=json.loads(line)
            row=json.loads(db.execute('SELECT data FROM routes WHERE key=?',(job['key'],)).fetchone()[0])
            job['referenceRailIDs']=[c['cushionID'] for c in row['route']['trajectory2mm']['cushions']]
            inputs[(count-1)%4].write(json.dumps(job)+'\n')
        for f in inputs:f.close()
        db.close()
        (OUT/'dispatch.json').write_text(json.dumps(dict(routes=count,workers=4,udid=uid,originalState=original)))
        for i in range(4):
            log=(OUT/f'worker-{i}.log').open('w');logs.append(log)
            procs.append(subprocess.Popen(['xcrun','simctl','spawn',uid,worker,str(OUT/f'jobs-{i}.jsonl'),str(OUT/'protocol.json'),str(OUT/f'results-{i}.jsonl')],stdout=log,stderr=subprocess.STDOUT))
        while any(p.poll() is None for p in procs):
            failures=[p.returncode for p in procs if p.returncode not in (None,0)]
            if failures:raise RuntimeError(f'Worker failure {failures}')
            time.sleep(2)
        assert all(p.returncode==0 for p in procs)
        (OUT/'execution.json').write_text(json.dumps(dict(complete=True,workerExitCodes=[p.returncode for p in procs],routes=count)))
    finally:
        for p in procs:
            if p.poll() is None:p.terminate()
        for p in procs:
            p.wait()
        for f in logs:f.close()
        if original=='Shutdown':subprocess.run(['xcrun','simctl','shutdown',uid],check=True)


if __name__=='__main__':main()
