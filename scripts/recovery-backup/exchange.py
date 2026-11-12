#!/usr/bin/python3
"""Forced SSH command. No shell evaluation, paths, generic file access or secret material."""
import json
import time
import os
import pathlib
import shutil
import sys

from common import NAME, atomic_json, read_json, period

BASE = pathlib.Path('/var/lib/cuephys-backup')


def health(manifest, receipts, now):
    issues = []
    if manifest.get('error'):
        issues.append('云端备份生成失败')
    if now - manifest.get('tick', 0) > 240:
        issues.append('云端定时任务超过 4 分钟未更新')
    if now - receipts.get('pulse', {}).get('at', 0) > 600:
        issues.append('Mac mini 超过 10 分钟未连接')
    for kind, label in [('proof', '注销记录'), ('full', '业务备份')]:
        meta = manifest.get(kind)
        ack = receipts.get(kind, {})
        if not meta:
            issues.append(label + '尚无可用归档')
        elif ack.get('name') != meta['name'] and now - ack.get('at', 0) > 600:
            issues.append(label + '超过 10 分钟未收到异机回执')
    if manifest.get('full') and period(manifest['full']['captured']) < period(now-600):
        issues.append('每日业务备份逾期')
    return issues


def status():
    manifest = read_json(BASE/'export/manifest.json', {}) or {}
    receipts = {k: read_json(BASE/'receipts'/k, {}) for k in ('full','proof','pulse')}
    history = read_json(BASE/'export/incidents.json', [])
    return {'manifest': manifest, 'receipts': receipts, 'issues': health(manifest, receipts, time.time()), 'incidents':history}


def dispatch(role, args):
    data = status()
    if args == ['status']:
        print(json.dumps(data, ensure_ascii=False))
        return
    if role != 'pull':
        raise ValueError('status-only key')
    if args == ['pulse']:
        atomic_json(BASE/'receipts/pulse', {'at':int(time.time())})
        return
    if len(args) < 2 or not NAME.fullmatch(args[1]):
        raise ValueError('invalid request')
    name = args[1]
    kind = NAME.fullmatch(name)[1]
    meta = data['manifest'].get(kind, {})
    if meta.get('name') != name:
        raise ValueError('archive changed; refresh manifest')
    if args == ['get', name]:
        with (BASE/'export'/name).open('rb') as file:
            shutil.copyfileobj(file, sys.stdout.buffer, length=1024*1024)
    elif args == ['ack', name, meta['sha256']]:
        now = int(time.time())
        previous = data['receipts'][kind]
        first = previous.get('first_at',previous.get('at',now)) if previous.get('name') == name else now
        atomic_json(BASE/'receipts'/kind, {'name':name, 'seq':meta['seq'], 'at':now, 'first_at':first})
    else:
        raise ValueError('invalid request')


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['watchdog']:
            data = status()
            current = data['issues']
            now = int(time.time())
            history = [event for event in data['incidents'] if now-event['at'] < 30*86400]
            previous = read_json(BASE/'watchdog.json', {})
            if current != previous.get('issues'):
                print('CuePhys backup:', ' / '.join(current) or 'healthy', flush=True)
                if current:
                    history.append({'at':now,'issues':current})
            if history != data['incidents']:
                atomic_json(BASE/'export/incidents.json', history[-100:], 0o640)
            atomic_json(BASE/'watchdog.json', {'at':now,'issues':current})
        else:
            assert sys.argv[1:] in (['pull'], ['observe'])
            dispatch(sys.argv[1], os.environ.get('SSH_ORIGINAL_COMMAND','').split())
    except Exception as error:
        print('Request failed:', type(error).__name__, file=sys.stderr)
        sys.exit(1)
