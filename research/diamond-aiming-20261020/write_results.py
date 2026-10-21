"""Write readable metrics without transcribing or rounding away coverage."""
import csv,json,platform,sys
from pathlib import Path
P=Path(__file__).resolve().parent
rows=list(csv.DictReader((P/'results/metrics.csv').open()))
names={'alpha':'α直接代θ','dual_directions':'双方向颗星表','ratio_exact_oracle':'A/H精确公式（对照）','ratio_quarter_grid':'A/H取1/4格','ratio_table10':'10项比例表+插值','standard_direction':'标准进球方向','fraction5_oracle':'五档最优选档','locus_quarter_template':'1/4颗星预制模板','first_order_oracle':'一阶修正（对照）','first_order_mental':'5°估角+简化修正','dual_first_order':'双方向+一阶修正'}
lines=['# 主实验指标','', '从 `results/metrics.csv` 自动生成；MAE/P95仅包含返回结果，±5°通过率以全部真实有效样本为分母，拒答也计入分母。厚度误差用百分点（pp），不是百分比相对误差。','']
for model,title in [('ideal','理想8×4模型'),('production','项目实际几何')]:
 for noise in ['0','0.1','0.25']:
  lines += [f'## {title} / 每坐标±{noise}格','', '| 方法 | MAE° | P95° | 厚度MAE pp | 厚度P95 pp | 返回率 | 全体±5°通过 | 带切侧P95° |','|---|---:|---:|---:|---:|---:|---:|---:|']
  for r in rows:
   if r['model']==model and r['noise_grid']==noise and r['group']=='all':
    values=[float(r[k]) for k in ['mae_deg','p95_deg','fraction_mae','fraction_p95','coverage','within5_all','signed_p95_deg']]
    a,b,c,d,e,f,g=values
    lines.append(f"| {names[r['method']]} | {a:.3f} | {b:.3f} | {c*100:.3f} | {d*100:.3f} | {e*100:.2f}% | {f*100:.2f}% | {g:.3f} |")
  lines.append('')
lines+=['## 分层明细','', 'CSV按distance_grid、cut_deg、fraction、pocket、OP_grid提供所有方法和噪声的n、返回数、MAE、P95、最大值、厚度误差及切侧误差；screen为探索性子集，不是可部署的自动筛选器。']
(P/'RESULTS.md').write_text('\n'.join(lines)+'\n')
import numpy as np
(P/'results/environment.json').write_text(json.dumps({'python':sys.version,'numpy':np.__version__,'platform':platform.platform()},indent=2)+'\n')
print('Wrote RESULTS.md and environment.json')
