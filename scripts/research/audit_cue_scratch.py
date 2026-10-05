#!/usr/bin/env python3
"""Independent Python reconstruction of success predicates from raw event rows."""
import json,collections,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/cue-scratch-research-20261004'
def audit(paths):
 counts=collections.Counter();issues=[]
 for p in paths:
  for line in p.open():
   r=json.loads(line);counts['rows']+=1
   if not r.get('reject') and r.get('termination') not in (None,'nil'):counts['physicalTrials']+=1
   if not r.get('hit'):continue
   counts['hits']+=1
   ev=r['events'];ball=[e for e in ev if e['kind']=='ball']
   cap={e['ball']:e for e in ev if e['kind']=='pocket'}
   errors=[]
   if len(ball)!=1 or {ball[0]['a'],ball[0]['b']}!={'cueBall','object'}:errors.append('ball_contacts')
   if 'cueBall' not in cap or 'object' not in cap:errors.append('missing_capture')
   if not errors:
    t=ball[0]['t'];cueEnd=cap['cueBall']['t'];objEnd=cap['object']['t']
    rails=[e for e in ev if e['kind']=='rail' and e['ball']=='cueBall' and t<=e['t']<=cueEnd]
    if any(e['kind']=='rail' and e['ball']=='cueBall' and e['t']<t for e in ev):errors.append('pre_rail')
    if any(e['kind']=='rail' and e['ball']=='object' and e['t']<=objEnd for e in ev):errors.append('object_rail_or_jaw')
    if any(not 0<=e['segment']<6 for e in rails):errors.append('jaw')
    if [e['segment'] for e in rails]!=r['rails'] or len(rails)>3:errors.append('rail_count')
    if cap['object']['pocket']!=f'pocket_{r["pocket"]}' or cap['cueBall']['pocket']!=r['cuePocket']:errors.append('pocket')
    if not r['resolved']:errors.append('unresolved')
   if errors:issues.append(dict(id=r['id'],errors=errors))
   counts[f'rail_{len(r["rails"])}']+=1
 result=dict(counts=dict(counts),issues=issues,passed=not issues)
 print(json.dumps(result,ensure_ascii=False));return result
if __name__=='__main__':
 paths=[Path(x) for x in sys.argv[1:]] or sorted(OUT.glob('*.jsonl'))
 result=audit(paths);(OUT/'independent-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
 if result['issues']:raise SystemExit(1)
