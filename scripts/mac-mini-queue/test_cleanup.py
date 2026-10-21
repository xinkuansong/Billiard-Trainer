"""Reclamation must fail closed and leave reproducible evidence intact."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'mac_mini_queue.py'
spec = importlib.util.spec_from_file_location('cleanup_queue', SCRIPT)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
SID = 'a' * 64


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve() / 'queue'
        self.root.mkdir()
        self.activity = patch.object(q, 'host_activity', return_value=('', {}))
        self.activity.start()

    def tearDown(self):
        self.activity.stop()
        for base, dirs, files in os.walk(self.tmp.name):
            Path(base).chmod(0o700)
        self.tmp.cleanup()

    def job(self, name='done', state='succeeded', sequence=1):
        p = self.root / 'jobs' / name
        for d in ['build', 'source', 'evidence']:
            (p / d).mkdir(parents=True)
        (p / 'build/product').write_text('build')
        (p / 'source/file.swift').write_text('source')
        q.write_json(p / 'job.json', {'job_id': name, 'sequence': sequence, 'state': state,
                                     'spec': {'snapshot_id': SID, 'task': name}})
        q.write_json(p / 'evidence/result.json', {'state': state})
        (p / 'worker.log').write_text('execution log')
        q.write_json(p / 'evidence/evidence-sha256.json', {'result.json': q.digest(p / 'evidence/result.json')})
        s = self.root / 'snapshots' / SID
        (s / 'source').mkdir(parents=True, exist_ok=True)
        (s / 'source/file.swift').write_text('source')
        q.write_json(s / 'manifest.json', {'snapshot_id': SID, 'origin': 'fixture', 'files': q.tree_files(p / 'source')})
        return p

    def close(self, p, defer=True):
        return q.acknowledge(self.root, q.make_receipt(p), True, 'Inspection complete; no pending review', defer)

    def test_plain_fetch_ack_keeps_successful_job(self):
        p = self.job()
        q.acknowledge(self.root, q.make_receipt(p))
        result = q.cleanup(self.root, apply=True)
        self.assertIn('closure', result['jobs'][0]['retained'])
        self.assertTrue((p / 'build/product').exists())

    def test_complete_automatically_removes_only_temporary_files(self):
        p = self.job()
        evidence = q.retained_evidence(p)
        self.close(p, defer=False)
        self.assertFalse((p / 'build').exists())
        self.assertFalse((p / 'source').exists())
        self.assertEqual(q.retained_evidence(p), evidence)
        self.assertTrue((p / 'job.json').exists())
        self.assertTrue((p / 'snapshot-manifest.json').exists())
        self.assertFalse((self.root / 'snapshots' / SID).exists())
        q.cleanup(self.root, apply=True)  # idempotent

    def test_preview_does_not_delete_and_apply_rechecks_state(self):
        p = self.job(); self.close(p)
        q.cleanup(self.root)
        self.assertTrue((p / 'source').exists())
        j = q.read_json(p / 'job.json'); j['state'] = 'running'; q.write_json(p / 'job.json', j)
        self.assertIn('active', q.cleanup(self.root, apply=True)['jobs'][0]['retained'])
        self.assertTrue((p / 'build').exists())

    def test_running_queued_failed_and_unknown_are_retained_without_closure(self):
        for i, state in enumerate(['running', 'queued', 'failed', 'interrupted', 'cancelled']):
            self.job(state, state, i)
        result = q.cleanup(self.root, apply=True)
        self.assertEqual(len(result['jobs']), 5)
        self.assertTrue(all('retained' in row for row in result['jobs']))

    def test_shared_snapshot_kept_for_queued_and_review_jobs(self):
        a = self.job(); b = self.job('waiting', 'queued', 2)
        self.close(a, defer=False)
        self.assertTrue((self.root / 'snapshots' / SID).exists())
        self.assertTrue((b / 'source').exists())
        self.assertTrue((b / 'build').exists())

    def test_hold_requires_explicit_release_then_completion(self):
        p = self.job()
        q.retention(self.root, 'done', 'User review pending')
        with self.assertRaisesRegex(ValueError, 'hold'):
            self.close(p)
        self.assertEqual(q.cleanup(self.root, apply=True)['jobs'][0]['retained'], 'review hold')
        q.retention(self.root, 'done', 'Review ended', release=True)
        self.close(p, defer=False)
        with self.assertRaisesRegex(ValueError, 'already reclaimed'):
            q.retention(self.root, 'done', 'Too late')

    def test_archive_mismatch_or_remote_evidence_addition_blocks(self):
        p = self.job(); receipt = q.make_receipt(p)
        (p / 'evidence/new.log').write_text('later diagnosis')
        with self.assertRaisesRegex(ValueError, 'does not match'):
            q.acknowledge(self.root, receipt, True, 'finished')
        self.close(p)
        (p / 'evidence/new.log').write_text('changed again')
        self.assertIn('changed', q.cleanup(self.root, apply=True)['jobs'][0]['retained'])
        self.assertTrue((p / 'build').exists())

    def test_manifest_corruption_and_missing_evidence_rejected(self):
        p = self.job()
        (p / 'evidence/result.json').write_text('tampered')
        with self.assertRaisesRegex(ValueError, 'manifest mismatch'):
            self.close(p)
        shutil.rmtree(p / 'evidence')
        with self.assertRaisesRegex(ValueError, 'Missing execution evidence'):
            self.close(p)

    def test_failed_job_requires_closure_and_preserves_failure_evidence(self):
        p = self.job(state='failed'); evidence = q.retained_evidence(p)
        self.close(p, defer=False)
        self.assertFalse((p / 'build').exists())
        self.assertEqual(q.retained_evidence(p), evidence)
        self.assertEqual(q.read_json(p / 'job.json')['state'], 'failed')

    def test_process_references_and_retained_simulator_block_deletion(self):
        p = self.job(); self.close(p)
        for activity, devices in [(str(p / 'build/product'), {}),
                                  ('', {'id': {'lease': {'task': 'done'}}}),
                                  ('', {'id': {'reason': 'done', 'status': 'protected'}})]:
            with patch.object(q, 'host_activity', return_value=(activity, devices)):
                self.assertIn('retained', q.cleanup(self.root, apply=True)['jobs'][0])
                self.assertTrue((p / 'build').exists())

    def test_inspection_failure_never_deletes(self):
        p = self.job(); self.close(p)
        with patch.object(q, 'host_activity', side_effect=RuntimeError('lsof unavailable')):
            with self.assertRaises(RuntimeError): q.cleanup(self.root, apply=True)
        self.assertTrue((p / 'build').exists())

    def test_unarchived_remote_source_edit_is_retained(self):
        p = self.job(); self.close(p)
        (p / 'source/file.swift').write_text('unique remote fix')
        self.assertIn('unarchived', q.cleanup(self.root, apply=True)['jobs'][0]['retained'])
        self.assertTrue((p / 'build').exists())

    def test_symlinked_target_or_parent_never_deletes_external_content(self):
        p = self.job(); self.close(p)
        external = self.root.parent / 'external'; external.mkdir(); (external / 'keep').write_text('keep')
        shutil.rmtree(p / 'build'); (p / 'build').symlink_to(external)
        self.assertIn('Unsafe', q.cleanup(self.root, apply=True)['jobs'][0]['retained'])
        self.assertTrue((external / 'keep').exists())
        (p / 'build').unlink()
        moved = self.root.parent / 'moved'; p.rename(moved); p.symlink_to(moved)
        self.assertIn('Unsafe', q.cleanup(self.root, apply=True)['jobs'][0]['retained'])
        self.assertTrue((moved / 'source').exists())

    def test_nested_build_symlink_does_not_touch_destination(self):
        p = self.job(); self.close(p)
        external = self.root.parent / 'external'; external.mkdir(); f = external / 'keep'; f.write_text('keep')
        (p / 'build/link').symlink_to(external)
        q.cleanup(self.root, apply=True)
        self.assertEqual(f.read_text(), 'keep')

    def test_interrupted_cleanup_is_retryable(self):
        p = self.job(); self.close(p)
        original = q.remove_temporary
        def fail_source(root, path):
            if path.name == 'source': raise OSError('injected disk error')
            original(root, path)
        with patch.object(q, 'remove_temporary', side_effect=fail_source):
            q.cleanup(self.root, apply=True)
        self.assertTrue((p / 'cleanup-intent.json').exists())
        self.assertFalse((p / 'cleanup.json').exists())
        self.assertTrue((self.root / 'snapshots' / SID).exists())
        q.cleanup(self.root, apply=True)
        self.assertTrue((p / 'cleanup.json').exists())

    def test_cancelled_job_without_execution_can_release_snapshot(self):
        p = self.job(state='cancelled')
        shutil.rmtree(p / 'evidence'); (p / 'worker.log').unlink()
        self.close(p, defer=False)
        self.assertFalse((self.root / 'snapshots' / SID).exists())

    def test_complete_client_to_server_receipt_and_cleanup(self):
        p = self.job()
        dest = self.root.parent / 'download'; shutil.copytree(p, dest)
        args = argparse.Namespace(job='done', root=str(self.root), complete=True,
                                  reason='Review complete', defer_cleanup=False)
        def local_remote(args, argv):
            # Exercise the exact serialized server CLI arguments; only host inspection is mocked.
            with patch('sys.argv', argv[1:]):
                import io
                from contextlib import redirect_stdout
                out = io.StringIO()
                with redirect_stdout(out): q.main()
                return out.getvalue()
        with patch.object(q, 'remote', side_effect=local_remote):
            q.acknowledge_fetch(args, dest, str(SCRIPT))
        self.assertFalse((p / 'build').exists())
        self.assertTrue((dest / 'cleanup-response.json').exists())

    def test_local_generated_index_is_allowed_but_remote_original_is_required(self):
        p = self.job(); dest = self.root.parent / 'archive'; shutil.copytree(p, dest)
        (dest / 'evidence/database.sqlite3').write_bytes(b'local xcresult index')
        args = argparse.Namespace(job='done', root=str(self.root), complete=True,
                                  reason='Review done', defer_cleanup=True)
        prepared = {'receipt': q.make_receipt(p), 'evidence': q.retained_evidence(p)}
        with patch.object(q, 'remote', side_effect=[json.dumps(prepared), '{"acknowledged":true}']):
            q.acknowledge_fetch(args, dest, str(SCRIPT))
        # A new remote log must not disappear from the archived set merely because it was
        # not in the original evidence-sha256.json published by the executor.
        (p / 'evidence/later-diagnosis.log').write_text('remote evidence')
        prepared = {'receipt': q.make_receipt(p), 'evidence': q.retained_evidence(p)}
        with patch.object(q, 'remote', return_value=json.dumps(prepared)):
            with self.assertRaisesRegex(ValueError, 'every current remote'):
                q.acknowledge_fetch(args, dest, str(SCRIPT))
        self.assertTrue((p / 'build').exists())

    def test_low_disk_keeps_job_queued_instead_of_failing_build(self):
        self.job(state='queued')
        usage = shutil.disk_usage(self.root)
        with patch.object(q.shutil, 'disk_usage', return_value=usage._replace(free=1)):
            with self.assertRaisesRegex(RuntimeError, '12 GiB'):
                q.worker(self.root)
        self.assertEqual(q.jobs(self.root)[0]['state'], 'queued')

    def test_failed_ingestion_removes_only_its_own_upload_and_records_error(self):
        incoming = self.root / 'incoming'; incoming.mkdir()
        uploaded = incoming / 'bad.tar'; uploaded.write_bytes(b'not an archive')
        unrelated = incoming / 'other.tar'; unrelated.write_bytes(b'active upload')
        argv = [str(SCRIPT), '_ingest', '--root', str(self.root), '--archive', str(uploaded),
                '--task', 'bad', '--job-id', 'bad', '--test', 'QiuJiTests/ExampleTests',
                '--runtime', 'com.apple.CoreSimulator.SimRuntime.iOS-26-2',
                '--device', 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro']
        with patch('sys.argv', argv):
            with self.assertRaises(q.tarfile.ReadError): q.main()
        self.assertFalse(uploaded.exists())
        self.assertEqual(list(incoming.iterdir()), [unrelated])
        self.assertEqual(len(list((self.root / 'ingest-failures').glob('*.json'))), 1)

    def test_blocked_diagnostic_fetch_is_retained_without_acknowledgement(self):
        p = self.job(state='failed')
        j = q.read_json(p / 'job.json'); j['blocked'] = True; q.write_json(p / 'job.json', j)
        result = q.acknowledge_fetch(argparse.Namespace(complete=False), p)
        self.assertFalse(result['acknowledged'])
        self.assertTrue((p / 'build').exists())


if __name__ == '__main__':
    unittest.main()
