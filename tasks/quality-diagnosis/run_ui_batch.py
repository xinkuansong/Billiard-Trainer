#!/usr/bin/env python3
"""Run an explicitly reviewed selector list against snapshot-002, serially.

JSON input: run, udid, selectors, optional env, derived_data and scheme. Never selects a
whole target, edits production, resets a device, or overwrites an earlier run.
Call with the system Python. The parent records the returned process handle.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    repo = Path(__file__).resolve().parents[2]
    base = repo / 'build/quality-diagnosis'
    snapshot = base / 'snapshot-002'
    name = config['run']
    assert re.fullmatch(r'formal-[a-z0-9-]+', name)
    assert re.fullmatch(r'[0-9A-Fa-f-]{36}', config['udid'])
    selectors = config['selectors']
    assert selectors and len(set(selectors)) == len(selectors)
    assert all(re.fullmatch(r'QiuJi(?:UI)?Tests/[A-Za-z0-9_]+/test[A-Za-z0-9_]+', x) for x in selectors)
    assert all(not any(word in x.lower() for word in ['bake', 'exportrunner', 'renderall']) for x in selectors)
    for selector in selectors:
        target, cls, method = selector.split('/')
        source = snapshot/target/(cls+'.swift')
        assert source.is_file(), 'Selector class source missing: '+selector
        code = source.read_text()
        assert re.search(r'\bclass\s+'+re.escape(cls)+r'\b', code), 'Selector class declaration missing: '+selector
        assert re.search(r'\bfunc\s+'+re.escape(method)+r'\s*\(', code), 'Selector method missing: '+selector
    assert not (snapshot/'build/.run-bake-runners').exists()
    run = base/name
    run.mkdir()  # Refuse a used output directory, including interrupted runs.
    shots = run/'screenshots'
    shots.mkdir()
    dd = config.get('derived_data', 'formal-DerivedData')
    assert re.fullmatch(r'[A-Za-z0-9-]+', dd)
    args = ['make', '-f', str(snapshot/'scripts/Makefile'), 'test',
            'BUILD_DIR='+str(run), 'DERIVED_DATA='+str(base/dd),
            'TEST_LOG='+str(run/'xcode-test.log'),
            'TEST_DESTINATION=platform=iOS Simulator,id='+config['udid'],
            'TEST_SELECTOR='+' '.join('-only-testing:'+x for x in selectors)+' -parallel-testing-enabled NO']
    scheme = config.get('scheme', 'QiuJi')
    assert scheme in ['QiuJi', 'QiuJiDiagnosticMemoryHost']
    if scheme != 'QiuJi':
        assert all(x.startswith('QiuJiTests/') for x in selectors)
        args.append('SCHEME='+scheme)
    env = os.environ.copy()
    extra = config.get('env', {})
    assert all(k.startswith('TEST_RUNNER_') for k in extra)
    env.update(extra)
    for k in ['QD_SHOT_DIR', 'V54_SHOT_DIR', 'V51_SHOT_DIR']:
        env['TEST_RUNNER_'+k] = str(shots)
    env['TEST_RUNNER_V50_SHOT_DIR'] = extra.get('TEST_RUNNER_V50_SHOT_DIR', str(shots))
    files = list((snapshot/'QiuJiUITests').glob('*.swift'))
    files += list((snapshot/'QiuJiTests').glob('*.swift'))
    files += [snapshot/'QiuJi.xcodeproj/project.pbxproj', snapshot/'QiuJi.xcodeproj/xcshareddata/xcschemes/QiuJi.xcscheme']
    if scheme != 'QiuJi':
        scheme_path = snapshot/('QiuJi.xcodeproj/xcshareddata/xcschemes/'+scheme+'.xcscheme')
        assert scheme_path.is_file()
        files.append(scheme_path)
    hashes = {str(p.relative_to(snapshot)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()}
    (run/'inputs.json').write_text(json.dumps({'config':config,'hashes':hashes,'runner_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'production_baseline':'b0/formal-baseline.json','started':datetime.datetime.now().astimezone().isoformat()}, indent=2))
    (run/'command.json').write_text(json.dumps(args, indent=2))
    (run/'selectors.txt').write_text('\n'.join(selectors)+'\n')
    with (run/'make.log').open('w') as log:
        result = subprocess.run(args, cwd=snapshot/'scripts', env=env, stdout=log, stderr=subprocess.STDOUT)
    manifest = [{'path':p.name, 'bytes':p.stat().st_size, 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in shots.iterdir() if p.is_file()]
    (run/'screenshot-manifest.json').write_text(json.dumps(manifest, indent=2))
    (run/'exit.json').write_text(json.dumps({'make_exit':result.returncode, 'finished':datetime.datetime.now().astimezone().isoformat()}, indent=2))
    print('MAKE_EXIT', result.returncode, flush=True)
    print((run/'make.log').read_text()[-2200:])
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
