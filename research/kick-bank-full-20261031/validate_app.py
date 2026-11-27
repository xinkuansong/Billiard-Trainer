"""Run the final packaged-bank replay and one real UI flow in the held build workspace.
Invoke through simulator_fleet.py run --role standard-phone ... {udid} RUN_ID.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-bank-full-20261031'
uid,run_id=sys.argv[1:3];collect='--collect-only' in sys.argv;run=ROOT/'output/local-test-runs'/run_id
state=json.loads((run/'run.json').read_text());assert state.get('hold') and state['task']=='kick-bank-full-app-20261031'
work=run/'work';evidence=run/'evidence'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths=list((ROOT/'QiuJi/Features/KickPractice').glob('*.swift'))+[ROOT/'QiuJiTests/KickPracticeTests.swift',ROOT/'QiuJiUITests/KickPracticeUITests.swift',ROOT/'QiuJi/Core/Components/PracticeRailColors.swift',ROOT/'QiuJi/Resources/kick-practice-bank.json']
paths += [ROOT/b['path'] for b in json.loads((OUT/'source-binding.json').read_text())['sources'] if b['currentProduction']]
def hashes():return {str(p.relative_to(ROOT)):sha(p) for p in paths}
before=json.loads((OUT/'app-source-before.json').read_text()) if collect else hashes()
if not collect:(OUT/'app-source-before.json').write_text(json.dumps(before,indent=2)+'\n')
expected=set(re.findall(r'func (test\w+)\(', (ROOT/'QiuJiTests/KickPracticeTests.swift').read_text()))
result=evidence/'full-bank.xcresult';log=evidence/'full-bank.log'
if not collect:assert not result.exists()
command=['make','-f','scripts/Makefile','_test','TEST_ACTION=test',f'TEST_DESTINATION=platform=iOS Simulator,id={uid}',
    f'BUILD_DIR={work}',f'DERIVED_DATA={work}/DerivedData',f'TEST_LOG={log}',f'TEST_JUNIT={evidence}/full-bank.xml',
    f'TEST_RESULT_BUNDLE={result}','ONLY_TESTING=QiuJiTests/KickPracticeTests',
    'TEST_BUILD_SETTINGS=-only-testing:QiuJiUITests/KickPracticeUITests/testDirectionRetrySettingsAndNextQuestion']
started=(OUT/'app-source-before.json').stat().st_mtime if collect else time.time()
try:
    if not collect:subprocess.run(command,cwd=ROOT,check=True)
    assert '** TEST SUCCEEDED **' in log.read_text()
    after=hashes();assert before==after,'App sources changed during validation'
    packages=list((work/'DerivedData/Build/Products/Debug-iphonesimulator').glob('*.app/kick-practice-bank.json'))
    assert len(packages)==1,packages
    packed=packages[0]
    assert sha(packed)==sha(ROOT/'QiuJi/Resources/kick-practice-bank.json')
    contents=log.read_text()
    passed=set(re.findall(r"KickPracticeTests (test\w+)\]' passed",contents))
    assert passed==expected,(passed,expected)
    assert "KickPracticeUITests testDirectionRetrySettingsAndNextQuestion]' passed" in contents
    summary=subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',str(result)])
    (OUT/'app-test-summary.json').write_bytes(summary)
    report=dict(udid=uid,runID=run_id,seconds=time.time()-started,unitTests=len(passed),unitMethods=sorted(passed),uiTests=1,
        bankSHA256=sha(packed),sourceStable=True,resultBundle=str(result),log=str(log),sourceHashes=after)
    (OUT/'app-validation.json').write_text(json.dumps(report,indent=2)+'\n')
finally:
    if not collect:subprocess.run(['xcrun','simctl','shutdown',uid],check=False)
