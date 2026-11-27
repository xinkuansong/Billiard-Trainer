"""Summarize the complete source potential pass, without choosing an elimination threshold."""
from pathlib import Path
import sqlite3,json,hashlib,gzip
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
status=json.loads((OUT/'status.json').read_text());assert status['state']=='complete'
manifest=json.loads((OUT/'input-manifest.json').read_text());identity=json.loads((OUT/'run-identity.json').read_text())
con=sqlite3.connect('file:'+str(OUT/'region-results.sqlite3')+'?mode=ro',uri=True);con.execute('ATTACH DATABASE ? AS inputs',(str(OUT/'inputs.sqlite3'),))
assert con.execute('SELECT COUNT(*) FROM results').fetchone()[0]==688806
assert con.execute('SELECT COUNT(*) FROM inputs.maps m LEFT JOIN results r ON m.id=r.id WHERE r.id IS NULL').fetchone()[0]==0
assert con.execute('SELECT COUNT(*) FROM inputs.roles a JOIN results r ON a.map=r.id').fetchone()[0]==1331922
# One source-role join; accumulate whole score buckets rather than rereading the join for each column.
thresholds=[70,75,80,85,90,95]; kinds=['two_black','two_own','three']
case='CASE '+ ' '.join(f'WHEN r.maximum<{t} THEN {i}' for i,t in enumerate(thresholds))+' ELSE 6 END'
hist={(k,i):(0,0) for k in kinds for i in range(7)}
for k,i,n,e in con.execute(f'SELECT a.kind,{case} AS bucket,COUNT(*),SUM(r.estimated) FROM inputs.roles a JOIN results r ON a.map=r.id GROUP BY a.kind,bucket'):
 hist[k,i]=(n,e)
bands=[];exclusive=[]
for i,t in enumerate(thresholds):
 row={'threshold':t}
 for k in kinds:
  n,e=map(sum,zip(*(hist[k,j] for j in range(i+1,7))))
  row[k]={'all':n,'estimatedMaximum':e,'nonEstimatedMaximum':n-e}
 bands.append(row)
reference=json.loads((OUT/'summary.json').read_text())
for r in reference['roleBands']:
 assert next(b for b in bands if b['threshold']==r['threshold'])[r['kind']]=={'all':r['all'],'estimatedMaximum':r['all']-r['confirmed'],'nonEstimatedMaximum':r['confirmed']}
for i,(lo,hi) in enumerate(zip([-1]+thresholds,thresholds+[101])):
 exclusive.append({'lower':lo,'upper':hi,**{k:hist[k,i][0] for k in kinds}})
for k,expected in [('two_black',332886),('two_own',332886),('three',666150)]:assert sum(r[k] for r in exclusive)==expected
confidence=[dict(kind=k,maps=n,estimatedMaxima=e) for k,n,e in con.execute('SELECT kind,COUNT(*),SUM(estimated) FROM results GROUP BY kind')]
blocks=[dict(kind=k,maps=n,fullDirectBlock=direct,potContactsBlocked=pot) for k,n,direct,pot in con.execute("SELECT kind,COUNT(*),SUM(COALESCE(json_extract(payload,'$.effect.fullDirectBlock'),0)=1), SUM(COALESCE(json_extract(payload,'$.effect.potContactsBlocked'),0)=1) FROM results GROUP BY kind")]
con.close()
archives=[];rows=0
for p in sorted(OUT.glob('full-wave-*/archive.json')):
 entry=json.loads(p.read_text());path=Path(entry['file']);assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']
 payload=json.loads(gzip.decompress(path.read_bytes()));assert payload['identity']==identity['id'];assert len(payload['rows'])==entry['rows'];rows+=entry['rows'];archives.append(entry)
assert rows==688806
report=dict(passed=True,scoringVersion='defense-target-pipe-cut-lambda5-v9',sourceBoards=manifest['counts'],roles=manifest['roles'],maps=manifest['maps'],cumulative=bands,exclusive=exclusive,confidence=confidence,blockPeaks=blocks,archiveCount=len(archives),archivedMaps=rows,trajectorySearchStarted=False,productionBanksReplaced=False,finalCutoffSelected=False)
(OUT/'filter-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
lines=['# 防守初始球形：λ5全量区域潜力筛查','',
'本轮仅做球形潜力分档，未搜索击球轨迹、未替换App题库，也未自行决定新淘汰门槛。',
'', '原始两球166,443个、三球111,025个问题；展开球权后为1,331,922条组合。两球/三球不含母球。重复的固定对手目标＋静止遮挡球组合复用计算，共688,806组区域配置。初筛保存最高分、代表母球点和评分依据，不保存每格完整热力图。以下是角色展开项数，尚未按最终题库规则去重。',
'', 'S＝100√[(1−C/100)/(1＋5×θ/1°×cos²α)]；六袋取对手最佳进攻机会。使用50×25合法母球格中心，母目标球心距离至少30cm，目标球不扰动。此处最高分是网格最高分，不是连续全台最大值，也不代表初始母球可达。',
'', '## 累计达到门槛', '', '|区域最高分|两球：我方8／对方9|两球：我方1／对方8|三球：我方1／对方9，静止8|','|---|---:|---:|---:|']
for r in bands:lines.append('|≥'+str(r['threshold'])+'|'+'|'.join(f"{r[k]['all']:,}" for k in ['two_black','two_own','three'])+'|')
lines+=['','两种两球球权得到相同数量：此阶段只看对手球位置对应的母球区域，不计算我方球的击球方式。三球另包含静止8号的遮挡作用，不能与无遮挡两球混成一个分布。',
'', '## 互斥分档','','|最高分区间|两球：我方8／对方9|两球：我方1／对方8|三球|','|---|---:|---:|---:|']
for r in exclusive:
 label='<70' if r['lower']==-1 else '≥95' if r['upper']==101 else f"[{r['lower']}, {r['upper']})"
 lines.append('|'+label+'|'+'|'.join(f"{r[k]:,}" for k in ['two_black','two_own','three'])+'|')
lines+=['','## 最高点的估算标记','','|门槛|两球8/9：估算最高点|两球1/8：估算最高点|三球：估算最高点|','|---|---:|---:|---:|']
for r in bands:lines.append('|≥'+str(r['threshold'])+'|'+'|'.join(f"{r[k]['estimatedMaximum']:,}" for k in ['two_black','two_own','three'])+'|')
lines+=['','这些数量是“总最高点来自估算分支”，不能当作已证明防守有效，也不说明该图没有稍低的确认高分点。本轮先保留标记，不直接据此删除球形。基础区域潜力低的球形，仍可能靠移动我方球形成遮挡，应归后续遮挡型候选。',
'', '## 可复算数据','', '- inputs.sqlite3：原始球形、全部角色、区域映射及精确坐标。','- region-results.sqlite3：每图最高分、代表母球点、评分明细、计算统计与估算标记。','- full-archives：逐波压缩原始结果，完整性与SHA已核对。','- filter-report.json：累计门槛、互斥分档和估算分类统计。','- run-identity.json／full-driver-identity.json：评分源码、二进制及执行脚本身份。','']
lines.extend(['## 遮挡对最高分的影响（按去重区域配置计数）','','|区域配置|全部配置|最高点完全遮挡|最高点全部直进下球点受阻|','|---|---:|---:|---:|'])
for r in blocks:lines.append('|'+('三球' if r['kind']=='three' else '两球')+'|'+ '|'.join(f"{r[k]:,}" for k in ['maps','fullDirectBlock','potContactsBlocked'])+'|')
lines.extend(['','这里只统计扫描选中的最高点，不表示其他母球位置也能遮挡，或该位置可从起杆点到达。',''])
(OUT/'README.md').write_text('\n'.join(lines))
print(json.dumps({k:v for k,v in report.items() if k not in ['exclusive']},ensure_ascii=False,indent=2))
