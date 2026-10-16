"""Destructive-boundary and lifecycle regression tests; never touches real devices."""
import copy
import argparse
from concurrent.futures import ThreadPoolExecutor
import sys
import threading
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('lifecycle', Path(__file__).resolve().parents[1] / 'simulator_lifecycle.py')
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.now = 1000
        self.devices = {}
        self.busy = {}
        self.calls = []
        self.counter = 0
        self.manager = m.Manager(self.temp.name, lambda: copy.deepcopy(self.devices), lambda: self.busy.copy(), lambda: self.now, self.simctl)
        self.manager.pins = lambda live: {}
        self.proof = Path(self.temp.name) / 'proof.json'
        self.proof.write_text('{"result": "exported"}')

    def simctl(self, action, *args):
        self.calls.append((action, *args))
        if action == 'create':
            self.counter += 1
            uid = f'00000000-0000-0000-0000-{self.counter:012}'
            self.devices[uid] = dict(udid=uid, name=args[0], deviceTypeIdentifier=args[1], runtime=args[2], state='Shutdown', isAvailable=True)
            return uid
        if action == 'delete':
            del self.devices[args[0]]
        elif action == 'shutdown':
            self.devices[args[0]]['state'] = 'Shutdown'
        return ''

    def acquire(self, temporary=False):
        return self.manager.acquire('test', device_type='phone', runtime='ios', temporary=temporary)

    def finish(self, lease, success=True):
        self.manager.release(lease[0], lease[1], success, str(self.proof))

    def legacy(self):
        return self.simctl('create', 'Legacy', 'phone', 'ios')

    def ready(self):
        lease = self.acquire(temporary=True)
        self.finish(lease)
        return lease[0]

    def test_success_pool_reuses_same_udid_and_keeps_data(self):
        a = self.acquire(); self.finish(a)
        b = self.acquire(); self.assertEqual(a[0], b[0]); self.finish(b)
        self.manager.cleanup(True)
        self.assertEqual(len(self.devices), 1)
        self.assertEqual(sum(c[0] == 'create' for c in self.calls), 1)

    def test_temporary_success_dry_run_then_delete(self):
        uid = self.ready()
        self.assertEqual(self.manager.cleanup()[0]['action'], 'would-delete')
        self.assertIn(uid, self.devices)
        self.assertEqual(self.manager.cleanup(True)[0]['action'], 'deleted')
        self.assertNotIn(uid, self.devices)

    def test_failed_pool_holds_seven_days_then_reclaims(self):
        lease = self.acquire(); self.finish(lease, False)
        self.assertEqual(self.manager.cleanup(True), [])
        self.now += 7 * m.DAY
        self.assertEqual(self.manager.cleanup(True)[0]['action'], 'deleted')

    def test_other_session_cannot_borrow_or_delete_leased_device(self):
        a = self.acquire()
        with self.assertRaises(RuntimeError):
            self.manager.acquire('other task', uid=a[0])
        b = self.acquire()
        self.assertNotEqual(a[0], b[0])
        with self.assertRaises(RuntimeError):
            self.acquire()
        self.assertEqual(self.manager.cleanup(True), [])

    def test_unknown_devices_never_deleted_or_implicitly_reused(self):
        uid = self.legacy()
        self.assertEqual(self.manager.cleanup(True), [])
        a = self.acquire(); self.assertNotEqual(uid, a[0])

    def test_explicit_legacy_borrow_preserves_boot_state_and_data(self):
        uid = self.legacy(); self.devices[uid]['state'] = 'Booted'
        a = self.manager.acquire('preview', uid=uid); self.finish(a, False)
        self.assertEqual(self.devices[uid]['state'], 'Booted')
        self.assertEqual(self.manager.cleanup(True), [])

    def test_all_safety_guards_block_deletion(self):
        for guard in ('booted', 'busy', 'unresolved', 'pin', 'config', 'identity', 'new-boot', 'missing-evidence', 'lease'):
            with self.subTest(guard=guard):
                uid = self.ready()
                original = copy.deepcopy(self.devices[uid])
                with self.manager.state() as state:
                    record = state['devices'][uid]
                    if guard == 'pin': record['pin'] = 'User needs this'
                    if guard == 'lease': record['lease'] = {'task': 'active'}
                if guard == 'booted': self.devices[uid]['state'] = 'Booted'
                if guard == 'busy': self.busy = {uid: [99]}
                if guard == 'unresolved': self.busy = {'*': [99]}
                if guard == 'config': self.manager.pins = lambda live: {uid: 'review device'}
                if guard == 'identity': self.devices[uid]['name'] = 'renamed'
                if guard == 'new-boot': self.devices[uid]['lastBootedAt'] = 'now'
                if guard == 'missing-evidence': self.proof.unlink()
                self.assertEqual(self.manager.cleanup(True), [])
                self.assertIn(uid, self.devices)
                del self.devices[uid]
                self.busy = {}; self.manager.pins = lambda live: {}
                self.proof.write_text('{}')

    def test_process_start_between_plan_and_delete_is_rechecked(self):
        uid = self.ready()
        count = 0
        def activity():
            nonlocal count
            count += 1
            return {} if count == 1 else {uid: [123]}
        self.manager.activity = activity
        self.assertEqual(self.manager.cleanup(True)[0]['action'], 'skipped-recheck')
        self.assertIn(uid, self.devices)

    def test_token_mismatch_cannot_release_lease(self):
        a = self.acquire()
        with self.assertRaises(RuntimeError): self.manager.release(a[0], 'wrong', True, str(self.proof))
        with self.manager.state() as state: self.assertIn('lease', state['devices'][a[0]])

    def test_missing_evidence_keeps_lease(self):
        a = self.acquire(True)
        with self.assertRaises(ValueError): self.manager.release(a[0], a[1], True, '/no-such-proof')
        with self.manager.state() as state: self.assertIn('lease', state['devices'][a[0]])

    def test_explicit_retirement_requires_evidence_and_respects_pin(self):
        uid = self.legacy()
        with self.assertRaises(ValueError): self.manager.retire(uid, 'done', '/missing', 0)
        self.manager.protect(uid, 'manual review')
        with self.assertRaises(RuntimeError): self.manager.retire(uid, 'done', str(self.proof), 0)
        other = self.legacy(); self.manager.retire(other, 'done', str(self.proof), 0)
        self.assertEqual(self.manager.cleanup(True)[0]['udid'], other)
        self.assertIn(uid, self.devices)

    def test_corrupt_registry_fails_closed(self):
        self.ready()
        (Path(self.temp.name) / 'registry.json').write_text('broken')
        with self.assertRaises(json.JSONDecodeError): self.manager.cleanup(True)
        self.assertFalse(any(c[0] == 'delete' for c in self.calls))

    def test_global_pool_cap(self):
        for i in range(8):
            a = self.manager.acquire('task', device_type=str(i), runtime='ios'); self.finish(a)
        with self.assertRaises(RuntimeError): self.manager.acquire('task', device_type='ninth', runtime='ios')

    def test_two_independent_managers_contend_for_one_device(self):
        uid = self.legacy()
        barrier = threading.Barrier(2)
        def contender(i):
            manager = m.Manager(self.temp.name, lambda: copy.deepcopy(self.devices), lambda: {}, lambda: self.now, self.simctl)
            manager.pins = lambda live: {}
            barrier.wait()
            try:
                manager.acquire(str(i), uid=uid)
                return 'acquired'
            except RuntimeError:
                return 'busy'
        with ThreadPoolExecutor(2) as executor:
            self.assertCountEqual(list(executor.map(contender, range(2))), ['acquired', 'busy'])

    def test_real_child_failure_retains_device_and_exit_code(self):
        args = argparse.Namespace(command=['--', sys.executable, '-c', 'raise SystemExit(3)'],
            destination=None, udid=None, task='failed child', type='phone', runtime='ios', temporary=True,
            evidence=str(self.proof))
        self.assertEqual(m.run_managed(args, self.manager), 3)
        self.assertEqual(len(self.devices), 1)
        with self.manager.state() as state:
            r = next(iter(state['devices'].values()))
            self.assertEqual(r['status'], 'failed')
            self.assertNotIn('lease', r)
        receipts = list((Path(self.temp.name) / 'runs').glob('*.json'))
        self.assertEqual(json.loads(receipts[0].read_text())['exitCode'], 3)

    def test_real_child_temporary_success_exports_and_deletes(self):
        output = Path(self.temp.name) / 'child-result.json'
        code = 'import os,json,pathlib; pathlib.Path(' + repr(str(output)) + ').write_text(json.dumps(dict(udid=os.environ["QIUJI_SIMULATOR_UDID"])))'
        args = argparse.Namespace(command=['--', sys.executable, '-c', code], destination=None,
            udid=None, task='successful child', type='phone', runtime='ios', temporary=True, evidence=str(output))
        self.assertEqual(m.run_managed(args, self.manager), 0)
        self.assertFalse(self.devices)
        self.assertTrue(json.loads(output.read_text())['udid'])

    def test_stale_export_does_not_authorize_temporary_deletion(self):
        args = argparse.Namespace(command=['--', sys.executable, '-c', 'pass'], destination=None,
            udid=None, task='stale artifact', type='phone', runtime='ios', temporary=True, evidence=str(self.proof))
        with self.assertRaises(ValueError): m.run_managed(args, self.manager)
        self.assertEqual(len(self.devices), 1)
        with self.manager.state() as state:
            self.assertIn('lease', next(iter(state['devices'].values())))

    def test_unprotect_respects_configuration_and_active_use(self):
        uid = self.legacy(); self.manager.protect(uid, 'keep')
        self.manager.pins = lambda live: {uid: 'review'}
        with self.assertRaises(RuntimeError): self.manager.unprotect(uid, 'finished')
        self.manager.pins = lambda live: {}
        self.devices[uid]['state'] = 'Booted'
        with self.assertRaises(RuntimeError): self.manager.unprotect(uid, 'finished')
        self.devices[uid]['state'] = 'Shutdown'
        self.manager.unprotect(uid, 'finished')
        self.manager.retire(uid, 'finished', str(self.proof), 0)
        self.assertEqual(self.manager.cleanup(True)[0]['action'], 'deleted')

    def test_invalid_retention_and_empty_protection_rejected(self):
        uid = self.legacy()
        with self.assertRaises(ValueError): self.manager.protect(uid, '')
        for days in (float('nan'), float('inf'), -1):
            with self.assertRaises(ValueError): self.manager.retire(uid, 'done', str(self.proof), days)

    def test_macos_process_detection_with_space_and_long_executable_path(self):
        uid = '00000000-0000-0000-0000-000000000001'
        exe = '91 /Applications/Xcode Beta.app/Contents/Developer/usr/bin/xcodebuild\n92 /usr/bin/simctl\n'
        args = f'91 /Applications/Xcode Beta.app/Contents/Developer/usr/bin/xcodebuild -destination id={uid}\n92 simctl list devices\n'
        with patch.object(m.subprocess, 'check_output', side_effect=[exe, args]):
            self.assertEqual(m.processes(), {uid: [91], '*': [92]})

    def test_scoped_cleanup_leaves_other_eligible_devices_alone(self):
        first, second = self.ready(), self.ready()
        result = self.manager.cleanup(True, only=[first])
        self.assertEqual([r['udid'] for r in result], [first])
        self.assertIn(second, self.devices)

    def test_generic_compile_only_does_not_block_device_but_test_or_unknown_still_does(self):
        uid = '00000000-0000-0000-0000-000000000001'
        exe = '91 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild\n'
        cases = [
            ('xcodebuild -destination generic/platform=iOS Simulator build-for-testing', {}),
            ('xcodebuild -destination \'generic/platform=iOS Simulator\' -only-testing:QiuJiTests/A build-for-testing', {}),
            ('xcodebuild -destination generic/platform=iOS Simulator build-for-testing test', {'*': [91]}),
            ('xcodebuild -destination generic/platform=iOS Simulator test-without-building', {'*': [91]}),
            ('xcodebuild build-for-testing', {'*': [91]}),
            (f'xcodebuild -destination id={uid} build-for-testing', {uid: [91]}),
            (f'xcodebuild -destination generic/platform=iOS Simulator -destination id={uid} build-for-testing', {uid: [91]}),
        ]
        for command, expected in cases:
            with self.subTest(command=command), patch.object(m.subprocess, 'check_output', side_effect=[exe, f'91 {command}\n']):
                self.assertEqual(m.processes(), expected)

    def test_latest_destination_resolves_numeric_versions_and_ambiguity(self):
        uid = self.legacy(); self.devices[uid].update(name='Phone', runtime='com.apple.CoreSimulator.SimRuntime.iOS-9-0')
        uid2 = self.legacy(); self.devices[uid2].update(name='Phone', runtime='com.apple.CoreSimulator.SimRuntime.iOS-26-3')
        self.assertEqual(m.resolve_destination('platform=iOS Simulator,name=Phone,OS=latest', self.devices), uid2)
        self.devices[uid]['runtime'] = self.devices[uid2]['runtime']
        with self.assertRaises(ValueError): m.resolve_destination('platform=iOS Simulator,name=Phone,OS=latest', self.devices)


if __name__ == '__main__':
    unittest.main()
