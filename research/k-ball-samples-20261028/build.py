"""Freeze current physics dependencies and rebuild every changed object; retain provenance."""
from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys, gzip, random

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/k-ball-samples-20261028'
BASE=ROOT/'research/two-ball-strike-full-20261024'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def build():
    OUT.mkdir(exist_ok=True)
    work=Path(os.environ['QIUJI_TEST_WORK']); ev=Path(os.environ['QIUJI_TEST_EVIDENCE'])
    src=work/'source';src.mkdir()
    current={p.name:p for p in (ROOT/'QiuJi').rglob('*.swift')}
    bindings=[]; changed=[]
    for old in sorted((BASE/'native-source').glob('*.swift')):
        q=current.get(old.name)
        critical=q and ('/Physics/' in str(q) or old.name in {
            'AngleSceneCalculator.swift','BTSceneConstants.swift','CueClearance.swift','CueStrikeAccess.swift',
            'CueStick.swift','CueStyleModel.swift','TableModelLoader.swift','AccuracyTipSelector.swift'})
        source=q if critical else old
        (src/old.name).write_bytes(source.read_bytes())
        bindings.append({'path':str(source.relative_to(ROOT)),'sha256':sha(source),'currentProduction':bool(critical)})
        # Recompile every physics/clearance consumer to avoid old inlined constants/functions.
        if critical:changed.append(src/old.name)
    shutil.copy2(HERE/'main.swift',src/'main.swift');changed.append(src/'main.swift')
    app=work/'KBallWorker.app';app.mkdir()
    (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.kball-sample','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
    # Current cue/table assets used for the production cue clearance profile.
    resources=ROOT/'QiuJi/Resources'
    for name in ['ModelTrial20261010_CueUV.usdz','ModelTrial20261010_TaiQiuZhuo.usdz','TaiQiuZhuo.usdz','CueStyles','TableMaterials','TableStyles','ClothColors','BallStickers','MobilePocketOcclusion.png','MobilePocketOcclusionBounds.json','MobileRailOcclusion.png','MobileTableSoftbox.hdr']:
        matches=list(resources.rglob(name));assert len(matches)==1,(name,matches)
        p=matches[0]
        if p.is_dir():shutil.copytree(p,app/name)
        else:shutil.copy2(p,app/name)
    sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
    sources=list(map(str,sorted(src.glob('*.swift'))));objects=[];commands=[]
    for path in changed:
        obj=work/(path.stem+'.o');objects.append(str(obj))
        commands.append(['xcrun','swiftc','-frontend','-c',*[s for s in sources if s!=str(path)],'-primary-file',str(path),'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-module-name','QiuJi','-o',str(obj)])
    replaced={p.stem for p in changed}
    oldobjs=[p for p in sorted((BASE/'objects').glob('*.o')) if p.stem not in replaced]
    commands.append(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*map(str,oldobjs),*objects,'-lz','-Xlinker','-syslibroot','-Xlinker',sdk,'-o',str(app/'Worker')])
    (ev/'commands.json').write_text(json.dumps(commands,indent=2))
    (OUT/'source-binding.json').write_text(json.dumps({'sources':bindings,'rebuilt':[p.name for p in changed],
        'entrySHA256':sha(HERE/'main.swift'),'reusedObjects':{p.name:sha(p) for p in oldobjs},
        'scope':'Frozen production physics, current clearance and assets; historical UI dependencies are not exercised.'},indent=2))
    with (ev/'build.log').open('w') as log:
        for cmd in commands:
            print('Compiling',cmd[-1],flush=True)
            result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
            if result.returncode:raise RuntimeError((ev/'build.log').read_text()[-9000:])
    (OUT/'build.json').write_text(json.dumps({'exitCode':0,'executableSHA256':sha(app/'Worker'),'evidence':str(ev)}))
    return app

def seeds():
    bank=ROOT/'QiuJi/Resources/TwoBallBank';index=json.loads((bank/'index.json').read_text())
    rng=random.Random(20261028);entries=list(index['layouts']);rng.shuffle(entries)
    result=[];cache={};bindings={}
    for entry in entries[:600]:
        key=entry['shard'];p=bank/(key+'.jsonl.gz')
        if key not in cache:
            cache[key]=[json.loads(line) for line in gzip.open(p,'rt')];bindings[str(p.relative_to(ROOT))]=sha(p)
        layout=cache[key][entry['line']];b=layout['board'];routes=list(layout['routes']);rng.shuffle(routes)
        # Broad deterministic pilot sample, not the source bank's comfort ranking.
        for r in routes[:5]:
            result.append(dict(layout=layout['id'],route=r['id'],cue=b['cue'],object=b['object'],pocket=b['pocket'],dir=r['dir'],v=r['v'],sx=r['sx'],sy=r['sy']))
    rng.shuffle(result)
    (OUT/'seeds.json').write_text(json.dumps(result))
    (OUT/'seed-provenance.json').write_text(json.dumps({'randomSeed':20261028,'indexSHA256':sha(bank/'index.json'),'shards':bindings,'count':len(result)},indent=2))

if __name__=='__main__':
    OUT.mkdir(exist_ok=True);seeds();print(build())
