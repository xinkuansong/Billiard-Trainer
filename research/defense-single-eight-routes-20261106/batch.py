"""Run one worker per chunk and audit the final layout, probes and rail classes before admission."""
import collections
import concurrent.futures
import csv
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'output'/HERE.name
DEEP = os.environ.get('SINGLE_EIGHT_DEEP') == '1'
QUICK = OUT
if DEEP:
    OUT = QUICK/'deep'
OPENING=ROOT/'output/defense-single-eight-opening-20261106-10cm'
sys.path.insert(0,str(ROOT/'research/defense-lambda5-regeneration-20261106'))
from audit import physics, effect, rail_sequences

def write(path, data):
    tmp=path.with_suffix('.tmp')
    tmp.write_bytes(data)
    tmp.replace(path)

def validate(record,q):
    assert record['question']==q and len(q['balls'])==1
    routes=record['routes']
    assert len(routes)<=2
    sequences=[]
    for route in routes:
        probes=route['probes']
        assert route['replayVerified'] and {(p['angleDelta'],p['speedScale']) for p in probes}=={(-.1,1),(.1,1),(0,.95),(0,1.05)} and len(probes)==4
        for a in [route,*probes]:
            physics(a['events'],a['finalPositions'],q,.028575)
            effect(a['effect'],8)
            assert a['effect']['score']>=80 and not a['effect']['fullDirectBlock']
            seq=rail_sequences(a['events'],'_8')
            for rails in seq.values():
                sides=[(0,0,1,1,2,3)[i] for i in rails]
                assert not any(x==z and x^1==y for x,y,z in zip(sides,sides[1:],sides[2:]))
        seq=rail_sequences(route['events'],'_8')
        assert seq==route['railSequences'] and seq not in sequences
        sequences.append(seq)
        for key,start in [('cueBall',q['cue']),('_8',q['balls'][0]['position'])]:
            frames=route['tracks'][key]; assert math.dist(frames[0][1:],start)<1e-5
            assert math.dist(frames[-1][1:],route['finalPositions'][key])<1e-5
    return len(routes)

def main():
    uid,binary=sys.argv[1:]
    digest=hashlib.sha256((OUT/'identity.json').read_bytes()).hexdigest()
    raw=Path(os.environ['QIUJI_TEST_WORK'])/'single-cases'
    raw.mkdir(exist_ok=True); store=OUT/'records';store.mkdir(exist_ok=True)
    with (OPENING/'candidates.csv').open(encoding='utf-8-sig') as f: rows=list(csv.DictReader(f))
    assert len(rows)==697 and all(r['category']=='hard' and float(r['difficulty'])>=75 for r in rows)
    questions=[]
    for r in rows:
        key='E'+hashlib.sha256(r['sourceID'].encode()).hexdigest()[:16]
        questions.append(dict(id=key,sampleID=key,sourceFormationID=r['sourceID'],kind='one',ownBallNumber=8,opponentBallNumber=8,
            cue=[float(r['cueX']),float(r['cueZ'])],balls=[dict(number=8,position=[float(r['eightX']),float(r['eightZ'])])],references=[]))
    assert len({q['id'] for q in questions})==len(questions)
    seeds = {}
    if DEEP:
        quickIdentity = hashlib.sha256((QUICK/'identity.json').read_bytes()).hexdigest()
        for q in questions:
            rec = json.loads(gzip.decompress((QUICK/'records'/(q['id']+'.json.gz')).read_bytes()))
            assert rec['identity'] == quickIdentity
            validate(rec,q)
            seeds[q['id']] = rec['routes']
        questions.sort(key=lambda q:len(seeds[q['id']]))
    def run(batch):
        file=raw/(batch[0]['id']+'-inputs.json')
        file.write_text(json.dumps(batch))
        cmd = ['xcrun','simctl','spawn',uid,binary,file,raw]
        if DEEP:
            seedFile = raw/(batch[0]['id']+'-seeds.json')
            seedFile.write_text(json.dumps({q['id']:seeds[q['id']] for q in batch}))
            cmd.append(seedFile)
        subprocess.run(cmd,check=True)
        scores={}
        for q in batch:
            src=raw/(q['id']+'.json');record=json.loads(src.read_bytes())
            scores[q['id']]=validate(record,q)
            if DEEP:
                assert scores[q['id']] >= len(seeds[q['id']])
            record['identity']=digest
            write(store/(q['id']+'.json.gz'),gzip.compress(json.dumps(record,separators=(',',':')).encode(),compresslevel=3,mtime=0))
            src.unlink()
        return scores
    def report(done):
        counts=collections.Counter(done.values())
        status=dict(total=len(questions),processed=len(done),multi=counts[2],single=counts[1],none=counts[0],admittedRoutes=counts[2]*2,identity=digest)
        write(OUT/'status.json',json.dumps(status).encode())
    done={}
    for q in questions:
        file=store/(q['id']+'.json.gz')
        if file.exists():
            rec=json.loads(gzip.decompress(file.read_bytes()))
            assert rec['identity']==digest
            done[q['id']]=validate(rec,q)
    pending=[q for q in questions if q['id'] not in done]
    report(done)
    subprocess.run(['xcrun','simctl','boot',uid],check=True)
    try:
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            size = 2 if DEEP else 8
            jobs=[pool.submit(run,pending[i:i+size]) for i in range(0,len(pending),size)]
            for job in concurrent.futures.as_completed(jobs):
                done.update(job.result());report(done)
    finally:
        subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
    assert len(done)==697
    write(OUT/'admitted.json',json.dumps([dict(id=q['id'],sourceID=q['sourceFormationID'],record='records/'+q['id']+'.json.gz') for q in questions if done[q['id']]==2],indent=2).encode())
if __name__=='__main__':main()
