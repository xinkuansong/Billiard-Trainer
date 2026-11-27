"""Freeze current production sources; managed simulator CLI, no App installation."""
from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys, tarfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = Path(os.environ.get('DEFENSE_PILOT_OUTPUT', str(ROOT / 'output/pocket-heatmap-20261104'))).resolve()

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

if len(sys.argv) > 1 and sys.argv[1] == 'worker':
    uid, worker = sys.argv[2:]
    subprocess.run(['xcrun', 'simctl', 'boot', uid], check=True)
    try:
        subprocess.run(['xcrun', 'simctl', 'bootstatus', uid, '-b'], check=True)
        with (OUT / 'run.log').open('w') as log:
            subprocess.run(['xcrun', 'simctl', 'spawn', uid, worker, str(OUT), os.environ.get('DEFENSE_TARGET','500'), os.environ.get('DEFENSE_MAX_BASES','150000')],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', uid], check=True)
    sys.exit(0)

OUT.mkdir(parents=True, exist_ok=True)
work = Path(os.environ['QIUJI_TEST_WORK'])
evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
src = work / 'sources'
manifest, paths = {}, []
frozen=Path(os.environ['DEFENSE_FROZEN_FROM'])
manifest=json.loads((frozen/'source-manifest.json').read_text())
with tarfile.open(frozen/'source-snapshot.tar.gz') as archive:
    for name,expected in manifest.items():
        data=archive.extractfile('sources/'+name.removeprefix('QiuJi/')).read()
        raw=data.replace(b'// Research worker supplies main',b'@main') if name.endswith('/QiuJiApp.swift') else data
        assert hashlib.sha256(raw).hexdigest()==expected
        q=src/name.removeprefix('QiuJi/');q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(data);paths.append(str(q))
patch=HERE/'PipeWindow.swift'
calc=src/'Core/Scene/AngleSceneCalculator.swift'
calc.write_bytes(calc.read_bytes()+b'\n'+patch.read_bytes())
(OUT/'research-patch.json').write_text(json.dumps({'baseSHA256':manifest['QiuJi/Core/Scene/AngleSceneCalculator.swift'],'extensionSHA256':sha(patch),'patchedSHA256':sha(calc)},indent=2))
(work / 'main.swift').write_bytes((HERE / 'main.swift').read_bytes())
app = work / 'DefensePilot.app'
app.mkdir()
(app / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.qiuji.defense-bank',
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
assert assets==json.loads((frozen/'asset-manifest.json').read_text())
(OUT / 'frozen-assets-audit.json').write_text(json.dumps({'passed':True,'files':len(assets),'source':'r1 asset manifest, copied r2 runtime files rehashed','hashes':assets},indent=2))
for name in assets:
    resource=ROOT/name
    suffix=name.split('QiuJi/Resources/',1)[1]
    matches=[p for p in app.rglob(resource.name) if p.is_file() and sha(p)==assets[name]]
    assert matches,name
(OUT / 'source-manifest.json').write_text(json.dumps(manifest, indent=2))
(OUT / 'asset-manifest.json').write_text(json.dumps(assets, indent=2))
seed = next((ROOT / 'content/position_play/sequences').glob('drill_c060__manual01*'))
source = [json.loads(seed.read_text())['steps'][i] for i in [1,5]]
(OUT / 'seed.json').write_text(json.dumps({'source': str(seed.relative_to(ROOT)),
    'sha256': sha(seed), 'steps': [2,6], 'data': source}, ensure_ascii=False, indent=2))
shutil.copy2(HERE / 'candidate-input.json', OUT / 'candidate-input.json')
shutil.copy2(HERE / 'protocol.json', OUT / 'protocol.json')
# Preserve the small source snapshot; generated executable/cache is disposable.
with tarfile.open(OUT / 'source-snapshot.tar.gz', 'w:gz') as archive:
    archive.add(src, arcname='sources')
    archive.add(work / 'main.swift', arcname='main.swift')
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
cmd = ['xcrun', 'swiftc', '-O', '-whole-module-optimization', '-num-threads', '4',
       '-D', 'DEBUG', '-swift-version', '5', '-sdk', sdk,
       '-target', 'arm64-apple-ios17.0-simulator', *paths, str(work / 'main.swift'),
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
    '--role', os.environ.get('DEFENSE_SIM_ROLE', 'large-phone'), '--task', 'pocket-heatmap-20261104', '--',
    sys.executable, __file__, 'worker', '{udid}', str(app / 'Worker')], check=True)
drift = [p for p, h in manifest.items() if not (ROOT/p).exists() or sha(ROOT / p) != h]
(OUT / 'execution.json').write_text(json.dumps({'exitCode': 0, 'sourceDrift': drift,
    'evidence': str(evidence), 'scope': 'Frozen CLI physics and geometry; no App UI tested'}, indent=2))
print((OUT / 'run.log').read_text()[-4000:])
