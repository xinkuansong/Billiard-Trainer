#!/usr/bin/env python3
"""Join explicit state bindings to reviewed evidence without claiming acceptance."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--index', type=Path, default=Path('output/app-native-audit/review/index.json'))
p.add_argument('--atoms', type=Path, default=Path('tasks/app-interface-redesign/STATE-ATOMS-v4.json'))
p.add_argument('--bindings', type=Path, default=Path('tasks/app-interface-redesign/STATE-CAPTURE-BINDINGS-v4.json'))
p.add_argument('--table', action='store_true', help='Report the separate DAILY/TABLE candidate matrix; do not add it to App wrapper counts')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
if a.table:
    a.atoms = Path('tasks/app-interface-redesign/TABLE-STATE-MATRIX-v4.json')
    a.bindings = Path('tasks/app-interface-redesign/TABLE-CAPTURE-BINDINGS-v4.json')
atoms = json.loads(a.atoms.read_text())
bindings = json.loads(a.bindings.read_text())
index = json.loads(a.index.read_text())
assert atoms['baseline'] == bindings['baseline'] == index['baseline']
states = {s['id']: dict(s, evidence=[]) for e in atoms['entries'] for s in e['states']}
groups = {}
for binding in bindings['bindings']:
    assert binding['layoutGroup'] not in groups
    assert all(s in states for s in binding['stateIds'])
    groups[binding['layoutGroup']] = binding['stateIds']
legacy_slots = {}
for binding in bindings.get('legacySlotBindings', []):
    prefix = binding['slotPrefix']
    assert prefix.endswith('/') and prefix not in legacy_slots
    assert all(s in states for s in binding['stateIds'])
    legacy_slots[prefix] = binding['stateIds']
unmapped = set()
for image in index['images']:
    group = image.get('layoutGroup')
    matched_states = groups.get(group)
    if matched_states is None:
        matches = [ids for prefix, ids in legacy_slots.items()
                   if image['slotId'].startswith(prefix)]
        assert len(matches) <= 1, 'Ambiguous legacy slot binding: ' + image['slotId']
        matched_states = matches[0] if matches else None
    if matched_states is None:
        unmapped.add(group or image['slotId'])
        continue
    if image.get('status') != 'VALIDATED':
        continue
    for sid in matched_states:
        states[sid]['evidence'].append({k: image.get(k) for k in [
            'captureId', 'slotId', 'sha256', 'path', 'device', 'orientation', 'theme',
            'slice', 'coverageStatus', 'coverageNote', 'partialWorkflow',
            'resultEvidence', 'figmaURL', 'reviewManifests']})
for state in states.values():
    state['environmentsWithReviewedEvidence'] = sorted({
        '/'.join(e[k] or '?' for k in ['device', 'orientation', 'theme'])
        for e in state['evidence']})
    # Evidence is not full-page or whole-matrix acceptance. Preserve planned
    # statuses from the source until applicability and coverage are resolved.
    state['evidenceStatus'] = 'HAS_REVIEWED_VIEWPORTS' if state['evidence'] else 'NO_BOUND_REVIEWED_EVIDENCE'
report = dict(baseline=atoms['baseline'], domain='DAILY_TABLE' if a.table else 'APP',
    denominatorStatus=atoms.get('status', 'DRAFT_APPLICABILITY_AND_FIXTURE_AUDIT_REQUIRED'),
    candidateStates=len(states), statesWithReviewedEvidence=sum(bool(s['evidence']) for s in states.values()),
    userAcceptance=False,
    note='Candidate denominator remains under audit. Environment presence does not establish full-body coverage or Figma delivery. Unmapped evidence and missing states remain explicit.',
    unmappedCaptureGroups=sorted(unmapped), states=list(states.values()))
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({k: report[k] for k in ['candidateStates', 'statesWithReviewedEvidence', 'denominatorStatus']}))
