#!/usr/bin/env python3
"""Verified parallel execution of the frozen serial CB01 search; research only."""
import argparse
import fcntl
import gzip
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import sys
import threading
import time

import run_masse_search as search
import run_masse_full as full

HERE, ROOT = search.HERE, search.ROOT
POINTER = HERE / 'masse-parallel-current.json'


def configure(work):
    search.PRODUCTS = work / 'DerivedData/Build/Products'
    search.APP = search.PRODUCTS / 'Debug-iphonesimulator/球迹.app'
    search.BUNDLE = search.APP / 'PlugIns/QiuJiTests.xctest'


def read_packet(path):
    with gzip.open(path, 'rt') as stream:
        return json.load(stream)


def physics(row):
    return {k: v for k, v in row.items() if k not in ('reusedFrom', 'executionRevision')}


def build(args):
    assert os.environ.get('QIUJI_TEST_WORK') == str(args.work)
    request, out = full.paths()
    assert search.sha(HERE / 'MasseSearch.swift') == request['researchSwiftSHA256']
    snapshot = args.work / 'snapshot'
    subprocess.run(['cp', '-cR', str(search.BUILD / 'snapshot'), str(snapshot)], check=True)
    # The algorithm is extracted verbatim, not reimplemented or edited for concurrency.
    original = (HERE / 'MasseSearch.swift').read_text()
    prefix = original.split('    func testMasseSearch() throws {', 1)[0]
    worker = prefix.replace('final class CB01MasseSearchTests: XCTestCase {', 'final class CB01MasseSearchWorker {', 1)
    test = snapshot / 'QiuJiTests/PhysicsEngineTests.swift'
    test.write_text((HERE / 'masse-base-test-20261126.swift').read_text() + '\n' + worker + (HERE / 'MasseParallel.swift').read_text())
    configure(args.work)
    command = ['make', '-f', 'scripts/Makefile', 'test', 'TEST_ACTION=build-for-testing', 'SCHEME=CB01Research',
               f'PROJECT_FLAG=-project {snapshot / "QiuJi.xcodeproj"}', f'DERIVED_DATA={args.work / "DerivedData"}',
               f'BUILD_DIR={args.work / "build"}', 'TEST_DESTINATION=generic/platform=iOS Simulator',
               'TEST_CODE_COVERAGE=NO', 'TEST_BUILD_SETTINGS=-jobs 2 ARCHS=arm64',
               f'TEST_LOG={args.evidence / "build.log"}', f'TEST_JUNIT={args.evidence / "build.xml"}']
    with (args.evidence / 'build-driver.log').open('w') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    record = {'canonicalSearchSHA256': search.sha(HERE / 'MasseSearch.swift'),
              'parallelWrapperSHA256': search.sha(HERE / 'MasseParallel.swift'),
              'runnerSHA256': search.sha(Path(__file__)), 'snapshotTestSHA256': search.sha(test),
              'testBinaryUUID': subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(search.BUNDLE / 'QiuJiTests')], text=True).split()[1],
              'work': str(args.work), 'evidence': str(args.evidence), 'runIdentity': request['runIdentity']}
    # Demonstrate every frozen production source/resource is unchanged by this build.
    source_root = search.BUILD / 'snapshot'
    hashes = {}
    for path in source_root.rglob('*'):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(source_root)
        if rel == Path('QiuJiTests/PhysicsEngineTests.swift') or '.xcuser' in str(rel):
            continue
        assert search.sha(path) == search.sha(snapshot / rel), f'frozen source changed: {rel}'
        hashes[str(rel)] = search.sha(path)
    search.atomic(args.evidence / 'frozen-source-hashes.json', hashes)
    search.atomic(args.evidence / 'build.json', record)
    search.atomic(POINTER, record)
    print('PARALLEL_BUILD_PASSED', flush=True)


def sample_resources(udid, stop, samples):
    while not stop.wait(2):
        lines = subprocess.check_output(['ps', '-axo', 'pid,%cpu,rss,command'], text=True).splitlines()
        for line in lines:
            if f'/Devices/{udid}/' in line and '/球迹.app/球迹' in line:
                values = line.split(None, 3)
                samples.append({'epoch': time.time(), 'pid': int(values[0]), 'cpuPercent': float(values[1]), 'rssKiB': int(values[2])})


def batch(args, request, shapes, workers, destination, label):
    assert os.environ.get('QIUJI_SIMULATOR_LEASE_TOKEN') and os.environ.get('QIUJI_SIMULATOR_UDID') == args.udid
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'shapes').mkdir(exist_ok=True)
    tag = f'{label}-{time.time_ns()}'
    subrequest = dict(request, shapes=shapes, workers=workers)
    search.atomic(destination / (tag + '-input.json'), subrequest)
    shutil.copyfile(destination / (tag + '-input.json'), search.BUNDLE / 'masse-request.json')
    for bundle in (search.BUNDLE, search.APP):
        subprocess.run(['codesign', '--force', '--sign', '-', '--preserve-metadata=entitlements,requirements,flags', str(bundle)], check=True, capture_output=True)
    config = search.resolve_testroot(plistlib.loads(next(search.PRODUCTS.glob('CB01Research_*.xctestrun')).read_bytes()))
    test = config['QiuJiTests']
    test.setdefault('EnvironmentVariables', {})['CB01_MASSE_REQUEST'] = 'masse-request.json'
    test['OnlyTestIdentifiers'] = ['CB01MasseParallelTests']
    cfg = destination / (tag + '.xctestrun')
    cfg.write_bytes(plistlib.dumps(config))
    command = ['xcodebuild', 'test-without-building', '-xctestrun', str(cfg), '-destination', f'platform=iOS Simulator,id={args.udid}',
               '-parallel-testing-enabled', 'NO', '-only-testing:QiuJiTests/CB01MasseParallelTests',
               '-resultBundlePath', str(destination / (tag + '.xcresult'))]
    lookup = {s['sampleIndex']: s for s in shapes}
    received, stats, resources = set(), None, []
    start = time.monotonic()
    stop = threading.Event()
    monitor = threading.Thread(target=sample_resources, args=(args.udid, stop, resources), daemon=True)
    monitor.start()
    try:
        with (destination / (tag + '-boot.log')).open('w') as log:
            boot = subprocess.run(['xcrun', 'simctl', 'boot', args.udid], stdout=log, stderr=subprocess.STDOUT)
            if boot.returncode:
                inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
                assert any(d['udid'] == args.udid and d['state'] == 'Booted' for group in inventory['devices'].values() for d in group)
            subprocess.run(['xcrun', 'simctl', 'bootstatus', args.udid, '-b'], stdout=log, stderr=subprocess.STDOUT, check=True)
        with (destination / (tag + '.log')).open('w') as log:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            try:
                for line in process.stdout:
                    log.write(line); log.flush()
                    if 'CB01_PARALLEL_STATS ' in line:
                        stats = json.loads(line.split('CB01_PARALLEL_STATS ', 1)[1])
                    if 'CB01_MASSE ' not in line:
                        continue
                    row = json.loads(line.split('CB01_MASSE ', 1)[1])
                    index = row['sampleIndex']
                    assert index not in received
                    search.validate(row, lookup[index], request['runIdentity'])
                    path = destination / 'shapes' / f'{index:05d}.json.gz'
                    assert not path.exists(), f'refusing to overwrite completed shape {index}'
                    row['executionRevision'] = {'binaryUUID': args.build_record['testBinaryUUID'], 'workers': workers,
                                                'wrapperSHA256': args.build_record['parallelWrapperSHA256'], 'batch': tag}
                    tmp = path.with_suffix('.tmp')
                    with gzip.open(tmp, 'wt') as stream:
                        json.dump(row, stream, ensure_ascii=False, separators=(',', ':'))
                    tmp.replace(path)
                    received.add(index)
                    print(json.dumps({'index': index, 'status': row['status'], 'workers': workers}), flush=True)
                code = process.wait()
            finally:
                if process.poll() is None:
                    process.terminate(); process.wait(timeout=30)
        assert code == 0 and received == set(lookup), f'batch failed: {code}, {len(received)}/{len(lookup)}'
        assert stats and stats['completed'] == len(shapes) and stats['workers'] == workers
        receipt = dict(stats, exitCode=code, indexes=sorted(received), wallSeconds=time.monotonic()-start,
                       maxRSSMiB=max((r['rssKiB']/1024 for r in resources), default=0),
                       maxCPUPercent=max((r['cpuPercent'] for r in resources), default=0))
        search.atomic(destination / (tag + '-receipt.json'), receipt)
        print(json.dumps({'batchReceipt': receipt}), flush=True)
        return receipt
    finally:
        stop.set(); monitor.join(timeout=5)
        search.atomic(destination / (tag + '-resources.json'), resources)
        search.shutdown_device(args.udid, destination / (tag + '-shutdown.json'))


def benchmark(args, request, out):
    # Deterministic coverage across outcomes and source cells, with hard cases included.
    audit = json.loads((out / 'candidate-audit.json').read_text())
    review = {x['sampleIndex'] for x in audit['reviewRequired']}
    rows = []
    for path in sorted((out / 'shapes').glob('*.json.gz')):
        row = read_packet(path)
        status = 'review' if row['sampleIndex'] in review else ('incomplete' if row['incompleteFinalSimulations'] else row['status'])
        rows.append((row, status))
    chosen = []
    covered = set()
    # 32 cases: 8 accepted/raw solved, 12 exhausted, 6 incomplete, 6 independently rejected.
    for status, count in [('solved', 8), ('searchExhausted', 12), ('incomplete', 6), ('review', 6)]:
        candidates = [r for r, s in rows if s == status]
        for _ in range(min(count, len(candidates))):
            row = max(candidates, key=lambda r: (sum((k, str(r['source'][k])) not in covered for k in ('pocket', 'distanceBit', 'railIndex', 'angleIndex')), min(r['simulations'], 500)))
            candidates.remove(row); chosen.append(row)
            covered.update((k, str(row['source'][k])) for k in ('pocket', 'distanceBit', 'railIndex', 'angleIndex'))
    shapes = [r['source'] for r in chosen]
    search.atomic(args.evidence / 'benchmark-selection.json', [{'sampleIndex': r['sampleIndex'], 'simulations': r['simulations'], 'status': r['status']} for r in chosen])
    results = []
    for workers in (1, 2, 4, 8):
        dest = args.evidence / f'benchmark-{workers}'
        receipt = batch(args, request, shapes, workers, dest, 'bench')
        for old in chosen:
            new = read_packet(dest / 'shapes' / f"{old['sampleIndex']:05d}.json.gz")
            assert physics(old) == physics(new), f"serial equivalence failed: workers={workers}, index={old['sampleIndex']}"
        receipt['exactSerialMatches'] = len(chosen)
        receipt['speedup'] = results[0]['seconds']/receipt['seconds'] if results else 1.0
        results.append(receipt)
        search.atomic(args.evidence / 'benchmark-results.json', results)
        print('BENCHMARK_VERIFIED ' + json.dumps({'workers': workers, 'seconds': receipt['seconds'], 'speedup': receipt['speedup']}), flush=True)
    assert results[-1]['peakActive'] == 8
    assert results[-1]['seconds'] < results[0]['seconds'], 'eight workers did not improve throughput'
    return results


def execute(args):
    configure(args.work)
    args.build_record = json.loads((args.evidence / 'build.json').read_text())
    assert args.build_record['runnerSHA256'] == search.sha(Path(__file__))
    sources = args.evidence / 'sources'
    sources.mkdir(exist_ok=True)
    for name in ('MasseSearch.swift', 'MasseParallel.swift', 'run_masse_parallel.py',
                 'run_masse_search.py', 'run_masse_full.py', 'analyze_masse_search.py'):
        shutil.copyfile(HERE / name, sources / name)
    request, out = full.paths()
    assert args.build_record['canonicalSearchSHA256'] == search.sha(HERE / 'MasseSearch.swift') == request['researchSwiftSHA256']
    assert args.build_record['parallelWrapperSHA256'] == search.sha(HERE / 'MasseParallel.swift')
    assert args.build_record['testBinaryUUID'] == subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(search.BUNDLE / 'QiuJiTests')], text=True).split()[1]
    assert request['sourceBankSHA256'] == search.sha(search.source.BANK)
    assert request['sourceSampleSHA256'] == search.sha(search.source.INPUT)
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    with (HERE / 'masse-full.lock').open('a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        state = {'status': 'benchmarkingParallel', 'pid': os.getpid(), 'udid': args.udid, 'workers': 8,
                 'runIdentity': request['runIdentity'], 'work': str(args.work), 'lifecycleEvidence': str(args.evidence),
                 'startedAtEpoch': time.time(), 'batchSize': 400, 'executionRevision': args.build_record}
        # Archive serial run identity and source evidence before changing the execution backend.
        shutil.copyfile(out / 'job-state.json', args.evidence / 'serial-final-state.json')
        search.atomic(args.evidence / 'preserved-packets.json', {p.name: search.sha(p) for p in (out / 'shapes').glob('*.json.gz')})
        full.publish(out, state)
        try:
            results = benchmark(args, request, out)
            state['benchmark'] = results
            search.atomic(out / 'parallel-execution.json', dict(args.build_record, benchmark=results))
            startup_failures = 0
            while True:
                summary = search.summarize(out, request)
                checked = full.audit(out, request)
                state.update(summary=summary, candidateAudit=checked)
                pending = [s for s in request['shapes'] if not (out / 'shapes' / f"{s['sampleIndex']:05d}.json.gz").exists()]
                state['status'] = 'runningParallel' if pending else 'complete'
                full.publish(out, state)
                if not pending:
                    search.atomic(args.evidence / 'full-run-result.json', state)
                    return
                if shutil.disk_usage(HERE).free < 20 * 1024**3:
                    raise RuntimeError('Less than 20 GiB free; checkpoints preserved')
                previous_logs = set(out.glob('parallel-*.log'))
                try:
                    receipt = batch(args, request, pending[:400], 8, out, 'parallel')
                except AssertionError as error:
                    new_logs = set(out.glob('parallel-*.log')) - previous_logs
                    startup = any('Simulator device failed to launch' in p.read_text() for p in new_logs)
                    startup_failures += 1
                    if not startup or startup_failures >= 3:
                        raise
                    state.update(status='retryingStartup', lastError=str(error), consecutiveFailures=startup_failures)
                    full.publish(out, state)
                    time.sleep(5)
                    continue
                startup_failures = 0
                state['lastBatch'] = receipt
        except BaseException as error:
            state.update(status='interrupted' if isinstance(error, KeyboardInterrupt) else 'failed', lastError=repr(error))
            full.publish(out, state)
            search.atomic(args.evidence / 'full-run-result.json', state)
            raise


def main():
    p = argparse.ArgumentParser()
    p.add_argument('command', choices=['launch', 'execute', 'resume-build'])
    p.add_argument('--work', type=Path, required=True)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--udid')
    p.add_argument('--serial-pid', type=int)
    p.add_argument('--build-from', type=Path)
    args = p.parse_args()
    if args.command == 'execute':
        execute(args); return
    if args.command == 'resume-build':
        assert os.environ.get('QIUJI_TEST_WORK') == str(args.work)
        previous = json.loads((args.build_from / 'evidence/build.json').read_text())
        assert previous['canonicalSearchSHA256'] == search.sha(HERE / 'MasseSearch.swift')
        assert previous['parallelWrapperSHA256'] == search.sha(HERE / 'MasseParallel.swift')
        configure(args.work)
        search.PRODUCTS.parent.mkdir(parents=True)
        subprocess.run(['cp', '-cR', str(args.build_from / 'work/DerivedData/Build/Products'), str(search.PRODUCTS)], check=True)
        record = dict(previous, work=str(args.work), evidence=str(args.evidence),
                      runnerSHA256=search.sha(Path(__file__)), reusedBuildEvidence=str(args.build_from / 'evidence'))
        search.atomic(args.evidence / 'build.json', record)
        search.atomic(POINTER, record)
        # Explicitly borrow the known previous run's core device, which may still be booted.
        # Lifecycle still enforces the host-wide exclusive lease; no device data is erased.
        command = [sys.executable, str(ROOT / 'scripts/simulator_lifecycle.py'), 'run',
                   '--udid', args.udid, '--task', 'cb01-masse-parallel-10000-20261126', '--',
                   sys.executable, str(Path(__file__).resolve()), 'execute', '--work', str(args.work),
                   '--evidence', str(args.evidence), '--udid', '{udid}']
        subprocess.run(command, cwd=ROOT, check=True)
        return
    build(args)
    # Only hand over the known serial worker after the replacement binary exists.
    _, out = full.paths()
    state = json.loads((out / 'job-state.json').read_text())
    assert state['pid'] == args.serial_pid and state['status'] == 'running'
    command = subprocess.check_output(['ps', '-p', str(args.serial_pid), '-o', 'command='], text=True)
    assert 'run_masse_full.py work' in command and str(state['work']) in command
    os.kill(args.serial_pid, signal.SIGTERM)
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        check = subprocess.run(['ps', '-p', str(args.serial_pid), '-o', 'pid='], capture_output=True)
        if check.returncode:
            break
        time.sleep(2)
    else:
        raise RuntimeError('Serial worker did not stop; refusing concurrent writers')
    # The enclosing lifecycle releases its lease after the worker exits.
    time.sleep(5)
    command = [sys.executable, str(ROOT / 'scripts/simulator_lifecycle.py'), 'run', '--udid', state['udid'],
               '--task', 'cb01-masse-parallel-10000-20261126', '--', sys.executable, str(Path(__file__).resolve()),
               'execute', '--work', str(args.work), '--evidence', str(args.evidence), '--udid', '{udid}']
    subprocess.run(command, cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
