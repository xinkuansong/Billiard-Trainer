"""Recompute all 95 B43 endpoint evaluations and rank finite scores."""
from pathlib import Path
import hashlib, json, math, sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/two-ball-second-difficulty-20261024'
sys.path.insert(0, str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry, pocket_metrics

source = OUT/'analysis.json'
raw = source.read_bytes()
data = json.loads(raw)
bank = json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())
g = Geometry(**{k:bank['geometry'][k] for k in ['length','width','radius']})
b = next(c['position'] for c in data['candidates'] if c['cellID']==43)
names = ['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
rows = []
for row in data['rows']:
    cue = row['cueStop']
    previous = next(e for e in row['evaluations'] if e['cellID']==43)
    separation = math.dist(cue,b)
    options = []
    if separation >= 2*g.radius-1e-12:
        for pid,p in enumerate(g.anchors()):
            m = pocket_metrics(cue,b,p,g.radius,pid)
            score = m.object_distance_metres/math.cos(math.radians(m.cut_degrees)) if m.cut_degrees<90 else None
            options.append(dict(pocket=pid,angle=m.cut_degrees,distance=m.object_distance_metres,score=score))
    best = min((m for m in options if m['score'] is not None),key=lambda m:(m['score'],m['pocket']),default=None)
    status = 'overlap' if separation<2*g.radius-1e-12 else ('available' if best else 'no_forward_pocket')
    assert status==previous['status'] and best==previous['best'] and options==previous['pockets']
    rows.append(dict(comboIndex=row['comboIndex'],trialID=row['trialID'],cueStop=cue,
        spinX=row['spinX'],spinY=row['spinY'],velocity=row['velocity'],
        firstShotMainRails=row['mainRails'],cueObjectDistance=separation,
        status=status,best=best,pockets=options))
rows.sort(key=lambda r:(r['best'] is None,r['best']['score'] if r['best'] else math.inf,r['comboIndex']))
finite = [r for r in rows if r['best']]
for i,row in enumerate(rows): row['rank']=i+1 if row['best'] else None
assert len(rows)==95 and len({r['comboIndex'] for r in rows})==95 and len(finite)==93
assert all(a['best']['score']<=b['best']['score'] for a,b in zip(finite,finite[1:]))
assert source.read_bytes()==raw
result=dict(layoutID=data['layoutID'],secondBallCellID=43,position=b,
    score='min over six generation anchors of OP/cos(cut); cut<90; lower is easier',
    unit='metres',rankTieBreak='comboIndex ascending',total=95,ranked=93,unavailable=2,
    sourceSHA256=hashlib.sha256(raw).hexdigest(),rows=rows,
    validation='All 95 recomputed; per-pocket metrics and unavailable reasons equal prior analysis; unique combinations and ascending full-precision scores checked')
(OUT/'b43-ranked.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
lines=['# B43：95个母球停点难度排序','',
    '球形 `grid-v3:1512:68:1`。B43固定位置为世界坐标 X=0.3254384003m，Z=0.0691810357m。',
    '', '95项全部复算：93项有可排序几何分数，2项与B43重叠，不可用，单列末尾。',
    '', 'S=目标球到生成下球点距离÷cos(切角)，每个停点重评六袋取最低值，越小越容易。按未舍入值升序，完全同分时按组合ID升序。母球到B43距离另列，不作为旧分数的独立权重。',
    '', '该排序是几何难度；未验证第二杆实际入袋或第一杆受B43干扰。吃库次数描述第一杆，不参与第二杆难度排序。',
    '', '| 排名 | 组合ID | 难度S↓ | 几何最佳袋 | 切角 | 母球→B43(cm) | B43→下球点(cm) | 第一杆吃库数 |',
    '|---:|---:|---:|---|---:|---:|---:|---:|']
for row in finite:
    m=row['best']
    lines.append(f"| {row['rank']} | {row['comboIndex']} | {m['score']:.6f} | {names[m['pocket']]} | {m['angle']:.2f}° | {row['cueObjectDistance']*100:.2f} | {m['distance']*100:.2f} | {row['firstShotMainRails']} |")
lines+=['','## 不可用（不赋予数值排名）','','| 组合ID | 原因 | 母球与B43球心距离 |','|---:|---|---:|']
for row in rows:
    if not row['best']:lines.append(f"| {row['comboIndex']} | 两球重叠（小于直径{2*g.radius*100:.3f}cm） | {row['cueObjectDistance']*100:.3f}cm |")
lines+=['','[完整坐标、打点、杆速及六袋分数JSON](b43-ranked.json)','',
    '验证：全部95项重算，与此前每袋分数和不可用原因完全一致；95个组合ID唯一，93项按完整精度单调升序。','']
(OUT/'b43-ranking.md').write_text('\n'.join(lines))
print(json.dumps(dict(total=95,ranked=93,unavailable=2,best=finite[0]['comboIndex'],worst=finite[-1]['comboIndex'],selectedRanks={r['comboIndex']:r['rank'] for r in rows if r['comboIndex'] in [411,41,183,46,293]})))
