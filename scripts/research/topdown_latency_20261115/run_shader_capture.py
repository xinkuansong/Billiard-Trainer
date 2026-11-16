"""Reuse archived simulator products; externally inspect Metal via LLDB."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading
import time

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--work', type=Path, required=True)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--udid', required=True)
    p.add_argument('--cycles', type=int, default=3)
    p.add_argument('--max-libraries', type=int, default=1)
    p.add_argument('--empty-library-cache', action='store_true')
    a = p.parse_args()
    repo = Path(__file__).resolve().parents[3]
    evidence, work = a.evidence, a.work
    def run(cmd, **kw):
        return subprocess.run([str(x) for x in cmd], check=True, **kw)
    def sha(path):
        with path.open('rb') as stream:
            return hashlib.file_digest(stream, 'sha256').hexdigest()
    def container(kind):
        return Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji',kind],text=True).strip())
    def cache_manifest(root):
        return {str(f.relative_to(root)):sha(f) for f in root.rglob('*') if f.is_file()}
    source = repo/'output/topdown-latency-device-20261115/products/simulator-render-repro/Products'
    build = work/'B'; (build/'Build').mkdir(parents=True)
    run(['cp','-cR',source,build/'Build/Products'])
    app = build/'Build/Products/Debug-iphonesimulator/球迹.app'
    identity = sha(app/'球迹')
    assert identity == '241b9a28b93b6aba004fca90c5aa39a22dbe82718318c88edabe61a33c9d99aa'
    shutil.copy2(__file__,evidence/'runner.py')
    shutil.copy2(Path(__file__).with_name('shader_lldb.py'),evidence/'shader_lldb.py')
    (evidence/'protocol.json').write_text(json.dumps({**vars(a),'work':str(work),'evidence':str(evidence),
        'sha256':identity,'limits':'Debugger pauses perturb timings. Shader/option/request attribution only; no performance acceptance.'},indent=2))
    stop = threading.Event(); observer_errors=[]
    def observer():
        try:
            deadline=time.time()+45
            while time.time()<deadline and not stop.is_set():
                lines=subprocess.check_output(['ps','-axo','pid=,comm=','-ww'],text=True).splitlines()
                found=[]
                for line in lines:
                    pair=line.strip().split(None,1)
                    if len(pair)==2 and a.udid in pair[1] and pair[1].endswith('/球迹.app/球迹'):
                        found.append((int(pair[0]),pair[1]))
                if found:
                    assert len(found)==1,found
                    pid,executable=found[0]
                    conf={'pid':pid,'executable':executable,'output':str(evidence/'shader-capture'),
                          'markers':str(container('data')/'Documents/TopDownLatency'),
                          'maxLibraries':a.max_libraries,'timeoutSeconds':160}
                    config=evidence/'lldb-config.json';config.write_text(json.dumps(conf,indent=2))
                    commands=evidence/'lldb.commands'
                    commands.write_text('command script import '+str(evidence/'shader_lldb.py')+'\nscript shader_lldb.capture(lldb.debugger, '+repr(str(config))+')\nquit\n')
                    with (evidence/'lldb.log').open('w') as log:
                        result=subprocess.run(['xcrun','lldb','-b','-s',str(commands)],stdout=log,stderr=subprocess.STDOUT,timeout=190)
                    (evidence/'lldb-exit.json').write_text(json.dumps({'exitCode':result.returncode}))
                    return
                stop.wait(.1)
            raise RuntimeError('No fresh target App PID before attach deadline')
        except Exception as exc:
            observer_errors.append(repr(exc))
            (evidence/'observer-errors.json').write_text(json.dumps(observer_errors))
    backup=work/'original-library-cache'; original=None
    run(['xcrun','simctl','boot',a.udid]);run(['xcrun','simctl','bootstatus',a.udid,'-b'])
    try:
        run(['xcrun','simctl','install',a.udid,app])
        cache=container('data')/'Library/Caches/com.xinkuan.qiuji/com.apple.metal'
        original=cache_manifest(cache)
        assert original
        run(['cp','-cR',cache,backup])
        if a.empty_library_cache:shutil.rmtree(cache)
        (evidence/'cache-before.json').write_text(json.dumps({'original':original,'emptyLibraryCache':a.empty_library_cache},indent=2))
        armstart=time.time()
        thread=threading.Thread(target=observer);thread.start()
        cmd=['make','-f',repo/'scripts/Makefile','test','TEST_ACTION=test-without-building',
             f'DERIVED_DATA={build}',f'BUILD_DIR={work}',f'TEST_LOG={evidence/"test.log"}',
             f'TEST_JUNIT={evidence/"test.xml"}',f'TEST_RESULT_BUNDLE={evidence/"result.xcresult"}',
             f'TEST_DESTINATION=platform=iOS Simulator,id={a.udid}','SIM_TEST_GUARD=','TEST_CODE_COVERAGE=NO',
             'ONLY_TESTING=QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownBuildComparison',
             'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES -collect-test-diagnostics never']
        (evidence/'test-command.json').write_text(json.dumps([str(x) for x in cmd],indent=2))
        try:
            with (evidence/'console.log').open('w') as log:
                result=subprocess.run([str(x) for x in cmd],cwd=repo,stdout=log,stderr=subprocess.STDOUT,
                    env={**os.environ,'TEST_RUNNER_DAILY_ADAPTIVITY_DIR':str(evidence/'ui'),
                         'TEST_RUNNER_TOPDOWN_CYCLES':str(a.cycles),'TEST_RUNNER_TOPDOWN_SMOKE':'0'},timeout=240)
        finally:
            stop.set();thread.join(timeout=195)
        samples=evidence/'samples';samples.mkdir()
        for f in (container('data')/'Documents/TopDownLatency').glob('*/*.json'):
            events=json.loads(f.read_text());b=next(e for e in events if e['event']=='begin')
            if b['wallUnix']>=armstart:shutil.copy2(f,samples/f.name)
        installed=sha(container('app')/'球迹')
        (evidence/'summary.json').write_text(json.dumps({'testExit':result.returncode,'installedSHA256':installed,
            'expectedSHA256':identity,'samples':len(list(samples.glob('*.json'))),'observerErrors':observer_errors},indent=2))
        assert not observer_errors and installed==identity and result.returncode==0
        events=[json.loads(line) for line in (evidence/'shader-capture/requests.jsonl').read_text().splitlines()]
        assert any(e['event']=='library' for e in events),events[-3:]
        assert not any(e['event'] in ['capture_error','attach_error'] for e in events)
        print('CAPTURED',sum(e['event']=='library' for e in events),'libraries',flush=True)
    finally:
        try:
            subprocess.run(['xcrun','simctl','terminate',a.udid,'com.xinkuan.qiuji'],capture_output=True)
            if original is not None:
                cache=container('data')/'Library/Caches/com.xinkuan.qiuji/com.apple.metal'
                final_index=evidence/'generated-cache-index';final_index.mkdir(exist_ok=True)
                for name in ['libraries.list','functions.list']:
                    if (cache/name).exists():shutil.copy2(cache/name,final_index/name)
                (final_index/'manifest.json').write_text(json.dumps(cache_manifest(cache),indent=2))
                if cache.exists():shutil.rmtree(cache)
                run(['cp','-cR',backup,cache])
                restored=cache_manifest(cache)
                (evidence/'cache-restored.json').write_text(json.dumps({'matched':restored==original,'manifest':restored},indent=2))
                assert restored==original
        finally:run(['xcrun','simctl','shutdown',a.udid])

if __name__ == '__main__':
    main()
