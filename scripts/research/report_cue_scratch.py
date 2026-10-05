#!/usr/bin/env python3
"""Streaming audit/index and measured-path gallery for V023."""
import collections,html,json,math,sqlite3,subprocess,sys
from pathlib import Path
from run_cue_scratch_session import OUT,ROOT,family
REPORT=ROOT/'output/cue-scratch-research-20261004'

def readrows(path):
 for line in path.open():yield json.loads(line)
def svg(row,geo):
 W,H=800,420
 def pt(p):return (400+p[0]*270,210+p[1]*270)
 def path(ps):return ' '.join(f'{pt(p)[0]:.2f},{pt(p)[1]:.2f}' for p in ps)
 out=[f'<svg viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg">', '<rect width="800" height="420" rx="16" fill="#122b26"/>', '<rect x="57.1" y="38.55" width="685.8" height="342.9" fill="#226b53"/>']
 for p in geo['pockets']:
  out.append(f'<polygon points="{path(p["lip"])}" fill="#091816"/>')
  x,y=pt(p['center']);out.append(f'<circle cx="{x}" cy="{y}" r="{p["radius"]*270}" fill="#091816"/>')
 for rail in geo['rails']:
  a,b=pt(rail['a']),pt(rail['b']);out.append(f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" stroke="#8ca894" stroke-width="2"/>')
 for name,color in [('object','#ffca60'),('cueBall','#f7faf7')]:
  frames=row.get('paths',{}).get(name,[])
  if frames:out.append(f'<polyline points="{path([[f[1],f[2]] for f in frames])}" fill="none" stroke="{color}" stroke-width="2.4" opacity=".9"/>')
 for key,color in [('cue','#fff'),('object','#ffca60')]:
  x,y=pt(row[key]);out.append(f'<circle cx="{x}" cy="{y}" r="{geo["radius"]*270}" fill="{color}" stroke="#122b26" stroke-width="1.2"/>')
 k=0
 for ev in row.get('events',[]):
  if ev.get('kind')=='rail' and ev.get('ball')=='cueBall' and 0<=ev.get('segment',99)<6 and 'p' in ev:
   k+=1;x,y=pt(ev['p']);out.append(f'<circle cx="{x}" cy="{y}" r="10" fill="#f29c50"/><text x="{x}" y="{y+4}" text-anchor="middle" font-size="12" fill="#142a23">{k}</text>')
 target=next((p for p in geo['pockets'] if p['id']==row.get('cuePocket')),None)
 if target:
  x,y=pt(target['center']);out.append(f'<circle cx="{x}" cy="{y}" r="17" fill="none" stroke="#ff8270" stroke-width="3"/>')
 out.append('</svg>');return ''.join(out)

def main():
 assert not (REPORT/'expansion-summary.json').exists(), 'Expanded gallery exists; use render_cue_scratch_expansion.py to preserve its selection'
 REPORT.mkdir(parents=True,exist_ok=True)
 geo=json.loads((OUT/'geometry.json').read_text())
 db=sqlite3.connect(OUT/'results.sqlite');db.execute('PRAGMA journal_mode=WAL')
 db.execute('CREATE TABLE IF NOT EXISTS trials (id TEXT PRIMARY KEY,batch TEXT,layout INTEGER,mode TEXT,speed REAL,pocket INTEGER,resolved INTEGER,target_pot INTEGER,hit INTEGER,rails INTEGER,reject TEXT,raw TEXT)')
 existing_batches={x[0] for x in db.execute('SELECT DISTINCT batch FROM trials')}
 count=collections.Counter();bybatch=collections.defaultdict(collections.Counter);speeds=collections.defaultdict(collections.Counter);broad_speeds=collections.defaultdict(collections.Counter);hist=collections.Counter();hits=[];verifications={};ids=set();layouts=set(); families=collections.Counter();discoveries=[];missingidx=0; probe_calls=0; full_trials=0; physical_trials=0
 for p in sorted(OUT.glob('*.jsonl')):
  for row in readrows(p):
   ident=row['id'];assert ident not in ids, f'duplicate trial {ident}';ids.add(ident)
   layouts.add(tuple(row['cue']+row['object']))
   assert all(math.isfinite(v) for v in row['cue']+row['object']+[row['speed']])
   if 'reject' not in row and row.get('termination') not in (None,'nil'):
    physical_trials+=1
    if row.get('aimPolicy')=='production-first-offset':probe_calls+=1
    else:full_trials+=1
   times=[e['t'] for e in row.get('events',[])];assert all(b>=a-1e-5 for a,b in zip(times,times[1:])),ident
   missingidx+=sum(e['kind']=='rail' and e.get('segment',-1)<0 for e in row.get('events',[]))
   if row.get('targetPot'):assert row['objectPocket']==f'pocket_{row["pocket"]}'
   if row.get('reject'):outcome='reject_'+row['reject']
   elif not row.get('resolved'):outcome='unresolved'
   elif not row.get('targetPot'):outcome='target_miss'
   elif row.get('hit'):outcome=f'scratch_{len(row["rails"])}'
   else:outcome='target_pot_other'
   count[outcome]+=1;count['total']+=1;bybatch[p.stem][outcome]+=1;bybatch[p.stem]['total']+=1
   speeds[round(row['speed'],3)][outcome]+=1
   if p.stem.startswith('broad-'):
    b=broad_speeds[round(row['speed'],3)];b[outcome]+=1;b['records']+=1
    b['physical']+=int('reject' not in row);b['targetPot']+=int(row.get('targetPot',False))
   if 'cut' in row:hist[f'{min(8,int(row["cut"]//10))*10}–{min(8,int(row["cut"]//10))*10+10}°']+=1
   if row.get('hit'):hits.append(row);families[str(family(row))]+=1
   if p.stem.startswith('verify'):verifications[ident]=row
   if p.stem not in existing_batches:db.execute('INSERT OR REPLACE INTO trials VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',(ident,p.stem,row['layout'],row['mode'],row['speed'],row.get('pocket'),row.get('resolved'),row.get('targetPot'),row.get('hit'),len(row.get('rails',[])),row.get('reject'),json.dumps(row,separators=(',',':'))))
  db.commit();discoveries.append(dict(batch=p.stem,rows=count['total'],families=len(families)))
 db.execute('CREATE INDEX IF NOT EXISTS trial_outcomes ON trials(hit,rails,speed)');db.commit();db.close()
 chosen_path=OUT/('selected-stable.json' if (OUT/'verify-stable-summary.json').exists() else 'selected.json')
 prefix='w' if chosen_path.name=='selected-stable.json' else 'v'
 selected=json.loads(chosen_path.read_text()) if chosen_path.exists() else []
 cards=[];final=[]
 for i,original in enumerate(selected):
  full=verifications.get(f'{prefix}-{i}-full');fixed=verifications.get(f'{prefix}-{i}-fixed')
  keys=['pocket','cuePocket','rails','contacts','preRails','cueJaws','objectJaws','objectRails']
  valid=full and fixed and full.get('hit') and fixed.get('hit') and all(full.get(k)==original.get(k)==fixed.get(k) for k in keys)
  if not valid:continue
  row=full;row['sourceID']=original['id']
  perturb=[x for k,x in verifications.items() if k.startswith(f'{prefix}-{i}-speed-')]
  same=sum(x.get('hit',False) and x['rails']==row['rails'] and x['cuePocket']==row['cuePocket'] and x.get('pocket')==row['pocket'] for x in perturb)
  row['fixedAimSpeedChecks']=dict(tested=len(perturb),sameRoute=same,points=[dict(speed=x['speed'],targetPot=x.get('targetPot'),hit=x.get('hit'),rails=x.get('rails'),cuePocket=x.get('cuePocket')) for x in sorted(perturb,key=lambda r:r['speed'])])
  row['cueAccess']='not-validated';final.append(row)
  file=REPORT/f'case-{len(final):02}.svg';file.write_text(svg(row,geo))
  cells=''.join(f'<span class="{ "yes" if x.get("hit") else "no"}" title="目标进袋:{x.get("targetPot")} 母球库数:{len(x.get("rails",[]))}">{x["speed"]:.2f}</span>' for x in sorted(perturb,key=lambda a:a['speed']))
  cards.append(f'<article data-rails="{len(row["rails"])}"><h2>{len(row["rails"])}库 · 杆速 {row["speed"]:.3f} m/s</h2><img src="{file.name}"><p>目标袋 {row["pocket"]} → 母球 {html.escape(row["cuePocket"])} · 推荐几何切角 {row["cut"]:.1f}° · 主库段 {row["rails"]}</p><p>固定瞄准、杆速±1%至±8%：{same}/{len(perturb)}次保持同袋同库序。水平出杆空间尚未核验。</p><div class="spectrum">{cells}</div><details><summary>摆位与复现ID</summary><pre>{html.escape(json.dumps({k:row[k] for k in ["sourceID","cue","object","speed","offset","aim"]},ensure_ascii=False,indent=2))}</pre></details></article>')
 summary=dict(physicalTrials=physical_trials,singleOffsetPhysicalCalls=probe_calls,fullSolverTrials=full_trials,fullSolverUnderlyingCalls='not separately instrumented; 1–21 per completed solve',counts=dict(count),uniqueTrials=len(ids),uniquePositions=len(layouts),rawRouteFamilies=len(families),hitTrials=len(hits),verifiedRepresentatives=len(final),missingCushionIDs=missingidx,byBatch={k:dict(v) for k,v in bybatch.items()},angleHistogram=dict(hist),discoveryByFile=discoveries)
 assert missingidx==0,'Lost raw cushion IDs'
 (REPORT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
 (REPORT/'verified-cases.json').write_text(json.dumps(final,ensure_ascii=False,indent=2))
 audit=[r for p in OUT.glob('audit.jsonl') for r in readrows(p)]
 summary['fullSolverMissAudit']=dict(tested=len(audit),recoveredTargetPots=sum(x.get('targetPot',False) for x in audit),recoveredHits=sum(x.get('hit',False) for x in audit))
 (REPORT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
 labels={'total':'记录总数','reject_layout':'摆位不合法','reject_recommendation':'无推荐袋','reject_aimGeometry':'瞄准几何不可行','unresolved':'未完成，需复核','target_miss':'目标未进推荐袋','target_pot_other':'目标进袋，母球结局不符合本期条件',**{f'scratch_{n}':f'符合条件的{n}库掉袋' for n in range(4)}}
 table=''.join(f'<tr><td>{labels.get(k,k)}</td><td>{v:,}</td></tr>' for k,v in sorted(count.items()))
 (REPORT/'speed-matrix.json').write_text(json.dumps({str(k):dict(v) for k,v in sorted(broad_speeds.items())},ensure_ascii=False,indent=2))
 speed_table='<tr><th>杆速 m/s</th><th>物理探测</th><th>目标进袋</th><th>0库</th><th>1库</th><th>2库</th><th>3库</th></tr>'+''.join('<tr><td>'+str(v)+'</td>'+''.join(f'<td>{c.get(k,0):,}</td>' for k in ['physical','targetPot','scratch_0','scratch_1','scratch_2','scratch_3'])+'</tr>' for v,c in sorted(broad_speeds.items()))
 document='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>V023 母球掉袋 · 实测图册</title><style>body{margin:0;background:#eef2ed;color:#1c3029;font-family:-apple-system,"PingFang SC",sans-serif;line-height:1.65}main{max-width:1200px;margin:auto;padding:24px}h1{font-size:32px}header{background:#f8d750;padding:22px;border-radius:18px}section{margin:24px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:18px}article{background:#fff;border-radius:16px;padding:18px}h2{margin-top:0;font-size:21px}img{width:100%}table{border-collapse:collapse}td{padding:4px 20px;border-bottom:1px solid #cdd7cc}button{padding:10px 20px;margin:8px;border:0;border-radius:9px;background:#173c30;color:white;cursor:pointer}.spectrum span{display:inline-block;padding:3px 6px;margin:2px;border-radius:4px}.yes{background:#c3e6cf}.no{background:#f6dad1}pre{white-space:pre-wrap;font-size:12px}.note{color:#50655d}</style><main>'''
 document+=f'<header><h1>母球掉袋：真实物理搜索图册</h1><p>中杆无塞 · 推荐目标袋 · 零至三库 · 2026-10-04</p><b>{len(ids):,}次已记录试验 · {len(hits):,}次干净掉袋候选 · {len(final)}个完整复验代表</b></header>'
 document+='<p class="note">白色：母球实测轨迹；黄色：目标球；橙色数字：主库接触；红圈：母球落袋。X向右、Z向下，单位米。图为事件记录中的采样轨迹，不是原生场景截图或成片。所有展示代表通过生产完整求解与固定方向重放（演进上限30秒/1000事件）；实体球杆出杆空间尚未验证。</p>'
 document+='<section><button onclick="filter(-1)">全部</button>'+''.join(f'<button onclick="filter({n})">{n}库</button>' for n in range(4))+'</section><div class="grid">'+''.join(cards)+'</div>'
 document+=f'<section><h2>结果漏斗</h2><table>{table}</table><p>包含预设采样、细搜、完整求解及扰动复验，不能把混合总数当随机球形掉袋概率。首选方向失败未全部补救；未完成轨迹独立保留。近袋启发只用于排种子，不证明可进入袋口。</p><p>原始路线族尚未按镜像去重，代表已按球位距离避免邻近重复。罕见路线数量不是物理完备性证明。</p><p><a href="summary.json">统计JSON</a> · <a href="verified-cases.json">复现参数与真实轨迹</a></p></section>'
 document+='<section><h2>广搜力度分布</h2><table>'+speed_table+'</table><p>各力度对应的盘面集合不完全相同，仅展示本轮采样分布，不作力度因果比较。</p></section>'
 document+='</main><script>function filter(n){document.querySelectorAll("article").forEach(e=>e.style.display=n<0||Number(e.dataset.rails)===n?"":"none")}</script></html>'
 (REPORT/'index.html').write_text(document)
 (REPORT/'REPORT.md').write_text('# V023 限时搜索结果\n\n'+json.dumps(summary,ensure_ascii=False,indent=2)+'\n\n当前图册是物理候选，出杆空间、原生画面与视频尚未验证。\n')
 print(json.dumps(summary,ensure_ascii=False),flush=True)
if __name__=='__main__':main()
