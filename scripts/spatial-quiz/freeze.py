#!/usr/bin/env python3
"""Freeze accepted CB-01 candidates, without writing research sources. Re-export from snapshot."""
import gzip, hashlib, json, math, shutil, struct, sys
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT / 'research/masse-jump-capability-20261122'
SNAP = ROOT / 'tasks/spatial-v73/snapshot'
OUT = ROOT / 'CuePhys/Resources/SpatialQuizBank'
def sha(b): return hashlib.sha256(b).hexdigest()
def dump(v): return json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def f32(v): return struct.unpack('f',struct.pack('f',v))[0]

def freeze(mode):
    pointer, filename = ('masse-full-current.json','question-candidates.jsonl') if mode=='masse' else ('one-solution-current-run.json','solutions.jsonl.gz')
    dest=SNAP/mode
    if dest.exists(): return
    info=json.loads((RESEARCH/pointer).read_text()); source=Path(info['evidence'])
    before=(source/filename).read_bytes()
    rows=[json.loads(s) for s in (gzip.decompress(before) if filename.endswith('.gz') else before).splitlines()]
    # Published files are replaced atomically by the independent auditor. Detect a racing snapshot.
    assert (source/filename).read_bytes()==before, 'candidate list changed; retry freeze'
    temporary=SNAP/(mode+'.partial');temporary.mkdir(parents=True,exist_ok=False)
    (temporary/filename).write_bytes(before)
    dependencies={filename:sha(before)}
    for name in ['manifest.json','audit.json','summary.json']:
        if (source/name).is_file():
            b=(source/name).read_bytes();(temporary/name).write_bytes(b);dependencies[name]=sha(b)
    (temporary/'shapes').mkdir()
    for row in rows:
        name=row.get('evidencePacket',f"shapes/{row.get('sampleIndex',0):05d}.json.gz")
        b=(source/name).read_bytes();(temporary/name).write_bytes(b);dependencies[name]=sha(b)
    identity={'mode':mode,'runIdentity':info['runIdentity'],'source':str(source.relative_to(ROOT)),
      'candidateFile':filename,'candidateSHA256':sha(before),'count':len(rows),
      'frozenAt':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),'dependencies':dependencies}
    (temporary/'snapshot.json').write_bytes(dump(identity));temporary.rename(dest)

def export(mode):
    folder=SNAP/mode; identity=json.loads((folder/'snapshot.json').read_bytes())
    for name, expected in identity['dependencies'].items(): assert sha((folder/name).read_bytes())==expected,name
    b=(folder/identity['candidateFile']).read_bytes()
    rows=[json.loads(s) for s in (gzip.decompress(b) if identity['candidateFile'].endswith('.gz') else b).splitlines()]
    questions=[]; numbers=[*range(1,8),*range(9,16)]
    for r in rows:
        layout=r.get('sourceLayoutID',r.get('layoutID'));id=f'spatial-v1-{mode}-{layout}'
        number=numbers[int(sha(('spatial-ball-v1:'+id).encode())[:16],16)%14]
        if mode=='masse':
            assert r['status']=='researchCandidate' and r['runIdentity']==identity['runIdentity']
            a=r['answer']; o=r['obstacle']; e,v,x,y=a['parameter']; yaw=a['yawRadians']
            assert a['cueAccessible'] and a['technique']=='masse' and a['metrics']['settled']
            obstacle=o['center'];s,q,side=o['s'],o['q'],o['side']
        else:
            assert all(r[k] for k in ['settled','basePotted','baseSafe','objectPotted','firstContactIsTarget','techniqueShapePass','contactHemispherePass','cueFinalOnBed'])
            assert not r['obstacleContact'] and r['technique']=='jump'
            obstacle=r['obstacle']; s,q,side=r['obstacleS'],r['obstacleQ'],r['obstacleSide']
            # Preserve Research.swift's Float point subtraction before bearing conversion.
            dx=f32(f32(r['ghost']['x'])-f32(r['cue']['x'])); dz=f32(f32(r['ghost']['z'])-f32(r['cue']['z']))
            yaw=math.atan2(dz,dx); e,v,x,y=[r[k] for k in ['elevationDegrees','speedMPS','spinX','spinY']]
        packet=r.get('evidencePacket',f"shapes/{r.get('sampleIndex',0):05d}.json.gz")
        questions.append(dict(id=id,mode=mode,sourceLayoutID=layout,sourceID=r['id'],runIdentity=identity['runIdentity'],
            sourcePacketSHA256=identity['dependencies'][packet],cue=r['cue'],target=r['target'],obstacle=obstacle,
            targetNumber=number,s=s,q=q,side=side,distance=math.hypot(r['cue']['x']-r['target']['x'],r['cue']['z']-r['target']['z']),
            reference=dict(yaw=yaw,speed=v,spinX=x,spinY=y,elevation=e),referencePocket=r['pocket']))
    assert len({q['id'] for q in questions})==len(questions)
    candidate_data=gzip.compress(dump(questions),mtime=0)
    approval=ROOT/f'tasks/spatial-v73/evidence/B5-qualification/{mode}.json'
    assert approval.is_file(), 'formal export requires a complete current-reference audit; never publish unaudited candidates'
    verification=None
    if approval.exists():
        audit_bytes=approval.read_bytes(); audit=json.loads(audit_bytes)
        assert audit['mode']==mode and audit['rule']=='spatial-quiz-v1'
        assert audit['fingerprint']==sha(candidate_data), 'audit belongs to different candidate inputs'
        assert audit['planned']==audit['completed']==len(questions)==len(audit['rows'])
        by_id={row['id']:row for row in audit['rows']}
        assert len(by_id)==len(questions) and set(by_id)=={q['id'] for q in questions}
        approved={key for key,row in by_id.items() if row['accepted']}
        assert len(approved)==audit['passed']
        assert audit['passed']+audit['failed']+audit['unconfirmed']==len(questions)
        assert all(by_id[key]['complete'] and by_id[key]['accessible'] and not by_id[key]['issues'] for key in approved)
        questions=[q for q in questions if q['id'] in approved]
        assert len(questions)>=15, 'no viable formal bank'
        verification=dict(candidateSHA256=sha(candidate_data),auditSHA256=sha(audit_bytes),
            planned=audit['planned'],completed=audit['completed'],passed=audit['passed'],
            failed=audit['failed'],unconfirmed=audit['unconfirmed'])
    data=gzip.compress(dump(questions),mtime=0); OUT.mkdir(exist_ok=True,parents=True); (OUT/f'{mode}.json.gz').write_bytes(data)
    manifest=dict(version=1,mode=mode,physics='spatialPractice',judgement='spatial-quiz-v1',geometry='bundled-table-exterior-v2',
        file=f'{mode}.json.gz',sha256=sha(data),count=len(questions),sourceSHA256=identity['candidateSHA256'],runIdentity=identity['runIdentity'],
        distanceBins=sorted({int(q['distance']*2) for q in questions}),sValues=sorted({q['s'] for q in questions}),qValues=sorted({q['q'] for q in questions}))
    if verification: manifest['verification']=verification
    (OUT/f'{mode}-manifest.json').write_bytes(dump(manifest)); print(mode,len(questions),len(data),manifest['sha256'])
if __name__=='__main__':
    for mode in ['masse','jump']:
        if '--freeze' in sys.argv: freeze(mode)
        export(mode)
