#!/usr/bin/env python3
"""Resolve the shared local fleet; lease and cleanup remain in simulator_lifecycle."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'scripts/simulator-fleet.json'


def select(config, live, *, role=None, device_type=None, runtime=None):
    matches = [d for d in config['core'] if
               (role is None or d['role'] == role) and
               (device_type is None or d['deviceTypeIdentifier'] == device_type) and
               (runtime is None or d['runtime'] == runtime)]
    if len(matches) != 1:
        raise ValueError('Expected one configured core device; use an explicit role/type/runtime. No device was created.')
    expected = matches[0]
    actual = live.get(expected['udid'])
    if not actual or not actual.get('isAvailable', True):
        raise ValueError('Configured device unavailable on this host; do not substitute or create another pool.')
    for key in ('runtime', 'deviceTypeIdentifier', 'name'):
        if actual.get(key) != expected[key]:
            raise ValueError('Configured device identity changed: ' + key)
    return expected['udid']


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['resolve', 'run', 'validate'])
    p.add_argument('--role')
    p.add_argument('--type', dest='device_type')
    p.add_argument('--runtime')
    p.add_argument('--task')
    # Parse command separately so child flags cannot be mistaken for fleet flags.
    args = list(sys.argv[1:] if argv is None else argv)
    split = args.index('--') if '--' in args else len(args)
    command = args[split + 1:]
    a = p.parse_args(args[:split])
    from simulator_lifecycle import inventory
    config, live = json.loads(CONFIG.read_text()), inventory()
    if a.action == 'validate':
        ids = [d['udid'] for d in config['core'] + config['retained']]
        if len(ids) != len(set(ids)) or len(ids) != config['baseline_count']:
            raise ValueError('Duplicate or incorrect baseline membership')
        for d in config['core']:
            select(config, live, role=d['role'])
        missing = set(ids) - live.keys()
        if missing:
            raise ValueError('Missing retained devices: ' + ', '.join(sorted(missing)))
        print(json.dumps({'baseline': len(ids), 'core': len(config['core']),
                          'retained': len(config['retained']), 'actual': len(live),
                          'outside_baseline': sorted(live.keys() - set(ids))}, indent=2))
        return 0
    uid = select(config, live, role=a.role, device_type=a.device_type, runtime=a.runtime)
    if a.action == 'resolve':
        print(uid)
        return 0
    if not a.task or not command:
        p.error('run requires --task and -- command')
    # Do not take an interactive session simply because no managed lease exists.
    if live[uid]['state'] != 'Shutdown':
        raise ValueError('Core device is running; wait for review to finish or choose another coverage role.')
    return subprocess.call([sys.executable, str(ROOT / 'scripts/simulator_lifecycle.py'),
                            'run', '--task', a.task, '--udid', uid, '--', *command])


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
