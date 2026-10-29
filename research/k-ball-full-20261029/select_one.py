"""Select one unchanged, previously validated B placement per archived route."""
import collections
import hashlib
import json
from pathlib import Path
import shutil
import sqlite3
import zlib

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'output/k-ball-full-20261029'
OUT=ROOT/'output/k-ball-one-per-route-20261029'


def rank(s):
    # Offset is a proposal's saved corridor offset, not measured physical tolerance.
    return (-s['grade'],abs(s['candidate']['corridorOffset']),s['id'])


def run():
    assert json.loads((SOURCE/'audit.json').read_text())['passed']
    OUT.mkdir(exist_ok=False)
    winners={};options=collections.defaultdict(list);source_hash=hashlib.sha256()
    for raw in (SOURCE/'selected.jsonl').open('rb'):
        source_hash.update(raw);s=json.loads(raw);route=s['routeKey']
        options[route].append(dict(id=s['id'],grade=s['grade'],axis=s['candidate']['axis'],rank=rank(s)))
        if route not in winners or rank(s)<winners[route]['rank']:
            winners[route]=dict(id=s['id'],rank=rank(s))
    db=sqlite3.connect(OUT/'atlas.sqlite')
    db.execute('CREATE TABLE questions(id TEXT PRIMARY KEY, route TEXT UNIQUE, layout TEXT, grade INTEGER, axis TEXT, rail INTEGER, pocket TEXT, data BLOB)')
    timing=collections.Counter();grades=collections.Counter();rails=collections.Counter();pockets=collections.Counter();layouts=set();scratches=0;out_hash=hashlib.sha256();read_hash=hashlib.sha256()
    with (OUT/'selected.jsonl').open('wb') as f:
        for raw in (SOURCE/'selected.jsonl').open('rb'):
            read_hash.update(raw);s=json.loads(raw)
            if s['id']!=winners[s['routeKey']]['id']:continue
            assert s['baseline']['success'] and s['exactReplay'] and s['grade']>=1
            assert rank(s)==min(tuple(x['rank']) for x in options[s['routeKey']])
            f.write(raw);out_hash.update(raw);c=s['candidate'];seed=s['seed']
            pocket='middle' if seed['pocket']>=4 else 'corner'
            db.execute('INSERT INTO questions VALUES(?,?,?,?,?,?,?,?)',(s['id'],s['routeKey'],seed['layout'],s['grade'],c['axis'],c['railOrdinal'],pocket,zlib.compress(raw,1)))
            timing[c['axis']]+=1;grades[['','敏感','常规','宽容'][s['grade']]]+=1;rails[c['railOrdinal']]+=1;pockets[pocket]+=1;layouts.add(seed['layout']);scratches+=s['baseline']['scratch']
    assert read_hash.digest()==source_hash.digest()
    count=db.execute('SELECT count(*) FROM questions').fetchone()[0]
    assert count==len(winners)==11458
    db.execute('CREATE INDEX question_filter ON questions(grade,axis,rail,pocket)');db.commit();db.close()
    summary=dict(complete=True,selected=count,retainedRoutes=count,retainedLayouts=len(layouts),byTiming=dict(timing),grades=dict(grades),byObservedRail=dict(rails),byPocket=dict(pockets),selectedScratches=scratches,sourceQuestions=sum(map(len,options.values())),removed=sum(map(len,options.values()))-count,newSimulations=0)
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    (OUT/'selection-ledger.json').write_text(json.dumps({k:dict(selected=v['id'],candidates=options[k]) for k,v in winners.items()},ensure_ascii=False))
    (OUT/'audit.json').write_text(json.dumps(dict(passed=True,source=str(SOURCE/'selected.jsonl'),sourceSHA256=source_hash.hexdigest(),selectedSHA256=out_hash.hexdigest(),exactUnmodifiedSubset=True,onePerRoute=True,allSourceRoutesPreserved=True,ranking='grade descending; absolute saved corridorOffset ascending; id ascending',inheritedPhysicsAudit=str(SOURCE/'audit.json'),newSimulations=0),indent=2))
    shutil.copyfile(SOURCE/'geometry.json',OUT/'geometry.json')
    page=Path(__file__).with_name('page.html').read_text()
    page=page.replace('每条轨迹，入库前与出库后各留一个','每条轨迹，只留一个B球位置')
    page=page.replace('缺少合格候选如实缺项，不用另一类补足。','入库前、出库后合并择一，优先容错等级；同档优先更靠近候选管道中心线的位置。')
    page=page.replace('查看这条路线的入／出库题','查看这条路线的保留题')
    page=page.replace('${s.routesWithBoth} 条路线入/出各一题，${s.routesWithOne} 条路线仅保留一题。','每条路线恰好保留一题，较上一版减少 ${s.removed} 题。')
    (OUT/'index.html').write_text(page)
    (OUT/'REPORT.md').write_text(f'''# K球：每条轨迹一题

从上一版已物理验证并去重的15351题中，按原球形ID＋存档路线ID分组，入库前／出库后合并择一。保留{count}题，覆盖{len(layouts)}球形；移除3893个同路线备选。全部来源路线仍覆盖。

选择顺序：模拟容错等级更高优先；同档时已存候选管道偏移绝对值较小优先；再同分按稳定ID。管道偏移仅是几何候选生成记录，不是实测碰撞余量或额外容错保证。不因入库前／出库后身份设置偏好。

题目坐标、杆法、完整轨迹、事件和既有容错等级逐字节保留，不跑新物理。原库角5–50°、轨迹角≤45°、B球心距库≤10cm及进A/碰B成功判据保持。母球落袋与碰B后的效果不考核。

时机：{dict(timing)}。难度：{dict(grades)}。难度是模拟分级，未实台标定。

完整选择台账selection-ledger.json，子集及来源SHA审计audit.json。旧图册8859与原证据保留；本版图册8860，尚未接入App。
''')
    print(json.dumps(summary,ensure_ascii=False))


if __name__=='__main__':run()
