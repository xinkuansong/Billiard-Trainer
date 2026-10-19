"""Run explicit two-device integration against formationTestServer's isolated fixture."""
import os
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[3]
out = root / 'output/custom-formation-sync-20261019'
a = '6873B8B5-226A-4C33-BAA6-3516CF26D1F8'
b = 'FEC0D1E7-0A8E-4CDB-ADE9-D33DC2D4C898'
for phase, device in [('A-create',a),('B-restore-edit',b),('A-offline-conflict',a),('B-delete',b),('A-observe-delete',a)]:
    env = dict(os.environ, TEST_RUNNER_FORMATION_FIXTURE=str(out/'local-fixture.json'), TEST_RUNNER_FORMATION_PHASE=phase)
    command = ['python3','scripts/simulator_lifecycle.py','run','--task','formation-sync-'+phase,'--udid',device,'--',
      'make','-f','scripts/Makefile','test','TEST_DESTINATION=platform=iOS Simulator,id={udid}',
      'TEST_ACTION=test-without-building','DERIVED_DATA='+str(root/'build/CustomFormation-20261018'),
      'TEST_LOG='+str(out/(phase+'.log')),'ONLY_TESTING=QiuJiTests/CustomFormationSyncIntegrationTests/testTwoDeviceSyncPhase','TEST_BUILD_SETTINGS=ARCHS=arm64']
    with open(out/(phase+'-console.log'),'w') as log:
        subprocess.run(command,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    print('PASS '+phase,flush=True)
