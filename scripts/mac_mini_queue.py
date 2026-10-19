#!/usr/bin/env python3
"""Immutable QiuJi snapshots and a single-worker SSH simulator queue (stdlib only)."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid

DEFAULT_ROOT = '/Users/song/simulator-work/queue'
DEFAULT_HOST = 'song@fengchuibuchuifengdeMac-mini.local'
ROOTS = ['QiuJi', 'QiuJiLiveActivity', 'QiuJiTests', 'QiuJiUITests', 'QiuJi.xcodeproj',
         'Config', 'scripts', 'project.yml', 'AGENTS.md', '.agents', '.cursor/rules', '.kiro/steering']
EXCLUDED = ['QiuJi/Resources/DrillTutorials', 'QiuJi/Resources/Previews', 'QiuJi/Resources/Videos']
DEFAULT_TESTS = ['QiuJiTests/DrillContentServiceTests',
                 'QiuJiUITests/P2_DataLayerUITests/testS01_ColdLaunchNoCrash',
                 'QiuJiUITests/P2_DataLayerUITests/testS02_AllFiveTabsSwitchable',
                 'QiuJiUITests/P2_DataLayerUITests/testS04_DrillLibraryShowsDrills']
TERMINAL = {'succeeded', 'failed', 'cancelled', 'interrupted'}


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    with tmp.open('wb') as f:
        f.write(canonical(value) + b'\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def read_json(path):
    return json.loads(Path(path).read_text())


@contextmanager
def lock(path, blocking=True):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with Path(path).open('a') as f:
        fcntl.flock(f, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        try:
            yield f
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def safe_path(value):
    p = PurePosixPath(value)
    if p.is_absolute() or '..' in p.parts or not p.parts or '\\' in value:
        raise ValueError('Unsafe archive path: ' + value)
    return p


def selected(value, roots=ROOTS):
    p = safe_path(value)
    if not any(value == r or value.startswith(r + '/') for r in roots):
        return False
    if any(value == r or value.startswith(r + '/') for r in EXCLUDED):
        return False
    if any(x in p.parts for x in ['.git', 'xcuserdata', '__pycache__', '.DS_Store', 'node_modules']):
        return False
    return not (p.name.startswith(('Secrets', '.env')) or p.suffix in ['.p12', '.key', '.pem', '.mobileprovision', '.cer'])


def tree_files(root):
    result = {}
    for base, dirs, files in os.walk(root):
        for name in dirs + files:
            p = Path(base) / name
            if p.is_symlink():
                raise ValueError('Symlinks are not allowed in snapshots: ' + str(p))
        for name in files:
            p = Path(base) / name
            if not p.is_file():
                raise ValueError('Not a regular file: ' + str(p))
            result[p.relative_to(root).as_posix()] = {'sha256': digest(p), 'executable': bool(p.stat().st_mode & 0o111)}
    return result


def seal(path):
    for base, dirs, files in os.walk(path, topdown=False):
        for name in files:
            p = Path(base) / name
            p.chmod(0o555 if p.stat().st_mode & 0o111 else 0o444)
        Path(base).chmod(0o555)


def unpack(archive, target, filtering=False, roots=ROOTS):
    with tarfile.open(archive, 'r:*') as tar:
        seen = set()
        for item in tar:
            rel = safe_path(item.name)
            if item.isdir():
                continue
            if not item.isfile() or item.name in seen:
                raise ValueError('Nonregular or duplicate archive member: ' + item.name)
            seen.add(item.name)
            if filtering and not selected(item.name, roots):
                continue
            p = target / str(rel)
            p.parent.mkdir(parents=True, exist_ok=True)
            with tar.extractfile(item) as inp, p.open('xb') as out:
                shutil.copyfileobj(inp, out)
            p.chmod(0o755 if item.mode & 0o111 else 0o644)


def working_files(repo, roots):
    result = {}
    for r in roots:
        p = repo / r
        if not p.exists():
            continue
        if p.is_symlink():
            raise ValueError('Symlink source root: ' + str(p))
        candidates = [p] if p.is_file() else p.rglob('*')
        for f in candidates:
            rel = f.relative_to(repo).as_posix()
            if not selected(rel, roots):
                continue
            if f.is_symlink():
                raise ValueError('Symlink source: ' + rel)
            if f.is_file():
                result[rel] = {'sha256': digest(f), 'executable': bool(f.stat().st_mode & 0o111)}
    return result


def snapshot(repo, out, ref='HEAD', dirty=False, quiescent=False, roots=ROOTS, after_copy=None):
    repo, out = Path(repo).resolve(), Path(out).resolve()
    if out.exists():
        raise ValueError('Snapshot output already exists')
    if dirty and not quiescent:
        raise ValueError('Dirty snapshot requires --quiescent after all writers have stopped')
    commit = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', ref + '^{commit}'], text=True).strip()
    out.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.snapshot-', dir=out.parent))
    src = stage / 'source'
    src.mkdir()
    # This lock coordinates participating snapshot writers only; it cannot lock an editor.
    git_dir = Path(subprocess.check_output(['git', '-C', str(repo), 'rev-parse', '--absolute-git-dir'], text=True).strip())
    with lock(git_dir / 'mac-mini-snapshot.lock'):
        if dirty:
            before = working_files(repo, roots)
            for rel in before:
                dest = src / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(repo / rel, dest)
            if after_copy:
                after_copy()
            if before != working_files(repo, roots) or before != tree_files(src):
                raise ValueError('Source drift during capture; unpublished staging retained: ' + str(stage))
            if commit != subprocess.check_output(['git', '-C', str(repo), 'rev-parse', ref + '^{commit}'], text=True).strip():
                raise ValueError('Git ref changed during capture')
        else:
            # Git objects are immutable even while another agent edits the checkout.
            paths = subprocess.check_output(['git', '-C', str(repo), 'ls-tree', '-r', '-z', '--name-only', commit]).decode().split('\0')
            paths = [p for p in paths if p]
            included = [p for p in paths if selected(p, roots)]
            if not included:
                raise ValueError('No build files in Git revision')
            archive = stage / 'git.tar'
            with archive.open('wb') as stream:
                subprocess.run(['git', '-C', str(repo), 'archive', commit, '--', *included], stdout=stream, check=True)
            unpack(archive, src)
            archive.unlink()
    body = {'schema': 1, 'origin': {'commit': commit, 'mode': 'quiescent-working-tree' if dirty else 'git-commit'}, 'files': tree_files(src)}
    if not body['files']:
        raise ValueError('Empty snapshot')
    body['snapshot_id'] = hashlib.sha256(canonical(body)).hexdigest()
    write_json(stage / 'manifest.json', body)
    seal(stage)
    # macOS requires write permission on the directory being renamed (for '..').
    stage.chmod(0o755)
    stage.rename(out)
    out.chmod(0o555)
    return body


def verify(bundle):
    bundle = Path(bundle)
    if bundle.is_symlink() or (bundle / 'manifest.json').is_symlink() or (bundle / 'source').is_symlink():
        raise ValueError('Symlink bundle')
    if {p.name for p in bundle.iterdir()} != {'source', 'manifest.json'}:
        raise ValueError('Unexpected files in snapshot bundle')
    m = read_json(bundle / 'manifest.json')
    body = {k: v for k, v in m.items() if k != 'snapshot_id'}
    if m.get('schema') != 1 or m.get('snapshot_id') != hashlib.sha256(canonical(body)).hexdigest():
        raise ValueError('Snapshot manifest hash mismatch')
    if not m['files'] or tree_files(bundle / 'source') != m['files']:
        raise ValueError('Snapshot content mismatch (including added/deleted files or modes)')
    return m


def checked_root(root):
    p = Path(root).expanduser().absolute()
    # The repository Makefile expands several path variables without shell quoting.
    if not re.fullmatch(r'/[A-Za-z0-9_./-]+', str(p)) or p.is_symlink() or p == Path('/'):
        raise ValueError('Queue path must be an absolute, nonsymlink path without shell metacharacters/spaces')
    p.mkdir(parents=True, exist_ok=True)
    if p.resolve() != p:
        raise ValueError('Queue path traverses a symlink')
    return p


def jobs(root):
    return sorted((read_json(p) for p in (root / 'jobs').glob('*/job.json')), key=lambda j: j['sequence'])


def valid_id(value):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}', value):
        raise ValueError('Invalid job/task identifier')
    return value


def enqueue(root, bundle, task, tests, runtime, device, job_id=None):
    root = checked_root(root)
    task = valid_id(task)
    job_id = valid_id(job_id or (task + '-' + uuid.uuid4().hex[:12]))
    if not tests or any(not re.fullmatch(r'(QiuJiTests|QiuJiUITests)/[A-Za-z0-9_/]+', t) for t in tests):
        raise ValueError('Explicit QiuJi test selectors required')
    for value, prefix in [(runtime, 'com.apple.CoreSimulator.SimRuntime.iOS-'), (device, 'com.apple.CoreSimulator.SimDeviceType.')]:
        if not value.startswith(prefix) or not re.fullmatch(r'[A-Za-z0-9_.-]+', value):
            raise ValueError('Invalid runtime or device type')
    m = verify(bundle)
    spec = {'task': task, 'snapshot_id': m['snapshot_id'], 'tests': tests, 'runtime': runtime, 'device': device}
    with lock(root / 'queue.lock'):
        path = root / 'jobs' / job_id
        if (path / 'job.json').exists():
            old = read_json(path / 'job.json')
            if old['spec'] != spec:
                raise ValueError('Job id already belongs to a different request')
            return old
        dest = root / 'snapshots' / m['snapshot_id']
        if not dest.exists():
            dest.parent.mkdir(exist_ok=True)
            tmp = dest.with_name('.' + uuid.uuid4().hex)
            shutil.copytree(bundle, tmp)
            verify(tmp)
            seal(tmp)
            tmp.chmod(0o755)
            tmp.rename(dest)
            dest.chmod(0o555)
        else:
            verify(dest)
        engine = Path(__file__).resolve()
        engine_sha = digest(engine)
        deployed = root / 'engines' / (engine_sha + '.py')
        deployed.parent.mkdir(exist_ok=True)
        if not deployed.exists():
            shutil.copyfile(engine, deployed)
            deployed.chmod(0o444)
        if digest(deployed) != engine_sha:
            raise ValueError('Engine checksum mismatch')
        all_jobs = jobs(root)
        job = {'schema': 1, 'job_id': job_id, 'sequence': max([j['sequence'] for j in all_jobs], default=0) + 1,
               'spec': spec, 'origin': m['origin'], 'engine_sha': engine_sha, 'state': 'queued', 'queued_at': time.time()}
        write_json(path / 'job.json', job)
        return job


def cancel(root, job_id):
    root = checked_root(root)
    with lock(root / 'queue.lock'):
        p = root / 'jobs' / valid_id(job_id) / 'job.json'
        j = read_json(p)
        if j['state'] != 'queued':
            raise ValueError('Only queued jobs can be cancelled; running work is not killed')
        j.update(state='cancelled', finished_at=time.time())
        write_json(p, j)
        return j


def worker(root, executor=None):
    root = checked_root(root)
    try:
        guard = (root / 'worker.lock').open('a')
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        guard.close()
        return 'already-running'
    try:
        while True:
            with lock(root / 'queue.lock'):
                current = jobs(root)
                if any(j['state'] == 'running' or j.get('blocked') for j in current):
                    raise RuntimeError('Interrupted worker state; inspect process/lease and use recover before continuing')
                pending = [j for j in current if j['state'] == 'queued']
                if not pending:
                    # Release under queue.lock: enqueue + kick cannot lose the wake-up.
                    fcntl.flock(guard, fcntl.LOCK_UN)
                    return 'drained'
                j = pending[0]
                p = root / 'jobs' / j['job_id']
                j.update(state='running', started_at=time.time(), worker_pid=os.getpid())
                write_json(p / 'job.json', j)
            try:
                if executor:
                    code = executor(root, j)
                else:
                    engine = root / 'engines' / (j['engine_sha'] + '.py')
                    if digest(engine) != j['engine_sha']:
                        raise ValueError('Pinned executor changed')
                    with (p / 'worker.log').open('w') as stream:
                        proc = subprocess.Popen([sys.executable, str(engine), '_execute', '--root', str(root), '--job', j['job_id']],
                                                stdout=stream, stderr=subprocess.STDOUT, pass_fds=(guard.fileno(),))
                        j['executor_pid'] = proc.pid
                        write_json(p / 'job.json', j)
                        code = proc.wait()
                state = 'succeeded' if code == 0 else 'failed'
                if code < 0 or code in (130, 143):
                    state = 'interrupted'
                    j['blocked'] = True
                error = None
            except Exception as exc:
                code, state, error = 1, 'failed', str(exc)
            # _execute only returns zero after result/selector/source checks and lease release.
            with lock(root / 'queue.lock'):
                if (p / 'evidence/blocked.json').exists():
                    j['blocked'] = True
                j.update(state=state, exit_code=code, finished_at=time.time())
                if error:
                    j['error'] = error
                write_json(p / 'job.json', j)
            if j.get('blocked'):
                raise RuntimeError('Executor interrupted; stop queue for inspection')
    finally:
        guard.close()


def recover(root, job_id, reason):
    root = checked_root(root)
    with lock(root / 'worker.lock', blocking=False), lock(root / 'queue.lock'):
        path = root / 'jobs' / valid_id(job_id)
        j = read_json(path / 'job.json')
        if not (j['state'] == 'running' or j.get('blocked')) or not reason.strip():
            raise ValueError('Recovery requires running state and an inspection reason')
        for pid in [j.get('worker_pid'), j.get('executor_pid')]:
            if pid:
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    continue
                raise ValueError('Recorded process is still alive; do not reclaim')
        activity = subprocess.check_output(['pgrep', '-fl', 'xcodebuild|simulator_lifecycle.py'], text=True) if subprocess.run(['pgrep', '-q', 'xcodebuild|simulator_lifecycle.py']).returncode == 0 else ''
        if activity:
            raise ValueError('Inspect active build/lifecycle processes before recovery')
        reg = Path.home() / 'Library/Application Support/QiuJi/simulator-lifecycle/registry.json'
        if reg.exists() and any(r.get('lease', {}).get('task') == job_id for r in read_json(reg)['devices'].values()):
            raise ValueError('Recover simulator lease through its manager first')
        j.update(state='interrupted', finished_at=time.time(), recovery_reason=reason, blocked=False)
        write_json(path / 'job.json', j)
        return j


def run_logged(evidence, name, argv, cwd):
    row = {'command': argv, 'started_at': time.time()}
    write_json(evidence / (name + '.command.json'), row)
    with (evidence / (name + '.log')).open('w') as stream:
        proc = subprocess.run(argv, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    row.update(exit_code=proc.returncode, finished_at=time.time())
    write_json(evidence / (name + '.command.json'), row)
    if proc.returncode:
        raise RuntimeError(name + ' exited ' + str(proc.returncode))


def make_args(path, action, destination, result_path, selectors):
    return ['make', '-f', 'scripts/Makefile', 'test', 'BUILD_DIR=' + str(path / 'build'),
            'TEST_ACTION=' + action, 'TEST_DESTINATION=' + destination, 'TEST_CODE_COVERAGE=NO',
            'TEST_SELECTOR=' + ' '.join('-only-testing:' + t for t in selectors),
            'TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO ARCHS=arm64 -jobs 4 -resultBundlePath ' + str(result_path)]


def test_summary(evidence, selectors):
    summary = json.loads(subprocess.check_output(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(evidence / 'tests.xcresult')]))
    details = json.loads(subprocess.check_output(['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', str(evidence / 'tests.xcresult')]))
    write_json(evidence / 'test-summary.json', summary)
    write_json(evidence / 'test-details.json', details)
    cases = []
    def visit(node, target=''):
        if node.get('nodeType') in ['Unit test bundle', 'UI test bundle']:
            target = node['name']
        if node.get('nodeType') == 'Test Case':
            cases.append((target + '/' + node['nodeIdentifier'].removesuffix('()'), node.get('result')))
        for child in node.get('children', []):
            visit(child, target)
    for node in details['testNodes']:
        visit(node)
    matches = lambda case, selection: case == selection or case.startswith(selection + '/')
    if (summary.get('result') != 'Passed' or summary.get('failedTests') != 0 or summary.get('skippedTests') != 0
            or not cases or summary.get('totalTestCount') != len(cases) or any(r != 'Passed' for _, r in cases)
            or any(not any(matches(c, s) for c, _ in cases) for s in selectors)
            or any(not any(matches(c, s) for s in selectors) for c, _ in cases)):
        raise RuntimeError('Test count/selector/result mismatch; zero tests cannot pass')
    return summary


def device_run(root, job_id, uid):
    root = checked_root(root)
    p = root / 'jobs' / valid_id(job_id)
    job = read_json(p / 'job.json')
    assert os.environ.get('QIUJI_SIMULATOR_UDID') == uid
    src, ev = p / 'source', p / 'evidence'
    result = {'job_id': job_id, 'snapshot_id': job['spec']['snapshot_id'], 'udid': uid, 'state': 'running'}
    write_json(ev / 'device-result.json', result)
    try:
        live = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))
        state = next(d['state'] for ds in live['devices'].values() for d in ds if d['udid'] == uid)
        if state != 'Booted':
            run_logged(ev, 'boot', ['xcrun', 'simctl', 'boot', uid], src)
        run_logged(ev, 'bootstatus', ['xcrun', 'simctl', 'bootstatus', uid, '-b'], src)
        app = p / 'build/DerivedData/Build/Products/Debug-iphonesimulator/球迹.app'
        import plistlib
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        bundle = info['CFBundleIdentifier']
        run_logged(ev, 'install', ['xcrun', 'simctl', 'install', uid, str(app)], src)
        run_logged(ev, 'launch', ['xcrun', 'simctl', 'launch', uid, bundle, '-hasCompletedOnboarding', 'YES', '-resetDebugPremium', '-AppleLanguages', '(zh-Hans)', '-AppleLocale', 'zh_CN'], src)
        time.sleep(3)
        run_logged(ev, 'screenshot', ['xcrun', 'simctl', 'io', uid, 'screenshot', str(ev / 'launch.png')], src)
        run_logged(ev, 'tests', make_args(p, 'test-without-building', 'platform=iOS Simulator,id=' + uid, ev / 'tests.xcresult', job['spec']['tests']), src)
        result.update(state='succeeded', summary=test_summary(ev, job['spec']['tests']))
    except BaseException as exc:
        result.update(state='failed', error=str(exc))
        raise
    finally:
        write_json(ev / 'device-result.json', result)


def execute(root, job_id):
    root = checked_root(root)
    p = root / 'jobs' / valid_id(job_id)
    job = read_json(p / 'job.json')
    bundle = root / 'snapshots' / job['spec']['snapshot_id']
    ev = p / 'evidence'
    ev.mkdir()
    result = {'job_id': job_id, 'snapshot_id': job['spec']['snapshot_id'], 'state': 'running'}
    try:
        m = verify(bundle)
        shutil.copytree(bundle / 'source', p / 'source')  # no shared writable hardlinks
        write_json(ev / 'snapshot-manifest.json', m)
        run_logged(ev, 'environment', ['xcodebuild', '-version'], p / 'source')
        run_logged(ev, 'build', make_args(p, 'build-for-testing', 'generic/platform=iOS Simulator', ev / 'build.xcresult', job['spec']['tests']), p / 'source')
        run_logged(ev, 'lifecycle', ['python3', 'scripts/simulator_lifecycle.py', 'run', '--task', job_id,
                   '--type', job['spec']['device'], '--runtime', job['spec']['runtime'], '--temporary', '--evidence', str(ev / 'device-result.json'),
                   '--', sys.executable, str(Path(__file__).resolve()), '_device', '--root', str(root), '--job', job_id, '--udid', '{udid}'], p / 'source')
        device = read_json(ev / 'device-result.json')
        if device['state'] != 'succeeded':
            raise RuntimeError('Device workflow did not succeed')
        reg = read_json(Path.home() / 'Library/Application Support/QiuJi/simulator-lifecycle/registry.json')['devices'][device['udid']]
        write_json(ev / 'lease-after.json', reg)
        if reg.get('lease') or reg.get('status') != 'deleted':
            raise RuntimeError('Simulator lease not cleanly released')
        if tree_files(p / 'source') != m['files']:
            raise RuntimeError('Execution changed the source snapshot')
        verify(bundle)
        result.update(state='succeeded', summary=device['summary'])
    except BaseException as exc:
        result.update(state='failed', error=str(exc))
        raise
    finally:
        write_json(ev / 'result.json', result)
        registry = Path.home() / 'Library/Application Support/QiuJi/simulator-lifecycle/registry.json'
        if registry.exists():
            leases = [uid for uid, r in read_json(registry)['devices'].items() if r.get('lease', {}).get('task') == job_id]
            if leases:
                write_json(ev / 'blocked.json', {'reason': 'unreleased simulator lease', 'devices': leases})
        hashes = {f.relative_to(ev).as_posix(): digest(f) for f in ev.rglob('*') if f.is_file()}
        write_json(ev / 'evidence-sha256.json', hashes)


def ssh_options(args, scp=False):
    options = []
    for value in args.ssh_option:
        options += ['-o', value]
    return options


def remote(args, argv):
    if not re.fullmatch(r'[A-Za-z0-9_.@:-]+', args.host) or args.host.startswith('-'):
        raise ValueError('Invalid SSH host')
    return subprocess.check_output(['ssh', *ssh_options(args), args.host, shlex.join(argv)], text=True)


def deploy(args):
    if not re.fullmatch(r'/[A-Za-z0-9_/-]+', args.root):
        raise ValueError('Remote queue root must be an absolute path without spaces/metacharacters')
    sha = digest(__file__)
    engine = args.root + '/engines/' + sha + '.py'
    remote(args, ['mkdir', '-p', args.root + '/engines', args.root + '/incoming'])
    uploaded = args.root + '/incoming/engine-' + uuid.uuid4().hex + '.py'
    subprocess.run(['scp', *ssh_options(args), __file__, args.host + ':' + uploaded], check=True)
    # Never truncate a pinned executor while another client admits/starts a job.
    publish = '''import hashlib,os,pathlib,sys
stage,dest,sha=pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]),sys.argv[3]
if hashlib.sha256(stage.read_bytes()).hexdigest()!=sha: raise ValueError('Engine upload checksum mismatch')
stage.chmod(0o444)
os.replace(stage,dest)
'''
    remote(args, ['python3', '-c', publish, uploaded, engine, sha])
    return engine


def submit(args):
    m = verify(args.bundle)
    valid_id(args.task)
    jid = valid_id(args.job_id or (args.task + '-' + uuid.uuid4().hex[:12]))
    print(json.dumps({'job_id': jid, 'snapshot_id': m['snapshot_id'], 'phase': 'uploading'}), flush=True)
    engine = deploy(args)
    with tempfile.TemporaryDirectory(prefix='mac-mini-upload-') as td:
        tarpath = Path(td) / 'bundle.tar'
        with tarfile.open(tarpath, 'w') as tar:
            tar.add(Path(args.bundle) / 'manifest.json', arcname='manifest.json')
            tar.add(Path(args.bundle) / 'source', arcname='source')
        dest = args.root + '/incoming/' + uuid.uuid4().hex + '.tar'
        subprocess.run(['scp', *ssh_options(args), str(tarpath), args.host + ':' + dest], check=True)
    cmd = ['python3', engine, '_ingest', '--root', args.root, '--archive', dest, '--task', args.task,
           '--job-id', jid, '--runtime', args.runtime, '--device', args.device]
    for test in args.test or DEFAULT_TESTS:
        cmd += ['--test', test]
    print(remote(args, cmd).strip())
    if not args.no_start:
        print(remote(args, ['python3', engine, 'start', '--root', args.root]).strip())


def fetch(args):
    jid = valid_id(args.job)
    engine = deploy(args)
    status = json.loads(remote(args, ['python3', engine, 'status', '--root', args.root, '--job', jid]))
    if status['state'] not in TERMINAL:
        raise ValueError('Job is not terminal; fetch after completion')
    dest = Path(args.out).resolve()
    if dest.exists():
        raise ValueError('Use a new output directory')
    dest.mkdir(parents=True)
    source = args.host + ':' + args.root + '/jobs/' + jid + '/'
    subprocess.run(['rsync', '-a', '--include=/job.json', '--include=/worker.log', '--include=/evidence/***', '--exclude=*',
                    '-e', shlex.join(['ssh', *ssh_options(args)]), source, str(dest) + '/'], check=True)
    if (dest / 'job.json').read_bytes() != (canonical(status) + b'\n'):
        raise ValueError('Job status changed while fetching')
    if status['state'] == 'succeeded' or (dest / 'evidence/evidence-sha256.json').exists():
        manifest = read_json(dest / 'evidence/evidence-sha256.json')
        if any(digest(dest / 'evidence' / str(safe_path(k))) != h for k, h in manifest.items()):
            raise ValueError('Returned evidence hash mismatch')
    write_json(dest / 'fetch-verification.json', {'job_id': jid, 'snapshot_id': status['spec']['snapshot_id'], 'verified': True,
                                                'evidence_available': (dest / 'evidence/evidence-sha256.json').exists()})
    print(json.dumps({'out': str(dest), 'state': status['state']}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    s = sub.add_parser('snapshot')
    s.add_argument('--repo', default='.')
    s.add_argument('--out', required=True)
    s.add_argument('--ref', default='HEAD')
    s.add_argument('--include-dirty', action='store_true')
    s.add_argument('--quiescent', action='store_true')
    v = sub.add_parser('verify'); v.add_argument('--bundle', required=True)
    for name in ['submit', 'fetch', 'remote-status', 'remote-start', 'remote-cancel']:
        p = sub.add_parser(name)
        p.add_argument('--host', default=DEFAULT_HOST)
        p.add_argument('--root', default=DEFAULT_ROOT)
        p.add_argument('--ssh-option', action='append', default=[])
        if name == 'submit':
            p.add_argument('--bundle', required=True)
            p.add_argument('--task', required=True)
            p.add_argument('--job-id')
            p.add_argument('--no-start', action='store_true')
            p.add_argument('--test', action='append')
            p.add_argument('--runtime', default='com.apple.CoreSimulator.SimRuntime.iOS-26-2')
            p.add_argument('--device', default='com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro')
        if name in ['fetch', 'remote-cancel']:
            p.add_argument('--job', required=True)
        if name == 'remote-status':
            p.add_argument('--job')
        if name == 'fetch':
            p.add_argument('--out', required=True)
    for name in ['status', 'start', 'worker', 'cancel', 'recover', '_execute', '_device', '_ingest']:
        p = sub.add_parser(name)
        p.add_argument('--root', default=DEFAULT_ROOT)
        if name in ['cancel', 'recover', '_execute', '_device']:
            p.add_argument('--job', required=True)
        if name == 'status':
            p.add_argument('--job')
        if name == 'recover':
            p.add_argument('--reason', required=True)
        if name == '_device':
            p.add_argument('--udid', required=True)
        if name == '_ingest':
            p.add_argument('--archive', required=True)
            p.add_argument('--task', required=True)
            p.add_argument('--job-id', required=True)
            p.add_argument('--test', action='append', required=True)
            p.add_argument('--runtime', required=True)
            p.add_argument('--device', required=True)
    a = parser.parse_args()
    if a.command == 'snapshot':
        m = snapshot(a.repo, a.out, a.ref, a.include_dirty, a.quiescent)
        print(json.dumps({'snapshot_id': m['snapshot_id'], 'files': len(m['files']), 'out': a.out, 'origin': m['origin']}, ensure_ascii=False))
    elif a.command == 'verify':
        m = verify(a.bundle); print(json.dumps({'snapshot_id': m['snapshot_id'], 'files': len(m['files'])}))
    elif a.command == 'submit':
        submit(a)
    elif a.command == 'fetch':
        fetch(a)
    elif a.command.startswith('remote-'):
        engine = deploy(a)
        cmd = ['python3', engine, a.command.removeprefix('remote-'), '--root', a.root]
        if getattr(a, 'job', None):
            cmd += ['--job', a.job]
        print(remote(a, cmd).strip())
    elif a.command == '_ingest':
        root = checked_root(a.root)
        archive = Path(a.archive)
        if archive.parent != root / 'incoming' or archive.is_symlink():
            raise ValueError('Archive must be in this queue incoming directory')
        stage = Path(tempfile.mkdtemp(prefix='unpack-', dir=root / 'incoming'))
        unpack(archive, stage)
        print(json.dumps(enqueue(root, stage, a.task, a.test, a.runtime, a.device, a.job_id)))
        shutil.rmtree(stage)
        archive.unlink()
    elif a.command == 'worker':
        print(worker(a.root))
    elif a.command == 'start':
        root = checked_root(a.root)
        with (root / 'worker.log').open('a') as stream:
            p = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'worker', '--root', str(root)],
                                 stdin=subprocess.DEVNULL, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        print(json.dumps({'worker_pid': p.pid, 'mode': 'drain-once'}))
    elif a.command == 'status':
        root = checked_root(a.root)
        with lock(root / 'queue.lock'):
            value = read_json(root / 'jobs' / valid_id(a.job) / 'job.json') if a.job else jobs(root)
        print(json.dumps(value))
    elif a.command == 'cancel':
        print(json.dumps(cancel(a.root, a.job)))
    elif a.command == 'recover':
        print(json.dumps(recover(a.root, a.job, a.reason)))
    elif a.command == '_execute':
        execute(a.root, a.job)
    elif a.command == '_device':
        device_run(a.root, a.job, a.udid)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(type(exc).__name__ + ': ' + str(exc), file=sys.stderr)
        sys.exit(1)
