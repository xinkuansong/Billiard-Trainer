import argparse, hashlib, json, os, shutil, subprocess, time, signal
from pathlib import Path
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
def run(cmd, **kw):
    return subprocess.run([str(x) for x in cmd], check=True, **kw)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser()
    p.add_argument('--work', type=Path, required=True); p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--udid', required=True); p.add_argument('--skip-build', action='store_true')
    p.add_argument('--reuse-work', type=Path)
    p.add_argument('--rebuild', action='store_true')
    p.add_argument('--video', action='store_true')
    p.add_argument('--revision')
    p.add_argument('--rounds', default='3D:default:3')
    a=p.parse_args(); w=a.reuse_work or a.work; e=a.evidence; e.mkdir(exist_ok=True, parents=True)
    shutil.copytree(HERE,e/'research-source',ignore=shutil.ignore_patterns('__pycache__'))
    assert shutil.disk_usage(w).free > 10*1024**3, 'Need 10GiB headroom'
    src=w/'source'
    if not a.skip_build:
        if not a.rebuild:
            src.mkdir()
            for name in ['QiuJi','QiuJiLiveActivity','QiuJiUITests','QiuJiTests','Config','Packages','scripts','QiuJi.xcodeproj']:
                run(['cp','-cR',REPO/name,src/name])
            if a.revision:
                archive=w/'tracked.tar'
                with archive.open('wb') as out:
                    run(['git','archive',a.revision,'QiuJi','QiuJiLiveActivity','Config','Packages','QiuJi.xcodeproj'],cwd=REPO,stdout=out)
                run(['tar','-xf',archive,'-C',src]); archive.unlink()
                (e/'revision.json').write_text(json.dumps({'revision':a.revision,'note':'Tracked App/config/project at revision; identical current UI harness; ignored model assets copied from current workspace and separately hashed.'}))
        else:
            original=json.loads((w.parent/'evidence/source-before.json').read_text())
            # Restore every drifted source from the clean baseline, including files
            # added to instrumentation after the first run and partial failed runs.
            for path, before in original.items():
                assert sha(REPO/path)==before, ('Concurrent source drift',path)
                if sha(src/path)!=before:
                    shutil.copy2(REPO/path,src/path)
            shutil.copy2(REPO/'QiuJiUITests/AdaptiveShotControlsUITests.swift',src/'QiuJiUITests/AdaptiveShotControlsUITests.swift')
        identity={str(f.relative_to(src)):sha(f) for f in (src/'QiuJi').rglob('*') if f.is_file()}
        (e/'source-before.json').write_text(json.dumps(identity, indent=2))
        for scheme in (src/'QiuJi.xcodeproj').rglob('QiuJi.xcscheme'):
            tree=ET.parse(scheme)
            for parent in list(tree.iter('Testables'))+list(tree.iter('BuildActionEntries')):
                for child in list(parent):
                    ref=child.find('BuildableReference')
                    if ref is not None and ref.get('BlueprintName')=='QiuJiTests': parent.remove(child)
            tree.write(scheme,encoding='utf-8',xml_declaration=True)
        run(['python3', HERE/'instrument.py',src])
        changed={}
        for path, before in identity.items():
            f=src/path
            if sha(f)!=before:
                dest=e/'instrumented'/path; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(f,dest)
                changed[path]={'original':before,'instrumented':sha(f)}
        (e/'instrumentation.json').write_text(json.dumps(changed,indent=2))
        cmd=['make','-f',src/'scripts/Makefile','test','TEST_ACTION=build-for-testing',
             f'DERIVED_DATA={w/"DerivedData"}',f'BUILD_DIR={w}',f'TEST_LOG={e/"build.log"}',
             f'TEST_JUNIT={e/"build.xml"}','TEST_DESTINATION=generic/platform=iOS Simulator',
             'TEST_CODE_COVERAGE=NO','ONLY_TESTING=QiuJiUITests/TableEntryLatencyResearchTests/testEntryStages',
             'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES']
        (e/'build-command.json').write_text(json.dumps(list(map(str,cmd)),indent=2))
        with (e/'build-console.log').open('w') as log: run(cmd,cwd=src,stdout=log,stderr=subprocess.STDOUT)
    product=w/'DerivedData/Build/Products/Debug-iphonesimulator/球迹.app'
    run(['xcrun','simctl','boot',a.udid]); run(['xcrun','simctl','bootstatus',a.udid,'-b'])
    try:
        for i, spec in enumerate(a.rounds.split(',')):
            fields=spec.split(':'); mode,arm,cycles=fields[:3]; routes=fields[3] if len(fields)>3 else 'composer,daily'
            out=e/f'round-{i}-{mode}-{arm}'; out.mkdir()
            run(['xcrun','simctl','install',a.udid,product])
            start=time.time()
            recorder=None
            if a.video:
                recorder=subprocess.Popen(['xcrun','simctl','io',a.udid,'recordVideo','--codec=h264',str(out/'screen.mp4')],
                    stdout=(out/'video.log').open('w'),stderr=subprocess.STDOUT)
                (out/'video-start.json').write_text(json.dumps({'beforeSpawnUnix':start,'afterSpawnUnix':time.time(),'pid':recorder.pid}))
            cmd=['make','-f',src/'scripts/Makefile','test','TEST_ACTION=test-without-building',
                 f'DERIVED_DATA={w/"DerivedData"}', f'BUILD_DIR={w}',f'TEST_LOG={out/"test.log"}',
                 f'TEST_JUNIT={out/"test.xml"}', f'TEST_RESULT_BUNDLE={out/"result.xcresult"}',
                 f'TEST_DESTINATION=platform=iOS Simulator,id={a.udid}','SIM_TEST_GUARD=',
                 'TEST_CODE_COVERAGE=NO','ONLY_TESTING=QiuJiUITests/TableEntryLatencyResearchTests/testEntryStages',
                 'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES -collect-test-diagnostics never']
            with (out/'console.log').open('w') as log:
                result=subprocess.run(list(map(str,cmd)),cwd=src,stdout=log,stderr=subprocess.STDOUT,
                    env={**os.environ,'TEST_RUNNER_ENTRY_MODE':mode,'TEST_RUNNER_ENTRY_ARM':arm,'TEST_RUNNER_ENTRY_CYCLES':cycles,'TEST_RUNNER_ENTRY_ROUTES':routes})
            if recorder:
                recorder.send_signal(signal.SIGINT); recorder.wait(timeout=45)
            container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','data'],text=True).strip())
            samples=container/'Documents/TableEntryLatency'
            if samples.exists(): shutil.copytree(samples,out/'samples')
            installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','app'],text=True).strip())
            (out/'identity.json').write_text(json.dumps({'exit':result.returncode,'startUnix':start,'endUnix':time.time(),
                'productSHA':sha(product/'球迹'),'installedSHA':sha(installed/'球迹'),'device':a.udid,'mode':mode,'arm':arm},indent=2))
            assert result.returncode==0, out
            assert sha(product/'球迹')==sha(installed/'球迹')
        (e/'completed.json').write_text(json.dumps({'status':'completed'}))
    finally: run(['xcrun','simctl','shutdown',a.udid])
if __name__=='__main__': main()
