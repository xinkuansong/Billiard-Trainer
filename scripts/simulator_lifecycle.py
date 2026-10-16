#!/usr/bin/env python3
"""Host-wide simulator leases, bounded reuse and opt-in retirement (stdlib only)."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
STATE_ROOT = Path.home() / 'Library/Application Support/QiuJi/simulator-lifecycle'
UUID = re.compile(r'\b[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\b')
DAY = 86400


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.' + str(uuid.uuid4()) + '.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    temp.replace(path)


def inventory():
    raw = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
    return {d['udid']: dict(d, runtime=runtime) for runtime, rows in raw['devices'].items() for d in rows}


def processes():
    # macOS truncates comm when it is not the last ps column, even with -ww.
    # Query full executable and arguments separately; disappearing processes are
    # conservatively treated as unresolved until the next inventory.
    executable_rows = subprocess.check_output(['ps', '-ww', '-axo', 'pid=,comm='], text=True)
    argument_rows = subprocess.check_output(['ps', '-ww', '-axo', 'pid=,args='], text=True)
    arguments = {}
    for line in argument_rows.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2:
            arguments[int(parts[0])] = parts[1]
    busy = {}
    for line in executable_rows.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2:
            continue
        pid, executable = int(parts[0]), parts[1]
        if pid == os.getpid() or Path(executable).name not in ('xcodebuild', 'simctl'):
            continue
        command = arguments.get(pid, '')
        # A generic build-for-testing destination cannot start a device workload.
        # Keep real test actions and unresolved commands protected as before.
        if (Path(executable).name == 'xcodebuild'
                and len(re.findall(r'(?:^|\s)-destination\s', command)) == 1
                and not UUID.search(command)
                and re.search(r'-destination\s+[\'\"]?generic/platform=iOS Simulator[\'\"]?(?:\s|$)', command)
                and re.search(r'(?:^|\s)build-for-testing(?:\s|$)', command)
                and not re.search(r'(?:^|\s)(?:test|test-without-building)(?:\s|$)', command)):
            continue
        ids = UUID.findall(command)
        for uid in ids:
            busy.setdefault(uid.upper(), []).append(pid)
        if not ids:
            busy.setdefault('*', []).append(pid)
    return busy


def identity(d):
    return {key: d[key] for key in ('name', 'runtime', 'deviceTypeIdentifier')}


def evidence_path(value):
    path = Path(value).expanduser().resolve()
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError('Evidence must be an existing nonempty file outside the simulator')
    if 'CoreSimulator/Devices' in str(path):
        raise ValueError('Evidence must be exported outside the simulator')
    return str(path)


class Manager:
    def __init__(self, root=STATE_ROOT, snapshot=inventory, activity=processes, clock=time.time, simctl=None):
        self.root = Path(root)
        self.snapshot, self.activity, self.clock = snapshot, activity, clock
        self.simctl = simctl or self._simctl

    @staticmethod
    def _simctl(*args):
        return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()

    @contextmanager
    def state(self):
        self.root.mkdir(parents=True, exist_ok=True)
        with (self.root / 'registry.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            path = self.root / 'registry.json'
            data = json.loads(path.read_text()) if path.exists() else {'version': 1, 'devices': {}}
            if data.get('version') != 1 or not isinstance(data.get('devices'), dict):
                raise ValueError('Invalid registry; refusing to mutate simulators')
            yield data
            atomic_json(path, data)

    def event(self, action, **fields):
        with (self.root / 'events.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(time=self.clock(), action=action, **fields), ensure_ascii=False) + '\n')

    def pins(self, live):
        config = json.loads((ROOT / 'scripts/simulator-preview/devices.json').read_text())
        result = {d['udid']: '人工十设备评审配置' for d in config['devices']}
        for uid, d in live.items():
            if d['name'] == 'iPhone 17 Pro':
                result[uid] = 'Makefile 默认开发设备'
        return result

    def blockers(self, uid, d, record, busy, pins):
        reasons = []
        if d['state'] != 'Shutdown':
            reasons.append('device-not-shutdown')
        if uid in busy or '*' in busy:
            reasons.append('external-simctl-or-xcodebuild')
        if uid in pins:
            reasons.append(pins[uid])
        if not record:
            reasons.append('unregistered-owner-unknown')
            return reasons
        if record.get('pin'):
            reasons.append(record['pin'])
        if record.get('lease'):
            reasons.append('leased:' + record['lease']['task'])
        if record.get('identity') != identity(d):
            reasons.append('identity-changed')
        return reasons

    def report(self):
        with self.state() as state:
            live, busy = self.snapshot(), self.activity()
            pins = self.pins(live)
            rows = []
            for uid, d in live.items():
                record = state['devices'].get(uid, {})
                rows.append(dict(udid=uid, **identity(d), state=d['state'],
                    dataBytes=d.get('dataPathSize', 0), lastBootedAt=d.get('lastBootedAt'),
                    kind=record.get('kind', 'unregistered'), status=record.get('status', 'protected'),
                    reasons=self.blockers(uid, d, record, busy, pins),
                    reason=record.get('reason'), expiresAt=record.get('expiresAt')))
            return {'time': datetime.now(timezone.utc).isoformat(), 'count': len(rows),
                    'reportedDataGiB': round(sum(r['dataBytes'] for r in rows) / 2**30, 2), 'devices': rows}

    def protect(self, uid, reason):
        if not reason.strip():
            raise ValueError('A nonempty reason is required')
        with self.state() as state:
            d = self.snapshot()[uid]
            record = state['devices'].setdefault(uid, dict(identity=identity(d), kind='legacy', status='protected'))
            record['pin'] = reason
            record['reason'] = reason
            self.event('protect', udid=uid, reason=reason)

    def unprotect(self, uid, reason):
        if not reason.strip():
            raise ValueError('A nonempty reason is required')
        with self.state() as state:
            live, busy = self.snapshot(), self.activity()
            r = state['devices'][uid]
            blockers = self.blockers(uid, live[uid], dict(r, pin=None), busy, self.pins(live))
            if blockers:
                raise RuntimeError('Cannot remove protection: ' + ', '.join(blockers))
            r.pop('pin', None)
            self.event('unprotect', udid=uid, reason=reason)

    def retire(self, uid, reason, evidence, days):
        evidence = evidence_path(evidence)
        if not math.isfinite(days) or days < 0 or not reason.strip():
            raise ValueError('Retention must be finite and nonnegative; a reason is required')
        with self.state() as state:
            live, busy = self.snapshot(), self.activity()
            d = live[uid]
            old = state['devices'].get(uid)
            blockers = self.blockers(uid, d, old, busy, self.pins(live))
            # An explicit, evidenced retirement can classify an unknown legacy device.
            blockers = [r for r in blockers if r != 'unregistered-owner-unknown']
            if blockers:
                raise RuntimeError('Cannot retire: ' + ', '.join(blockers))
            state['devices'][uid] = dict(identity=identity(d), kind='retired', status='ready',
                reason=reason, evidence=evidence, expiresAt=self.clock() + days * DAY,
                lastBootedAt=d.get('lastBootedAt'))
            self.event('retire', udid=uid, reason=reason, evidence=evidence)

    def _eligible(self, uid, d, record, busy, pins):
        reasons = self.blockers(uid, d, record, busy, pins)
        if not (record.get('kind') in ('temporary', 'retired') and record.get('status') in ('ready', 'failed') or record.get('kind') == 'pool' and record.get('status') == 'failed'):
            reasons.append('not-released-disposable')
        if record.get('expiresAt', float('inf')) > self.clock():
            reasons.append('retention-not-expired')
        if record.get('lastBootedAt') != d.get('lastBootedAt'):
            reasons.append('booted-since-release')
        try:
            evidence_path(record.get('evidence', ''))
        except (ValueError, OSError):
            reasons.append('missing-exported-evidence')
        return reasons

    def cleanup(self, apply=False, only=None):
        results = []
        with self.state() as state:
            live, busy = self.snapshot(), self.activity()
            pins = self.pins(live)
            for uid, record in state['devices'].items():
                if only is not None and uid not in only:
                    continue
                if uid not in live or self._eligible(uid, live[uid], record, busy, pins):
                    continue
                result = dict(udid=uid, name=live[uid]['name'], action='would-delete')
                if apply:
                    # Recheck both state and users immediately before each deletion.
                    fresh, current_busy = self.snapshot(), self.activity()
                    if uid not in fresh or self._eligible(uid, fresh[uid], record, current_busy, self.pins(fresh)):
                        result['action'] = 'skipped-recheck'
                    else:
                        self.event('delete-intent', udid=uid, evidence=record['evidence'])
                        self.simctl('delete', uid)
                        if uid in self.snapshot():
                            raise RuntimeError('simctl delete returned without removing ' + uid)
                        record['status'] = 'deleted'
                        result['action'] = 'deleted'
                        self.event('deleted', udid=uid)
                results.append(result)
        return results

    def acquire(self, task, uid=None, device_type=None, runtime=None, temporary=False):
        if not task.strip():
            raise ValueError('A task name is required')
        with self.state() as state:
            live, busy = self.snapshot(), self.activity()
            records = state['devices']
            pins = self.pins(live)
            owned = uid is None
            if owned:
                if not device_type or not runtime:
                    raise ValueError('--type and --runtime required for managed devices')
                candidates = [u for u, r in records.items() if u in live and r['kind'] == 'pool'
                    and r['identity']['runtime'] == runtime and r['identity']['deviceTypeIdentifier'] == device_type
                    and r.get('status') == 'idle' and not self.blockers(u, live[u], r, busy, pins)]
                if candidates and not temporary:
                    uid = sorted(candidates)[0]
                else:
                    managed = [r for u, r in records.items() if u in live and r['kind'] in ('pool', 'temporary')]
                    same = [r for r in managed if r['identity']['runtime'] == runtime and r['identity']['deviceTypeIdentifier'] == device_type]
                    if len(managed) >= 8 or len(same) >= 2:
                        raise RuntimeError('Managed capacity reached (8 total / 2 per type+runtime); release or retire a device first')
                    if '*' in busy:
                        raise RuntimeError('Unresolved external simulator command is active')
                    name = 'QiuJi-Managed-' + ('Temp-' if temporary else 'Pool-') + str(uuid.uuid4())[:8]
                    uid = self.simctl('create', name, device_type, runtime)
                    d = self.snapshot()[uid]
                    records[uid] = dict(identity=identity(d), kind='temporary' if temporary else 'pool',
                        status='idle', createdAt=self.clock(), reason=task)
                    # Persist ownership before running anything on the new simulator.
                    self.event('created', udid=uid, task=task)
                    live[uid] = d
            d = live[uid]
            r = records.setdefault(uid, dict(identity=identity(d), kind='legacy', status='protected',
                pin='Existing device: explicit retention; never automatically reclaimed'))
            if r.get('lease') or uid in busy or '*' in busy:
                raise RuntimeError('Device is already in use: ' + uid)
            if r['identity'] != identity(d):
                raise RuntimeError('Device identity changed')
            if owned and (d['state'] != 'Shutdown' or r.get('pin')):
                raise RuntimeError('Managed device no longer idle')
            if not owned and r['kind'] in ('temporary', 'retired'):
                raise RuntimeError('Disposable device must be run through its managed lifecycle')
            token = str(uuid.uuid4())
            r['lease'] = dict(token=token, pid=os.getpid(), task=task, startedAt=self.clock(), owned=owned)
            self.event('acquired', udid=uid, task=task, owned=owned)
            return uid, token, owned

    def release(self, uid, token, success, evidence=None):
        with self.state() as state:
            r = state['devices'][uid]
            if r.get('lease', {}).get('token') != token:
                raise RuntimeError('Lease token mismatch')
            owned = r['lease']['owned']
            live = self.snapshot()
            if uid not in live:
                raise RuntimeError('Leased simulator disappeared')
            d = live[uid]
            if owned:
                if uid in self.activity() or '*' in self.activity():
                    raise RuntimeError('Child/external simulator command still active; retaining lease')
                if d['state'] == 'Booted':
                    self.simctl('shutdown', uid)
                    d = self.snapshot()[uid]
                if d['state'] != 'Shutdown':
                    raise RuntimeError('Shutdown unconfirmed; retaining lease')
                r['status'] = 'idle' if success and r['kind'] == 'pool' else ('ready' if success else 'failed')
                r['expiresAt'] = self.clock() + (0 if success else 7 * DAY)
                r['lastBootedAt'] = d.get('lastBootedAt')
                r['evidence'] = evidence_path(evidence)
            del r['lease']
            r['lastReleasedAt'] = self.clock()
            self.event('released', udid=uid, success=success)

    def recover(self, uid, reason):
        if not reason.strip():
            raise ValueError('A nonempty reason is required')
        # Crashes never silently free a lease. Recovery preserves the device pinned.
        with self.state() as state:
            r = state['devices'][uid]
            lease = r.get('lease')
            if not lease:
                raise ValueError('No abandoned lease')
            try:
                os.kill(lease['pid'], 0)
            except ProcessLookupError:
                pass
            else:
                raise RuntimeError('Lease owner process still exists')
            d = self.snapshot()[uid]
            busy = self.activity()
            if d['state'] != 'Shutdown' or uid in busy or '*' in busy:
                raise RuntimeError('Device still active')
            del r['lease']
            r['pin'] = 'Recovered interrupted task: ' + reason
            r['status'] = 'protected'
            self.event('recovered-and-pinned', udid=uid, reason=reason)


@contextmanager
def device_lease(uid, task):
    """Borrow an explicitly selected device; preserve its data and power state."""
    manager = Manager()
    uid, token, _ = manager.acquire(task, uid=uid)
    success = False
    try:
        yield uid
        success = True
    finally:
        manager.release(uid, token, success)


def resolve_destination(destination, live):
    fields = dict(part.split('=', 1) for part in destination.split(',') if '=' in part)
    if fields.get('platform') != 'iOS Simulator':
        raise ValueError('Managed test requires an explicit iOS Simulator destination')
    if 'id' in fields:
        uid = fields['id'].upper()
        if uid not in live:
            raise ValueError('Unknown simulator destination: ' + uid)
        return uid
    choices = [d for d in live.values() if d['name'] == fields.get('name') and d.get('isAvailable')]
    version = fields.get('OS', 'latest')
    if version != 'latest':
        choices = [d for d in choices if d['runtime'].endswith('iOS-' + version.replace('.', '-'))]
    elif choices:
        latest = max((d['runtime'] for d in choices), key=lambda r: tuple(int(x) for x in r.split('iOS-')[-1].split('-')))
        choices = [d for d in choices if d['runtime'] == latest]
    if len(choices) != 1:
        raise ValueError('Destination ambiguous or missing; use id=<UDID>')
    return choices[0]['udid']


def run_managed(args, manager):
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        raise ValueError('Missing command after --')
    if args.udid and (args.temporary or args.type or args.runtime):
        raise ValueError('--udid cannot be combined with creation options')
    if args.destination:
        if 'platform=iOS Simulator' not in args.destination:
            return subprocess.call(command)
        if args.udid or args.temporary or args.type or args.runtime:
            raise ValueError('--destination cannot be combined with device creation options')
        args.udid = resolve_destination(args.destination, manager.snapshot())
        # Pin the actual xcodebuild destination, including OS=latest resolutions.
        command = [part.replace(args.destination, 'platform=iOS Simulator,id=' + args.udid) for part in command]
    inherited = os.environ.get('QIUJI_SIMULATOR_LEASE_TOKEN')
    if inherited and args.udid == os.environ.get('QIUJI_SIMULATOR_UDID'):
        with manager.state() as state:
            lease = state['devices'].get(args.udid, {}).get('lease', {})
            if lease.get('token') != inherited:
                raise RuntimeError('Invalid inherited lease')
        return subprocess.call(command)
    if args.temporary and not args.evidence:
        raise ValueError('--temporary requires --evidence pointing to the exported result file')
    manager.cleanup(apply=True)
    uid, token, owned = manager.acquire(args.task, args.udid, args.type, args.runtime, args.temporary)
    receipt = manager.root / 'runs' / (token + '.json')
    started_ns = time.time_ns()
    result = dict(udid=uid, task=args.task, startedAt=started_ns / 1e9, status='interrupted')
    atomic_json(receipt, result)
    code = 1
    child = None
    old_handlers = {}
    def interrupted(signum, _frame):
        raise KeyboardInterrupt
    try:
        for sig in (signal.SIGTERM, signal.SIGINT):
            old_handlers[sig] = signal.signal(sig, interrupted)
        env = dict(os.environ, QIUJI_SIMULATOR_UDID=uid, QIUJI_SIMULATOR_LEASE_TOKEN=token)
        argv = [part.replace('{udid}', uid) for part in command]
        print('Simulator: ' + uid, file=sys.stderr, flush=True)
        child = subprocess.Popen(argv, env=env, start_new_session=True)
        code = child.wait()
        result['status'] = 'success' if code == 0 else 'failed'
    except KeyboardInterrupt:
        code = 130
        if child:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
    finally:
        for sig, previous in old_handlers.items():
            signal.signal(sig, previous)
        result.update(exitCode=code, endedAt=time.time())
        atomic_json(receipt, result)
        try:
            exported = evidence_path(args.evidence) if code == 0 and args.evidence else str(receipt)
            if code == 0 and args.evidence and Path(exported).stat().st_mtime_ns < started_ns:
                raise ValueError('Exported evidence predates this run; retaining device and lease')
        except (ValueError, OSError) as error:
            result.update(status='retained-evidence-error', error=str(error))
            atomic_json(receipt, result)
            raise
        manager.release(uid, token, code == 0, exported)
        manager.cleanup(apply=True)
    return code


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='action', required=True)
    report = sub.add_parser('inventory'); report.add_argument('--output', type=Path)
    clean = sub.add_parser('cleanup'); clean.add_argument('--apply', action='store_true')
    clean.add_argument('--udid', action='append', help='Limit cleanup to these exact UDIDs; repeat as needed')
    for verb in ('protect', 'unprotect', 'recover', 'retire'):
        cmd = sub.add_parser(verb); cmd.add_argument('--udid', required=True); cmd.add_argument('--reason', required=True)
        if verb == 'retire':
            cmd.add_argument('--evidence', required=True); cmd.add_argument('--retain-days', type=float, default=7)
    run = sub.add_parser('run')
    run.add_argument('--task', required=True); run.add_argument('--udid')
    run.add_argument('--destination'); run.add_argument('--evidence')
    run.add_argument('--type'); run.add_argument('--runtime'); run.add_argument('--temporary', action='store_true')
    run.add_argument('command', nargs=argparse.REMAINDER)
    args = p.parse_args(argv)
    manager = Manager()
    if args.action == 'inventory':
        result = manager.report()
        if args.output:
            atomic_json(args.output, result)
    elif args.action == 'cleanup':
        result = manager.cleanup(args.apply, args.udid)
    elif args.action == 'run':
        return run_managed(args, manager)
    elif args.action == 'retire':
        manager.retire(args.udid, args.reason, args.evidence, args.retain_days); result = {'retired': args.udid}
    else:
        getattr(manager, args.action)(args.udid, args.reason); result = {args.action: args.udid}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
