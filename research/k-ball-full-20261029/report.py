"""Build a paginated research atlas from audited, physically verified selections."""
from pathlib import Path
import json,sqlite3,zlib
from scan import ROOT,OUT


def run():
    summary=json.loads((OUT/'summary.json').read_text())
    assert json.loads((OUT/'audit.json').read_text())['passed']
    db=sqlite3.connect(OUT/'atlas.sqlite')
    db.execute('CREATE TABLE questions(id TEXT PRIMARY KEY, route TEXT, layout TEXT, grade INTEGER, axis TEXT, rail INTEGER, pocket TEXT, data BLOB)')
    for line in (OUT/'selected.jsonl').open():
        s=json.loads(line);c=s['candidate'];seed=s['seed']
        db.execute('INSERT INTO questions VALUES(?,?,?,?,?,?,?,?)',(s['id'],s['routeKey'],seed['layout'],s['grade'],c['axis'],c['railOrdinal'],'middle' if seed['pocket']>=4 else 'corner',zlib.compress(line.encode(),1)))
    db.execute('CREATE INDEX question_filter ON questions(grade,axis,rail,pocket)');db.commit()
    assert db.execute('SELECT count(*) FROM questions').fetchone()[0]==summary['selected'];db.close()
    (OUT/'index.html').write_text(Path(__file__).with_name('page.html').read_text())
    scan=json.loads((OUT/'scan-audit.json').read_text());candidates=json.loads((OUT/'candidate-summary.json').read_text())
    report=f'''# K球全库生成结果

- 原库{scan['sourceLayouts']}球形；源角5–50°合格{scan['angleEligibleLayouts']}球形，核对{scan['counts']['matchedRoutes']}条保存轨迹。
- 自然路线及局部轨迹角≤45°筛出{scan['counts']['eligibleRoutes']}条路线，覆盖{scan['layoutsWithEligibleRoutes']}球形。
- {candidates['counts']['routes']}条路线产生{candidates['counts']['candidates']}个B备选位置；球心距观察库≤10cm。
- 真实事件与容错验证共{summary['counts']['simulations']}次；验证后{summary['validatedBeforeDedup']}题，去重后{summary['selected']}题。
- 最终覆盖{summary['retainedLayouts']}球形、{summary['retainedRoutes']}条路线；{summary['routesWithBoth']}条路线入/出各一题，{summary['routesWithOne']}条仅一题。
- 难度（模拟暂定）：{summary['grades']}。时机：{summary['byTiming']}。袋型：{summary['byPocket']}。
- 母球落袋仅记录：保留样本中{summary['selectedScratches']}题基线母球落袋，仍符合新判据。

成功条件：首碰A、A进指定袋、母球随后碰B；母球落袋和B碰后的效果不考核。容错沿用小/中/大档及8个单轴＋32个组合探针；必败档提前停止，高档不再算，已有1万组结果构造验证累计分级等价。找到常规及以上候选后停止该路线该时机的备选搜索，保留敏感作为兜底，不保证穷举到全局最优。

每条存档路线最多入库前一个、出库后一个，三个观察库各自筛选但不重复配额。缺项不补；有限随机候选未通过不代表物理上不可能。去重须同初始母球/A、目标袋、入出库时机、观察库、实际碰库序，且B及K前整段母球路径均相近（一个球直径内）。去重保留独立来源台账，不把替代题的B位置冒称为在被移除路线中验证过。

证据：scan-audit.json、candidate-summary.json、protocol.json、smoke-audit.json、focused-checks.json、audit.json、source-slots.json、duplicates.json；最终题集selected.jsonl，去重前验证集validated-before-dedup.jsonl，原始事件压缩于chunks/。保存的两球轨迹已复用，未重算原库；新增B及扰动使用当前生产物理。未接入App、未做实台难度标定。
'''
    (OUT/'REPORT.md').write_text(report)
    print('ATLAS READY',summary['selected'],flush=True)


if __name__=='__main__':run()
