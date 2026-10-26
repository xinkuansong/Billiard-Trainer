"""Compile only the research entry; verify production physics bindings before linking."""
from pathlib import Path
import hashlib, json, os, plistlib, subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/rack-energy-separation-20261026/control'
BASE = ROOT / 'research/two-ball-strike-full-20261024'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def build():
    OUT.mkdir(exist_ok=True)
    work = Path(os.environ['QIUJI_TEST_WORK'])
    ev = Path(os.environ['QIUJI_TEST_EVIDENCE'])
    current = {p.name: p for p in (ROOT / 'QiuJi').rglob('*.swift')}
    frozen = sorted((BASE / 'native-source').glob('*.swift'))
    bindings = []
    for p in frozen:
        q = current.get(p.name)
        if q and ('/Physics/' in str(q) or '/Rack/' in str(q) or any(s in p.name for s in (
                'AngleSceneCalculator', 'BTPhysics', 'CueClearance', 'CueStrikeAccess', 'TableGeometry', 'ShotFacts', 'AccuracyTipSelector'))):
            assert sha(p) == sha(q), f'Production drift: {q}'
            bindings.append(dict(path=str(q.relative_to(ROOT)), sha256=sha(q)))
    assert len(bindings) >= 32
    app = work / 'MultiBallWorker.app'
    app.mkdir()
    (app / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.qiuji.multiball-research',
        CFBundleExecutable='Worker', CFBundleName='MultiBallResearch', CFBundlePackageType='APPL')))
    for p in (BASE / 'Worker.app').iterdir():
        if p.name not in ('Worker', 'Info.plist', '_CodeSignature'):
            (app / p.name).symlink_to(p)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    copies = work/'source'; copies.mkdir()
    source_map = {p.name:p for p in frozen}
    changes = {}
    for name in ['EngineNumerics.swift', 'PhysicsEvent.swift', 'EventDrivenEngine.swift', 'CollisionDetector.swift']:
        original = source_map[name].read_text()
        altered = original
        if name == 'EngineNumerics.swift':
            assert original.count('let eps: Float = 0.00025') == 1
            altered = original.replace('let eps: Float = 0.00025', 'let eps: Float = researchContactEpsilon')
            marker = '    static func isBallPairOverlappingOrTouching('
            altered = altered.replace(marker, '    static var researchContactEpsilon: Float = 0.00025\n'+marker)
        if name == 'PhysicsEvent.swift':
            assert original.count('private static let tieEpsilon: Float = 1e-7') == 1
            altered = original.replace('private static let tieEpsilon: Float = 1e-7', 'static var researchTieEpsilon: Float = 1e-7')
            altered = altered.replace('< tieEpsilon', '< researchTieEpsilon')
        if name in ['EventDrivenEngine.swift','CollisionDetector.swift']:
            from instrument import instrument
            altered = instrument(name,altered)
        q=copies/name; q.write_text(altered); source_map[name]=q
        changes[name]=dict(originalSHA=sha(BASE/'native-source'/name), researchSHA=sha(q))
        import difflib
        (OUT/(name+'.diff')).write_text(''.join(difflib.unified_diff(original.splitlines(True),altered.splitlines(True),fromfile=name,tofile='research/'+name)))
        (HERE/name).write_text(altered)
    sources = list(source_map.values()) + [HERE/'main.swift']
    replacement = ['EngineNumerics', 'PhysicsEvent', 'EventDrivenEngine', 'CollisionDetector', 'main']
    commands=[]
    for name in replacement:
        primary = HERE/'main.swift' if name == 'main' else source_map[name+'.swift']
        args=[]
        for src in sources:
            if src == primary: args.append('-primary-file')
            args.append(str(src))
        commands.append(['xcrun','swiftc','-frontend','-c',*args,'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-module-name','QiuJi','-o',str(work/(name+'.o'))])
    objects=[p for p in sorted((BASE/'objects').glob('*.o')) if p.stem not in replacement]
    commands.append(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*map(str,objects),*[str(work/(n+'.o')) for n in replacement],'-lz','-Xlinker','-syslibroot','-Xlinker',sdk,'-o',str(app/'Worker')])
    binding = dict(method='research copies of contact epsilon and event tie epsilon; recompile both and caller EventDrivenEngine; no production edits',production=bindings,entrySHA256=sha(HERE/'main.swift'),changes=changes,frozenSources={p.name:sha(p) for p in frozen},objects={p.name:sha(p) for p in objects})
    (OUT/'source-binding.json').write_text(json.dumps(binding, indent=2))
    (ev/'build-commands.json').write_text(json.dumps(commands, indent=2))
    with (ev/'build.log').open('w') as log:
        for command in commands:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, SDKROOT=sdk))
            if result.returncode:
                raise RuntimeError((ev/'build.log').read_text()[-7000:])
    return app/'Worker'
