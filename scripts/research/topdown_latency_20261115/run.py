import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def run(cmd, **kwargs):
    return subprocess.run([str(x) for x in cmd], check=True, **kwargs)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--udid', required=True)
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    work, evidence, udid = args.work, args.evidence, args.udid
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence/'protocol.json').write_text(json.dumps({'baseline':'259a2116b', 'current':'dd6476979',
        'sequence':['B','A','A','B'], 'cyclesPerArm':5, 'device':udid,
        'scope':'Actual composer page, first/repeated temporary open, two cue drags; renderer callback is render completion, not on-glass presentation',
        'sampling':'Same probe and UI harness, Debug -O, no shader overrides'},indent=2))
    sources = {}
    for label, revision in [('B','dd6476979'),('A','259a2116b')]:
        source = work/label/'source'
        fresh = not source.exists()
        source.mkdir(parents=True, exist_ok=True)
        # APFS clone local resources, including ignored imported assets.
        for name in (['QiuJi','QiuJiLiveActivity','QiuJiUITests','QiuJiTests','Config','Packages','scripts','QiuJi.xcodeproj'] if fresh else []):
            run(['cp','-cR',REPO/name,source/name])
        archive = work/label/'tracked.tar'
        if fresh:
            with archive.open('wb') as out:
                run(['git','archive',revision,'QiuJi','QiuJiLiveActivity','Config','Packages','QiuJi.xcodeproj'],cwd=REPO,stdout=out)
            run(['tar','-xf',archive,'-C',source])
            archive.unlink()
        # Both versions execute the same current UI test helpers and probe.
        if fresh: run(['python3',HERE/'instrument.py',source])
        for scheme in (source/'QiuJi.xcodeproj').rglob('QiuJi.xcscheme'):
            tree=ET.parse(scheme)
            for parent in list(tree.iter('Testables')) + list(tree.iter('BuildActionEntries')):
                for child in list(parent):
                    ref=child.find('BuildableReference')
                    if ref is not None and ref.get('BlueprintName')=='QiuJiTests': parent.remove(child)
            tree.write(scheme,encoding='utf-8',xml_declaration=True)
        files=['QiuJi/Core/Scene/'+n+'.swift' for n in ['AngleSceneView','AngleTrainingScene','CameraRig']]
        (evidence/f'{label}-source.json').write_text(json.dumps({p:digest(source/p) for p in files},indent=2))
        for p in files:
            destination=evidence/label/Path(p).name
            destination.parent.mkdir(exist_ok=True)
            shutil.copy2(source/p,destination)
        sources[label]=source
        if args.skip_build:
            assert not fresh, 'Cannot skip build without an existing instrumented product'
            continue
        buildlog=evidence/f'{label}-build.log'
        cmd=['make','-f',source/'scripts/Makefile','test','TEST_ACTION=build-for-testing',
             f'DERIVED_DATA={work/label/"DerivedData"}',f'BUILD_DIR={work/label}',
             f'TEST_LOG={buildlog}',f'TEST_JUNIT={evidence/label/"build.xml"}',
             'TEST_DESTINATION=generic/platform=iOS Simulator', 'TEST_CODE_COVERAGE=NO',
             'ONLY_TESTING=QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownLatencyResearch',
             'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES']
        print('BUILD',label,flush=True)
        with (evidence/f'{label}-console.log').open('w') as out: run(cmd,cwd=source,stdout=out,stderr=subprocess.STDOUT)
    run(['xcrun','simctl','boot',udid])
    run(['xcrun','simctl','bootstatus',udid,'-b'])
    try:
        for index,label in enumerate(['B','A','A','B'],1):
            target=evidence/f'arm{index}-{label}'
            target.mkdir()
            product=work/label/'DerivedData/Build/Products/Debug-iphonesimulator/球迹.app'
            run(['xcrun','simctl','install',udid,product])
            container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,'com.xinkuan.qiuji','data'],text=True).strip())
            probe=container/'Documents/TopDownLatency'
            if probe.exists(): shutil.rmtree(probe)
            cmd=['make','-f',sources[label]/'scripts/Makefile','test', 'TEST_ACTION=test-without-building',
                 f'DERIVED_DATA={work/label/"DerivedData"}',f'BUILD_DIR={work/label}',
                 f'TEST_LOG={target/"test.log"}',f'TEST_JUNIT={target/"test.xml"}',
                 f'TEST_RESULT_BUNDLE={target/"result.xcresult"}', f'TEST_DESTINATION=platform=iOS Simulator,id={udid}',
                 'SIM_TEST_GUARD=', 'TEST_CODE_COVERAGE=NO',
                 'ONLY_TESTING=QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownLatencyResearch',
                 'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES']
            print('ARM',index,label,flush=True)
            start=time.time()
            with (target/'console.log').open('w') as out:
                result=subprocess.run([str(x) for x in cmd],cwd=sources[label],stdout=out,stderr=subprocess.STDOUT,
                    env={**os.environ, 'TEST_RUNNER_DAILY_ADAPTIVITY_DIR':str(target/'ui')})
            # launchClean/Xcode may reinstall the app, replacing its data container.
            container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,'com.xinkuan.qiuji','data'],text=True).strip())
            probe=container/'Documents/TopDownLatency'
            if probe.exists(): shutil.copytree(probe,target/'samples')
            installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,'com.xinkuan.qiuji','app'],text=True).strip())
            identity={'exitCode':result.returncode,'appSHA':digest(product/'球迹'), 'installedSHA':digest(installed/'球迹'),'seconds':time.time()-start}
            (target/'identity.json').write_text(json.dumps(identity,indent=2))
            assert result.returncode==0, target
            assert identity['appSHA']==identity['installedSHA']
            assert len(list((target/'samples').glob('*.json')))==5
        (evidence/'completed.json').write_text(json.dumps({'status':'completed','arms':4}))
    finally:
        run(['xcrun','simctl','shutdown',udid])

if __name__=='__main__': main()
