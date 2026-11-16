"""A/B/B/A current-source simulator comparison of inherited versus global -O.

Runs only inside local-test and fleet leases. Does not operate on physical devices.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET

p=argparse.ArgumentParser()
p.add_argument('--work',type=Path,required=True)
p.add_argument('--evidence',type=Path,required=True)
p.add_argument('--udid',required=True)
a=p.parse_args()
repo=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
work,evidence=a.work,a.evidence
def run(cmd,**kw): return subprocess.run([str(x) for x in cmd],check=True,**kw)
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def replace(p,old,new):
    s=p.read_text();assert s.count(old)==1,(p,old,s.count(old));p.write_text(s.replace(old,new))

assert shutil.disk_usage(work).free>8*1024**3
snapshot=work/'snapshot';snapshot.mkdir()
for name in ['QiuJi','QiuJiLiveActivity','QiuJiUITests','QiuJiTests','Config','Packages','scripts','QiuJi.xcodeproj']:
    run(['cp','-cR',repo/name,snapshot/name])
run(['python3',here/'instrument_device.py',snapshot])
replace(snapshot/'QiuJi/Data/Services/TablePreferencesStore.swift',
    '        return result\n    }\n\n    /// Explicit user action:',
    '''        if page == .composer && ProcessInfo.processInfo.arguments.contains("-topDown.direct3D") {
            result.values[.view3D] = 1
        }
        return result
    }

    /// Explicit user action:''')
test='''    func testTemporaryTopDownBuildComparison() throws {
        let app = try launchP01(requiresLandscape: false,
            extraArgs: ["-topDown.latencyProbe", "-topDown.direct3D"], normalizeView: false)
        defer { app.terminate() }
        XCTAssertEqual(try p01Scene(app)["cameraMode"] as? String, "3D")
        sleep(3)
        let peek = app.buttons["shotCamera.temporaryTopDown"]
        for cycle in 0..<15 {
            peek.tap()
            sleep(2)
            XCTAssertEqual(peek.value as? String, "已选中")
            if cycle == 0 || cycle == 14 {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "temporary-build-comparison-\\(cycle)"
                shot.lifetime = .keepAlways
                add(shot)
            }
            peek.tap()
            sleep(1)
            XCTAssertEqual(peek.value as? String, "未选中")
        }
    }

'''
replace(snapshot/'QiuJiUITests/DailyAdaptivePanelUITests.swift',
        '    func testP01TemporaryTableProjection() throws {',test+'    func testP01TemporaryTableProjection() throws {')
for scheme in (snapshot/'QiuJi.xcodeproj').rglob('QiuJi.xcscheme'):
    tree=ET.parse(scheme)
    for parent in list(tree.iter('Testables'))+list(tree.iter('BuildActionEntries')):
        for child in list(parent):
            ref=child.find('BuildableReference')
            if ref is not None and ref.get('BlueprintName')=='QiuJiTests':parent.remove(child)
    tree.write(scheme,encoding='utf-8',xml_declaration=True)
for f in ['AngleSceneView.swift','AngleTrainingScene.swift','CameraRig.swift']:
    shutil.copy2(snapshot/'QiuJi/Core/Scene'/f,evidence/f)
shutil.copy2(snapshot/'QiuJiUITests/DailyAdaptivePanelUITests.swift',evidence/'DailyAdaptivePanelUITests.swift')
protocol={'arms':['A','B','B','A'],'cyclesPerArm':15,'sourceHead':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
    'A':'project inherited main App -O; package Debug defaults',
    'B':'global SWIFT_OPTIMIZATION_LEVEL=-O including dependencies',
    'target':'generic iOS Simulator for both; same instrumented source and direct-3D fixture',
    'limits':'Not the saved physical-device executables; C1 simulator support measured in probe events; no on-glass timing.'}
(evidence/'protocol.json').write_text(json.dumps(protocol,indent=2))
selector='QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownBuildComparison'
for label in ['A','B']:
    target=evidence/label;target.mkdir()
    cmd=['make','-f',snapshot/'scripts/Makefile','test','TEST_ACTION=build-for-testing',
         f'DERIVED_DATA={work/label}',f'BUILD_DIR={work}',f'TEST_LOG={target/"build.log"}',
         f'TEST_JUNIT={target/"build.xml"}','TEST_DESTINATION=generic/platform=iOS Simulator',
         'TEST_CODE_COVERAGE=NO',f'ONLY_TESTING={selector}',
         'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES'+(' SWIFT_OPTIMIZATION_LEVEL=-O' if label=='B' else '')]
    (target/'build-command.json').write_text(json.dumps([str(x) for x in cmd],indent=2))
    print('BUILD',label,flush=True)
    with (target/'console.log').open('w') as log:run(cmd,cwd=snapshot,stdout=log,stderr=subprocess.STDOUT)

# Equalize the XCTest runner; only the App/dependency build recipe differs.
products={k:work/k/'Build/Products/Debug-iphonesimulator' for k in ['A','B']}
runner='QiuJiUITests-Runner.app'
assert (products['A']/runner).is_dir() and (products['B']/runner).is_dir()
shutil.rmtree(products['A']/runner)
run(['cp','-cR',products['B']/runner,products['A']/runner])
identity={k:{'appSHA256':sha(v/'球迹.app/球迹'),'runnerSHA256':sha(v/runner/'QiuJiUITests-Runner')} for k,v in products.items()}
(evidence/'built-identities.json').write_text(json.dumps(identity,indent=2))
run(['xcrun','simctl','boot',a.udid])
run(['xcrun','simctl','bootstatus',a.udid,'-b'])
try:
    for index,label in enumerate(['A','B','B','A'],1):
        target=evidence/f'arm{index}-{label}';target.mkdir()
        app=products[label]/'球迹.app'
        run(['xcrun','simctl','install',a.udid,app])
        start=time.time()
        cmd=['make','-f',snapshot/'scripts/Makefile','test','TEST_ACTION=test-without-building',
             f'DERIVED_DATA={work/label}',f'BUILD_DIR={work}',f'TEST_LOG={target/"test.log"}',
             f'TEST_JUNIT={target/"test.xml"}',f'TEST_RESULT_BUNDLE={target/"result.xcresult"}',
             f'TEST_DESTINATION=platform=iOS Simulator,id={a.udid}',
             'SIM_TEST_GUARD=','TEST_CODE_COVERAGE=NO',f'ONLY_TESTING={selector}',
             'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES']
        print('ARM',index,label,flush=True)
        with (target/'console.log').open('w') as log:
            done=subprocess.run([str(x) for x in cmd],cwd=snapshot,stdout=log,stderr=subprocess.STDOUT,
                env={**os.environ,'TEST_RUNNER_DAILY_ADAPTIVITY_DIR':str(target/'ui')})
        data=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','data'],text=True).strip())
        selected=[]
        samples=target/'samples';samples.mkdir()
        for f in (data/'Documents/TopDownLatency').glob('*/*.json'):
            rows=json.loads(f.read_text())
            begin=next(x for x in rows if x['event']=='begin')
            if begin['wallUnix']<start:continue
            shutil.copy2(f,samples/f.name);selected.append(f)
        installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','app'],text=True).strip())
        state={'exitCode':done.returncode,'startUnix':start,'sampleCount':len(selected),
               'installedSHA256':sha(installed/'球迹'),'expectedSHA256':identity[label]['appSHA256']}
        (target/'identity.json').write_text(json.dumps(state,indent=2))
        assert done.returncode==0,state
        assert state['installedSHA256']==state['expectedSHA256'],state
        assert len(selected)==15,state
    (evidence/'completed.json').write_text(json.dumps({'arms':4,'samples':60,'status':'completed'}))
finally:
    run(['xcrun','simctl','shutdown',a.udid])
