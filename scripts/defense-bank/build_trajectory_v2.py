"""Package completed v9 searches. Each question is independently gzip compressed.
Offsets in the UTF-8 index are relative to the first payload byte.
"""
import argparse
import collections
import gzip
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SINGLE = ROOT / 'output/defense-single-eight-routes-20261106/deep'
MULTI = ROOT / 'output/defense-opening-routes-20261106/rollout-full-v2'
VERSION = 'defense-target-pipe-cut-lambda5-v9'


def read(path):
    return json.loads(path.read_bytes())


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def records():
    identity = hashlib.sha256((SINGLE / 'identity.json').read_bytes()).hexdigest()
    for row in read(SINGLE / 'admitted.json'):
        yield SINGLE / row['record'], row['id'], identity, None, 'single-deep'
    parts = read(MULTI / 'parts.json')
    def entry(path, key, origin):
        check = read(path.with_name(key + '.checkpoint.json'))
        assert check['identity'] == parts['identity'] and check['summary']['admitted'] and check['summary']['id'] == key
        return path, key, check['identity'], check['sha256'], origin
    for shard in parts['shards']:
        for row in read(MULTI / shard):
            yield entry(MULTI / row['record'], row['id'], shard.split('-')[0])
    for checkpoint in sorted((MULTI / 'deep-0008/records').glob('*.checkpoint.json')):
        row = read(checkpoint)['summary']
        if row['admitted']:
            yield entry(checkpoint.with_name(row['id']+'.json.gz'), row['id'], 'deep-partial')


def number(key):
    return 0 if key == 'cueBall' else int(key.removeprefix('_'))


def signature(events, own):
    return tuple(tuple(e['index'] for e in events if e['kind']=='cushion' and e['ball']==b)
                 for b in ('cueBall','_'+str(own)))


def convert(route, q):
    p, events, probes = route['shot'], route['events'], route['probes']
    own = q['ownBallNumber']
    rails = signature(events, own)
    effects = [route['effect']] + [v['effect'] for v in probes]
    assert route['replayVerified'] and len(probes)==4
    assert {(v['angleDelta'],v['speedScale']) for v in probes} == {(-0.1,1),(0.1,1),(0,0.95),(0,1.05)}
    assert tuple(map(tuple,(route['railSequences']['cue'],route['railSequences']['target']))) == rails
    assert all(e['scoringVersion']==VERSION and e['score']>=80 for e in effects)
    assert all(v.get('passes',True) and v.get('physicalVerified',True) for v in probes)
    assert set(route['finalPositions']) == {'cueBall',*('_'+str(b['number']) for b in q['balls'])}
    stable = sum(signature(v['events'],own)==rails for v in probes)
    estimates = sum(bool(e.get('estimateReason') or (e.get('pipeRoute') or {}).get('zeroWidthEstimate')) for e in effects)
    expected = []
    for e in events:
        item = dict(kind=e['kind'],timeSeconds=e['time'])
        if e['kind']=='cushion':
            assert 0<=e['index']<6
            item.update(ballNumbers=[number(e['ball'])],railIndex=e['index'])
        else:
            assert e['kind']=='ballBall' and 'cueBall' in e['balls']
            item.update(ballNumbers=list(map(number,e['balls'])))
        expected.append(item)
    result=dict(id=str(route['id']),parameters=dict(direction=p['direction'],velocity=p['speed'],spinX=p['spinX'],spinY=p['spinY']),
                quality=dict(estimatedCount=estimates,sameRails=stable,minimumScore=min(e['score'] for e in effects),
                             score=effects[0]['score']), expected=dict(events=expected,pocketedBallNumbers=[],
                finalBalls=[dict(number=number(k),position=v) for k,v in sorted(route['finalPositions'].items())]))
    return ((estimates,-stable,abs(p['spinX'])+abs(p['spinY']),p['speed'],sum(map(len,rails)),-result['quality']['minimumScore'],result['id']),rails,result)


def main():
    args=argparse.ArgumentParser()
    args.add_argument('--output',type=Path,required=True)
    args.add_argument('--reject',type=Path,help='JSON mapping of question IDs to failed route IDs after app replay')
    config=args.parse_args()
    rejected=read(config.reject) if config.reject else {}
    seen=set(); payload=bytearray(); rows=[]; totals=collections.Counter(); routes=collections.Counter()
    for path,key,identity,digest,origin in records():
        packed=path.read_bytes()
        assert not digest or hashlib.sha256(packed).hexdigest()==digest, path
        data=json.loads(gzip.decompress(packed)); r=data.get('record',data); q=r['question']
        assert key==q['id'] and key not in seen and r['identity']==identity
        seen.add(key)
        refs=sorted(convert(route,q) for route in (r['routes'] if 'routes' in r else r['result']['routes']))
        assert len(refs)>=2 and len({v[1] for v in refs})==len(refs)
        q['references']=[v[2] for v in refs if v[2]['id'] not in rejected.get(key,[])]
        if len(q['references'])<2: continue
        blob=gzip.compress(canonical(q),compresslevel=6,mtime=0)
        rows.append(dict(id=key,kind=q['kind'],offset=len(payload),size=len(blob)))
        payload.extend(blob)
        totals[origin,q['kind']]+=1; routes[origin,q['kind']]+=len(q['references'])
    assert len(seen)==8662
    index=canonical(rows)
    data=b'DFT2'+struct.pack('>I',len(index))+index+payload
    config.output.write_bytes(data)
    print(len(rows),sum(routes.values()),len(data),hashlib.sha256(data).hexdigest())
    for k in sorted(totals): print(*k,totals[k],routes[k])

if __name__=='__main__': main()
