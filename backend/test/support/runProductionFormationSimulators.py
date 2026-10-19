"""Explicit, sequential two-device production probe; fixture tokens never enter argv/logs."""
import json
import os
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[3]
out = root / 'output/custom-formation-production-sims-20261019'
a = '6873B8B5-226A-4C33-BAA6-3516CF26D1F8'
b = 'FEC0D1E7-0A8E-4CDB-ADE9-D33DC2D4C898'
selector = 'QiuJiTests/CustomFormationSyncIntegrationTests/testAuthorizedProductionTwoDevicePhase'
phases = [('A-create', a, 1), ('B-restore', b, 1), ('B-edit', b, 2),
          ('A-observe-edit-and-edit', a, 3), ('B-observe-edit-and-delete', b, 4),
          ('A-observe-delete', a, 4), ('B-fresh-after-delete', b, 4)]
results = []


def run_phase(phase, device, label=None):
    label = label or phase
    env = dict(os.environ,
               TEST_RUNNER_FORMATION_PRODUCTION_AUTHORIZATION='authorized',
               TEST_RUNNER_FORMATION_PRODUCTION_FIXTURE=str(out / 'fixture.json'),
               TEST_RUNNER_FORMATION_PRODUCTION_PHASE=phase,
               TEST_RUNNER_FORMATION_PRODUCTION_REPORT=str(out / (label + '-state.json')))
    command = ['python3', 'scripts/simulator_lifecycle.py', 'run', '--task', 'formation-production-' + label,
               '--udid', device, '--', 'make', '-f', 'scripts/Makefile', 'test',
               'TEST_DESTINATION=platform=iOS Simulator,id={udid}', 'TEST_ACTION=test-without-building',
               'DERIVED_DATA=' + str(root / 'build/CustomFormation-20261018'),
               'BUILD_DIR=' + str(out / 'build'), 'TEST_LOG=' + str(out / (label + '.log')),
               'ONLY_TESTING=' + selector,
               'TEST_BUILD_SETTINGS=ARCHS=arm64 -collect-test-diagnostics never -resultBundlePath ' + str(out / (label + '.xcresult'))]
    (out / (label + '-command.json')).write_text(json.dumps(command, indent=2))
    with (out / (label + '-console.log')).open('w') as log:
        subprocess.run(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    summary = json.loads(subprocess.check_output(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                                                  '--path', str(out / (label + '.xcresult'))]))
    assert summary['result'] == 'Passed' and summary['passedTests'] == 1
    assert summary['failedTests'] == 0 and summary['skippedTests'] == 0
    state = json.loads((out / (label + '-state.json')).read_text())
    assert state['simulatorUDID'] == device, state
    assert state['baseURL'] == 'http://106.54.3.210:3000' and state['pendingCount'] == 0
    (out / (label + '-summary.json')).write_text(json.dumps(summary, indent=2))
    results.append({'phase': label, 'udid': device, 'passed': 1, 'failed': 0, 'skipped': 0, 'state': state})
    (out / 'results.json').write_text(json.dumps(results, indent=2))
    print('PASS ' + label, flush=True)


for phase, device, revision in phases:
    run_phase(phase, device)
    with (out / (phase + '-server.json')).open('w') as log:
        subprocess.run(['ssh', 'root@106.54.3.210',
                        'PRODUCTION_FORMATION_SMOKE=authorized node /root/formation-production-sims-20261019/account.cjs inspect ' + str(revision)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)

assert len({r['state']['accountID'] for r in results}) == 1
run_phase('cleanup', a, 'A-cleanup')
run_phase('cleanup', b, 'B-cleanup')
with (out / 'account-cleanup.log').open('w') as log:
    subprocess.run(['ssh', 'root@106.54.3.210',
                    'PRODUCTION_FORMATION_SMOKE=authorized node /root/formation-production-sims-20261019/account.cjs cleanup'],
                   stdout=log, stderr=subprocess.STDOUT, check=True)
(out / 'fixture.json').unlink()
print('PASS same account, seven production phases, two local cleanups and production cleanup', flush=True)
