#!/usr/bin/python3
import fcntl
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

from common import DAY, append_json_event, atomic_json, checksum, period, prune, read_json, sync_dir

BASE = pathlib.Path('/var/lib/cuephys-backup')
EXPORT = BASE / 'export'
MANIFEST = EXPORT / 'manifest.json'
FAILURES = EXPORT / 'failures.json'
HERE = pathlib.Path(__file__).resolve().parent
CONFIG = pathlib.Path('/etc/cuephys-backup')
SOURCE_RETRY_DELAYS = (2, 5)


class BackupCommandError(RuntimeError):
    def __init__(self, stage, args, detail):
        self.stage = stage
        self.args_list = [str(arg) for arg in args]
        self.detail = detail
        super().__init__(f'{stage}: {detail}')


def _text(value):
    if value is None:
        return ''
    if isinstance(value, bytes):
        value = value.decode('utf-8', 'replace')
    return str(value).strip()[-4000:]


def run(args, *, stage='command', **kwargs):
    kwargs.setdefault('capture_output', True)
    try:
        return subprocess.run(args, check=True, timeout=240, **kwargs)
    except subprocess.TimeoutExpired as error:
        raise BackupCommandError(stage, args, 'timeout after 240 seconds') from error
    except subprocess.CalledProcessError as error:
        detail = _text(error.stderr) or _text(error.stdout) or f'exit code {error.returncode}'
        raise BackupCommandError(stage, args, detail) from error


def source(mode, directory=None):
    cmd = ['/usr/bin/node', HERE / 'source.cjs', mode]
    if directory:
        cmd.append(directory)
    return json.loads(run(cmd, stage=f'source:{mode}').stdout)


def make_bundle(kind):
    with tempfile.TemporaryDirectory(prefix='staging-', dir=BASE / 'work') as work:
        work = pathlib.Path(work)
        before = source(kind, work)
        now = int(time.time())
        name = f'{kind}-{now}-{before["seq"]}.cms'
        contents = ['ledger.gz', 'checkpoints.tar.gz']
        if kind == 'full':
            contents += ['business.gz', 'avatars.tar.gz']
        for db, archive in [('cuephys_deletions', 'ledger.gz'), ('qiuji', 'business.gz')]:
            if archive in contents:
                run(['mongodump', '--config', CONFIG / 'dump.yml', '--db', db,
                     '--archive=' + str(work / archive), '--gzip', '--quiet'], stage=f'mongodump:{db}')
        run(['tar', '-czf', work/'checkpoints.tar.gz', '-C', before['checkpoints'], '.'],
            stage='tar:checkpoints')
        if kind == 'full':
            run(['tar', '-czf', work/'avatars.tar.gz', '-C', before['avatars'], '-T', work/'avatar-list'],
                stage='tar:avatars')
        if source(kind) != before:
            raise RuntimeError('source-changed-during-backup')
        atomic_json(work/'recovery-point.json', {k: before[k] for k in ('identity', 'seq', 'hash')} |
                    {'captured': now, 'kind': kind})
        contents.append('recovery-point.json')
        (work/'SHA256SUMS').write_text(''.join(f'{checksum(work/f)}  {f}\n' for f in contents))
        # The plaintext tar and MongoDB artifacts live only in this private staging directory.
        run(['tar','-cf',work/'bundle.tar','-C',work,*contents,'SHA256SUMS'], stage='tar:bundle')
        cipher = work/'bundle.cms'
        run(['openssl','cms','-encrypt','-binary','-aes-256-gcm','-in',work/'bundle.tar',
             '-outform','DER','-out',cipher,CONFIG/'recipient.crt'], stage='openssl:cms')
        meta = {k: before[k] for k in ('identity', 'seq', 'hash')}
        meta.update(name=name, size=cipher.stat().st_size, sha256=checksum(cipher), captured=now)
        os.chmod(cipher, 0o640)
        shutil.chown(cipher, group='cuephysbackup')
        with cipher.open('rb') as fd:
            os.fsync(fd.fileno())
        os.replace(cipher, EXPORT/name)
        sync_dir(EXPORT)
        return meta


def make_bundle_with_retry(kind):
    for attempt in range(len(SOURCE_RETRY_DELAYS) + 1):
        try:
            return make_bundle(kind)
        except RuntimeError as error:
            if str(error) != 'source-changed-during-backup' or attempt >= len(SOURCE_RETRY_DELAYS):
                raise
            time.sleep(SOURCE_RETRY_DELAYS[attempt])


def failure_record(error):
    record = {'at': int(time.time()), 'type': type(error).__name__, 'message': _text(error)}
    if isinstance(error, BackupCommandError):
        record.update(stage=error.stage, command=error.args_list, detail=error.detail)
    return record


def tick(force_full=False):
    data = read_json(MANIFEST, {}) or {}
    try:
        now = time.time()
        head = source('probe')
        proof = data.get('proof')
        if proof and (head['identity'] != proof['identity'] or head['seq'] < proof['seq']
                      or (head['seq'] == proof['seq'] and head['hash'] != proof['hash'])):
            raise RuntimeError('ledger-regressed')
        if not proof or proof['seq'] != head['seq'] or now-proof['captured'] >= DAY:
            data['proof'] = make_bundle_with_retry('proof')
        if force_full or not data.get('full') or period(data['full']['captured']) < period(now):
            data['full'] = make_bundle_with_retry('full')
            if data['full']['seq'] > data['proof']['seq']:
                data['proof'] = make_bundle_with_retry('proof')
        data.update(tick=int(time.time()), error=None)
        data.pop('error_detail', None)
        prune(EXPORT, {data[k]['name'] for k in ('full','proof')}, 2, 2)
    except Exception as error:
        detail = failure_record(error)
        data.update(tick=int(time.time()), error=detail['message'], error_detail=detail)
        try:
            append_json_event(FAILURES, detail, mode=0o640)
        except Exception as log_error:
            # Diagnostics must never replace the original backup failure.
            detail['diagnostic_error'] = type(log_error).__name__
        data['error_detail'] = detail
        raise
    finally:
        atomic_json(MANIFEST, data, 0o640)


if __name__ == '__main__':
    os.umask(0o077)
    with (BASE/'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for path in (BASE/'work').glob('staging-*'):
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
        tick(force_full=sys.argv[1:] == ['--full-now'])
