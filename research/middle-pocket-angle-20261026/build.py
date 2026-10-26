"""Compile only the research entry; verify production physics bindings before linking."""
from pathlib import Path
import hashlib, json, os, plistlib, subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/middle-pocket-angle-20261026'
BASE = ROOT / 'research/two-ball-strike-full-20261024'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def build(entry=None, output=None):
    entry = Path(entry) if entry else HERE / "main.swift"
    output = Path(output) if output else OUT
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
    app = work / 'MiddlePocketWorker.app'
    app.mkdir()
    (app / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.qiuji.middle-pocket-research',
        CFBundleExecutable='Worker', CFBundleName='MiddlePocketResearch', CFBundlePackageType='APPL')))
    for p in (BASE / 'Worker.app').iterdir():
        if p.name not in ('Worker', 'Info.plist', '_CodeSignature'):
            (app / p.name).symlink_to(p)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    compile_entry = work / 'main.swift'
    compile_entry.write_bytes(entry.read_bytes())
    obj = work / 'main.o'
    commands = [
        ['xcrun', 'swiftc', '-frontend', '-c', *map(str, frozen), '-primary-file', str(compile_entry),
         '-sdk', sdk, '-target', 'arm64-apple-ios17.0-simulator', '-swift-version', '5', '-O', '-D', 'DEBUG', '-module-name', 'QiuJi', '-o', str(obj)],
        ['xcrun', 'swiftc', '-sdk', sdk, '-target', 'arm64-apple-ios17.0-simulator',
         *[str(p) for p in sorted((BASE/'objects').glob('*.o')) if p.name != 'main.o'], str(obj),
         '-lz', '-Xlinker', '-syslibroot', '-Xlinker', sdk, '-o', str(app/'Worker')]
    ]
    binding = dict(method='unchanged production physics objects; new research entry only',
        production=bindings, entrySHA256=sha(entry), frozenSources={p.name:sha(p) for p in frozen},
        objects={p.name:sha(p) for p in sorted((BASE/'objects').glob('*.o')) if p.name!='main.o'})
    (output/'source-binding.json').write_text(json.dumps(binding, indent=2))
    (ev/'build-commands.json').write_text(json.dumps(commands, indent=2))
    with (ev/'build.log').open('w') as log:
        for command in commands:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, SDKROOT=sdk))
            if result.returncode:
                raise RuntimeError((ev/'build.log').read_text()[-7000:])
    return app/'Worker'
