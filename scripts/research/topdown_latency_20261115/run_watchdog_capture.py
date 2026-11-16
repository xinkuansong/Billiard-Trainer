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
import threading
import struct
import xml.etree.ElementTree as ET

p=argparse.ArgumentParser()
p.add_argument('--work',type=Path,required=True)
p.add_argument('--evidence',type=Path,required=True)
p.add_argument('--udid',required=True)
p.add_argument('--reuse',type=Path)
p.add_argument('--rounds',type=int,default=4)
p.add_argument('--cycles',type=int,default=30)
a=p.parse_args()
repo=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
work,evidence=a.work,a.evidence
shutil.copy2(__file__, evidence/"runner.py")
def run(cmd,**kw): return subprocess.run([str(x) for x in cmd],check=True,**kw)
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def replace(p,old,new):
    s=p.read_text();assert s.count(old)==1,(p,old,s.count(old));p.write_text(s.replace(old,new))

if a.reuse:
    source=a.reuse.resolve()/'work'
    snapshot=source/'snapshot'
    (work/'B/Build').mkdir(parents=True)
    run(['cp','-cR',source/'B/Build/Products',work/'B/Build/Products'])
    selector='QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownBuildComparison'
    (evidence/'protocol.json').write_text(json.dumps({'reuse':str(a.reuse.resolve()),'cycles':a.cycles,'rounds':a.rounds,'triggerMs':100,'hostContainerRefreshSeconds':.5},indent=2))
else:
    assert shutil.disk_usage(work).free>8*1024**3
    snapshot=work/'snapshot';snapshot.mkdir()
    for name in ['QiuJi','QiuJiLiveActivity','QiuJiUITests','QiuJiTests','Config','Packages','scripts','QiuJi.xcodeproj']:
        run(['cp','-cR',repo/name,snapshot/name])
    run(['python3',here/'instrument_watchdog.py',snapshot])
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
                extraArgs: ["-topDown.latencyProbe", "-topDown.direct3D"] + (ProcessInfo.processInfo.environment["TOPDOWN_SMOKE"] == "1" ? ["-topDown.watchdogSmoke"] : []), normalizeView: false)
            defer { app.terminate() }
            XCTAssertEqual(try p01Scene(app)["cameraMode"] as? String, "3D")
            sleep(3)
            let peek = app.buttons["shotCamera.temporaryTopDown"]
            let cycles = Int(ProcessInfo.processInfo.environment["TOPDOWN_CYCLES"] ?? "30")!
            for cycle in 0..<cycles {
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
    makefile=snapshot/'scripts/Makefile';replace(makefile,'-enableCodeCoverage $(TEST_CODE_COVERAGE)','-enableCodeCoverage $(TEST_CODE_COVERAGE) -collect-test-diagnostics never')
    for f in ['AngleSceneView.swift','AngleTrainingScene.swift','CameraRig.swift']:
        shutil.copy2(snapshot/'QiuJi/Core/Scene'/f,evidence/f)
    shutil.copy2(snapshot/'QiuJiUITests/DailyAdaptivePanelUITests.swift',evidence/'DailyAdaptivePanelUITests.swift')
    protocol={'arms':['smoke','capture1','capture2','capture3','capture4'],'cyclesPerArm':[2,30,30,30,30],'sourceHead':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
        'A':'project inherited main App -O; package Debug defaults',
        'B':'global SWIFT_OPTIMIZATION_LEVEL=-O including dependencies',
        'target':'generic iOS Simulator for both; same instrumented source and direct-3D fixture',
        'limits':'Not the saved physical-device executables; C1 simulator support measured in probe events; no on-glass timing.'}
    (evidence/'protocol.json').write_text(json.dumps(protocol,indent=2))
    selector='QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownBuildComparison'
    for label in ['B']:
        target=evidence/label;target.mkdir()
        cmd=['make','-f',snapshot/'scripts/Makefile','test','TEST_ACTION=build-for-testing',
             f'DERIVED_DATA={work/label}',f'BUILD_DIR={work}',f'TEST_LOG={target/"build.log"}',
             f'TEST_JUNIT={target/"build.xml"}','TEST_DESTINATION=generic/platform=iOS Simulator',
             'TEST_CODE_COVERAGE=NO',f'ONLY_TESTING={selector}',
             'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES'+(' SWIFT_OPTIMIZATION_LEVEL=-O' if label=='B' else '')]
        (target/'build-command.json').write_text(json.dumps([str(x) for x in cmd],indent=2))
        print('BUILD',label,flush=True)
        with (target/'console.log').open('w') as log:run(cmd,cwd=snapshot,stdout=log,stderr=subprocess.STDOUT)

app=work/'B/Build/Products/Debug-iphonesimulator/球迹.app'
identity=sha(app/'球迹')
(evidence/'built-identity.json').write_text(json.dumps({'sha256':identity},indent=2))

def observe(target,stop,armstart,errors):
    try:
        dest=target/'triggered-stacks';dest.mkdir()
        seen=set();sequences={};last_lookup=0;data=None;last_discovery=0;markers=[];deadline=time.time()+300
        transitions=[]
        while not stop.is_set() and time.time()<deadline:
            now=time.time()
            if now-last_lookup>.5:
                last_lookup=now
                r=subprocess.run(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','data'],text=True,capture_output=True)
                if r.returncode==0:data=Path(r.stdout.strip())/'Documents/TopDownLatency'
            if data is not None and now-last_discovery>.2:
                markers=list(data.glob('*/render-state.bin'));last_discovery=now
            for f in markers:
                try:
                    raw=f.read_bytes()
                except FileNotFoundError:continue
                if len(raw)!=56:continue
                seq,activation,phase,wall,uptime,pid,seq2=struct.unpack('<QQQddQQ',raw)
                if seq!=seq2 or wall<armstart:continue
                key=(str(f),activation)
                if sequences.get(str(f))!=seq:
                    transitions.append({'session':f.parent.name,'activation':activation,'phase':phase,'wallUnix':wall,'seenAt':now,'pid':pid,'sequence':seq})
                    sequences[str(f)]=seq
                    (target/'marker-transitions.json').write_text(json.dumps(transitions,indent=2))
                if phase!=1 or key in seen or now-wall<.100:continue
                # Confirm process identity before sampling; no global or unrelated target.
                command=subprocess.run(['ps','-p',str(pid),'-o','comm='],capture_output=True,text=True).stdout.strip()
                if a.udid not in command or not command.endswith('/球迹.app/球迹'):continue
                seen.add(key);base=dest/f'{f.parent.name}-activation-{activation}'
                record={'activation':activation,'session':f.parent.name,'pid':pid,'willWall':wall,'triggerWall':time.time(),'phase':phase,'process':command}
                with base.with_suffix('.log').open('w') as log:
                    proc=subprocess.Popen(['sample',str(pid),'1','1','-file',str(base.with_suffix('.txt'))],stdout=log,stderr=log)
                    record['samplerPID']=proc.pid
                    base.with_suffix('.json').write_text(json.dumps(record,indent=2))
                    record['exitCode']=proc.wait(timeout=20)
                record['endedWall']=time.time();base.with_suffix('.json').write_text(json.dumps(record,indent=2))
                print('TRIGGER',target.name,activation,round((record['triggerWall']-wall)*1000,1),'ms',flush=True)
            stop.wait(.01)
    except Exception as error:
        errors.append(repr(error));(target/'monitor-error.json').write_text(json.dumps(errors))

run(['xcrun','simctl','boot',a.udid]);run(['xcrun','simctl','bootstatus',a.udid,'-b'])
completed=[]
try:
    for label,cycles,smoke in [('smoke',2,True)]+[(f'capture{i}',a.cycles,False) for i in range(1,a.rounds+1)]:
        target=evidence/label;target.mkdir();run(['xcrun','simctl','install',a.udid,app])
        armstart=time.time();stop=threading.Event();errors=[]
        thread=threading.Thread(target=observe,args=(target,stop,armstart,errors));thread.start()
        cmd=['make','-f',snapshot/'scripts/Makefile','test','TEST_ACTION=test-without-building',
             f'DERIVED_DATA={work/"B"}',f'BUILD_DIR={work}',f'TEST_LOG={target/"test.log"}',
             f'TEST_JUNIT={target/"test.xml"}',f'TEST_RESULT_BUNDLE={target/"result.xcresult"}',
             f'TEST_DESTINATION=platform=iOS Simulator,id={a.udid}','SIM_TEST_GUARD=','TEST_CODE_COVERAGE=NO',
             f'ONLY_TESTING={selector}','TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES']
        print('ARM',label,flush=True)
        try:
            with (target/'console.log').open('w') as log:
                result=subprocess.run([str(x) for x in cmd],cwd=snapshot,stdout=log,stderr=subprocess.STDOUT,
                    env={**os.environ,'TEST_RUNNER_DAILY_ADAPTIVITY_DIR':str(target/'ui'),
                         'TEST_RUNNER_TOPDOWN_CYCLES':str(cycles),'TEST_RUNNER_TOPDOWN_SMOKE':'1' if smoke else '0'})
        finally:
            stop.set();thread.join(timeout=25)
        assert not thread.is_alive() and not errors,errors
        data=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','data'],text=True).strip())
        out=target/'samples';out.mkdir();rows=[]
        for f in (data/'Documents/TopDownLatency').glob('*/*.json'):
            events=json.loads(f.read_text());begin=next(e for e in events if e['event']=='begin')
            if begin['wallUnix']<armstart:continue
            shutil.copy2(f,out/f.name)
            rows.append({'activation':begin['activation'],'beginWall':begin['wallUnix'],
                'willMs':next(e['ms'] for e in events if e['event']=='overlayWillRender'),
                'didMs':next(e['ms'] for e in events if e['event']=='overlayDidRender')})
        installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','app'],text=True).strip())
        state={'exitCode':result.returncode,'sampleCount':len(rows),'expectedCycles':cycles,'smokeSynthetic':smoke,
               'expectedSHA256':identity,'installedSHA256':sha(installed/'球迹'),'rows':sorted(rows,key=lambda x:x['activation'])}
        (target/'summary.json').write_text(json.dumps(state,indent=2))
        assert result.returncode==0 and len(rows)==cycles and state['installedSHA256']==identity,state
        if smoke:
            captures=list((target/'triggered-stacks').glob('*.txt'));assert captures,'Synthetic stall did not trigger sampler'
            assert any('sleep' in f.read_text(errors='replace').lower() for f in captures),'Smoke stack missing sleep'
        else:
            completed.extend(rows)
        print('RESULT',label,'n',len(rows),'max',round(max(r['didMs'] for r in rows),2),flush=True)
        if not smoke and any(r['didMs']-r['willMs']>500 for r in rows) and list((target/'triggered-stacks').glob('*.txt')):
            print('LONG_RENDER_CAPTURED; stop for independent stack analysis',flush=True);break
    (evidence/'completed.json').write_text(json.dumps({'realSamples':len(completed),'smokeSamples':2,'status':'completed'},indent=2))
finally:
    run(['xcrun','simctl','shutdown',a.udid])
