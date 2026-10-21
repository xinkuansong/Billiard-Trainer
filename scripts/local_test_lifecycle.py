#!/usr/bin/env python3
"""Own local disposable test workspaces and reclaim them at successful completion."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid

DEFAULT_ROOT = Path(__file__).resolve().parents[1] / 'output/local-test-runs'


def write(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def checked(path):
    path = Path(os.path.abspath(path))
    if path.resolve() != path:
        raise ValueError('Symlinked lifecycle path: ' + str(path))
    return path


def identity(path):
    s = path.stat()
    return [s.st_dev, s.st_ino]


@contextlib.contextmanager
def locked(run):
    checked(run)
    with checked(run / 'state.lock').open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def record(run):
    r = json.loads(checked(run / 'run.json').read_text())
    if r['id'] != run.name or r['run_identity'] != identity(run):
        raise ValueError('Workspace identity changed')
    return r


def fingerprint(path):
    files = {}
    checked(path)
    for base, dirs, names in os.walk(path):
        for name in dirs + names:
            f = Path(base) / name
            if f.is_symlink():
                raise ValueError('Evidence contains a symlink')
        for name in names:
            f = Path(base) / name
            h = hashlib.sha256()
            with f.open('rb') as source:
                for block in iter(lambda: source.read(1024 * 1024), b''):
                    h.update(block)
            files[str(f.relative_to(path))] = h.hexdigest()
    return files


def activity(work):
    ps = subprocess.check_output(['ps', '-axo', 'pid=,args=', '-ww'], text=True)
    opened = subprocess.run(['/usr/sbin/lsof', '-nP', '-a', '-u', str(os.getuid()), '-Fpn'],
                            capture_output=True, text=True)
    if opened.returncode or opened.stderr.strip() or not opened.stdout.strip():
        raise RuntimeError('Cannot inspect open files; cleanup deferred')
    if re.search(re.escape(str(work)) + r'(?=/|\s|$)', ps + '\n' + opened.stdout):
        raise RuntimeError('Workspace still referenced by a process/open file')


def reclaim(run):
    """Only delete the fresh workspace this runner created, never caller-owned paths."""
    with locked(run):
        r = record(run)
        if r['state'] != 'complete' or r.get('hold'):
            return r
        work = checked(run / 'work')
        try:
            if fingerprint(run / 'evidence') != r['evidence_sha256']:
                raise ValueError('Evidence changed or missing')
            if work.exists():
                if identity(work) != r['work_identity']:
                    raise ValueError('Workspace directory replaced')
                activity(work)
                for base, dirs, _ in os.walk(work, followlinks=False):
                    p = Path(base)
                    if p.stat().st_dev != run.stat().st_dev or os.path.ismount(p):
                        raise ValueError('Mounted directory in workspace')
                before = shutil.disk_usage(run).free
                # rmtree does not follow nested symlinks; read-only build folders are writable first.
                for base, _, _ in os.walk(work, followlinks=False):
                    p = Path(base)
                    p.chmod(p.stat().st_mode | 0o700)
                shutil.rmtree(work)
                r['free_space_delta'] = shutil.disk_usage(run).free - before
            r.update(state='reclaimed', reclaimed_at=time.time())
            r.pop('cleanup_deferred', None)
        except (ValueError, OSError, RuntimeError) as exc:
            r['cleanup_deferred'] = str(exc)
        write(run / 'run.json', r)
        return r


def sweep(root):
    results = []
    if root.exists():
        for run in sorted(root.iterdir()):
            if re.fullmatch(r'[0-9a-f]{32}', run.name) and run.is_dir():
                try:
                    results.append(reclaim(checked(run)))
                except (ValueError, OSError, RuntimeError) as exc:
                    results.append({'id': run.name, 'cleanup_deferred': str(exc)})
    return results


def change(run, action, reason):
    if not reason.strip():
        raise ValueError('A reason is required')
    with locked(run):
        r = record(run)
        if r['state'] == 'reclaimed':
            raise ValueError('Workspace already reclaimed')
        if action == 'protect':
            r['hold'] = reason
        else:
            # Explicit completion may close failed runs, but never a live runner.
            if r['state'] == 'running':
                try:
                    os.kill(r['pid'], 0)
                except ProcessLookupError:
                    pass
                else:
                    raise ValueError('Runner is still active')
            r.update(state='complete', hold=None, completion_reason=reason,
                     evidence_sha256=fingerprint(run / 'evidence'))
        write(run / 'run.json', r)
    return reclaim(run) if action == 'complete' else r


def execute(root, task, command, hold=''):
    if not command:
        raise ValueError('Missing command')
    root = checked(root)
    root.mkdir(parents=True, exist_ok=True)
    sweep(root)
    run = root / uuid.uuid4().hex
    staging = root / ('.new-' + run.name)
    staging.mkdir()
    (staging / 'work').mkdir(); (staging / 'evidence').mkdir()
    work, evidence = run / 'work', run / 'evidence'
    argv = [part.replace('{work}', str(work)).replace('{evidence}', str(evidence)) for part in command]
    r = dict(id=run.name, task=task, state='running', pid=os.getpid(), started_at=time.time(),
             hold=hold or None, command=argv, run_identity=identity(staging), work_identity=identity(staging / 'work'))
    write(staging / 'run.json', r)
    staging.rename(run)  # Publish a complete record atomically to concurrent sweeps.
    print('Local test run: ' + str(run), flush=True)
    child, code = None, 127
    old_handlers = {}
    def interrupt(signum, frame):
        raise KeyboardInterrupt
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            old_handlers[sig] = signal.signal(sig, interrupt)
        env = dict(os.environ, QIUJI_TEST_WORK=str(work), QIUJI_TEST_EVIDENCE=str(evidence),
                   QIUJI_TEST_RUN_ID=run.name)
        with (evidence / 'command.log').open('wb') as log:
            child = subprocess.Popen(argv, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            code = child.wait()
    except KeyboardInterrupt:
        code = 130
        if child and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL); child.wait()
    except OSError as exc:
        (evidence / 'launch-error.txt').write_text(str(exc))
    finally:
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
        with locked(run):
            r = record(run)  # A concurrent protect must survive completion.
            r.update(exit_code=code, ended_at=time.time(), state='complete' if code == 0 else 'failed')
            try:
                r['evidence_sha256'] = fingerprint(evidence)
            except (ValueError, OSError) as exc:
                r.update(state='evidence-error', cleanup_deferred=str(exc))
            write(run / 'run.json', r)
    r = reclaim(run)
    with (evidence / 'command.log').open('rb') as log:
        log.seek(max(0, log.seek(0, 2) - 8000))
        print(log.read().decode(errors='replace'), end='')
    print('\nLocal workspace: ' + r['state'] + '; evidence: ' + str(evidence), flush=True)
    if r.get('cleanup_deferred'):
        print('Cleanup deferred: ' + r['cleanup_deferred'], file=sys.stderr)
    return code if code >= 0 else 128 - code


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=DEFAULT_ROOT)
    commands = p.add_subparsers(dest='action', required=True)
    run = commands.add_parser('run')
    run.add_argument('--task', required=True)
    run.add_argument('--hold', default='', help='Keep work for review; provide a concrete reason')
    run.add_argument('command', nargs=argparse.REMAINDER)
    for name in ['protect', 'complete']:
        c = commands.add_parser(name)
        c.add_argument('--id', required=True)
        c.add_argument('--reason', required=True)
    commands.add_parser('cleanup')
    commands.add_parser('status')
    a = p.parse_args(argv)
    root = checked(a.root)
    if a.action == 'run':
        command = a.command[1:] if a.command[:1] == ['--'] else a.command
        return execute(root, a.task, command, a.hold)
    if a.action in ['protect', 'complete']:
        if not re.fullmatch(r'[0-9a-f]{32}', a.id):
            raise ValueError('Invalid run ID')
        result = change(checked(root / a.id), a.action, a.reason)
    elif a.action == 'cleanup':
        result = sweep(root)
    else:
        result = [record(checked(x)) for x in root.iterdir() if re.fullmatch(r'[0-9a-f]{32}', x.name)] if root.exists() else []
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, RuntimeError) as exc:
        print('ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(1)
