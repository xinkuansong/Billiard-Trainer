"""Freeze current production sources; managed simulator CLI, no App installation."""
from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys, tarfile, gzip, time, signal
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = Path(os.environ.get('DEFENSE_PILOT_OUTPUT', str(ROOT / 'output/defense-no-recontact-522-20261104/r1')))

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def atomic(path, value):
    tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2));tmp.replace(path)

def compress_results(folder):
    for cp in (folder/'questions').glob('*.checkpoint.json'):
        p=cp.with_name(cp.name.replace('.checkpoint.json','.json'))
        if not p.exists():continue
        raw=p.read_bytes();record=json.loads(raw);checkpoint=json.loads(cp.read_bytes())
        assert hashlib.sha256(raw).hexdigest()==checkpoint['resultSHA256']
        assert record['input']==checkpoint['input'] and record['summary']==checkpoint['summary']
        gz=p.with_suffix('.json.gz');tmp=gz.with_suffix('.tmp')
        tmp.write_bytes(gzip.compress(raw,mtime=0));assert gzip.decompress(tmp.read_bytes())==raw
        tmp.replace(gz);p.unlink()

if len(sys.argv) > 1 and sys.argv[1] == 'worker':
    uid, worker = sys.argv[2:]
    subprocess.run(['xcrun','simctl','boot',uid],check=True)
    processes=[];logs=[]
    try:
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
        begun=time.time()
        for folder in sorted((OUT/'workers').iterdir()):
            log=(folder/'run.log').open('a');logs.append(log)
            proc=subprocess.Popen(['xcrun','simctl','spawn',uid,worker,str(folder)],stdout=log,stderr=subprocess.STDOUT)
            processes.append((folder,proc))
        while True:
            rows=[]
            for folder,proc in processes:
                compress_results(folder)
                count=len(list((folder/'questions').glob('*.checkpoint.json')))
                rows.append(dict(worker=folder.name,pid=proc.pid,completed=count,total=len(json.loads((folder/'samples.json').read_bytes())),exitCode=proc.poll()))
            atomic(OUT/'status.json',dict(state='running' if any(p.poll() is None for _,p in processes) else 'workers-finished',updatedAt=time.time(),elapsedSeconds=time.time()-begun,completed=sum(r['completed'] for r in rows),total=522,workers=rows))
            if all(p.poll() is not None for _,p in processes):break
            time.sleep(5)
        if any(p.returncode!=0 for _,p in processes):raise RuntimeError('One or more workers failed; checkpoints retained')
        dest=OUT/'questions';dest.mkdir(exist_ok=True)
        reports=[]
        for folder,proc in processes:
            summary=json.loads((folder/'summary.json').read_bytes());assert summary['complete']
            reports+=summary['questions']
            for p in (folder/'questions').glob('*.json.gz'):
                target=dest/p.name
                if target.exists():assert target.read_bytes()==p.read_bytes()
                else:os.link(p,target)
        assert len(reports)==522 and len({r['sampleID'] for r in reports})==522
        atomic(OUT/'summary.json',dict(complete=True,layouts=522,questions=reports,elapsedSeconds=time.time()-begun,scope='Full constrained search; no App UI acceptance'))
        subprocess.run([sys.executable,str(OUT/'tooling/pack.py'),str(OUT),str(OUT/'bank')],check=True)
        subprocess.run([sys.executable,str(HERE/'bank.py'),'merge'],check=True)
        atomic(OUT/'status.json',dict(state='complete',completed=522,total=522,elapsedSeconds=time.time()-begun,workers=rows,bank=str(OUT/'bank')))
    except BaseException as error:
        atomic(OUT/'failure.json',dict(error=repr(error),time=time.time()))
        for _,p in processes:
            if p.poll() is None:p.terminate()
        for _,p in processes:
            try:p.wait(timeout=20)
            except subprocess.TimeoutExpired:p.kill();p.wait()
        raise
    finally:
        for log in logs:log.close()
        subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
    sys.exit(0)

subprocess.run([sys.executable,str(HERE/'prepare.py')],check=True)
OUT.mkdir(parents=True, exist_ok=True)
# Build from the same live source identities as the already audited pilot.
expected=json.loads((ROOT/'output/defense-constrained-20-20261104/r1/source-manifest.json').read_bytes())
# Reuse the audited source archive, independent of concurrent App UI changes.
(OUT/'tooling').mkdir(exist_ok=True)
shutil.copy2(HERE/'pack.py',OUT/'tooling/pack.py')
work = Path(os.environ['QIUJI_TEST_WORK'])
evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
src = work / 'sources'
manifest=expected;paths=[]
with tarfile.open(ROOT/'output/defense-full-5698-20261104/r1/source-snapshot.tar.gz') as archive:
    for entry in archive.getmembers():
        if not entry.isfile() or not entry.name.startswith('sources/') or not entry.name.endswith('.swift'):continue
        relative=Path(entry.name).relative_to('sources');assert '..' not in relative.parts
        target=src/relative;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(archive.extractfile(entry).read());paths.append(str(target))
paths.sort()
for name in ['main.swift','Attack.swift']:(work/name).write_bytes((HERE/name).read_bytes())
# The frozen calculator already contains the same PipeWindow extension. Do not append twice.
(OUT/'research-sources.json').write_text(json.dumps({n:sha(HERE/n) for n in ['main.swift','Attack.swift','PipeWindow.swift','run.py']},indent=2))
app = work / 'DefensePilot.app'
app.mkdir()
(app / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.qiuji.defense-pilot',
    'CFBundleExecutable': 'Worker', 'CFBundlePackageType': 'APPL'}))
assets = {}
for name in ['ModelTrial20261010_CueUV.usdz', 'ModelTrial20261010_TaiQiuZhuo.usdz',
             'TaiQiuZhuo.usdz', 'CueStyles', 'TableMaterials', 'TableStyles', 'ClothColors',
             'BallStickers', 'MobilePocketOcclusion.png', 'MobilePocketOcclusionBounds.json',
             'MobileRailOcclusion.png', 'MobileTableSoftbox.hdr']:
    matches = list((ROOT / 'QiuJi/Resources').rglob(name))
    assert len(matches) == 1, (name, matches)
    p = matches[0]
    if p.is_dir():
        shutil.copytree(p, app / name)
        for f in p.rglob('*'):
            if f.is_file(): assets[str(f.relative_to(ROOT))] = sha(f)
    else:
        shutil.copy2(p, app / name)
        assets[str(p.relative_to(ROOT))] = sha(p)
(OUT / 'source-manifest.json').write_text(json.dumps(manifest, indent=2))
assert assets==json.loads((ROOT/'output/defense-constrained-20-20261104/r1/asset-manifest.json').read_bytes()),'Assets changed since audited pilot'
(OUT / 'asset-manifest.json').write_text(json.dumps(assets, indent=2))
seed = next((ROOT / 'content/position_play/sequences').glob('drill_c060__manual01*'))
source = json.loads(seed.read_text())['steps'][2]
(OUT / 'seed.json').write_text(json.dumps({'source': str(seed.relative_to(ROOT)),
    'sha256': sha(seed), 'step': 3, 'data': source}, ensure_ascii=False, indent=2))
# Preserve the small source snapshot; generated executable/cache is disposable.
with tarfile.open(OUT / 'source-snapshot.tar.gz', 'w:gz') as archive:
    archive.add(src, arcname='sources')
    archive.add(work / 'main.swift', arcname='main.swift')
    archive.add(work / 'Attack.swift', arcname='Attack.swift')
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
cmd = ['xcrun', 'swiftc', '-O', '-whole-module-optimization', '-num-threads', '4',
       '-D', 'DEBUG', '-swift-version', '5', '-sdk', sdk,
       '-target', 'arm64-apple-ios17.0-simulator', *paths, str(work / 'Attack.swift'), str(work / 'main.swift'),
       '-lz', '-o', str(app / 'Worker')]
(evidence / 'build-command.json').write_text(json.dumps(cmd, indent=2))
print('Building frozen production CLI', flush=True)
with (evidence / 'build.log').open('w') as log:
    result = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, SDKROOT=sdk))
if result.returncode:
    print((evidence / 'build.log').read_text()[-8000:])
    sys.exit(result.returncode)
print('BUILD COMPLETE', flush=True)
(OUT / 'build.json').write_text(json.dumps({'exitCode': 0, 'binarySHA256': sha(app / 'Worker'),
    'evidence': str(evidence)}, indent=2))
subprocess.run([sys.executable, str(ROOT / 'scripts/simulator_fleet.py'), 'run',
    '--role', 'large-phone', '--task', 'defense-no-recontact-522-20261104', '--',
    sys.executable, __file__, 'worker', '{udid}', str(app / 'Worker')], check=True)
drift = [p for p, h in manifest.items() if not (ROOT/p).exists() or sha(ROOT / p) != h]
(OUT / 'execution.json').write_text(json.dumps({'exitCode': 0, 'sourceDrift': drift,
    'evidence': str(evidence), 'scope': 'Frozen CLI physics and geometry; no App UI tested'}, indent=2))
print((OUT / 'status.json').read_text())
