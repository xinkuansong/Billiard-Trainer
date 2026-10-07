#!/usr/bin/env python3
"""Re-curate low-speed 2/3-cushion cases from existing native research records."""
import collections, hashlib, json, math, re, sqlite3, sys
from pathlib import Path
import cue_scratch_research as runner
from run_cue_scratch_session import family, job
from audit_cue_scratch import audit
from report_cue_scratch import svg
import dedup_cue_scratch_manual500 as dedup

RAW = runner.OUT
DEST = runner.ROOT / 'output/cue-scratch-research-20261004/manual-23-20261006'
OLD = DEST.parent / 'manual-500'
BATCH = 'verify-low-speed-23-20261006'
LIMIT = 100

def write(name, data):
    runner.write(DEST / name, data)

def distance(x):
    return math.dist(x['cue'], x['object'])

def prepare():
    assert not (DEST / 'pool.json').exists(), 'Preserve existing preparation'
    groups = collections.defaultdict(list)
    counts = collections.Counter()
    db = sqlite3.connect(f'file:{RAW}/results.sqlite?mode=ro', uri=True)
    for raw, in db.execute('SELECT raw FROM trials WHERE hit=1 AND rails IN (2,3) AND speed<=4.5 ORDER BY id'):
        x = json.loads(raw)
        if distance(x) < .6:
            continue
        counts[len(x['rails'])] += 1
        groups[(tuple(x['cue']), tuple(x['object']), family(x))].append(x)
    db.close()
    pool = []
    for key, g in sorted(groups.items()):
        # Only permitted speeds participate in representative selection.
        speeds = sorted({x['speed'] for x in g})
        mid = speeds[len(speeds)//2]
        x = min(g, key=lambda x: (abs(x['speed']-mid), x['id']))
        pool.append(x)
    write('pool.json', pool)
    write('selection.json', dict(rawEligibleRecords=dict(counts), uniquePositionRoutes=dict(collections.Counter(len(x['rails']) for x in pool)), minDistanceM=.6, maxSpeed=4.5, requestedPerRail=LIMIT, sourceDatabase=str(RAW/'results.sqlite')))
    jobs = []
    for i, x in enumerate(pool):
        jobs += [job(x, f'low23-{i}-full', mode='full'), job(x, f'low23-{i}-fixed', mode='fixed', offset=x['offset'])]
        for percent in [-5, -2, 2, 5]:
            speed = x['speed']*(1+percent/100)
            if .5 <= speed <= 4.5:
                jobs.append(job(x, f'low23-{i}-speed-{percent}', mode='fixed', speed=speed, offset=x['offset']))
    request = dict(batch=BATCH, workers=12, seconds=600, start=0, count=len(jobs), mode='verify', jobs=jobs)
    runner.write(RAW/f'{BATCH}-request.json', request)
    print('Prepared', len(pool), 'candidates;', len(jobs), 'native replay jobs', flush=True)

def finish():
    pool = json.loads((DEST/'pool.json').read_text())
    request = json.loads((RAW/f'{BATCH}-request.json').read_text())
    execution = json.loads((RAW/f'{BATCH}-execution.json').read_text())
    assert execution['executed']
    rows = [json.loads(s) for s in (RAW/f'{BATCH}.jsonl').open()]
    byid = {x['id']: x for x in rows}
    assert len(byid) == len(rows) == len(request['jobs'])
    assert set(byid) == {x['id'] for x in request['jobs']}
    independent = audit([RAW/f'{BATCH}.jsonl'])
    assert independent['passed']
    valid, rejected = [], []
    fields = ['pocket', 'cuePocket', 'rails', 'contacts', 'preRails', 'cueJaws', 'objectJaws', 'objectRails']
    for i, x in enumerate(pool):
        a, b = byid[f'low23-{i}-full'], byid[f'low23-{i}-fixed']
        if not (a.get('hit') and b.get('hit') and all(a.get(k)==b.get(k)==x.get(k) for k in fields) and math.dist(a['aim'], b['aim'])<1e-6 and abs(a['offset']-b['offset'])<1e-6):
            rejected.append(dict(source=x['id'], index=i, reason='outcome-or-aim-mismatch'))
            continue
        checks = [byid[f'low23-{i}-speed-{p}'] for p in [-5,-2,2,5] if f'low23-{i}-speed-{p}' in byid]
        a.update(sourceID=x['id'], distanceM=distance(a), cueAccess='not-validated', galleryID=f'P{i+1:04}', speedChecks=dict(tested=len(checks), sameRoute=sum(bool(v.get('hit') and family(v)==family(a)) for v in checks), points=[dict(speed=v['speed'],sameRoute=bool(v.get('hit') and family(v)==family(a))) for v in checks]))
        valid.append(a)
    write('cases.json', valid)
    write('cards.json', [])
    dedup.DEST = DEST
    dedup.main()
    candidates = json.loads((DEST/'deduplicated-cases.json').read_text())
    # Mirror-invariant route buckets, using the same engine geometry as clustering.
    geo = json.loads((RAW/'geometry.json').read_text())
    pockets = {int(p['id'].split('_')[-1]): p['center'] for p in geo['pockets']}
    rails = {r['id']: [(a+b)/2 for a,b in zip(r['a'],r['b'])] for r in geo['rails'] if r['id']<6}
    maps = []
    for s in dedup.TRANSFORMS:
        pm, rm = [{i:min(pos,key=lambda j:math.dist(dedup.transform(p,s),pos[j])) for i,p in pos.items()} for pos in (pockets,rails)]
        maps.append((pm,rm))
    def route(x):
        return min((pm[x['pocket']],pm[int(x['cuePocket'].split('_')[-1])],tuple(rm[r] for r in x['rails'])) for pm,rm in maps)
    selected = []
    for n in [2,3]:
        remaining = [x for x in candidates if len(x['rails'])==n]
        used_route, used_band, used_angle, used_speed = [collections.Counter() for _ in range(4)]
        def features(x):
            return route(x), 0 if distance(x)<.9 else 1 if distance(x)<1.2 else 2, int(x['cut']//15), round(x['speed'],1)
        def rank(x):
            r,b,a,s = features(x)
            return (used_route[r], used_band[b], used_angle[a], used_speed[s], -x.get('cueClearance',0), hashlib.sha256(x['sourceID'].encode()).hexdigest())
        for _ in range(min(LIMIT,len(remaining))):
            x = min(remaining,key=rank); remaining.remove(x); selected.append(x)
            for counter, value in zip((used_route,used_band,used_angle,used_speed),features(x)):
                counter[value] += 1
    mapping = []
    for n in [2,3]:
        for i,x in enumerate([x for x in selected if len(x['rails'])==n],1):
            mapping.append(dict(id=f'K{n}-{i:03}',poolID=x['galleryID'],source=x['sourceID']))
            x['poolID']=x['galleryID'];x['galleryID']=f'K{n}-{i:03}'
    write('active-cases.json', selected)
    write('id-map.json', mapping)
    write('verification.json', dict(execution=execution,audit=independent,rejected=rejected,verified=len(valid),jobCount=len(rows),sourceHashes=json.loads((RAW/'compiled.json').read_text())['sources']))
    summary = dict(selection=json.loads((DEST/'selection.json').read_text()),verifiedByRail=dict(collections.Counter(len(x['rails']) for x in valid)),deduplicatedByRail=dict(collections.Counter(len(x['rails']) for x in candidates)),displayedByRail=dict(collections.Counter(len(x['rails']) for x in selected)),displayed=len(selected),rejected=len(rejected),speedRange=[min(x['speed'] for x in selected),max(x['speed'] for x in selected)],distanceRangeCm=[min(distance(x) for x in selected)*100,max(distance(x) for x in selected)*100],routeFamiliesByRail={n:len({route(x) for x in selected if len(x['rails'])==n}) for n in [2,3]},cueAccess='not-validated',expandedSearch=False)
    write('summary.json',summary)
    render()
    print(json.dumps(summary,ensure_ascii=False),flush=True)

def render():
    cases = json.loads((DEST/'active-cases.json').read_text())
    geo = json.loads((RAW/'geometry.json').read_text())
    cards=[]
    for x in cases:
        (DEST/f'{x["galleryID"]}.svg').write_text(svg(x,geo))
        cards.append(dict(id=x['galleryID'],rails=len(x['rails']),distance=distance(x)*100,cut=x['cut'],speed=x['speed'],target=x['pocket'],scratch=int(x['cuePocket'].split('_')[-1]),old='',archive=False,speedChecks=x['speedChecks'],cue=x['cue'],object=x['object'],source=x['sourceID']))
    write('cards.json',cards)
    oldpage=(OLD/'index.html').read_text()
    style=re.search(r'<style>.*?</style>',oldpage,re.S).group()
    controls=re.search(r'<section class="selection">.*?<section id="results">',oldpage,re.S).group()
    controls=re.sub(r'<select id="scope">.*?</select>','<select id="scope"><option value="main">全部候选</option><option value="selected">仅看已选</option></select>',controls,flags=re.S)
    controls=controls.replace('<option value="0">0库</option>','').replace('<option value="1">1库</option>','').replace('例如 M001 / R001','例如 K2-001 / K3-001')
    results=re.search(r'<section id="results">(.*?)</section>',oldpage,re.S).group(1)
    dialog=re.search(r'<dialog .*?</dialog>',oldpage,re.S).group()
    counts=collections.Counter(x['rails'] for x in cards)
    page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>两库、三库掉袋 · 重新筛选</title>'+style+'<main>'
    page+=f'<header><h1>母球掉袋 · 两库 / 三库</h1><p>两库 {counts[2]}例 · 三库 {counts[3]}例</p><b>杆速 ≤4.5 m/s · 球心距 ≥60厘米 · 对称 / 相似去重</b><p>从原始候选池重新筛选，每例通过生产完整求解及固定瞄准复验。</p></header>'
    page+='<p>白线＝母球，黄线＝目标球，橙色数字＝碰库顺序，红圈＝母球进袋。点击图片放大，勾选后导出清单。</p><p class="notes">中杆无塞；目标球直接进入引擎推荐袋。按库序、袋口、球距和角度分组选取，不按杆速微扰稳定性排名。切角为推荐几何角，实际碰撞角在制作时另测。实体出杆空间尚未验证。</p>'
    page+=controls+results+'</section>'+dialog+'<footer><p><a href="active-cases.json">完整轨迹与参数</a> · <a href="summary.json">筛选统计</a> · <a href="REPORT.md">筛选说明</a> · <a href="../manual-500/index.html">原始选择页面</a></p></footer>'
    page+='<script id="case-data" type="application/json">'+json.dumps(cards,ensure_ascii=False).replace('</','<\\/')+'</script><script src="app.js"></script></main></html>'
    (DEST/'index.html').write_text(page)
    js=(OLD/'app.js').read_text().replace('V023-manual500-r8','V023-low23-20261006')
    js=js.replace(' · 切角 ${x.cut.toFixed(1)}°',' · 推荐切角 ${x.cut.toFixed(1)}°')
    (DEST/'app.js').write_text(js)

if __name__=='__main__':
    {'prepare':prepare,'finish':finish,'render':render}[sys.argv[1]]()
