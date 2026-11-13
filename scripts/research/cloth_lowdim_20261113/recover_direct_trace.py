#!/usr/bin/env python3
"""Offline recovery of a failed, late-sealed trace; never records or controls an App."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from local_test_lifecycle import DEFAULT_ROOT, fingerprint, locked, record

CORE = {'time-info', 'metal-gpu-intervals', 'metal-application-command-buffer-submissions',
        'time-profile', 'activity-monitor-process-live', 'os-signpost'}

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n')

def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def need(condition, text):
    if not condition:
        raise ValueError(text)

def quiet_source(source, pid, evidence, tag):
    checks = {}
    for key, command in [('recorder', ['/bin/ps', '-p', str(pid), '-o', 'pid=,ppid=,lstart=,comm=']),
                         ('handles', ['/usr/sbin/lsof', '-nP', '+D', str(source)])]:
        p = subprocess.run(command, text=True, capture_output=True, timeout=30)
        checks[key] = {'argv': command, 'exitCode': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}
        write(evidence / (tag + '-quiescence.json'), checks)
        need(p.returncode == 1 and not p.stdout.strip() and not p.stderr.strip(),
             key + ' remains active or its absence cannot be established')
    return checks

def exported(command, evidence, name):
    write(evidence / (name + '-command.json'), command)
    started = time.time()
    row = {'argv': command, 'timeoutSeconds': 120, 'startedAt': started,
           'workaroundEnvironmentApplied': False}
    print('EXPORT_BEGIN ' + name, flush=True)
    with (evidence / (name + '-export.log')).open('wb') as log:
        try:
            p = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            row['exitCode'] = p.returncode
        except subprocess.TimeoutExpired:
            row.update(exitCode=None, timedOut=True)
    row['elapsedSeconds'] = time.time() - started
    write(evidence / (name + '-export-result.json'), row)
    print('EXPORT_END ' + name + ' ' + json.dumps(row), flush=True)
    return row

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-run', type=Path, required=True)
    p.add_argument('--recorder-pid', type=int, required=True)
    p.add_argument('--work', type=Path, required=True)
    p.add_argument('--evidence', type=Path, required=True)
    a = p.parse_args()
    work, evidence, run = a.work.resolve(), a.evidence.resolve(), a.source_run.absolute()
    need(str(work) == os.environ.get('QIUJI_TEST_WORK') and str(evidence) == os.environ.get('QIUJI_TEST_EVIDENCE')
         and bool(os.environ.get('QIUJI_TEST_RUN_ID')), 'Use the existing local_test_lifecycle owner')
    need(not os.environ.get('QIUJI_SIMULATOR_LEASE_TOKEN'), 'No simulator lease permitted')
    need(run.parent == DEFAULT_ROOT and run.resolve() == run and run != work.parent, 'Invalid source owner')
    source = run / 'evidence/capture.trace'
    clone = work / 'capture-recovery.trace'
    need(source.is_dir() and not source.is_symlink() and not clone.exists(), 'Require original trace and fresh clone')
    result = {'status': 'failed', 'performanceAccepted': False, 'originalRun': str(run),
              'originalRecordingExitCode': None, 'originalRunRemainsFailed': True,
              'scope': 'offline recovery on APFS clone only; no new record/App/GPU workload', 'exports': []}
    before = None
    with locked(run):
        try:
            state = record(run)
            need(state['state'] == 'failed' and state['exit_code'] != 0, 'Expected the specific failed original run')
            result['originalRunJSONSHA256'] = sha(run / 'run.json')
            write(evidence / 'source-run-record-copy.json', state)
            write(evidence / 'source-launcher-summary-copy.json', json.loads((run / 'evidence/summary.json').read_text()))
            for filename in ['process-before.json', 'recorder-process.json', 'record-command.json', 'launcher.json']:
                (evidence / ('source-' + filename)).write_bytes((run / 'evidence' / filename).read_bytes())
            (evidence / 'recover_direct_trace.py').write_bytes(Path(__file__).read_bytes())
            quiet_source(source, a.recorder_pid, evidence, 'before')
            before = fingerprint(run / 'evidence')
            old = state['evidence_sha256']
            drift = {'sealedCount': len(old), 'currentCount': len(before),
                     'added': sorted(set(before) - set(old)), 'removed': sorted(set(old) - set(before)),
                     'changed': sorted(k for k in before.keys() & old.keys() if before[k] != old[k]),
                     'originalSealRewritten': False}
            write(evidence / 'original-seal-drift.json', drift)
            write(evidence / 'source-evidence-before.json', before)
            trace_before = {k.removeprefix('capture.trace/'): v for k, v in before.items() if k.startswith('capture.trace/')}
            need(bool(trace_before), 'Trace has no files')
            print('SOURCE_QUIESCENT ' + json.dumps({'files': len(trace_before), 'drift': {k: len(drift[k]) for k in ['added','removed','changed']}}), flush=True)
            command = ['/bin/cp', '-cR', str(source), str(clone)]
            write(evidence / 'clone-command.json', command)
            subprocess.run(command, check=True, timeout=120)
            clone_before = fingerprint(clone)
            need(clone_before == trace_before, 'APFS clone differs from current original trace')
            need(fingerprint(run / 'evidence') == before, 'Original evidence changed while cloning')
            quiet_source(source, a.recorder_pid, evidence, 'after-clone')
            write(evidence / 'clone-before.json', clone_before)
            result['cloneVerifiedBeforeExports'] = True
            command = ['xcrun','xctrace','export','--input',str(clone),'--toc','--output',str(evidence/'trace-toc.xml')]
            toc = exported(command, evidence, 'toc')
            need(toc.get('exitCode') == 0, 'Recovered clone TOC export failed')
            root = ET.parse(evidence / 'trace-toc.xml').getroot()
            need(root.tag == 'trace-toc' and root.findall('./run'), 'Unexpected/empty recovered TOC')
            inventory = []
            for recording in root.findall('./run'):
                number = recording.get('number', '')
                need(number.isdigit(), 'Invalid run number')
                for index, table in enumerate(recording.findall('./data/table'), 1):
                    attributes = dict(table.attrib)
                    item = {'run': number, 'tableIndex': index, 'attributes': attributes}
                    inventory.append(item)
                    schema = table.get('schema', '')
                    if schema not in CORE:
                        continue
                    name = f'run-{number}-table-{index}-{schema}'
                    target = evidence / (name + '.xml')
                    xpath = f'/trace-toc/run[@number="{number}"]/data/table[{index}]'
                    row = {**item, **exported(['xcrun','xctrace','export','--input',str(clone),
                                              '--xpath',xpath,'--output',str(target)], evidence, name)}
                    if row.get('exitCode') == 0:
                        try:
                            count = 0
                            for _, element in ET.iterparse(target, events=('end',)):
                                if element.tag == 'row': count += 1
                                element.clear()
                            row.update(xmlValid=True, rows=count, nonempty=count > 0, sha256=sha(target))
                        except (OSError, ET.ParseError) as error:
                            row.update(xmlValid=False, error=repr(error))
                    result['exports'].append(row)
                    write(evidence / 'table-export-results.json', result['exports'])
                    if row.get('timedOut'):
                        # Do not start another export while a timeout may have left an open owner.
                        opened = subprocess.run(['/usr/sbin/lsof','-nP','+D',str(clone)], capture_output=True,text=True,timeout=30)
                        write(evidence / (name+'-timeout-handles.json'), {'exitCode':opened.returncode,'stdout':opened.stdout,'stderr':opened.stderr})
                        need(opened.returncode == 1 and not opened.stdout.strip() and not opened.stderr.strip(), 'Timed-out export still owns clone; stop sequential recovery')
            write(evidence / 'schema-inventory.json', {'observedTables': inventory,
                  'requestedSchemasAbsent': sorted(CORE - {i['attributes'].get('schema') for i in inventory})})
            result.update(status='recovered_exports_pending_analysis', tocExported=True,
                          nonemptyTables=sum(bool(r.get('nonempty')) for r in result['exports']))
        except BaseException as error:
            result['error'] = repr(error)
        finally:
            if before is not None:
                after = fingerprint(run / 'evidence')
                write(evidence / 'source-evidence-after.json', after)
                result['originalEvidenceUnchangedByRecovery'] = before == after
                result['originalRunJSONUnchanged'] = result['originalRunJSONSHA256'] == sha(run / 'run.json')
                if not result['originalEvidenceUnchangedByRecovery'] or not result['originalRunJSONUnchanged']:
                    result['status'] = 'failed'
            if clone.exists():
                clone_after = fingerprint(clone)
                write(evidence / 'clone-after.json', clone_after)
                result['cloneChangedByExporter'] = clone_after != locals().get('clone_before', {})
            write(evidence / 'summary.json', result)
            print('RECOVERY_SUMMARY ' + json.dumps(result, ensure_ascii=False), flush=True)
    return 0 if result['status'] == 'recovered_exports_pending_analysis' else 1

if __name__ == '__main__':
    sys.exit(main())
