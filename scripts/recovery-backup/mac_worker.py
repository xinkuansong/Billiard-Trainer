#!/usr/bin/python3
import argparse
import datetime as dt
import fcntl
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

from common import NAME, atomic_json, checksum, prune, read_json, sync_dir

ROOT = pathlib.Path.home()/'.local/share/cuephys-backups/managed'
ARCHIVES = ROOT/'archives'
TARGET = 'cuephysbackup@106.54.3.210'


def remote(*args, output=subprocess.PIPE):
    result = subprocess.run([
        '/usr/bin/ssh','-F','/dev/null','-T','-o','BatchMode=yes','-o','IdentitiesOnly=yes',
        '-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(ROOT/'known_hosts'),
        '-o','ConnectTimeout=8','-o','ServerAliveInterval=10','-o','ServerAliveCountMax=2',
        '-i',ROOT/'transport-key',TARGET,*args
    ], stdout=output, stderr=subprocess.PIPE, timeout=300, check=True)
    return result.stdout


def verify_meta(meta, kind):
    match = NAME.fullmatch(meta['name'])
    if not match or match[1] != kind or int(match[2]) != meta['captured'] or int(match[3]) != meta['seq']:
        raise ValueError('归档标识无效')
    if meta['size'] <= 0 or len(meta['sha256']) != 64:
        raise ValueError('归档摘要无效')


def receive(meta, previous):
    name = meta['name']
    destination = ARCHIVES/name
    if previous and (meta['identity'] != previous['identity'] or meta['seq'] < previous['seq']
                     or meta['captured'] < previous['captured']
                     or (meta['seq'] == previous['seq'] and meta['hash'] != previous['hash'])):
        raise ValueError('云端恢复点回退，保留原有备份')
    # Rehash newly obtained or changed files and periodically recheck unchanged files.
    if destination.is_file() and destination.stat().st_size == meta['size']:
        if (previous and previous['name'] == name and previous.get('mtime') == destination.stat().st_mtime_ns
                and time.time()-previous.get('verified',0) < 86400):
            return previous
        if checksum(destination) == meta['sha256']:
            return dict(meta, verified=int(time.time()), mtime=destination.stat().st_mtime_ns)
    if shutil.disk_usage(ARCHIVES).free < meta['size'] + 2*1024**3:
        raise OSError('备份空间不足，需预留 2 GiB')
    with tempfile.NamedTemporaryFile(dir=ARCHIVES, prefix='.receiving-', delete=False) as file:
        pending = pathlib.Path(file.name)
        try:
            remote('get',name,output=file)
            file.flush()
            os.fsync(file.fileno())
            if pending.stat().st_size != meta['size'] or checksum(pending) != meta['sha256']:
                raise ValueError('密文传输校验失败')
            os.replace(pending, destination)
            sync_dir(ARCHIVES)
        finally:
            pending.unlink(missing_ok=True)
    return dict(meta, verified=int(time.time()), mtime=destination.stat().st_mtime_ns)


def receive_and_ack(kind, meta, saved):
    verify_meta(meta, kind)
    saved[kind] = receive(meta, saved.get(kind))
    atomic_json(ROOT/'verified.json', saved)
    remote('ack',meta['name'],meta['sha256'])


def backup():
    for pending in ARCHIVES.glob('.receiving-*'):
        if pending.is_file() and not pending.is_symlink():
            pending.unlink()
    remote('pulse')
    manifest = json.loads(remote('status'))['manifest']
    saved = read_json(ROOT/'verified.json', {})
    issues = []
    for kind, label in [('proof','注销记录'), ('full','业务库')]:
        try:
            meta = manifest[kind]
            try:
                receive_and_ack(kind, meta, saved)
            except subprocess.CalledProcessError:
                # The server may publish a newer generation during download or ACK.
                current = json.loads(remote('status'))['manifest'][kind]
                if current['name'] == meta['name']:
                    raise
                receive_and_ack(kind, current, saved)
        except Exception as error:
            issues.append(label+'传输或确认失败（'+type(error).__name__+'）')
    if 'full' in saved and 'proof' in saved:
        # Protect the latest verified recovery pair during an extended outage.
        keep = {saved[k]['name'] for k in ('full','proof')}
        prune(ARCHIVES, keep, 30, 7)
    return issues


def banner(message):
    script = 'on run argv\n display notification (item 1 of argv) with title "CuePhys 备份"\nend run'
    subprocess.run(['/usr/bin/osascript','-e',script,message], check=True, capture_output=True, timeout=12)


def notify(issues, statefile, *, test=False, incidents=()):
    now = int(time.time())
    state = read_json(statefile, {})
    reported = state.get('reported', state.get('issues', []))
    seen = state.get('incident_at', 0)
    missed = [event for event in incidents if event['at'] > seen]
    due = issues != reported or (issues and now-state.get('notified',0) >= 3600)
    state.update(at=now, issues=issues)
    if due or (missed and not issues):
        body = '；'.join(issues) if issues else '备份连接和异机回执已恢复'
        if missed and not issues:
            event = missed[-1]
            when = dt.datetime.fromtimestamp(event['at']).strftime('%m-%d %H:%M')
            body = when+' 曾发生：'+'；'.join(event['issues'])+'。当前已恢复。'
        try:
            banner(('演练 · ' if test else '')+body)
        except (OSError,subprocess.SubprocessError) as error:
            state['reported'] = reported
            state['notification_error'] = type(error).__name__
            atomic_json(statefile, state)
            raise
        state.update(notified=now, reported=issues)
        state.pop('notification_error',None)
    if missed:
        state['incident_at'] = missed[-1]['at']
    atomic_json(statefile, state)


def tick(role, local_pull=False):
    issues = []
    if role == 'pull':
        try:
            issues.extend(backup())
        except Exception as error:
            issues.append('Mac mini 无法取得备份（'+type(error).__name__+'）')
        atomic_json(ROOT/'pull-status.json', {'at':int(time.time()), 'issues':issues})
        return bool(issues)
    if local_pull:
        state = read_json(ROOT/'pull-status.json', {})
        issues.extend(state.get('issues', []))
        if time.time()-state.get('at',0) > 600:
            issues.append('本机备份进程超过 10 分钟未完成检查')
    incidents = []
    try:
        server = json.loads(remote('status'))
        issues.extend(server['issues'])
        incidents = server.get('incidents', [])
    except Exception as error:
        issues.append('无法联系腾讯云备份监控（'+type(error).__name__+'）')
    notify(issues,ROOT/'status.json',incidents=incidents)
    return bool(issues)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('role',choices=['pull','observe'])
    parser.add_argument('--local-pull',action='store_true')
    parser.add_argument('--test-alert',action='store_true')
    args=parser.parse_args()
    os.umask(0o077)
    with (ROOT/(args.role+'.lock')).open('a') as lock:
        try:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit(0)
        if args.test_alert:
            notify(['模拟：注销记录超过 10 分钟未收到异机回执'],ROOT/'test-status.json',test=True)
        else:
            sys.exit(int(tick(args.role,args.local_pull)))
