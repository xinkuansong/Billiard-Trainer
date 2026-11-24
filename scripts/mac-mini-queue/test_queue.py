import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'mac_mini_queue.py'
spec = importlib.util.spec_from_file_location('queue_tool', SCRIPT)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-26-2'
DEVICE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro'


def fake_executor(root, job):
    with (root / 'execution-events.jsonl').open('a') as f:
        f.write(json.dumps({'event': 'start', 'job': job['job_id'], 'time': time.time()}) + '\n')
    time.sleep(0.12)
    with (root / 'execution-events.jsonl').open('a') as f:
        f.write(json.dumps({'event': 'end', 'job': job['job_id'], 'time': time.time()}) + '\n')
    return 1 if job['spec']['task'] == 'fails' else 0


def drain(root):
    q.worker(root, fake_executor)


def admit(root, bundle, name):
    q.enqueue(root, bundle, name, ['CuePhysTests/ExampleTests'], RUNTIME, DEVICE, name)


class QueueTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name).resolve()
        self.repo = self.base / 'repo'
        self.repo.mkdir()
        self.queue = self.base / 'queue'
        self.git('init', '-q')
        self.git('config', 'user.name', 'Queue Test')
        self.git('config', 'user.email', 'queue@example.invalid')
        for root in ['CuePhys', 'CuePhysLiveActivity', 'CuePhysTests', 'CuePhysUITests',
                     'CuePhys.xcodeproj', 'Packages', 'Config', 'scripts']:
            (self.repo / root).mkdir()
            (self.repo / root / 'fixture').write_text('fixture')
        (self.repo / 'project.yml').write_text('fixture')
        (self.repo / '.gitattributes').write_text('')
        (self.repo / 'CuePhys/value.swift').write_text('version A\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'A')

    def tearDown(self):
        # Only the test-owned temporary directory: snapshots are deliberately read-only.
        for root, dirs, files in os.walk(self.base):
            Path(root).chmod(0o700)
            for name in files:
                p = Path(root) / name
                if not p.is_symlink():
                    p.chmod(0o600)
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], stderr=subprocess.DEVNULL).decode().strip()

    def snap(self, name='snap', **kw):
        p = self.base / name
        q.snapshot(self.repo, p, **kw)
        return p

    def enqueue(self, snap, task='task', **kw):
        return q.enqueue(self.queue, snap, task, ['CuePhysTests/ExampleTests'], RUNTIME, DEVICE, **kw)

    def test_current_method_selector_and_explicit_borrow_are_frozen(self):
        uid = '9B456D2E-C90E-4324-8E98-51A4CCA930A1'
        bundle = self.snap()
        job = q.enqueue(self.queue, bundle, 'borrow', ['CuePhysTests/ExampleTests/testA()'],
                        RUNTIME, DEVICE, udid=uid)
        self.assertEqual(job['spec']['udid'], uid)
        args = q.make_args(self.queue / 'jobs' / job['job_id'], 'test-without-building',
                           'platform=iOS Simulator,id=' + uid, self.base / 'result', job['spec']['tests'])
        self.assertIn("TEST_SELECTOR='-only-testing:CuePhysTests/ExampleTests/testA()'", args)
        with self.assertRaisesRegex(ValueError, 'Explicit CuePhys'):
            q.enqueue(self.queue, bundle, 'bad', ['QiuJiTests/ExampleTests'], RUNTIME, DEVICE)

    def test_missing_app_root_is_rejected(self):
        import shutil
        shutil.rmtree(self.repo / 'CuePhys')
        with self.assertRaisesRegex(ValueError, 'Missing required build roots'):
            self.snap(dirty=True, quiescent=True)

    def test_committed_lfs_is_hydrated_from_object_not_checkout(self):
        import hashlib
        data = b'real model bytes'
        oid = hashlib.sha256(data).hexdigest()
        obj = self.repo / '.git/lfs/objects' / oid[:2] / oid[2:4] / oid
        obj.parent.mkdir(parents=True); obj.write_bytes(data)
        pointer = f'version https://git-lfs.github.com/spec/v1\noid sha256:{oid}\nsize {len(data)}\n'
        model = self.repo / 'CuePhys/model.usdz'
        model.write_text(pointer)
        self.git('add', '.'); self.git('commit', '-qm', 'LFS fixture')
        model.write_bytes(b'uncommitted different model')
        bundle = self.snap()
        self.assertEqual((bundle / 'source/CuePhys/model.usdz').read_bytes(), data)
        self.assertIn('.gitattributes', q.verify(bundle)['files'])
        obj.write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'Missing/corrupt LFS'):
            self.snap(name='bad')
        self.assertFalse((self.base / 'bad').exists())
        model.write_text(pointer)
        with self.assertRaisesRegex(ValueError, 'Unhydrated LFS'):
            self.snap(name='dirty', dirty=True, quiescent=True)

    def test_git_snapshot_ignores_concurrent_checkout_edits(self):
        (self.repo / 'CuePhys/value.swift').write_text('uncommitted B')
        p = self.snap()
        self.assertEqual((p / 'source/CuePhys/value.swift').read_text(), 'version A\n')
        (self.repo / 'CuePhys/value.swift').write_text('still later C')
        q.verify(p)

    def test_git_unicode_and_newline_names_are_not_git_quoted(self):
        name = 'CuePhys/中文 空格\n换行.swift'
        (self.repo / name).write_text('content')
        self.git('add', '.'); self.git('commit', '-qm', 'Unicode name')
        p = self.snap()
        self.assertIn(name, q.verify(p)['files'])
        self.assertEqual((p / 'source' / name).read_text(), 'content')

    def test_dirty_requires_quiescence_and_captures_untracked(self):
        with self.assertRaisesRegex(ValueError, 'quiescent'):
            self.snap(dirty=True)
        (self.repo / 'CuePhys/new.swift').write_text('new')
        p = self.snap(dirty=True, quiescent=True)
        self.assertIn('CuePhys/new.swift', q.verify(p)['files'])

    def test_capture_rejects_mutation_and_addition(self):
        def mutation():
            (self.repo / 'CuePhys/late.swift').write_text('late write')
        with self.assertRaisesRegex(ValueError, 'drift'):
            self.snap(dirty=True, quiescent=True, after_copy=mutation)
        self.assertFalse((self.base / 'snap').exists())

    def test_secret_and_nonbuild_resources_are_excluded(self):
        (self.repo / 'Config').mkdir(exist_ok=True)
        (self.repo / 'Config/Secrets.xcconfig').write_text('secret')
        (self.repo / 'CuePhys/Resources/Previews').mkdir(parents=True)
        (self.repo / 'CuePhys/Resources/Previews/large.png').write_bytes(b'large')
        p = self.snap(dirty=True, quiescent=True)
        self.assertNotIn('Config/Secrets.xcconfig', q.verify(p)['files'])
        self.assertNotIn('CuePhys/Resources/Previews/large.png', q.verify(p)['files'])

    def test_local_package_sources_and_artifacts_survive_snapshot_without_caches(self):
        files = {
            'Packages/CuePhysWeChat/Package.swift': b'package manifest',
            'Packages/CuePhysWeChat/Sources/Bridge.swift': b'bridge source',
            'Packages/CuePhysWeChat/Artifacts/SDK.xcframework.zip': b'local binary artifact',
            'Packages/CuePhysWeChat/.build/cache': b'not source',
            'Packages/CuePhysWeChat/.swiftpm/configuration': b'local settings',
            'Packages/CuePhysWeChat/.env': b'secret',
        }
        for name, data in files.items():
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        bundle = self.snap(dirty=True, quiescent=True)
        manifest = q.verify(bundle)['files']
        for name in list(files)[:3]:
            self.assertIn(name, manifest)
            self.assertEqual((bundle / 'source' / name).read_bytes(), files[name])
        for name in list(files)[3:]:
            self.assertNotIn(name, manifest)

    def test_changed_snapshot_is_rejected(self):
        p = self.snap()
        f = p / 'source/CuePhys/value.swift'; f.chmod(0o644); f.write_text('changed')
        with self.assertRaisesRegex(ValueError, 'content mismatch'):
            self.enqueue(p)

    def test_manifest_tampering_is_rejected(self):
        p = self.snap(); f = p / 'manifest.json'; f.chmod(0o644)
        m = q.read_json(f); m['origin']['commit'] = 'spoofed'; f.write_text(json.dumps(m))
        with self.assertRaisesRegex(ValueError, 'manifest hash'):
            q.verify(p)

    def test_added_file_and_symlink_rejected(self):
        p = self.snap(); src = p / 'source'; src.chmod(0o755)
        (src / 'extra').write_text('extra')
        with self.assertRaisesRegex(ValueError, 'content mismatch'):
            q.verify(p)
        (src / 'extra').unlink(); (src / 'link').symlink_to('/etc/passwd')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            q.verify(p)

    def test_archive_traversal_and_links_rejected(self):
        for name, kind in [('../outside', tarfile.REGTYPE), ('symlink', tarfile.SYMTYPE)]:
            archive = self.base / 'bad.tar'
            with tarfile.open(archive, 'w') as f:
                item = tarfile.TarInfo(name); item.type = kind; item.linkname = '/etc/passwd'; f.addfile(item)
            with self.assertRaises(ValueError):
                q.unpack(archive, self.base / 'unpacked')

    def test_enqueue_is_idempotent_and_rejects_conflicting_id(self):
        p = self.snap(); a = self.enqueue(p, job_id='stable-id')
        self.assertEqual(a, self.enqueue(p, job_id='stable-id'))
        with self.assertRaisesRegex(ValueError, 'different request'):
            self.enqueue(p, task='different', job_id='stable-id')
        self.assertEqual(len(q.jobs(self.queue)), 1)

    def test_multiple_workers_are_fifo_and_never_overlap(self):
        p = self.snap()
        for name in ['first', 'fails', 'third']:
            self.enqueue(p, task=name, job_id=name)
        ctx = multiprocessing.get_context('fork')
        processes = [ctx.Process(target=drain, args=(self.queue,)) for _ in range(4)]
        for p in processes: p.start()
        for p in processes: p.join(10); self.assertEqual(p.exitcode, 0)
        events = [json.loads(line) for line in (self.queue / 'execution-events.jsonl').read_text().splitlines()]
        self.assertEqual([(e['event'], e['job']) for e in events],
                         [(ev, job) for job in ['first', 'fails', 'third'] for ev in ['start', 'end']])
        self.assertEqual([j['state'] for j in q.jobs(self.queue)], ['succeeded', 'failed', 'succeeded'])
        self.assertLessEqual(q.jobs(self.queue)[0]['finished_at'], q.jobs(self.queue)[1]['started_at'])

    def test_concurrent_admission_has_unique_sequences(self):
        bundle = self.snap()
        ctx = multiprocessing.get_context('fork')
        processes = [ctx.Process(target=admit, args=(self.queue, bundle, 'agent-' + str(i))) for i in range(4)]
        for p in processes: p.start()
        for p in processes: p.join(10); self.assertEqual(p.exitcode, 0)
        self.assertEqual([j['sequence'] for j in q.jobs(self.queue)], [1, 2, 3, 4])
        self.assertEqual(len({j['job_id'] for j in q.jobs(self.queue)}), 4)

    def test_engine_deployment_atomically_replaces_readonly_version(self):
        import argparse
        import shutil
        args = argparse.Namespace(root=str(self.queue), host='test-host', ssh_option=[])
        real_run = subprocess.run
        def fake_scp(cmd, **kw):
            self.assertEqual(cmd[0], 'scp')
            destination = cmd[-1].split(':', 1)[1]
            self.assertIn('/incoming/engine-', destination)
            shutil.copyfile(cmd[-2], destination)
        def local_remote(args, cmd):
            return real_run(cmd, check=True, capture_output=True, text=True).stdout
        with patch.object(q, 'remote', side_effect=local_remote), patch.object(q.subprocess, 'run', side_effect=fake_scp):
            engine = q.deploy(args)
            self.assertEqual(q.deploy(args), engine)
        self.assertEqual(q.digest(engine), q.digest(SCRIPT))
        self.assertFalse(Path(engine).stat().st_mode & 0o222)
        self.assertEqual(list((self.queue / 'incoming').iterdir()), [])

    def test_cancel_only_queued_and_new_job_after_drain(self):
        p = self.snap(); a = self.enqueue(p, job_id='one')
        q.cancel(self.queue, a['job_id']); q.worker(self.queue, fake_executor)
        self.assertEqual(q.jobs(self.queue)[0]['state'], 'cancelled')
        self.enqueue(p, job_id='two'); q.worker(self.queue, fake_executor)
        self.assertEqual(q.jobs(self.queue)[1]['state'], 'succeeded')
        with self.assertRaises(ValueError): q.cancel(self.queue, 'two')

    def test_worker_crash_is_not_retried_and_blocks_queue(self):
        p = self.snap(); self.enqueue(p, job_id='crash'); self.enqueue(p, job_id='waiting')
        def crash(*args): raise SystemExit(99)
        with self.assertRaises(SystemExit): q.worker(self.queue, crash)
        with self.assertRaisesRegex(RuntimeError, 'Interrupted'):
            q.worker(self.queue, fake_executor)
        self.assertEqual([j['state'] for j in q.jobs(self.queue)], ['running', 'queued'])

    def test_executor_signal_blocks_future_workers(self):
        p = self.snap(); self.enqueue(p, job_id='signal'); self.enqueue(p, job_id='waiting')
        with self.assertRaisesRegex(RuntimeError, 'interrupted'):
            q.worker(self.queue, lambda *a: -15)
        with self.assertRaisesRegex(RuntimeError, 'Interrupted'):
            q.worker(self.queue, fake_executor)
        self.assertTrue(q.jobs(self.queue)[0]['blocked'])
        self.assertEqual(q.jobs(self.queue)[1]['state'], 'queued')

    def test_identical_task_labels_still_have_distinct_job_dirs(self):
        p = self.snap(); a = self.enqueue(p); b = self.enqueue(p)
        self.assertNotEqual(a['job_id'], b['job_id'])
        self.assertEqual(a['spec']['snapshot_id'], b['spec']['snapshot_id'])

    def test_execution_sources_are_independent_copies(self):
        import shutil
        p = self.snap(); a = self.enqueue(p); b = self.enqueue(p)
        source = self.queue / 'snapshots' / a['spec']['snapshot_id'] / 'source'
        paths = []
        for j in [a, b]:
            dst = self.queue / 'jobs' / j['job_id'] / 'source'; shutil.copytree(source, dst)
            paths.append(dst / 'CuePhys/value.swift')
        self.assertNotEqual(paths[0].stat().st_ino, paths[1].stat().st_ino)
        paths[0].chmod(0o644); paths[0].write_text('A changed')
        self.assertEqual(paths[1].read_text(), 'version A\n')
        q.verify(self.queue / 'snapshots' / a['spec']['snapshot_id'])

    def test_zero_tests_or_missing_selector_cannot_pass(self):
        ev = self.base / 'evidence'; ev.mkdir()
        good = {'result': 'Passed', 'failedTests': 0, 'skippedTests': 0, 'totalTestCount': 1}
        details = {'testNodes': [{'nodeType': 'Unit test bundle', 'name': 'CuePhysTests', 'children': [
            {'nodeType': 'Test Case', 'nodeIdentifier': 'ExampleTests/testA()', 'result': 'Passed'}]}]}
        with patch.object(q.subprocess, 'check_output', side_effect=[json.dumps(good).encode(), json.dumps(details).encode()]):
            q.test_summary(ev, ['CuePhysTests/ExampleTests/testA'])
        with patch.object(q.subprocess, 'check_output', side_effect=[json.dumps(good).encode(), json.dumps(details).encode()]):
            with self.assertRaises(RuntimeError): q.test_summary(ev, ['CuePhysTests/ExampleTests/testB'])
        good['totalTestCount'] = 0
        with patch.object(q.subprocess, 'check_output', side_effect=[json.dumps(good).encode(), b'{"testNodes":[]}']):
            with self.assertRaises(RuntimeError): q.test_summary(ev, ['CuePhysTests/ExampleTests'])


if __name__ == '__main__':
    unittest.main()
