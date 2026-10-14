"""Offline controller tests: subprocess is always mocked, no simulator is touched."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('preview', Path(__file__).with_name('preview.py'))
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
CONFIG = json.loads(preview.CONFIG.read_text())


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.devices = CONFIG['devices'][:2]
        self.launch_failure = False
        self.preflight_failure = False
        self.launch_timeout = False
        self.malformed_pid = False
        self.calls = []
        self.artifacts = {}
        for device in CONFIG['devices']:
            app = self.root / device['udid'] / 'App.app'
            app.mkdir(parents=True)
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': CONFIG['bundleIdentifier'], 'CFBundleExecutable': 'App'}))
            (app / 'App').write_bytes(b'offline-test-executable')
            self.artifacts[device['udid']] = app
        self.expected_hash = preview.fingerprint(self.artifacts[self.devices[0]['udid']])[1]
        self.appearances = {device['udid']: 'light' for device in CONFIG['devices']}
        self.appearance_failures = set()
        self.keyboard_preferences = {'DevicePreferences': {
            d['udid']: {'ConnectHardwareKeyboard': False} for d in CONFIG['devices']}}
        self.keyboard_export_failure = False

    def fake_run(self, args, **kwargs):
        self.calls.append(args)
        if args[:2] == ('defaults', 'export'):
            if self.keyboard_export_failure:
                return subprocess.CompletedProcess(args, 1, '', 'preferences unavailable')
            output = plistlib.dumps(self.keyboard_preferences).decode('utf-8')
        elif args[2:4] == ('list', 'devices'):
            devices = [{**d, 'state': 'Booted'} for d in CONFIG['devices']]
            if self.preflight_failure:
                devices[0]['state'] = 'Shutdown'
            output = json.dumps({'devices': {CONFIG['runtime']: devices}})
        elif args[2] == 'get_app_container':
            output = str(self.artifacts[args[3]])
        elif args[2] == 'ui':
            if args[3] in self.appearance_failures:
                return subprocess.CompletedProcess(args, 4, '', 'appearance query failed')
            output = self.appearances[args[3]]
        elif args[2] == 'launch':
            if args[4] == self.devices[0]['udid']:
                if self.launch_timeout:
                    raise subprocess.TimeoutExpired(args, 180, output=b'partial\xff', stderr=b'error\x00')
                if self.launch_failure:
                    return subprocess.CompletedProcess(args, 3, '', 'launch failed')
                if self.malformed_pid:
                    return subprocess.CompletedProcess(args, 0, 'wrong-bundle: 123', '')
            output = CONFIG['bundleIdentifier'] + ': 123'
        else:
            self.fail(f'Unexpected command: {args}')
        return subprocess.CompletedProcess(args, 0, output, '')

    def invoke(self, *arguments, page='home', drill_id=None, content_id=None):
        request = ['open-page', '--page', page, '--only', '01,02']
        if drill_id:
            request += ['--drill-id', drill_id]
        if content_id:
            request += ['--content-id', content_id]
        with patch.object(preview, 'ROOT', self.root), patch.object(preview.subprocess, 'run', side_effect=self.fake_run), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            code = preview.main([*request, *arguments])
        folders = list((self.root / 'output/simulator-preview').glob('20*')) if (self.root / 'output/simulator-preview').exists() else []
        return code, folders[0] if folders else None

    def enable_theory_capability(self, device):
        app = self.artifacts[device['udid']]
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        info['CFBundleSupportedPlatforms'] = ['iPhoneSimulator']
        (app / 'Info.plist').write_bytes(plistlib.dumps(info))
        (app / 'App').write_bytes(b'offline-executable\0' + preview.LIVE_REVIEW_CAPABILITY + b'\0')

    def enable_drill_detail_capability(self, device):
        self.enable_theory_capability(device)
        app = self.artifacts[device['udid']]
        (app / 'App').write_bytes((app / 'App').read_bytes() + preview.DRILL_DETAIL_CAPABILITY + b'\0')

    def test_theory_cli_rejects_missing_conflicting_unknown_and_duplicate_identity(self):
        invalid = [
            ['open-page', '--page', 'theory'],
            ['open-page', '--page', 'home', '--content-id', 't01'],
            ['open-page', '--page', 'theory', '--content-id', 't01', '--drill-id', 'drill_c001'],
            ['status', '--content-id', 't01'],
            ['open-page', '--page', 'theory', '--content-id', 'T01'],
            ['open-page', '--page', 'theory', '--content-id', 't99'],
            ['open-page', '--page', 'theory', '--content-id', 't01', '--content-id=t02'],
            ['open-page', '--page=home', '--page', 'theory', '--content-id', 't01']
        ]
        for case in invalid:
            with self.subTest(case=case), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                preview.parse_options(case)

    def test_theory_arguments_use_explicit_identity_and_exclude_legacy_home_fixture(self):
        for content_id in preview.THEORY_IDS:
            args = preview.page_arguments(CONFIG, 'theory', content_id=content_id)
            self.assertEqual(args[-2:], ['-liveReview.pageId=theory', f'-liveReview.contentId={content_id}'])
            self.assertFalse(any(arg.startswith(('-v54.', '-deeplink.')) for arg in args))
        for content_id in (None, 'T01', 't99', 't01=other', '../t01'):
            with self.subTest(content_id=content_id), self.assertRaises(ValueError):
                preview.page_arguments(CONFIG, 'theory', content_id=content_id)
        with self.assertRaisesRegex(ValueError, 'conflicts'):
            preview.page_arguments({**CONFIG, 'launchArguments': ['-liveReview.pageId=theory']}, 'theory', content_id='t01')

    def test_abbreviated_identity_options_cannot_bypass_duplicate_rejection(self):
        for case in [
            ['open-page', '--page', 'theory', '--content-i', 't01', '--content-id', 't02'],
            ['open-page', '--pa', 'home', '--page', 'theory', '--content-id', 't01']
        ]:
            with self.subTest(case=case), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                preview.parse_options(case)

    def test_theory_old_installed_app_is_rejected_before_any_launch(self):
        code, folder = self.invoke(page='theory', content_id='t01')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertTrue(all(r['commandStatus'] == 'FAILED' and r['phase'] == 'preflight' for r in results))
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))
        self.assertTrue(all(r['pageStatus'] == 'NOT_CHECKED' for r in results))

    def test_theory_simulator_app_without_marker_is_rejected(self):
        for device in self.devices:
            self.enable_theory_capability(device)
            (self.artifacts[device['udid']] / 'App').write_bytes(b'old-frozen-simulator-executable')
        code, folder = self.invoke(page='theory', content_id='t01')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertTrue(all('lacks the Debug Simulator' in r['error']['message'] for r in results))
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_theory_mixed_capability_group_aborts_before_mutation(self):
        self.enable_theory_capability(self.devices[0])
        code, folder = self.invoke(page='theory', content_id='t01')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['BLOCKED', 'FAILED'])
        self.assertEqual(results[0]['liveReviewCapability'], preview.LIVE_REVIEW_CAPABILITY.decode())
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_theory_supported_app_logs_identity_capability_and_unverified_page(self):
        for device in self.devices:
            self.enable_theory_capability(device)
        code, folder = self.invoke(page='theory', content_id='t01')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 0)
        self.assertTrue(all(r['contentId'] == 't01' and r['targetPage'] == 'theory' for r in results))
        self.assertTrue(all(r['liveReviewCapability'] == preview.LIVE_REVIEW_CAPABILITY.decode() for r in results))
        self.assertTrue(all(r['commandStatus'] == 'COMPLETE' and r['pageStatus'] == 'NOT_CHECKED' for r in results))
        launches = [c for c in self.calls if c[2] == 'launch']
        self.assertEqual(len(launches), 2)
        self.assertTrue(all(c[-2:] == ('-liveReview.pageId=theory', '-liveReview.contentId=t01') for c in launches))

    def test_theory_dry_run_still_requires_installed_capability(self):
        for device in self.devices:
            self.enable_theory_capability(device)
        code, folder = self.invoke('--dry-run', page='theory', content_id='t01')
        self.assertEqual(code, 0)
        self.assertIsNone(folder)
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_drill_detail_theory_only_old_app_is_rejected_before_launch(self):
        for device in self.devices:
            self.enable_theory_capability(device)
        code, folder = self.invoke(page='drill-detail', drill_id='drill_c001')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertTrue(all(r['commandStatus'] == 'FAILED' and r['phase'] == 'preflight' for r in results))
        self.assertTrue(all('drill-detail review capability' in r['error']['message'] for r in results))
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_drill_detail_mixed_capability_group_aborts_before_any_launch(self):
        self.enable_drill_detail_capability(self.devices[0])
        self.enable_theory_capability(self.devices[1])
        code, folder = self.invoke(page='drill-detail', drill_id='drill_c001')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['BLOCKED', 'FAILED'])
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_drill_detail_supported_app_uses_real_navigation_identity(self):
        for device in self.devices:
            self.enable_drill_detail_capability(device)
        code, folder = self.invoke(page='drill-detail', drill_id='drill_c001')
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 0)
        self.assertTrue(all(r['drillId'] == 'drill_c001' and r['targetPage'] == 'drill-detail' for r in results))
        self.assertTrue(all(r['contentId'] == 'drill_c001' for r in results))
        self.assertTrue(all(r['liveReviewCapability'] == preview.DRILL_DETAIL_CAPABILITY.decode() for r in results))
        self.assertTrue(all(r['pageStatus'] == 'NOT_CHECKED' for r in results))
        launches = [c for c in self.calls if c[2] == 'launch']
        self.assertEqual(len(launches), 2)
        self.assertTrue(all(c[-2:] == ('-liveReview.pageId=drill-detail', '-liveReview.contentId=drill_c001') for c in launches))
        self.assertFalse(any(any(a.startswith('-deeplink.') for a in c) for c in launches))

    def test_cli_rejects_conflicting_page_options(self):
        cases = [ ['status', '--page', 'home'], ['open-page', '--page', 'settings', '--drill-id', 'drill_c001'],
                  ['open-page', '--page', 'home', '--appearance', 'dark'], ['open-page', '--page', 'drill-detail'] ]
        for case in cases:
            with self.subTest(case=case), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                preview.parse_options(case)

    def test_page_whitelist_excludes_home_and_other_probes(self):
        config = {**CONFIG, 'launchArguments': CONFIG['launchArguments'] + ['-intro.preview', '-v51.activeTraining']}
        for page, drill_id, route in [('settings', None, '-deeplink.settings'), ('drill-detail', 'drill_c001', '-liveReview.contentId=drill_c001')]:
            args = preview.page_arguments(config, page, drill_id)
            self.assertEqual(args[-1], route)
            self.assertFalse(any(arg.startswith('-v54.') or arg in ('-intro.preview', '-v51.activeTraining') for arg in args))
            self.assertIn('-v51.followSystemAppearance', args)

    def test_home_has_only_empty_fixture(self):
        args = preview.page_arguments(CONFIG, 'home')
        self.assertEqual([arg for arg in args if arg.startswith('-v54.')], ['-v54.todayState=empty'])
        self.assertIn('-v50.inMemoryStore', args)
        self.assertFalse(any(arg.startswith('-deeplink.') for arg in args))

    def test_invalid_and_nonexistent_drill_ids_are_rejected(self):
        for drill_id in ('drill_c001 --other', '../drill_c001', 'drill_c999', 'drill_c002', ''):
            with self.subTest(drill_id=drill_id), self.assertRaises(ValueError):
                preview.page_arguments(CONFIG, 'drill-detail', drill_id)

    def test_configured_deeplink_conflict_is_rejected(self):
        config = {**CONFIG, 'launchArguments': CONFIG['launchArguments'] + ['-deeplink.settings']}
        with self.assertRaisesRegex(ValueError, 'conflicts'):
            preview.page_arguments(config, 'drill-detail', 'drill_c001')

    def test_shared_argument_value_conflict_is_rejected(self):
        config = {**CONFIG, 'launchArguments': ['-AppleLocale', 'en_US']}
        with self.assertRaisesRegex(ValueError, 'Unexpected'):
            preview.page_arguments(config, 'settings')

    def test_nonpremium_flag_is_preserved_and_conflicting_flags_rejected(self):
        config = {**CONFIG, 'launchArguments': [arg for arg in CONFIG['launchArguments'] if arg != '-forcePremium'] + ['-forceNonPremium']}
        args = preview.page_arguments(config, 'settings')
        self.assertIn('-forceNonPremium', args)
        self.assertNotIn('-forcePremium', args)
        config['launchArguments'].append('-forcePremium')
        with self.assertRaisesRegex(ValueError, 'conflict'):
            preview.page_arguments(config, 'settings')

    def test_fixture_requires_explicit_open_page_request(self):
        for case in (['restart', '--fixture', 'l02-default'], ['status', '--fixture', 'l02-default'],
                     ['open-page', '--page', 'settings', '--fixture', 'unknown']):
            with self.subTest(case=case), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                preview.parse_options(case)
        self.assertIsNone(preview.parse_options(['open-page', '--page', 'settings']).fixture)

    def test_l02_fixture_logs_identity_and_adds_only_explicit_defaults(self):
        for device in self.devices:
            self.enable_drill_detail_capability(device)
        code, folder = self.invoke('--fixture', 'l02-default', page='drill-detail', drill_id='drill_c001')
        self.assertEqual(code, 0)
        run = json.loads((folder / 'run.json').read_text())
        self.assertEqual(run['request']['fixture'], 'l02-default')
        self.assertEqual(run['request']['page'], 'drill-detail')
        results = json.loads((folder / 'results.json').read_text())
        self.assertTrue(all(r['fixture'] == 'l02-default' for r in results))
        expected = ['-clothColor.v1', 'green', '-tableStyle.v1', 'charcoal',
                    '-roomStyle.v1', 'tournament', '-showsTableSights.v1', 'YES',
                    '-ballStickerStyle.v1', 'modern', '-cueStyle.v1', 'original',
                    '-renderFrameRate', '60']
        launches = [args for args in self.calls if args[2] == 'launch']
        self.assertEqual(len(launches), 2)
        self.assertTrue(all(list(args[-len(expected):]) == expected for args in launches))
        self.assertTrue(all(r['pageStatus'] == 'NOT_CHECKED' for r in results))

    def test_default_open_page_does_not_apply_visual_fixture(self):
        code, folder = self.invoke(page='settings')
        self.assertEqual(code, 0)
        self.assertIsNone(json.loads((folder / 'run.json').read_text())['request']['fixture'])
        self.assertTrue(all(not any(arg.endswith('.v1') for arg in args) for args in self.calls if args[2] == 'launch'))
        self.assertTrue(all('-renderFrameRate' not in args for args in self.calls if args[2] == 'launch'))

    def test_select_devices_deduplicates_and_rejects_invalid_selection(self):
        first = self.devices[0]
        self.assertEqual(preview.select_devices(self.devices, f" 01,{first['label']},{first['udid']},02"), self.devices)
        self.assertEqual(preview.select_devices(self.devices, None), self.devices)
        for selection in ('', '01,', '11'):
            with self.subTest(selection=selection), self.assertRaises(ValueError):
                preview.select_devices(self.devices, selection)
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            preview.select_devices([first, {**first, 'label': '01-other'}], '01')

    def test_success_records_launch_without_page_ready(self):
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 0)
        self.assertEqual([r['commandStatus'] for r in results], ['COMPLETE', 'COMPLETE'])
        self.assertTrue(all(r['pid'] == 123 and r['pageStatus'] == 'NOT_CHECKED' and r['appExecutableSHA256'] == self.expected_hash for r in results))
        self.assertEqual(json.loads((folder / 'run.json').read_text())['request']['page'], 'home')

    def test_single_launch_failure_is_recorded_and_other_device_continues(self):
        self.launch_failure = True
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'COMPLETE'])
        self.assertEqual(results[0]['phase'], 'launch')
        commands = [json.loads(line) for line in (folder / 'commands.jsonl').read_text().splitlines()]
        self.assertTrue(any(r.get('exit') == 3 and r['device'] == '01-SE' for r in commands))
        self.assertEqual(len([c for c in self.calls if c[2] == 'launch']), 2)

    def test_preflight_failure_aborts_all_mutations_and_accounts_all_devices(self):
        self.preflight_failure = True
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'BLOCKED'])
        self.assertEqual(results[0]['phase'], 'preflight')
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_timeout_preserves_raw_output_and_other_device_continues(self):
        self.launch_timeout = True
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'COMPLETE'])
        self.assertEqual(next(folder.glob('*-stdout.bin')).read_bytes(), b'partial\xff')
        self.assertEqual(next(folder.glob('*-stderr.bin')).read_bytes(), b'error\x00')

    def test_mixed_installed_versions_abort_before_launch(self):
        app = self.artifacts[self.devices[1]['udid']]
        (app / 'App').write_bytes(b'different-offline-executable')
        different_hash = preview.fingerprint(app)[1]
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'FAILED'])
        self.assertEqual([r['appExecutableSHA256'] for r in results], [self.expected_hash, different_hash])
        self.assertNotEqual(self.expected_hash, different_hash)
        self.assertTrue(all(r['phase'] == 'preflight' for r in results))
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_mixed_appearances_abort_before_launch(self):
        self.appearances[self.devices[1]['udid']] = 'dark'
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['appearance'] for r in results], ['light', 'dark'])
        self.assertTrue(all(r['commandStatus'] == 'FAILED' for r in results))
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_failed_appearance_readback_is_logged_and_blocks_launch(self):
        self.appearance_failures.add(self.devices[0]['udid'])
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'BLOCKED'])
        commands = [json.loads(line) for line in (folder / 'commands.jsonl').read_text().splitlines()]
        self.assertTrue(any(r.get('exit') == 4 and r['phase'] == 'preflight' for r in commands))
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_unknown_appearance_readback_is_rejected(self):
        self.appearances[self.devices[0]['udid']] = 'unspecified'
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertIn('Unexpected appearance', results[0]['error']['message'])
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_missing_installed_artifact_is_logged_and_blocks_launch(self):
        (self.artifacts[self.devices[0]['udid']] / 'App').unlink()
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'BLOCKED'])
        self.assertEqual(results[0]['error']['type'], 'FileNotFoundError')
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_malformed_pid_does_not_claim_success(self):
        self.malformed_pid = True
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual(results[0]['commandStatus'], 'FAILED')
        self.assertNotIn('pid', results[0])
        self.assertEqual(results[0]['pageStatus'], 'NOT_CHECKED')

    def test_dry_run_performs_reads_only_and_writes_no_evidence(self):
        code, folder = self.invoke('--dry-run')
        self.assertEqual(code, 0)
        self.assertIsNone(folder)
        self.assertFalse((self.root / 'output').exists())
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_keyboard_policy_respects_device_override_and_rejects_implicit_default(self):
        uid = self.devices[0]['udid']
        for value in (True, 'false', 0):
            prefs = {'ConnectHardwareKeyboard': False,
                     'DevicePreferences': {uid: {'ConnectHardwareKeyboard': value}}}
            self.assertEqual(preview.hardware_keyboard_policy(prefs, uid)['policy'], 'NEEDS_CONFIGURATION')
        self.assertEqual(preview.hardware_keyboard_policy({}, uid)['policy'], 'NEEDS_CONFIGURATION')
        self.assertEqual(preview.hardware_keyboard_policy({'ConnectHardwareKeyboard': False}, uid)['policy'], 'SOFTWARE_INPUT')

    def test_connected_keyboard_aborts_whole_group_before_any_launch(self):
        self.keyboard_preferences['DevicePreferences'][self.devices[0]['udid']]['ConnectHardwareKeyboard'] = True
        code, folder = self.invoke()
        results = json.loads((folder / 'results.json').read_text())
        self.assertEqual(code, 1)
        self.assertEqual([r['commandStatus'] for r in results], ['FAILED', 'BLOCKED'])
        self.assertEqual(results[0]['keyboard']['hardwareConnected'], True)
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))

    def test_unreadable_keyboard_preferences_never_launch(self):
        self.keyboard_export_failure = True
        code, folder = self.invoke()
        self.assertEqual(code, 1)
        self.assertFalse(any(c[2] == 'launch' for c in self.calls))
        self.assertTrue(all(r['commandStatus'] == 'FAILED' for r in json.loads((folder / 'results.json').read_text())))


if __name__ == '__main__':
    unittest.main()
