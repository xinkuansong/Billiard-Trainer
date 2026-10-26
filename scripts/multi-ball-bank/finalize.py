#!/usr/bin/env python3
"""Finish an audited bank export and its native app checks; never commit or publish."""
import argparse
import json
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', type=pathlib.Path, required=True)
    p.add_argument('--work', type=pathlib.Path, required=True)
    p.add_argument('--out', type=pathlib.Path, required=True)
    p.add_argument('--wait', action='store_true')
    a = p.parse_args()
    source, work, out = a.source.resolve(), a.work.resolve(), a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    started = time.time()

    def status(stage, **extra):
        value = dict(stage=stage, startedAt=started, updatedAt=time.time(), **extra)
        temp = out / 'status.partial'
        temp.write_text(json.dumps(value, indent=2))
        temp.replace(out / 'status.json')

    def run(stage, command):
        status(stage)
        with (out / (stage + '.log')).open('w') as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)

    try:
        status('waiting-for-audit')
        while not (source / 'closure.json').exists():
            if (source / 'failure.json').exists():
                raise RuntimeError((source / 'failure.json').read_text())
            if not a.wait:
                raise RuntimeError('Generation has not closed; --wait is required to wait')
            time.sleep(10)
        closure = json.loads((source / 'closure.json').read_text())
        assert closure['generationSucceeded'] and closure['shutdownExitCode'] == 0
        run('export', [sys.executable, str(ROOT / 'scripts/multi-ball-bank/export.py'), str(source)])
        run('build', ['make', '-f', 'scripts/Makefile', 'test', 'TEST_ACTION=build-for-testing',
                     'TEST_DESTINATION=generic/platform=iOS Simulator', f'BUILD_DIR={work}',
                     f'DERIVED_DATA={work}/DerivedData', f'TEST_LOG={out}/build-detail.log',
                     'TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO ARCHS=arm64 -jobs 4'])
        run('test', [sys.executable, 'scripts/simulator_fleet.py', 'run', '--role', 'notch-phone',
                    '--task', 'multi-ball-full-consumer-20261026', '--', sys.executable,
                    'scripts/multi-ball-bank/verify_app.py', '{udid}', '--work', str(work),
                    '--out', str(out / 'native'), '--expected-tests', '39', '--tests',
                    'QiuJiTests/MultiBallPracticeTests -only-testing:QiuJiTests/SnakePracticeTests '
                    '-only-testing:QiuJiUITests/MultiBallPracticeUITests'])
        result = json.loads((out / 'native/run.json').read_text())
        manifest = json.loads((ROOT / 'QiuJi/Resources/MultiBallBank/manifest.json').read_text())
        assert result['exitCode'] == 0 and result['sourceUnchanged']
        assert result['device']['state'] == 'Shutdown'
        assert manifest['formalBank'] and manifest['total'] == 50000
        status('complete', tests=39, count=50000, elapsedSeconds=time.time() - started)
    except BaseException as error:
        status('failed', error=repr(error))
        raise


if __name__ == '__main__':
    main()
