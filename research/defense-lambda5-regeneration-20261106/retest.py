from pathlib import Path
import os,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];ev=Path(os.environ['QIUJI_TEST_EVIDENCE'])
old=ROOT/'output/local-test-runs/260ea7dd002045df9cddd0e10915933f/work'
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','standard-pad','--task','defense-lambda5-physical-r2-20261106','--','make','-f',str(ROOT/'scripts/Makefile'),'_test',f'BUILD_DIR={old}',f'DERIVED_DATA={old}/DerivedData',f'TEST_LOG={ev}/test-results.log',f'TEST_JUNIT={ev}/test-results.xml',f'TEST_RESULT_BUNDLE={ev}/tests.xcresult','TEST_DESTINATION=platform=iOS Simulator,id={udid}','ONLY_TESTING=QiuJiTests/DefensePhysicalScoringTests','TEST_CODE_COVERAGE=NO'],check=True)
