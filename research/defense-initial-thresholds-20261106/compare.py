"""Compare four score bands on existing immutable fixed-target maps; no new solver."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];SOURCE=ROOT/'output/defense-threshold-comparison-20261105';OUT=ROOT/'output/defense-initial-thresholds-20261106';OUT.mkdir(parents=True,exist_ok=True)
thresholds=[70,80,90,95];cases=json.loads((SOURCE/'scenario.json').read_text())['cases'];results=[];sources={}
for c in cases:
 path=SOURCE/c['label']/'scan-adaptive.json';sources[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
 scan=json.loads(path.read_text());rows=[r for r in scan['rows'] if 'score' in r]
 def area(r):
  x,z,x1,z1=r['bounds'];return (x1-x)*(z1-z)
 total=sum(map(area,rows));levels=[]
 for t in thresholds:
  kept=[r for r in rows if r['score']>=t];by={}
  for r in kept:by[r['status']]=by.get(r['status'],0)+area(r)
  levels.append({'threshold':t,'areaSquareMeters':sum(map(area,kept)),'areaPercent':100*sum(map(area,kept))/total,'branchAreaSquareMeters':by})
 assert all(levels[i]['areaSquareMeters']>=levels[i+1]['areaSquareMeters'] for i in range(3))
 results.append({'label':c['label'],'target':c['target'],'railGapCM':c['railSurfaceGapMeters']*100,'maximum':max(r['score'] for r in rows),'validSampleAreaSquareMeters':total,'thresholds':levels})
report={'scope':'Fixed opponent9, no own8 blocker in map. Existing adaptive 5cm scans only; no position perturbation or new shot solve. All reported areas are leaf-centre estimates, not certified continuous sets.','thresholds':thresholds,'cases':results,'sourceSHA256':sources,'thresholdNestingChecked':True,'hardRejectionApplied':False}
(OUT/'comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
lines=['# 初始球形防守区域：70／80／90／95四档','',report['scope'],'','表中百分比为达到门槛的基础区域占有效采样面积的比例。各档累积包含；不是70～80等互斥分段。初始8号不作为固定障碍，尚未考虑其移动后的遮挡收益。','','| 球形 | 9号离库cm | ≥70 | ≥80 | ≥90 | ≥95 |','|---|---:|---:|---:|---:|---:|']
for r in results:
 lines.append('| '+r['label']+f" | {r['railGapCM']:.2f} | "+' | '.join(f"{v['areaPercent']:.2f}%" for v in r['thresholds'])+' |')
lines += ['','现有九例都有100分局部采样点，单独用最高分无法区分这些球形。高分区面积差异明显；贴库例大量采用0°估计分支，不能把分布差异直接当成已校准实战难度。','','当前仅并排比较，不据此淘汰整题。基础困难区域小不排除移动8号创造遮挡，F08已有这样的已验证路线。','']
for i in range(3):lines += [f'![F{i*3+1:02}–F{i*3+3:02}四档区域]({OUT/f"regions-{i+1}.png"})','']
(OUT/'comparison.md').write_text('\n'.join(lines))
print('\n'.join(lines[:17]))
