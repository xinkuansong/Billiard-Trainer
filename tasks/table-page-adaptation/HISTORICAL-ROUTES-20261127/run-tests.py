import sys, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[3]
run=root/'output/local-test-runs/bde525e42adf4bc6a96b9d1603ff3a7e'
tag,action,*selectors=sys.argv[1:]
args=['make','-f','scripts/Makefile','_test','TEST_ACTION='+action,
      'TEST_DESTINATION=platform=iOS Simulator,id=16D968CB-FA14-4E00-B79F-0D675D80179E',
      'BUILD_DIR='+str(run/'work'),'DERIVED_DATA='+str(run/'work/DerivedData'),
      'TEST_CODE_COVERAGE=NO','TEST_LOG='+str(run/'evidence'/f'{tag}.log'),
      'TEST_JUNIT='+str(run/'evidence'/f'{tag}.xml'),
      'TEST_RESULT_BUNDLE='+str(run/'evidence'/f'{tag}.xcresult'),
      'TEST_BUILD_SETTINGS='+' '.join('-only-testing:'+s for s in selectors)]
with (Path(__file__).parent/f'{tag}-console.log').open('w') as out:
    result=subprocess.run(args,cwd=root,stdout=out,stderr=subprocess.STDOUT)
print(tag, 'exit', result.returncode)
sys.exit(result.returncode)
