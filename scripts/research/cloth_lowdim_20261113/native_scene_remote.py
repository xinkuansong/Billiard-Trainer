#!/usr/bin/env python3
"""Plan or execute one frozen native macOS study on the explicitly released Mac mini.

Default is local plan-only: no SSH, GPU, simulator, or queue operation. --execute
must be supplied only after the coordinator releases the remote GPU. A failure
is fetched and preserved, never retried automatically. This tool never cleans.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shlex
import stat
import subprocess
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def inventory(path):
    result = {}
    for file in sorted(path.rglob('*')):
        if file.is_symlink():
            raise ValueError('Symlink in evidence: ' + str(file))
        if file.is_file():
            result[str(file.relative_to(path))] = {'sha256': sha(file), 'bytes': file.stat().st_size,
                                                  'mode': stat.S_IMODE(file.stat().st_mode)}
    return result


def verify_package(bundle):
    manifest = json.loads((bundle / 'manifest.json').read_text())
    body = {k: v for k, v in manifest.items() if k != 'packageID'}
    if hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest() != manifest['packageID']:
        raise ValueError('Package identity mismatch')
    for relative, expected in manifest['files'].items():
        file = bundle / relative
        if file.is_symlink() or not file.resolve().is_relative_to(bundle.resolve()) or sha(file) != expected:
            raise ValueError('Frozen package changed: ' + relative)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True, help='New local raw evidence directory')
    parser.add_argument('--transfer-out', type=Path, required=True, help='Local plan/transfer/verification directory')
    parser.add_argument('--host', default='song@fengchuibuchuifengdeMac-mini.local')
    parser.add_argument('--control-path', default='/tmp/cloth-lowdim-mini-20261113.sock')
    parser.add_argument('--remote-base', default='/Users/song/simulator-work/cloth-native-scene-20261113')
    parser.add_argument('--run-id', default='guardcombo-r1')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    bundle, out, evidence = args.bundle.resolve(), args.out.resolve(), args.transfer_out.resolve()
    for value in [args.remote_base, args.run_id]:
        if not re.fullmatch(r'[A-Za-z0-9_./-]+', value) or '..' in Path(value).parts:
            raise ValueError('Unsafe remote path/run-id')
    if not args.remote_base.startswith('/Users/song/simulator-work/cloth-native-scene-'):
        raise ValueError('Only the explicitly scoped native scene directory is supported')
    manifest = verify_package(bundle)
    remote_package = args.remote_base + '/package-' + args.run_id
    remote_results = args.remote_base + '/results-' + args.run_id
    remote_manifest = args.remote_base + '/evidence-' + args.run_id + '-manifest.json'
    ssh = ['ssh', '-S', args.control_path, '-o', 'BatchMode=yes', args.host]
    transport = 'ssh -S ' + shlex.quote(args.control_path) + ' -o BatchMode=yes'
    upload = ['rsync', '-a', '--exclude=benchmark', '-e', transport, str(bundle) + '/', args.host + ':' + remote_package + '/']
    run = ['python3', remote_package + '/run.py', '--bundle', remote_package, '--out', remote_results, '--run-only']
    fetch = ['rsync', '-a', '-e', transport, args.host + ':' + remote_results + '/', str(out) + '/']
    plan = {'mode': 'execute' if args.execute else 'plan-only', 'packageID': manifest['packageID'],
            'candidate': manifest['candidate'], 'arms': manifest['comparisonArms'], 'remoteBase': args.remote_base,
            'remotePackage': remote_package, 'remoteResults': remote_results, 'localRaw': str(out),
            'upload': upload, 'run': ssh + [shlex.join(run)], 'fetch': fetch,
            'scheduling': 'Coordinator must explicitly release M4 before --execute; no simulator/queue commands or automatic retry',
            'retention': 'Keep exact native task directory for requested follow-up; no cleanup performed'}
    evidence.mkdir(parents=True, exist_ok=True)
    write(evidence / 'plan.json', plan)
    print(json.dumps(plan, ensure_ascii=False, indent=2), flush=True)
    if not args.execute:
        return
    if out.exists() or (evidence / 'execution.json').exists():
        raise ValueError('Refusing to overwrite previous raw evidence or repeat an execution')

    def remote(code):
        return subprocess.run(ssh + ['python3 -'], input=code, text=True, capture_output=True, check=True).stdout

    preflight_code = '''import subprocess,json,shutil,platform
raw=json.loads(subprocess.check_output(['system_profiler','SPHardwareDataType','SPDisplaysDataType','-json']))
hw=raw['SPHardwareDataType'][0]
keys=['machine_name','machine_model','chip_type','cpu_type','number_processors','physical_memory']
ps=subprocess.check_output(['ps','-axo','pid=,args='],text=True)
active=[line for line in ps.splitlines() if ('xcodebuild' in line or '/benchmark' in line or 'ClothSupport' in line) and 'python3 -' not in line]
data={'computerName':subprocess.check_output(['scutil','--get','ComputerName'],text=True).strip(),'hardware':{k:hw[k] for k in keys if k in hw},'gpu':[{k:v for k,v in d.items() if k in ['_name','sppci_model','sppci_cores'] or 'metal' in k.lower() or 'mtl' in k.lower()} for d in raw['SPDisplaysDataType']],'os':subprocess.check_output(['sw_vers'],text=True),'architecture':platform.machine(),'xcode':subprocess.check_output(['xcodebuild','-version'],text=True),'swift':subprocess.check_output(['xcrun','swiftc','--version'],text=True),'freeBytes':shutil.disk_usage('/Users/song').free,'activeWorkloadMatches':active}
print(json.dumps(data,ensure_ascii=False,indent=2))
'''
    preflight = json.loads(remote(preflight_code))
    write(evidence / 'host-preflight.json', preflight)
    if preflight['activeWorkloadMatches'] or preflight['freeBytes'] < 12 * 1024**3:
        raise RuntimeError('Remote active workload or insufficient free space; no execution started')
    remote('from pathlib import Path\nimport json\nbase=Path(' + repr(args.remote_base) + ')\n'
           'assert base.is_dir() and not base.is_symlink()\nassert (base/"HOLD.json").is_file()\n'
           'assert not Path(' + repr(remote_package) + ').exists()\nassert not Path(' + repr(remote_results) + ').exists()\n')
    started = time.monotonic()
    subprocess.run(upload, check=True)
    execution = {'status': 'started', 'packageID': manifest['packageID'], 'remotePackage': remote_package,
                 'remoteResults': remote_results, 'startedUTC': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    write(evidence / 'execution.json', execution)
    with (evidence / 'remote-launch.log').open('w') as log:
        result = subprocess.run(ssh + [shlex.join(run)], stdout=log, stderr=subprocess.STDOUT, timeout=730)
    execution.update(status='succeeded' if result.returncode == 0 else 'failed', returncode=result.returncode,
                     seconds=time.monotonic() - started)
    write(evidence / 'execution.json', execution)
    # Even an ordinary failed validator is preserved and fetched. Never rerun it.
    seal = '''from pathlib import Path
import hashlib,json,stat,subprocess
package=Path(PACKAGE);results=Path(RESULTS)
m=json.loads((package/'manifest.json').read_text())
for n,h in m['files'].items(): assert hashlib.sha256((package/n).read_bytes()).hexdigest()==h,n
assert results.is_dir()
(results/'host-preflight.json').write_text(PREFLIGHT)
files={}
for p in sorted(results.rglob('*')):
 assert not p.is_symlink()
 if p.is_file():files[str(p.relative_to(results))]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size,'mode':stat.S_IMODE(p.stat().st_mode)}
manifest={'packageID':m['packageID'],'packageVerifiedAfterRun':True,'fileCount':len(files),'totalBytes':sum(v['bytes'] for v in files.values()),'files':files}
Path(MANIFEST).write_text(json.dumps(manifest,indent=2)+'\\n')
ps=subprocess.check_output(['ps','-axo','pid=,args='],text=True)
print(json.dumps({'manifest':manifest,'activeTaskProcesses':[line for line in ps.splitlines() if BASE in line]},indent=2))
'''
    for key, value in {'PACKAGE': remote_package, 'RESULTS': remote_results, 'MANIFEST': remote_manifest,
                       'PREFLIGHT': json.dumps(preflight, indent=2) + '\n', 'BASE': args.remote_base}.items():
        seal = seal.replace(key, repr(value))
    sealed = json.loads(remote(seal))
    write(evidence / 'remote-manifest.json', sealed['manifest'])
    write(evidence / 'remote-processes-after.json', sealed['activeTaskProcesses'])
    out.mkdir(parents=True, exist_ok=False)
    subprocess.run(fetch, check=True)
    actual = inventory(out)
    if actual != sealed['manifest']['files']:
        raise RuntimeError('Returned evidence differs from remote complete file set/hash/size/mode')
    write(evidence / 'verification.json', {'passed': True, 'packageID': manifest['packageID'],
          'fileCount': len(actual), 'bytes': sum(x['bytes'] for x in actual.values()),
          'rawEvidence': str(out), 'remoteHeld': True, 'remoteBase': args.remote_base,
          'scope': 'Complete evidence file set, SHA256, byte size and permission mode; package reverified after run'})
    if result.returncode:
        raise RuntimeError('Native study failed; complete failure evidence returned without retry')
    print('Native study returned and fully verified: ' + str(out), flush=True)


if __name__ == '__main__':
    main()
