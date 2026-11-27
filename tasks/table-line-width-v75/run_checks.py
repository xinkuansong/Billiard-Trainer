import json,subprocess,sys
from pathlib import Path
base=Path(__file__).resolve().parent
phase=sys.argv[1];device=sys.argv[2];selectors=json.loads((base/phase/'selectors.json').read_text())
p=base/phase
cmd=['make','-f','scripts/Makefile','_test','TEST_ACTION=test',f'TEST_DESTINATION=platform=iOS Simulator,id={device}',
'DERIVED_DATA=output/local-test-runs/b7836e3fbf3e4a4faf5b48af660d85c9/work/DerivedData',
f'TEST_LOG={p}/test.log',f'TEST_JUNIT={p}/test.xml',f'TEST_RESULT_BUNDLE={p}/tests.xcresult','TEST_CODE_COVERAGE=NO',
'TEST_BUILD_SETTINGS='+' '.join('-only-testing:'+s for s in selectors)]
(p/'command.json').write_text(json.dumps(cmd,indent=2));raise SystemExit(subprocess.call(cmd))
