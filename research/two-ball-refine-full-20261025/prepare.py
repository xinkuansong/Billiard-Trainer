from pathlib import Path
import json,time,hashlib
import core as C
ROOT=C.ROOT;HERE=Path(__file__).resolve().parent;OUT=C.OUT
if (OUT/'manifest.json').exists():raise SystemExit('Already prepared; do not replace frozen contract')
for name in ('final','refinement','receipts','logs','tmp','failures','sessions'): (OUT/name).mkdir(parents=True,exist_ok=True)
base=ROOT/'output/two-ball-p2-60-top5-full-20261025'
for name in ('two-ball-p2-60-top5-full-20261025','two-ball-independent125-full-20261024'):
 s=C.read(ROOT/'output'/name/'summary.json');assert s['state']=='complete' and s['auditPassed']
assert C.read(OUT/'parity.json')['passed']
index=C.read(base/'parts-index.json');assert sum(r['layouts'] for r in index)==13570 and sum(r['candidates'] for r in index)==173577
jobs=[dict(stem=Path(r['part']).name.split('.')[0],source=r['source'],baselineSHA256=r['sha256'],layouts=r['layouts']) for r in index]
assert len({r['stem'] for r in jobs})==len(jobs)
pilotstems={Path(b['simulationSource']['part']).name.split('.')[0] for b in C.D['boards']}
jobs.sort(key=lambda j:(j['stem'] not in pilotstems,j['stem']))
C.write(OUT/'schedule.json',jobs)
files=list(HERE.glob('*.py'))+list(HERE.glob('*.swift'))+[HERE/'dedup',OUT/'parity.json',OUT/'schedule.json',base/'parts-index.json',base/'summary.json',ROOT/'output/two-ball-block-sampled-13570-20261025/simulation-index.json',ROOT/'output/two-ball-top5-random-five-20261025/data.json']
files += [ROOT/'research/two-ball-independent125-full-20261024'/p for p in ('runtime_common.py','contract.py','Worker.app/Worker')]
files += [ROOT/'scripts/training-question-bank'/p for p in ('pocket_geometry_filter.py','filter_second_ball_preview.py')]
files += [ROOT/f'output/two-ball-refine-five-20261025/result-{i}.json' for i in range(1,6)]
manifest={'state':'prepared','createdAt':time.time(),'layouts':13570,'BPositions':173577,'workers':16,'parts':len(jobs),'policy':C.POLICY,'P2':'arc1cm-rms-p2-t20-potgate-v3','hashes':{str(p.relative_to(ROOT)):C.sha(p) for p in files},'source':'audited independent125 successful rows; selected13570 with nonempty2x2 B sampling','completion':'summary.state=complete and auditPassed=true; all 13570 unique layout IDs and 173577 B positions audited; process and final SHA checked'}
C.write(OUT/'manifest.json',manifest)
(OUT/'README.md').write_text('''# 两球25°微调全量（准备中，不能作为完整题库）

13,570初始球形，173,577第二球候选位置，16原生计算进程。只有 summary.json 的 state=complete 且 auditPassed=true 后才可切换为全量结果。

## 功能接入

读取 manifest.json、parts-index.json，再流式解压 final/*.jsonl.gz，每行一个初始球形。每个 candidates 元素是一道“初始球形 + 第二球位置”的题目；不要把同一行所有第二球同时摆上桌。题目键建议 id + cellID。board 是初始母球、第一目标球、目标袋口及下球点；candidates[].position 为第二球位置。

candidates[].top5 为推荐路线与第二杆目标袋口、切角 angle、距离 distance、难度 score。通过 comboIndex 关联同一行 routes[]，取得杆速 velocity、打点 spinX/spinY、strikeDirection、母球落点 cueStop、吃库计数、trajectory2mm。comboIndex 只在同一初始球形内唯一，新微调组合从10000开始。

trajectory2mm.points 为 [首碰后相对时间秒, 世界X米, 世界Z米]。世界Y向上；横桌X右Z下。它是碰第一球之后的母球近似轨迹；完整回放仍需模拟器与实际参数，不应把折线当作完整三球物理。board 和下球点采用题库原坐标定义，详 manifest 的 policy。

top5 可为空或不足5条。优先展示非空题目，不能强补缺失路线。routes 在同一初始球形下共享。第二球来自已筛选候选：不挡第一杆管道，初始母球直接打第二球的最优几何难度不低于第一球；不等于已经模拟验证第二球入袋。

## 规则与保存

无库的侧塞归零后重新模拟；剔除母球袋角/liner等非主库接触；2mm关键点检查途中碰第二球；有限速度/杆法微调，保持主库序列，第二杆切角≤25°；按第二杆几何难度排序，P2≥60合并，最多取5。每B最多8种子，失败不重试方向，具体数值在manifest.policy。不包含首杆执行难度惩罚，也不是完整三球重放或第二杆入袋验证。

final/ 只保存最终题目及共享推荐路线；refinement/ 独立gzip保留所有新增模拟（含失败）、参数请求、候选评分和微调判定。receipts/ 是分片提交标记，含两类文件SHA。旧结果与源数据均保留。过程文件用于研究追溯，App只需消费final。

当前可用旧全量：../two-ball-p2-60-top5-full-20261025/，该旧版没有本轮25°/无库去塞/袋角新规则。已验证新版小样：../two-ball-refine-five-20261025/。
''')
print('PREPARED',len(jobs),'parts',13570,'layouts',173577,'B')
