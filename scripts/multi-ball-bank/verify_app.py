#!/usr/bin/env python3
"""Run focused app checks within an already held simulator fleet lease."""
import argparse, os, pathlib, subprocess, json, hashlib, time, re
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(); p.add_argument('udid');p.add_argument('--work',required=True,type=pathlib.Path);p.add_argument('--out',required=True,type=pathlib.Path);p.add_argument('--tests',required=True);p.add_argument('--expected-tests',type=int);a=p.parse_args()
out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);work=a.work.resolve()
env=dict(os.environ);env['TEST_RUNNER_V52_SHOT_DIR']=str(out/'screenshots');env['V52_SHOT_DIR']=str(out/'screenshots')
files=list((ROOT/'QiuJi/Features/MultiBallPractice').glob('*.swift'))+[ROOT/'QiuJi/Features/PositionPlay/Views/FreePlayView.swift',ROOT/'QiuJiUITests/MultiBallPracticeUITests.swift',ROOT/'QiuJiTests/MultiBallPracticeTests.swift',ROOT/'project.yml']
files += [ROOT/f for f in ['QiuJi/Features/AngleTraining/AngleUsageLimiter.swift', 'QiuJi/App/MainTabView.swift', 'QiuJi/Features/AngleTraining/Views/AngleHomeView.swift', 'QiuJi/Data/Models/TablePreferencePage.swift', 'QiuJi/Data/Services/TablePreferencesStore.swift', 'QiuJi/Data/Models/ControlLayout.swift', 'QiuJi/Core/Components/ControlLayoutLibrary.swift']]
files += list((ROOT/'QiuJi/Resources/MultiBallBank').glob('*.json'))
files += [ROOT/'QiuJi/Core/Scene/AngleSceneView.swift', ROOT/'QiuJi/Core/Components/ControlLayoutHost.swift']
product=work/'DerivedData/Build/Products/Debug-iphonesimulator/球迹.app'
for resource in (ROOT/'QiuJi/Resources/MultiBallBank').glob('*.json'):
    assert resource.read_bytes()==(product/'MultiBallBank'/resource.name).read_bytes(), 'Built bank differs from current source'
fingerprints={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
command=['make','-f','scripts/Makefile','test','TEST_ACTION=test-without-building',f'TEST_DESTINATION=platform=iOS Simulator,id={a.udid}',f'BUILD_DIR={work}',f'DERIVED_DATA={work}/DerivedData',f'TEST_LOG={out}/test.log',f'TEST_JUNIT={out}/tests.xml',f'TEST_RESULT_BUNDLE={out}/tests.xcresult',f'ONLY_TESTING={a.tests}','TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO ARCHS=arm64']
start=time.time();status=1
try:
    # An unsigned incremental runner can retain an old executable in Simulator's
    # launch cache even when the installed file has the new bytes. Reinstall only
    # our test runner; preserve the user's app and its data on this shared device.
    inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))['devices']
    before=next(d for group in inventory.values() for d in group if d['udid']==a.udid)
    if before['state']=='Shutdown': subprocess.run(['xcrun','simctl','boot',a.udid],check=True)
    subprocess.run(['xcrun','simctl','bootstatus',a.udid,'-b'],check=True,stdout=subprocess.DEVNULL)
    runnerID='com.xinkuan.qiuji.uitests.xctrunner'
    existing=subprocess.run(['xcrun','simctl','get_app_container',a.udid,runnerID,'app'],capture_output=True,text=True)
    if existing.returncode==0: subprocess.run(['xcrun','simctl','uninstall',a.udid,runnerID],check=True)
    with (out/'command.log').open('w') as log: status=subprocess.call(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
    cases=re.findall(r"Test Case '([^']+)' (passed|failed) \(([0-9.]+) seconds\)", (out/'test.log').read_text())
    if not cases or (a.expected_tests is not None and len(cases)!=a.expected_tests):
        print(f'Test discovery mismatch: expected {a.expected_tests}, executed {len(cases)}')
        status=status or 3
    (out/'cases.json').write_text(json.dumps([dict(name=n,status=s,seconds=float(t)) for n,s,t in cases],indent=2))
finally:
    shutdown=subprocess.call(['xcrun','simctl','shutdown',a.udid],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))['devices']
    device=next(d for group in devices.values() for d in group if d['udid']==a.udid)
    runner=product.parent/'QiuJiUITests-Runner.app/PlugIns/QiuJiUITests.xctest/QiuJiUITests'
    summary={'device':device,'appBinarySHA256':hashlib.sha256((product/'球迹').read_bytes()).hexdigest(),'runnerBinarySHA256':hashlib.sha256(runner.read_bytes()).hexdigest(),'runnerFreshInstall':True,'command':command,'exitCode':status,'shutdownCode':shutdown,'elapsedSeconds':time.time()-start,'sourceSHA256':fingerprints,'sourceUnchanged':all(hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==s for f,s in fingerprints.items())}
    (out/'run.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
raise SystemExit(status)
