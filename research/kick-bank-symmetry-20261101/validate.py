"""Managed targeted App validation. Deliberately excludes the old full-bank replay."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/kick-bank-symmetry-20261101'
work = Path(os.environ['QIUJI_TEST_WORK'])
evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
uid = sys.argv[1]
unit = ROOT/'QiuJiTests/KickPracticeTests.swift'
methods = sorted(set(re.findall(r'func (test\w+)\(', unit.read_text())) - {'testAllBundledReferencesReplayUnderCurrentProductionPhysics'})
ui = ['testDirectionRetrySettingsAndNextQuestion', 'testViewSwitchAnimationBackgroundAndMeasurement']
paths = list((ROOT/'QiuJi/Features/KickPractice').glob('*.swift')) + [unit,ROOT/'QiuJiUITests/KickPracticeUITests.swift',ROOT/'QiuJi/Core/Components/PracticeRailColors.swift',ROOT/'QiuJi/Features/PositionPlay/Views/DailyTemplateHeader.swift',ROOT/'QiuJi/Resources/kick-practice-bank.json']
paths += list((ROOT/'QiuJi/Core/Physics').rglob('*.swift'))
def hashes():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
before = hashes()
(OUT/'validation-source-before.json').write_text(json.dumps(before,indent=2)+'\n')
log = evidence/'tests.log'
result = evidence/'tests.xcresult'
settings = ['ONLY_ACTIVE_ARCH=YES', 'ARCHS=arm64']
settings += ['-only-testing:QiuJiTests/KickPracticeTests/'+name for name in methods]
settings += ['-only-testing:QiuJiUITests/KickPracticeUITests/'+name for name in ui]
command = ['make','-f','scripts/Makefile','_test','TEST_ACTION=test',f'TEST_DESTINATION=platform=iOS Simulator,id={uid}',
           f'BUILD_DIR={work}',f'DERIVED_DATA={work}/DerivedData',f'TEST_LOG={log}',f'TEST_JUNIT={evidence}/tests.xml',
           f'TEST_RESULT_BUNDLE={result}', 'TEST_BUILD_SETTINGS='+' '.join(settings)]
started = time.time()
try:
    (OUT/'validation-command.json').write_text(json.dumps(dict(command=command,work=str(work),evidence=str(evidence),udid=uid),indent=2)+'\n')
    with (evidence/'console.log').open('w') as console:
        subprocess.run(command,cwd=ROOT,stdout=console,stderr=subprocess.STDOUT,check=True)
    contents = log.read_text()
    assert '** TEST SUCCEEDED **' in contents
    passed = set(re.findall(r"KickPracticeTests (test\w+)\]' passed", contents))
    passed_ui = set(re.findall(r"KickPracticeUITests (test\w+)\]' passed", contents))
    assert passed == set(methods), (passed,methods)
    assert passed_ui == set(ui), (passed_ui,ui)
    assert 'Kick symmetry stratified references replayed: 463/463' in contents
    packed = list((work/'DerivedData/Build/Products/Debug-iphonesimulator').glob('*.app/kick-practice-bank.json'))
    assert len(packed)==1
    sha = hashlib.sha256(packed[0].read_bytes()).hexdigest()
    assert sha == json.loads((OUT/'audit.json').read_text())['bankSHA256']
    after = hashes()
    drift = [p for p in before if before[p] != after[p]]
    summary = subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',str(result)])
    (OUT/'test-summary.json').write_bytes(summary)
    subprocess.run(['xcrun','xcresulttool','export','attachments','--path',str(result),'--output-path',str(OUT/'app-images')],check=True)
    report = dict(udid=uid,seconds=time.time()-started,unitTests=len(passed),uiTests=len(passed_ui),
                  sampleReplays=463,bankSHA256=sha,sourceDrift=drift,sourceHashes=before,
                  methods=methods,uiMethods=ui,resultBundle=str(result),log=str(log))
    (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    assert not drift, drift
    print(json.dumps({k:v for k,v in report.items() if k not in ['sourceHashes','methods','uiMethods']}))
finally:
    subprocess.run(['xcrun','simctl','shutdown',uid],check=False)
