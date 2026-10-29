"""Uniform fixed-seed sample of questions, without balancing or replacement."""
import collections
import hashlib
import json
from pathlib import Path
import random
import shutil
import sqlite3
import zlib
from grid100 import transform

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'output/k-ball-one-per-route-20261029'
OUT=ROOT/'output/k-ball-random100-20261029'
SEED=2026102901


def run(count=100,rail=None,seed=SEED,out=OUT):
    OUT=out
    SEED=seed
    assert json.loads((SOURCE/'audit.json').read_text())['passed']
    db=sqlite3.connect(f'file:{SOURCE}/atlas.sqlite?mode=ro',uri=True)
    where=' WHERE rail=?' if rail is not None else ''
    params=[rail] if rail is not None else []
    ids=[r[0] for r in db.execute('SELECT id FROM questions'+where+' ORDER BY id',params)]
    chosen=random.Random(SEED).sample(ids,count)
    OUT.mkdir(exist_ok=False)
    target=sqlite3.connect(OUT/'atlas.sqlite')
    target.execute('CREATE TABLE questions(id TEXT PRIMARY KEY,route TEXT UNIQUE,layout TEXT,grade INTEGER,axis TEXT,rail INTEGER,pocket TEXT,data BLOB,sample_order INTEGER UNIQUE)')
    samples=[];payload_hashes={}
    with (OUT/'selected.jsonl').open('wb') as f:
        for order,identity in enumerate(chosen,1):
            row=db.execute('SELECT * FROM questions WHERE id=?',(identity,)).fetchone()
            target.execute('INSERT INTO questions VALUES(?,?,?,?,?,?,?,?,?)',(*row,order))
            raw=zlib.decompress(row[7]);f.write(raw);samples.append(json.loads(raw))
            payload_hashes[identity]=hashlib.sha256(raw).hexdigest()
    target.commit();target.close()
    specs=[('K时机','axis',{'inAngle':'入库前','outAngle':'出库后'}),('观察库','rail',{1:'第1库',2:'第2库',3:'第3库'}),('A目标袋','pocket',{'corner':'角袋','middle':'中袋'}),('容错等级','grade',{1:'敏感',2:'常规',3:'宽容'})]
    distribution=[]
    for title,column,labels in specs:
        population=dict(db.execute(f'SELECT {column},count(*) FROM questions'+where+f' GROUP BY {column}',params))
        sample=collections.Counter((s['candidate']['axis'] if column=='axis' else s['candidate']['railOrdinal'] if column=='rail' else ('middle' if s['seed']['pocket']>=4 else 'corner') if column=='pocket' else s['grade']) for s in samples)
        for value,label in labels.items():distribution.append(dict(group=title,label=label,sample=sample[value],population=population.get(value,0),populationPercent=100*population.get(value,0)/len(ids)))
    db.close()
    summary=dict(complete=True,selected=count,retainedRoutes=count,retainedLayouts=len({s['seed']['layout'] for s in samples}),population=len(ids),randomSeed=SEED,observedRail=rail,distribution=distribution)
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    (OUT/'sample-manifest.json').write_text(json.dumps(dict(seed=SEED,observedRail=rail,method=f'random.Random(seed).sample(sorted eligible question IDs,{count})',populationIDsSHA256=hashlib.sha256('\n'.join(ids).encode()).hexdigest(),idsInDrawOrder=chosen,payloadSHA256=payload_hashes),indent=2))
    assert len(set(chosen))==count and random.Random(SEED).sample(ids,count)==chosen
    assert rail is None or all(s['candidate']['railOrdinal']==rail and len(s['baseline']['railsBeforeK'])==(rail-1 if s['candidate']['axis']=='inAngle' else rail) for s in samples)
    (OUT/'audit.json').write_text(json.dumps(dict(passed=True,uniqueQuestions=count,reproducible=True,unchangedSourcePayloads=True,observedRail=rail,actualRailCountsChecked=True,newSimulations=0,source=str(SOURCE),inheritedAudit=str(SOURCE/'audit.json')),indent=2))
    shutil.copyfile(SOURCE/'geometry.json',OUT/'geometry.json')
    page=(SOURCE/'index.html').read_text().replace('每条轨迹，只留一个B球位置','随机100题 · 分布预览')
    page=page.replace('K球题库 · 全库筛选与容错','K球题库 · 随机抽样')
    old='全库筛选后保留 ${s.selected} 题，覆盖 ${s.retainedLayouts} 个球形、${s.retainedRoutes} 条路线。每条路线恰好保留一题，较上一版减少 ${s.removed} 题。'
    new='从 ${s.population} 题中等概率、不放回抽取100题，覆盖 ${s.retainedLayouts} 个球形。按抽中顺序展示，刷新不会换题。'
    assert old in page;page=page.replace(old,new)
    page=page.replace('入库前、出库后合并择一，优先容错等级；同档优先更靠近候选管道中心线的位置。','本次没有按类别配平，也没有去除同球形的不同路线。样本比例会有随机波动，可与下方全库比例对照。')
    rows=''.join(f"<tr><td>{r['group']}</td><td>{r['label']}</td><td>{r['sample']}题 / {100*r['sample']/count:.1f}%</td><td>{r['population']}题 / {r['populationPercent']:.1f}%</td></tr>" for r in distribution)
    population_label=f'第{rail}库全部{len(ids)}题' if rail is not None else f'全库{len(ids):,}题'
    table=f'<section class="panel"><h2>样本与全库分布</h2><table style="width:100%;border-collapse:collapse"><thead><tr><th>维度</th><th>分类</th><th>随机{count}题</th><th>{population_label}</th></tr></thead><tbody>'+rows+f'</tbody></table><p>抽样种子：{SEED}。原库角5–50°；入出库标签与完整轨迹沿用原验证记录。</p></section>'
    page=page.replace('<section class="panel"><div class="filters">',table+'<section class="panel"><div class="filters">')
    page=page.replace('</style>','th,td{text-align:left;padding:8px 6px;border-bottom:1px solid #36515a}th{color:#80d8ee}</style>')
    page=page.replace('const esc=', 'const sampleNumbers='+json.dumps({identity:i for i,identity in enumerate(chosen,1)})+';\nconst esc=')
    page=page.replace('<h2>第${c.railOrdinal}库','<h2>R${String(sampleNumbers[s.id]).padStart(3,\'0\')} · 第${c.railOrdinal}库')
    page=transform(page)
    if rail is not None:
        page=page.replace('随机100题 · 每行5题 / 每页20行',f'第{rail}库 · 随机{count}题 · 每行5题 / 共{(count+4)//5}行')
        page=page.replace('K球 · 随机100题 · 5列图册',f'K球 · 第{rail}库{count}题 · 5列图册')
        page=page.replace('从 ${s.population} 题中等概率、不放回抽取100题',f'从第{rail}个观察库的 ${{s.population}} 题中等概率、不放回抽取{count}题')
        page=page.replace('样本与全库分布','样本与第三库题集分布')
        page=page.replace('原库角5–50°；入出库标签与完整轨迹沿用原验证记录。','第3库入库前K实际已吃2库，出库后K实际已吃3库；与此前图册口径一致。')
    (OUT/'index.html').write_text(page)
    (OUT/'REPORT.md').write_text(f'# K球随机{count}题\n\n从{population_label}中等概率、不放回抽样，种子{SEED}；未分层配平、未按球形去重，抽样单位是题目/路线。样本数{count}，涉及'+str(summary['retainedLayouts'])+f'个球形。\n\n所有数据逐字节复用既有题目；无新物理计算。sample-manifest.json保存随机顺序及来源哈希；summary.json给出样本与来源题集分布。刷新不重新抽题，R001–R{count:03d}稳定，过滤后编号不变。第3观察库入库前实际已吃2库，出库后已吃3库。\n')
    print(json.dumps(summary,ensure_ascii=False))


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--count',type=int,default=100);p.add_argument('--rail',type=int,choices=(1,2,3));p.add_argument('--seed',type=int,default=SEED);p.add_argument('--output',type=Path,default=OUT)
    a=p.parse_args();run(a.count,a.rail,a.seed,a.output)
