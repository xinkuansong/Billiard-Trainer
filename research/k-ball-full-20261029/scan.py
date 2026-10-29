"""Stream the full archived bank; reuse paths without running physics.

World XZ meters. Generation angle and local rail angle are separate.
Outputs are candidates, never a physical-solvability claim.
"""
from pathlib import Path
import collections
import gzip
import hashlib
import json
import math
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/k-ball-full-20261029'
OLD = ROOT / 'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'
NOW = ROOT / 'QiuJi/Resources/TwoBallBank'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def rail_angle(v, t, n):
    return math.degrees(math.atan2(abs(sum(x*y for x,y in zip(v,n))), abs(sum(x*y for x,y in zip(v,t)))))


def scan():
    OUT.mkdir(exist_ok=True)
    dbpath = OUT / 'pool.sqlite'
    if dbpath.exists():
        raise RuntimeError('Existing scan retained; use a new output or resume downstream.')
    old = json.loads((OLD/'index.json').read_text())
    now = json.loads((NOW/'index.json').read_text())
    geo = json.loads((ROOT/'output/k-ball-tolerance-20261029/geometry.json').read_text())
    assert old['geometry'] == now['geometry']
    assert all(old['geometry'][k] == geo[k] for k in ('length','width','radius'))
    (OUT/'geometry.json').write_text(json.dumps(geo))
    oldhash = {s['name']:s['sha256'] for s in old['shards']}
    newhash = {s['name']:s['sha256'] for s in now['shards']}
    eligible = {x['id'] for x in old['layouts'] if 5 <= x['board']['angle'] <= 50}
    shards = sorted({x['shard'] for x in old['layouts'] if x['id'] in eligible})
    db = sqlite3.connect(dbpath)
    db.executescript('''
      CREATE TABLE routes(key TEXT PRIMARY KEY, layout TEXT, data TEXT);
      CREATE TABLE regions(key TEXT PRIMARY KEY, route TEXT, data TEXT);
      CREATE TABLE scanned(shard TEXT PRIMARY KEY, oldSHA TEXT, currentSHA TEXT);
    ''')
    counts = collections.Counter(); rejects = collections.Counter(); bygroup = collections.Counter()
    seen = set(); layouts_with_routes = set()
    hx,hz,radius = geo['length']/2,geo['width']/2,geo['radius']
    # Preserve established natural-route pocket-distance reference points.
    corners = [[-hx,-hz],[hx,-hz],[-hx,hz],[hx,hz],[0,-hz],[0,hz]]
    for sn, shard in enumerate(shards):
        op,np = OLD/(shard+'.jsonl.gz'), NOW/(shard+'.jsonl.gz')
        oh,nh = sha(op),sha(np)
        assert oh == oldhash[shard] and nh == newhash[shard], shard
        current = {d['id']:d for d in map(json.loads,gzip.open(np,'rt'))}
        for d in map(json.loads,gzip.open(op,'rt')):
            if d['id'] not in eligible:
                continue
            seen.add(d['id']); cur = current[d['id']]
            assert cur['board'] == d['board']
            routes = {z['id']:z for z in cur['routes']}
            for route in d['routes']:
                counts['archivedRoutes'] += 1
                if route['comboIndex'] not in routes:
                    rejects['notInCurrentBank'] += 1; continue
                z = routes[route['comboIndex']]
                assert [route['velocity'],route['spinX'],route['spinY'],route['strikeDirection']] == [z['v'],z['sx'],z['sy'],z['dir']]
                tr = route['trajectory2mm']; cs = tr['cushions']; pts = [p[1:] for p in tr['points']]
                assert [c['cushionID'] for c in cs] == z['rails']
                assert tr['timeOrigin'] == 'firstTargetContact' and tr['maxDeviationMeters'] <= .002
                counts['matchedRoutes'] += 1
                fail = [name for name,ok in [('velocity',route['velocity']<=3),('sideSpin',abs(route['spinX'])<=.15),('verticalSpin',abs(route['spinY'])<=.5)] if not ok]
                if fail:
                    rejects.update(fail); continue
                counts['naturalInputRoutes'] += 1
                cumulative = [0.0]
                for a,b in zip(pts,pts[1:]): cumulative.append(cumulative[-1]+math.dist(a,b))
                routekey = f"{d['id']}/{route['comboIndex']}"
                accepted = []
                for j,c in enumerate(cs[:3]):
                    counts['observedRails'] += 1
                    i = c['pointIndex']; rid = c['cushionID']
                    if rid not in range(6) or i == 0 or i == len(pts)-1:
                        rejects['unmeasurableRail'] += 1; continue
                    rail = geo['rails'][rid]; n = rail['normal']; a,b = rail['start'],rail['end']
                    t = [(b[k]-a[k])/math.dist(a,b) for k in (0,1)]
                    before,hit,after = pts[i-1:i+2]
                    vin = [hit[k]-before[k] for k in (0,1)]; vout = [after[k]-hit[k] for k in (0,1)]
                    adj = [math.dist(before,hit),math.dist(hit,after)]
                    if min(adj)<=1e-8 or (j==0 and min(adj)<.06) or sum(vin[k]*n[k] for k in (0,1))>=0 or sum(vout[k]*n[k] for k in (0,1))<=0:
                        rejects['unresolvedAdjacentDirection'] += 1; continue
                    assert abs(sum((hit[k]-a[k])*n[k] for k in (0,1))-radius)<.001
                    lo = cs[j-1]['pointIndex'] if j else 0
                    hi = cs[j+1]['pointIndex'] if j+1<len(cs) else len(pts)-1
                    ix = [0]+[q['pointIndex'] for q in cs[:j+1]]
                    legs = [cumulative[y]-cumulative[x] for x,y in zip(ix,ix[1:])]
                    common = [('prefixLength',cumulative[i] <= (3.5 if j==2 else 2.5)),('shortIncomingLeg',legs[-1]>=.4),('shortPriorLeg',j==0 or min(legs[:-1])>=.4),('nearPriorPocket',j==0 or min(math.dist(pts[k],p) for k in ix[1:-1] for p in corners)>=.18)]
                    for axis,v in [('inAngle',vin),('outAngle',vout)]:
                        checks = common+[('angle>45',rail_angle(v,t,n)<=45)]
                        if axis=='outAngle':
                            checks += [('shortOutgoingLeg',cumulative[hi]-cumulative[i]>=.4),('shortRemainder',cumulative[-1]-cumulative[i]>=.6)]
                        failures = [name for name,ok in checks if not ok]
                        if failures:
                            rejects.update('region:'+name for name in failures); continue
                        key = f'{routekey}/{j+1}/{axis}'
                        reg = dict(key=key,routeKey=routekey,axis=axis,railOrdinal=j+1,railID=rid,sourceAngle=rail_angle(v,t,n),lo=lo if axis=='inAngle' else i,hi=i if axis=='inAngle' else hi,expectedRails=j if axis=='inAngle' else j+1)
                        accepted.append(reg); bygroup[f'{j+1}-{axis}'] += 1
                if accepted:
                    counts['eligibleRoutes'] += 1; layouts_with_routes.add(d['id'])
                    seed = dict(layout=d['id'],route=route['comboIndex'],cue=d['board']['cue'],object=d['board']['object'],pocket=d['board']['pocket'],dir=route['strikeDirection'],v=route['velocity'],sx=route['spinX'],sy=route['spinY'])
                    payload = dict(key=routekey,seed=seed,board=d['board'],route=route)
                    db.execute('INSERT INTO routes VALUES(?,?,?)',(routekey,d['id'],json.dumps(payload)))
                    for reg in accepted: db.execute('INSERT INTO regions VALUES(?,?,?)',(reg['key'],routekey,json.dumps(reg)))
        db.execute('INSERT INTO scanned VALUES(?,?,?)',(shard,oh,nh)); db.commit()
        if sn%50==0 or sn==len(shards)-1:
            print('SCAN',sn+1,'/',len(shards),dict(counts),flush=True)
    assert seen == eligible
    summary = dict(complete=True,sourceLayouts=len(old['layouts']),angleEligibleLayouts=len(eligible),layoutsWithEligibleRoutes=len(layouts_with_routes),shards=len(shards),counts=dict(counts),regionsByGroup=dict(bygroup),rejections=dict(rejects),archiveIndexSHA256=sha(OLD/'index.json'),currentIndexSHA256=sha(NOW/'index.json'),scriptSHA256=sha(Path(__file__)),physicsRuns=0)
    db.close(); (OUT/'scan-audit.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2));print(json.dumps(summary,ensure_ascii=False),flush=True)


if __name__ == '__main__':
    assert rail_angle([1,0],[1,0],[0,1]) == 0
    assert rail_angle([0,1],[1,0],[0,1]) == 90
    assert abs(rail_angle([1,1],[1,0],[0,1])-45)<1e-12
    scan()
