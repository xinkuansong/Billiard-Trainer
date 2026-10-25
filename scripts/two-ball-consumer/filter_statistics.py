#!/usr/bin/env python3
"""Count bundled questions/recommendations using the two-ball settings predicates.
No physics replay, sampling, mutation or new admission decisions.
"""
import argparse
import gzip
import hashlib
import itertools
import json
import math
import struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AXES = {
    'angle': ['近直球 0–10°', '小角度 11–30°', '中角度 31–50°', '大角度 51–70°', '极薄球 71–85°'],
    'cue': ['短 0.30–0.60m', '中 >0.60–1.20m', '长 >1.20–1.80m'],
    'pocketDistance': ['短 0.25–0.60m', '中 >0.60–1.20m', '长 >1.20–1.80m'],
    'pocket': ['角袋', '中袋'],
    'rail': ['离库 >10cm（补充分类）', '半贴库 0–10cm（不含贴库）', '贴库'],
    'spin': ['中杆：两项关闭', '仅允许高低杆', '仅允许左右塞', '高低杆、左右塞均允许'],
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def f(x):
    return struct.unpack('f', struct.pack('f', x))[0]

def gap(point, geometry):
    """Float arithmetic and finite segment clamp from SceneTrainingRailGeometry."""
    x, z = f(point['x']), f(point['z'])
    values = []
    for rail in geometry['lines'][:6]:
        a, b = rail['start'], rail['end']
        dx, dz = f(b['x']-a['x']), f(b['z']-a['z'])
        length2 = f(f(dx*dx)+f(dz*dz))
        t = f(f(f(f(x-a['x'])*dx)+f(f(z-a['z'])*dz))/length2)
        t = max(0, min(1, t))
        px, pz = f(a['x']+f(dx*t)), f(a['z']+f(dz*t))
        values.append(f(f(math.hypot(f(x-px), f(z-pz)))-f(geometry['radius'])))
    return min(values)

def run(dest):
    bank = ROOT/'QiuJi/Resources/TwoBallBank'
    raw = (bank/'index.json').read_bytes()
    index = json.loads(raw)
    gridraw = (ROOT/'QiuJi/Resources/training-grid-bank.json').read_bytes()
    grid = json.loads(gridraw)
    lookup = {t['inventoryTargetIndex']: t for t in grid['targets']}
    entries = {e['id']: (e['shard'], e['line']) for e in index['layouts']}
    counts = defaultdict(lambda: [0, 0, 0])
    seen = set()
    total_routes = 0
    tolerance = 4*2**-23
    for shard in index['shards']:
        data = (bank/(shard['name']+'.jsonl.gz')).read_bytes()
        assert len(data) == shard['bytes'] and sha(data) == shard['sha256']
        for line, rawrow in enumerate(gzip.decompress(data).splitlines()):
            row = json.loads(rawrow)
            identity = row['id']
            assert identity not in seen and entries[identity] == (shard['name'], line)
            seen.add(identity)
            _, ti, mi, bit = identity.split(':')
            ti, mi, bit = int(ti), int(mi), int(bit)
            target = lookup[ti]
            assert target['masks'][mi] & (1 << bit)
            ordinal = sum(m.bit_count() for m in target['masks'][:mi]) + (target['masks'][mi] & ((1 << bit)-1)).bit_count()
            cell = grid['combinationTable'][target['combinationIndices'][ordinal]]
            angle = abs(mi-85)
            ai = next(i for i, limit in enumerate([10,30,50,70,85]) if angle <= limit)
            clearance = gap(target['object'], grid['geometry'])
            assert math.isfinite(clearance) and clearance >= -tolerance
            ri = 2 if abs(clearance) <= tolerance else 1 if clearance <= f(f(.10)+tolerance) else 0
            assert cell['angleIndex'] == ai and cell['railIndex'] == ri
            assert cell['pocketType'] == (0 if target['pocket'] < 4 else 1)
            key = (ai,cell['cueIndex'],cell['objectIndex'],cell['pocketType'],ri)
            routes = {r['id']: r for r in row['routes']}
            total_routes += len(routes)
            assert len(routes) == len(row['routes'])
            assert len({q['id'] for q in row['questions']}) == len(row['questions'])
            for spin in range(4):
                qcount = rcount = 0
                for q in row['questions']:
                    # Python `or` returns an operand; make each term explicitly boolean.
                    n = sum(bool((spin & 1 or routes[r]['sy'] == 0) and (spin & 2 or routes[r]['sx'] == 0)) for r,p in q['refs'])
                    qcount += n > 0
                    rcount += n
                c = counts[key+(spin,)]
                c[0] += qcount > 0
                c[1] += qcount
                c[2] += rcount
    cells = [dict(zip(AXES, key), layouts=counts[key][0], questions=counts[key][1], recommendations=counts[key][2])
             for key in itertools.product(range(5),range(3),range(3),range(2),range(3),range(4))]
    totals = {key:sum(c[key] for c in cells if c['spin']==3) for key in ['layouts','questions','recommendations']}
    assert totals == {k:index['counts'][k] for k in totals}
    assert total_routes == index['counts']['routes'] and seen == set(entries)
    report = dict(schema='two-ball-filter-statistics-v1',indexSHA256=sha(raw),gridSHA256=sha(gridraw),
                  counts=index['counts'],axes=AXES,cells=cells,auditPassed=True,
                  scope='Bundled inventory after settings filters; not a full runtime physics replay.')
    dest.mkdir(parents=True, exist_ok=True)
    (dest/'statistics.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    text = ['# 两球走位练习：筛选条件统计','',
            '统计对象：当前 App 参数题库。题以「首杆布局ID + 第二球ID」去重；推荐数按每题引用计，同一参数被不同题使用会分别计数。',
            '所有几何条件均针对首杆。球距和袋距沿用共享题库分类；角度沿用 App 的生成角分类，不改用重算的实际切角。',
            '离库距离使用第一颗目标球表面到6段有限主库的最近距离；随机包含离库、半贴库、贴库。',
            '杆法关闭时严格要求对应参数等于0；开启表示允许，仍包含中杆。模式、2D/3D共用题库。',
            '这是库存筛选统计；运行时仍逐题重放验证，不代表本轮全量物理重放通过。','',
            f"总计 **{totals['questions']:,}题 / {totals['recommendations']:,}条推荐 / {totals['layouts']:,}首杆布局**。",'']
    titles = ['首杆切角', '母球到第一颗目标球', '第一颗目标球到袋口', '第一颗目标球的袋口', '第一颗目标球离库', '出题杆法']
    for (axis, labels), title in zip(AXES.items(), titles):
        text += [f'## {title}', '', '| 条件 | 首杆布局 | 题数 | 推荐路线数 |','|---|---:|---:|---:|']
        for v, label in enumerate(labels):
            rows = [c for c in cells if c[axis]==v and (axis=='spin' or c['spin']==3)]
            sums = [sum(c[k] for c in rows) for k in ['layouts','questions','recommendations']]
            text.append('| '+label+' | '+' | '.join(f'{n:,}' for n in sums)+' |')
        text += ['']
    text += ['除杆法表外，每张表均为其他条件随机、两项杆法均允许；不同维度不能相加。',
             '完整1080个互斥几何分类×杆法权限组合（含空组合）见 statistics.json；同一题可能出现在多种杆法权限下。',
             f"\nIndex SHA-256: `{sha(raw)}`\n"]
    (dest/'README.md').write_text('\n'.join(text))
    template = Path(__file__).with_name('filter_statistics.html').read_text()
    (dest/'index.html').write_text(template.replace('__STATISTICS__', json.dumps(report, ensure_ascii=False)))
    print('\n'.join(text))

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT/'output/two-ball-filter-statistics-20261026')
    run(parser.parse_args().output)
