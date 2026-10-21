import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'local_test_lifecycle.py'
spec = importlib.util.spec_from_file_location('local_lifecycle', SCRIPT)
lifecycle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lifecycle)


class LocalLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve() / 'runs'
        self.activity = patch.object(lifecycle, 'activity')
        self.activity.start()

    def tearDown(self):
        self.activity.stop()
        self.temp.cleanup()

    def run_task(self, code=0, hold='', extra=''):
        command = [sys.executable, '-c',
                   'from pathlib import Path; import os; '
                   'w=Path(os.environ["QIUJI_TEST_WORK"]); '
                   '(w/"product").write_text("disposable"); '
                   'Path(os.environ["QIUJI_TEST_EVIDENCE"],"result.json").write_text("evidence"); '
                   + (extra + '; ' if extra else '') + 'raise SystemExit(' + str(code) + ')']
        before = set(self.root.iterdir()) if self.root.exists() else set()
        result = lifecycle.execute(self.root, 'fixture', command, hold)
        run = (set(self.root.iterdir()) - before).pop()
        return result, run

    def test_success_reclaims_only_own_work_and_preserves_evidence(self):
        unrelated = self.root.parent / 'source'
        unrelated.mkdir(); (unrelated/'valuable').write_text('source')
        code, run = self.run_task()
        self.assertEqual(code, 0)
        self.assertFalse((run/'work').exists())
        self.assertEqual((run/'evidence/result.json').read_text(), 'evidence')
        self.assertEqual(lifecycle.record(run)['state'], 'reclaimed')
        self.assertTrue((unrelated/'valuable').exists())

    def test_failure_keeps_exit_code_then_explicit_completion_cleans(self):
        code, run = self.run_task(7)
        self.assertEqual(code, 7)
        self.assertTrue((run/'work/product').exists())
        lifecycle.sweep(self.root)
        self.assertTrue((run/'work').exists())
        lifecycle.change(run, 'complete', 'diagnosis finished')
        self.assertFalse((run/'work').exists())
        self.assertEqual(lifecycle.record(run)['exit_code'], 7)

    def test_hold_survives_next_success_then_completion_cleans(self):
        _, held = self.run_task(hold='review')
        self.run_task()
        self.assertTrue((held/'work').exists())
        lifecycle.change(held, 'complete', 'review finished')
        self.assertFalse((held/'work').exists())

    def test_evidence_change_blocks_deletion(self):
        _, run = self.run_task(hold='review')
        with patch.object(lifecycle, 'activity', side_effect=RuntimeError('busy')):
            lifecycle.change(run, 'complete', 'finished')
        (run/'evidence/result.json').write_text('changed')
        lifecycle.reclaim(run)
        self.assertTrue((run/'work').exists())
        self.assertIn('Evidence changed', lifecycle.record(run)['cleanup_deferred'])

    def test_busy_completed_work_retried_on_next_run(self):
        with patch.object(lifecycle, 'activity', side_effect=RuntimeError('busy')):
            _, run = self.run_task()
        self.assertTrue((run/'work').exists())
        self.run_task()
        self.assertFalse((run/'work').exists())

    def test_running_task_cannot_be_completed(self):
        _, run = self.run_task(hold='review')
        r = lifecycle.record(run); r.update(state='running', pid=os.getpid())
        lifecycle.write(run/'run.json', r)
        with self.assertRaisesRegex(ValueError, 'still active'):
            lifecycle.change(run, 'complete', 'not actually done')
        lifecycle.reclaim(run)
        self.assertTrue((run/'work').exists())

    def test_symlink_boundary_cannot_delete_external(self):
        _, run = self.run_task(hold='review')
        external = self.root.parent / 'valuable'; external.mkdir()
        (external/'file').write_text('keep')
        (run/'work').rename(run/'old-work')
        (run/'work').symlink_to(external)
        with self.assertRaises(ValueError):
            lifecycle.change(run, 'complete', 'finished')
        self.assertTrue((external/'file').exists())

    def test_nested_symlink_not_followed(self):
        external = self.root.parent / 'valuable'; external.mkdir()
        (external/'file').write_text('keep')
        self.run_task(extra='(w/"link").symlink_to(' + repr(str(external)) + ')')
        self.assertTrue((external/'file').exists())

    def test_replaced_workspace_preserved(self):
        _, run = self.run_task(hold='review')
        (run/'work').rename(run/'original-work'); (run/'work').mkdir()
        lifecycle.change(run, 'complete', 'finished')
        self.assertTrue((run/'work').exists())
        self.assertIn('replaced', lifecycle.record(run)['cleanup_deferred'])

    def test_symlink_evidence_keeps_work(self):
        _, run = self.run_task(extra='Path(os.environ["QIUJI_TEST_EVIDENCE"],"bad").symlink_to(w/"product")')
        self.assertTrue((run/'work').exists())
        self.assertEqual(lifecycle.record(run)['state'], 'evidence-error')

    def test_nonexistent_command_retains_failure(self):
        self.assertEqual(lifecycle.execute(self.root, 'bad', ['/no/such/command']), 127)
        run = next(self.root.iterdir())
        self.assertTrue((run/'work').exists())
        self.assertTrue((run/'evidence/launch-error.txt').exists())

    def test_unknown_directory_not_adopted(self):
        self.root.mkdir(); (self.root/'old-test').mkdir()
        self.run_task()
        self.assertTrue((self.root/'old-test').exists())

    def test_make_dry_run_creates_no_runs(self):
        root = self.root.parent/'dryrun'
        command = ['make', '-n', '-f', str(SCRIPT.parent/'Makefile'), 'test',
                   'LOCAL_TEST_LIFECYCLE=' + sys.executable + ' ' + str(SCRIPT) + ' --root ' + str(root)]
        p = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(root.exists())

    def test_real_make_entry_uses_owned_work_and_keeps_result(self):
        # Real Makefile/CLI/filesystem/ps/lsof; fake only Xcode and report formatter.
        bin_dir = self.root.parent/'bin'; bin_dir.mkdir()
        (bin_dir/'xcodebuild').write_text('#!' + sys.executable + '\n'
            'import sys,json\nfrom pathlib import Path\na=sys.argv\n'
            'w=Path(a[a.index("-derivedDataPath")+1]);w.mkdir(parents=True,exist_ok=True)\n'
            '(w/"product").write_text("build")\n'
            'e=Path(a[a.index("-resultBundlePath")+1]);e.mkdir()\n'
            '(e/"fixture.json").write_text(json.dumps(a))\nprint("fixture completed")\n')
        (bin_dir/'xcpretty').write_text('#!/bin/sh\ncat >/dev/null\nexit 0\n')
        for f in bin_dir.iterdir(): f.chmod(0o755)
        env = dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH'])
        cmd = ['make','-f',str(SCRIPT.parent/'Makefile'),'test','SIM_TEST_GUARD=',
               'ONLY_TESTING=QiuJiTests/Fixture',
               'LOCAL_TEST_LIFECYCLE='+sys.executable+' '+str(SCRIPT)+' --root '+str(self.root)]
        p = subprocess.run(cmd, env=env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        run = next(self.root.iterdir())
        self.assertEqual(lifecycle.record(run)['state'], 'reclaimed', p.stdout+p.stderr)
        self.assertFalse((run/'work').exists())
        args = json.loads((run/'evidence/tests.xcresult/fixture.json').read_text())
        self.assertIn('-only-testing:QiuJiTests/Fixture', args)
        self.assertTrue((run/'evidence/test-results.log').exists())

    def test_concurrent_protection_and_signal_retains_work(self):
        command = [sys.executable, str(SCRIPT), '--root', str(self.root), 'run', '--task', 'long', '--',
                   sys.executable, '-c', 'import time; time.sleep(30)']
        p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic()+10
            while time.monotonic()<deadline:
                runs=list(self.root.glob('*/run.json'))
                if runs: break
                time.sleep(.02)
            self.assertTrue(runs)
            run=runs[0].parent
            lifecycle.change(run, 'protect', 'review before exit')
            p.send_signal(signal.SIGTERM)
            stdout, stderr=p.communicate(timeout=15)
            self.assertEqual(p.returncode,130,stdout+stderr)
            self.assertTrue((run/'work').exists())
            self.assertEqual(lifecycle.record(run)['hold'], 'review before exit')
        finally:
            if p.poll() is None: p.kill();p.communicate()

    def test_matrix_entry_wraps_run_before_device_operations(self):
        sys.path.insert(0, str(SCRIPT.parent))
        try:
            import run_simulator_matrix as matrix
            with patch.dict(os.environ, {}, clear=True), patch.object(sys, 'argv', ['matrix', 'run']), \
                    patch.object(matrix, 'run_local_workspace', return_value=7) as wrapper, \
                    patch.object(matrix, 'resolve_devices') as devices:
                self.assertEqual(matrix.main(), 7)
                wrapper.assert_called_once()
                devices.assert_not_called()
        finally:
            sys.path.remove(str(SCRIPT.parent))

    def test_matrix_build_is_temporary_but_results_stay_outside(self):
        sys.path.insert(0, str(SCRIPT.parent))
        try:
            import run_simulator_matrix as matrix
            device = SimpleNamespace(matrix_id='A3', name='fixture', runtime_version='26', udid='fixture',
                                     as_dict=lambda: {'matrix_id': 'A3'})
            artifacts = self.root.parent/'matrix-evidence'
            work = self.root.parent/'matrix-work'
            config = {'artifact_root': str(artifacts), 'project': 'QiuJi.xcodeproj', 'scheme': 'QiuJi',
                      'manifest': 'fixture.json', 'suites': {'contract': ['QiuJiTests/Fixture']}}
            with patch.dict(os.environ, QIUJI_TEST_WORK=str(work)), \
                    patch.object(matrix, 'set_simulator_state', return_value=[]), \
                    patch.object(matrix, 'audit_images', return_value={'status':'passed'}), \
                    patch.object(matrix, 'selectors_for_suite', return_value=['QiuJiTests/Fixture']), \
                    patch.object(matrix, 'run', return_value=SimpleNamespace(returncode=0)) as invoked:
                result = matrix.run_unit(config, device, 'light', 'standard', 'contract',
                                         resume=False, content_size='large', fingerprint='fixture')
            self.assertEqual(result['status'], 'passed')
            command = invoked.call_args.args[0]
            self.assertEqual(command[command.index('-derivedDataPath')+1], str(work/'DerivedData/A3'))
            self.assertTrue(Path(command[command.index('-resultBundlePath')+1]).is_relative_to(artifacts))
            self.assertTrue(list(artifacts.rglob('unit-summary.json')))
        finally:
            sys.path.remove(str(SCRIPT.parent))


if __name__ == '__main__':
    unittest.main()
