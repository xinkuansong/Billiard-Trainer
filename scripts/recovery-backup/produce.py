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

from common import DAY, atomic_json, checksum, period, prune, read_json, sync_dir

BASE = pathlib.Path('/var/lib/cuephys-backup')
EXPORT = BASE / 'export'
MANIFEST = EXPORT / 'manifest.json'
HERE = pathlib.Path(__file__).resolve().parent
CONFIG = pathlib.Path('/etc/cuephys-backup')


def run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=240, **kwargs)


def source(mode, directory=None):
    cmd = ['/usr/bin/node', HERE / 'source.cjs', mode]
    if directory:
        cmd.append(directory)
    return json.loads(run(cmd, capture_output=True).stdout)


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
                     '--archive=' + str(work / archive), '--gzip', '--quiet'], capture_output=True)
        run(['tar', '-czf', work/'checkpoints.tar.gz', '-C', before['checkpoints'], '.'])
        if kind == 'full':
            run(['tar', '-czf', work/'avatars.tar.gz', '-C', before['avatars'], '-T', work/'avatar-list'])
        if source(kind) != before:
            raise RuntimeError('source-changed-during-backup')
        atomic_json(work/'recovery-point.json', {k: before[k] for k in ('identity', 'seq', 'hash')} |
                    {'captured': now, 'kind': kind})
        contents.append('recovery-point.json')
        (work/'SHA256SUMS').write_text(''.join(f'{checksum(work/f)}  {f}\n' for f in contents))
        # The plaintext tar and MongoDB artifacts live only in this private staging directory.
        run(['tar','-cf',work/'bundle.tar','-C',work,*contents,'SHA256SUMS'])
        cipher = work/'bundle.cms'
        run(['openssl','cms','-encrypt','-binary','-aes-256-gcm','-in',work/'bundle.tar',
             '-outform','DER','-out',cipher,CONFIG/'recipient.crt'], capture_output=True)
        meta = {k: before[k] for k in ('identity', 'seq', 'hash')}
        meta.update(name=name, size=cipher.stat().st_size, sha256=checksum(cipher), captured=now)
        os.chmod(cipher, 0o640)
        shutil.chown(cipher, group='cuephysbackup')
        with cipher.open('rb') as fd:
            os.fsync(fd.fileno())
        os.replace(cipher, EXPORT/name)
        sync_dir(EXPORT)
        return meta


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
            data['proof'] = make_bundle('proof')
        if force_full or not data.get('full') or period(data['full']['captured']) < period(now):
            data['full'] = make_bundle('full')
            if data['full']['seq'] > data['proof']['seq']:
                data['proof'] = make_bundle('proof')
        data.update(tick=int(time.time()), error=None)
        prune(EXPORT, {data[k]['name'] for k in ('full','proof')}, 2, 2)
    except Exception as error:
        data.update(tick=int(time.time()), error=str(error) if isinstance(error, RuntimeError) else type(error).__name__)
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
