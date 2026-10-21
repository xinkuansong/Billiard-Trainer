"""Offline fleet routing and destructive-boundary regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import simulator_fleet as fleet
import simulator_lifecycle as lifecycle

CONFIG = json.loads(fleet.CONFIG.read_text())

class FleetTests(unittest.TestCase):
    def setUp(self):
        self.live = {d['udid']: dict(d, state='Shutdown', isAvailable=True) for d in CONFIG['core'] + CONFIG['retained']}
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.calls = []
        self.manager = lifecycle.Manager(self.temp.name, snapshot=lambda: copy.deepcopy(self.live), activity=lambda: {}, simctl=lambda *args: self.calls.append(args))
        self.device = CONFIG['core'][0]

    def acquire(self, temporary=False):
        return self.manager.acquire('offline-test', device_type=self.device['deviceTypeIdentifier'], runtime=self.device['runtime'], temporary=temporary)

    def test_default_pool_request_reuses_core_without_creating(self):
        uid, token, owned = self.acquire()
        self.assertEqual(uid, self.device['udid'])
        self.assertFalse(owned)
        self.manager.release(uid, token, True)
        self.assertFalse(self.calls)

    def test_busy_core_does_not_create_replacement(self):
        self.acquire()
        with self.assertRaisesRegex(RuntimeError, 'already in use'): self.acquire()
        self.assertFalse(self.calls)

    def test_booted_interactive_core_is_preserved(self):
        self.live[self.device['udid']]['state'] = 'Booted'
        with self.assertRaisesRegex(RuntimeError, 'running'): self.acquire()
        self.assertFalse(self.calls)

    def test_unconfigured_type_cannot_grow_another_pool(self):
        with self.assertRaises(ValueError):
            self.manager.acquire('test', device_type='other', runtime=self.device['runtime'])
        self.assertFalse(self.calls)

    def test_one_temporary_device_allowed_despite_protected_old_pool(self):
        # Four retained authoring/review pool records must not consume the new
        # temporary slot's per-type limit. They remain excluded from auto reuse.
        with self.manager.state() as state:
            for d in CONFIG['retained'][:4]:
                state['devices'][d['udid']] = dict(kind='pool', status='protected',
                    identity=lifecycle.identity(self.device), pin='user data')
        def simctl(action, *args):
            self.calls.append((action, *args))
            self.assertEqual(action, 'create')
            self.live['temporary'] = dict(self.device, udid='temporary', name=args[0], state='Shutdown')
            return 'temporary'
        self.manager.simctl = simctl
        uid, token, owned = self.acquire(temporary=True)
        self.assertEqual(uid, 'temporary')
        self.assertTrue(owned)
        self.assertEqual(len(self.calls), 1)

    def test_temporary_exception_is_bounded(self):
        self.live['other'] = dict(self.device, udid='other')
        with self.assertRaisesRegex(RuntimeError, 'temporary capacity'): self.acquire(temporary=True)
        self.assertFalse(self.calls)

    def test_temporary_limit_survives_retiring_data_exceptions(self):
        for d in CONFIG['retained']: del self.live[d['udid']]
        self.live['pending'] = dict(self.device, udid='pending')
        with self.manager.state() as state:
            state['devices']['pending'] = dict(kind='temporary', status='failed',
                identity=lifecycle.identity(self.device), pin='awaiting diagnosis')
        with self.assertRaisesRegex(RuntimeError, 'temporary capacity'): self.acquire(temporary=True)
        self.assertFalse(self.calls)

    def test_missing_and_changed_core_fail_closed(self):
        uid = self.device['udid']
        for key, value in [('name','changed'),('runtime','wrong'),('deviceTypeIdentifier','wrong'),('isAvailable',False)]:
            with self.subTest(key=key):
                live=copy.deepcopy(self.live);live[uid][key]=value
                with self.assertRaises(ValueError): fleet.select(CONFIG,live,role=self.device['role'])
        del self.live[uid]
        with self.assertRaises(ValueError): fleet.select(CONFIG,self.live,role=self.device['role'])

    def test_all_configs_share_exact_core_membership(self):
        core={d['udid'] for d in CONFIG['core']}
        preview=json.loads((SCRIPTS/'simulator-preview/devices.json').read_text())
        matrix=json.loads((SCRIPTS/'simulator-matrix.json').read_text())
        self.assertEqual(len(core),8)
        self.assertEqual(len(CONFIG['retained']),6)
        self.assertEqual(core,{d['udid'] for d in preview['devices']})
        self.assertEqual(core,{d['udid'] for d in matrix['devices']})
        self.assertEqual(len(preview['devices']),8)
        for p in (SCRIPTS/'native-atlas').glob('*.json'):
            workers=json.loads(p.read_text()).get('workers',[])
            self.assertTrue(all(w['udid'] in core for w in workers),str(p))
            self.assertEqual(len(workers),len({w['udid'] for w in workers}))

    def test_matrix_resolves_exact_udid_with_patch_runtime(self):
        spec=importlib.util.spec_from_file_location('matrix_fleet_test',SCRIPTS/'run_simulator_matrix.py')
        mod=importlib.util.module_from_spec(spec);sys.modules[spec.name]=mod;spec.loader.exec_module(mod)
        config=json.loads((SCRIPTS/'simulator-matrix.json').read_text())
        runtime_map={d['runtime']: 'com.apple.CoreSimulator.SimRuntime.iOS-'+('26-3' if d['runtime']=='26.3.1' else '17-0') for d in config['devices']}
        inv={'runtimes':[{'version':v,'identifier':r,'platform':'iOS'} for v,r in runtime_map.items()], 'devices':{}}
        for d in self.live.values():inv['devices'].setdefault(d['runtime'],[]).append(d)
        # Same name/type duplicate must not redirect a pinned matrix row.
        inv['devices'][self.device['runtime']].append(dict(self.live[self.device['udid']],udid='duplicate'))
        with patch.object(mod,'simulator_inventory',return_value=inv):
            resolved=mod.resolve_devices(config)
        self.assertEqual({r.udid for r in resolved},{d['udid'] for d in CONFIG['core']})

if __name__=='__main__': unittest.main()
