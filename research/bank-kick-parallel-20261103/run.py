from pathlib import Path
import hashlib, json, os, subprocess, sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/bank-kick-parallel-20261103'

if sys.argv[1] == 'worker':
    uid, executable, destination = sys.argv[2:]
    subprocess.run(['xcrun', 'simctl', 'boot', uid], check=True)
    try:
        subprocess.run(['xcrun', 'simctl', 'bootstatus', uid, '-b'], check=True)
        with Path(destination).with_suffix('.log').open('w') as log:
            subprocess.run(['xcrun', 'simctl', 'spawn', uid, executable, destination],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', uid], check=True)
    sys.exit(0)

mode = sys.argv[1]
work = Path(os.environ['QIUJI_TEST_WORK'])
evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
sources = work / 'sources'
sources.mkdir()
manifest = {}
paths = []
for original in sorted((ROOT / 'QiuJi').rglob('*.swift')):
    source = original
    baseline = OUT / 'baseline' / source.name
    if mode == 'baseline' and baseline.exists():
        source = baseline
    raw = source.read_bytes()
    manifest[str(source.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
    destination = sources / original.relative_to(ROOT / 'QiuJi')
    destination.parent.mkdir(parents=True, exist_ok=True)
    if original.name == 'QiuJiApp.swift':
        raw = raw.replace(b'@main', b'// diagnostic executable supplies main')
    destination.write_bytes(raw)
    paths.append(str(destination))
for filename in ['BankKickParallelRailTests.swift', 'FrozenBankQualityPredictor20261102.swift']:
    original = ROOT / 'QiuJiTests' / filename
    raw = original.read_bytes()
    manifest[str(original.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
    raw = raw.replace(b'import XCTest', b'').replace(b'@testable import QiuJi', b'').replace(b': XCTestCase', b'')
    destination = sources / filename
    destination.write_bytes(raw)
    paths.append(str(destination))
(OUT / (mode + '-sources.json')).write_text(json.dumps(manifest, indent=2))
(work / 'main.swift').write_bytes((HERE / 'main.swift').read_bytes())
(OUT / (mode + '-harness.json')).write_text(json.dumps({str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE / 'main.swift', HERE / 'run.py']}, indent=2))
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
cmd = ['xcrun', 'swiftc', '-O', '-whole-module-optimization', '-num-threads', '4',
       '-D', 'DEBUG', '-swift-version', '5', '-sdk', sdk, '-target', 'arm64-apple-ios17.0-simulator']
if mode != 'baseline':
    cmd += ['-D', 'CENTERED_CHECK']
cmd += paths + [str(work / 'main.swift'), '-lz', '-o', str(work / 'Worker')]
(evidence / 'command.json').write_text(json.dumps(cmd, indent=2))
with (evidence / 'build.log').open('w') as log:
    result = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, SDKROOT=sdk))
if result.returncode:
    print((evidence / 'build.log').read_text()[-7000:])
    sys.exit(result.returncode)
print('BUILD COMPLETE', flush=True)
subprocess.run([sys.executable, str(ROOT / 'scripts/simulator_fleet.py'), 'run',
                '--role', 'compact-phone-floor', '--task', 'bank-kick-parallel-' + mode,
                '--', sys.executable, __file__, 'worker', '{udid}', str(work / 'Worker'),
                str(OUT / (mode + '.json'))], check=True)
drift = [p for p, h in manifest.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h]
(OUT / (mode + '-execution.json')).write_text(json.dumps(dict(sourceDrift=drift, evidence=str(evidence)), indent=2))
print((OUT / (mode + '.log')).read_text()[-2500:])
