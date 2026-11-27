"""Select simple representatives from verified replays; do not maximize own window."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-threshold-comparison-20261105'
config=json.loads((OUT/'scenario.json').read_text());validation=json.loads((OUT/'validation.json').read_text())
assert validation['passed']
rows=[];sources={};gallery=['# 防守代表：我方球留有机会，优先简单打法','',
'从已经完成重放与四次扰动验证的15条诊断代表重新选择；不增加最大容错角代表，不凑基础／遮挡分类配额。原始数据与图册保留。',
'', '当前仍沿用已验证的窗口不下降筛选，尚未定义绝对“舒服”角度阈值；不把相对改善当作已证实好打。生产评分中的0°估计问题仍在。','']
for case in config['cases']:
    path=OUT/case['label']/'routes.json';sources[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    data=json.loads(path.read_text());routes=data['routes'];ids=[];by_threshold={}
    # Execution effort and actual speed are separate: centre-ball shots <=4m/s have effort=0.
    def key(r):return (r['effort'],r['shot']['speed'],sum(e['kind']=='cushion' for e in r['events']),r['id'])
    for t in [70,80,90]:
        valid=[r for r in routes if t in r['stableThresholds'] and r['ownPreserved'] and r['replayVerified'] and len(r['probes'])==4 and all(p.get('score',-1)>=t and p.get('ownPreserved',False) for p in r['probes'])]
        if not valid:by_threshold[str(t)]=None;continue
        best=min(valid,key=key);by_threshold[str(t)]=best['id']
        if best['id'] not in ids:ids.append(best['id'])
    rows.append({'label':case['label'],'ids':ids,'byThreshold':by_threshold,'removedFromRecommendations':[r['id'] for r in routes if r['id'] not in ids]})
    gallery+=['## '+case['label'],'']
    if not ids:gallery+=['本轮没有已验证的联合达标代表。',''];continue
    for rid in ids:
        r=next(r for r in routes if r['id']==rid);s=r['shot'];image=OUT/case['label']/f'route-{rid:02}.png';assert image.is_file()
        gallery += [f"路线{rid}；门槛 {'/'.join(t for t,v in by_threshold.items() if v==rid)}；杆速{s['speed']:.3f}；已确认窗口{r['ownBefore']['bestClearDegrees']:.3f}°→{r['ownAfter']['bestClearDegrees']:.3f}°。",'',f'![{case["label"]} 路线{rid}]({image})','']
result={'policy':'Sufficient own opportunity, simple execution first. No maximum-window bonus. Presentation-only reselection of existing verified replays, not a new global search.','ranking':['executionEffort ascending','actualSpeed ascending','cushionEvents ascending only as tie-break','id for deterministic tie'],'selectedCount':sum(len(r['ids']) for r in rows),'scope':'Own-window preservation is inherited as a provisional safety filter, not a calibrated comfort threshold.','sources':sources,'cases':rows}
(OUT/'sufficient-selection.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
(OUT/'recommended-gallery.md').write_text('\n'.join(gallery)+'\n')
print(json.dumps({'selectedCount':result['selectedCount'],'cases':rows},ensure_ascii=False))
