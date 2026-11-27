from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys, tarfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/defense-lambda5-regeneration-20261106'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
OUT.mkdir(exist_ok=True,parents=True)
if '--parity-only' not in sys.argv:
    raise SystemExit('Current scope: raw source layout filtering. This driver is retained for --parity-only verification; do not regenerate the old 57,575-question pool.')
if '--parity-only' not in sys.argv:
    subprocess.run([sys.executable,str(HERE/'prepare.py')],check=True)
work = Path(os.environ['QIUJI_TEST_WORK']); evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
src = work/'sources'; paths = []; manifest = {}
for p in sorted((ROOT/'QiuJi').rglob('*.swift')):
    rel = p.relative_to(ROOT); data = p.read_bytes(); manifest[str(rel)] = sha(p)
    if b'@main' in data:
        assert p.name == 'QiuJiApp.swift', p
        data = data.replace(b'@main', b'// Native benchmark supplies main')
    dest = src/rel; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data); paths.append(str(dest))
# Extract only the existing post-legality evaluator; this is not a fabricated shot.
effect_source = (ROOT/'QiuJi/Features/DefensePractice/DefenseEffect.swift').read_text()
body = effect_source.split('        if fullyBlocked(cue, target, blockers) {',1)[1].split('    /// Upper bounds',1)[0]
body = '        if fullyBlocked(cue, target, blockers) {' + body
body = body.replace('var assessment = DefenseAttackAssessment()', 'var assessment = windows ?? DefenseAttackAssessment()')
wrapper = ('import Foundation\nimport SceneKit\nextension DefenseEffect {\n'
           'static func regionState(cue:SCNVector3,target:SCNVector3,blockers:[SCNVector3],windows:DefenseAttackAssessment?=nil,opponent:Int=9) throws -> Self {\n'
           'var timing=Timing(); let usePrecomputedWindows=false\n' + body + '}\n')
wrapper_path=src/'RegionState.swift';wrapper_path.write_text(wrapper);paths.append(str(wrapper_path))
(OUT/'extracted-evaluator.swift').write_text(wrapper)
(OUT/'extraction.json').write_text(json.dumps({'sourceSHA256':sha(ROOT/'QiuJi/Features/DefensePractice/DefenseEffect.swift'),
 'changes':['Entry accepts terminal positions, skips shot legality and state validation (research only)',
 'Exact six-window cache can be supplied for fixed target; unchanged post-legality branch logic'],
 'wrapperSHA256':sha(wrapper_path)},indent=2))
for name in ['OwnPotential.swift','DefenseRegionSolver.swift','RegionScan.swift','FactorStudy.swift']:
    dest=src/name;shutil.copy2(HERE/name,dest);paths.append(str(dest))
main = work/'main.swift'; shutil.copy2(HERE/'main.swift',main)
app = work/'DefenseBench.app'; app.mkdir(); binary = app/'Worker'
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.defense-benchmark','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
shutil.copytree(ROOT/'QiuJi/Resources/PocketPipe',app/'PocketPipe')
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



(OUT/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
with tarfile.open(OUT/'source-snapshot.tar.gz','w:gz') as ar:
    ar.add(HERE,arcname='research-tooling')
    ar.add(src,arcname='sources'); ar.add(main,arcname='main.swift'); ar.add(app/'PocketPipe',arcname='PocketPipe')
subprocess.run([sys.executable,str(ROOT/'scripts/verify_pocket_pipe_table.py')],check=True)
sdk = subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd = ['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(main),'-lz','-o',str(binary)]
(evidence/'build-command.json').write_text(json.dumps(cmd,indent=2))
print('Compiling current production sources',len(paths),flush=True)
with (evidence/'build.log').open('w') as log:
    result = subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
if result.returncode:
    print((evidence/'build.log').read_text()[-8000:]);sys.exit(result.returncode)
print('Native build passed; running benchmark',flush=True)
tooling={p.name:sha(p) for p in HERE.iterdir() if p.suffix in ['.py','.swift']}
asset_manifest={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'QiuJi/Resources/PocketPipe').rglob('*') if p.is_file()}
asset_manifest.update(assets)
identity_data=dict(production=manifest,assets=asset_manifest,tooling=tooling,policySHA256=sha(OUT/'policy.json') if (OUT/'policy.json').exists() else None,inputsSHA256=sha(OUT/'inputs.json') if (OUT/'inputs.json').exists() else None,binarySHA256=sha(binary))
identity=hashlib.sha256(json.dumps(identity_data,sort_keys=True).encode()).hexdigest()
(OUT/'run-identity.json').write_text(json.dumps(dict(identity=identity,**identity_data),indent=2))
(OUT/'run-paths.json').write_text(json.dumps(dict(work=str(work),evidence=str(evidence),binary=str(binary),identity=identity),indent=2))
# Freeze controller and audit too: a long run must not change behavior after code edits.
tooling_dir=work/'tooling';tooling_dir.mkdir()
# Controller ROOT/HERE are explicit so it can execute from the archived copy.
for name in ['controller.py','audit.py','verify_parity.py']:
    content=(HERE/name).read_text()
    if name=='controller.py':content=content.replace("ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name",f"ROOT=Path({str(ROOT)!r});HERE=Path({str(HERE)!r});OUT=Path({str(OUT)!r})")
    (tooling_dir/name).write_text(content)
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','defense-lambda5-regeneration-20261106','--',sys.executable,str(tooling_dir/'controller.py'),'{udid}',str(binary),identity,*sys.argv[1:]],check=True)
drift=[p for p,h in manifest.items() if sha(ROOT/p)!=h]
(OUT/'execution.json').write_text(json.dumps(dict(exitCode=0,sourceDrift=drift,binarySHA256=sha(binary),evidence=str(evidence)),indent=2))
print('Generation, independent audits and packaging finished. Source drift:',drift)
