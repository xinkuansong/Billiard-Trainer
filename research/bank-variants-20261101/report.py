from pathlib import Path
import json,hashlib,tarfile,collections
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/bank-variants-20261101'
m=json.loads((OUT/'manifest.json').read_text());export=json.loads((OUT/'export.json').read_text());s=json.loads((OUT/'status.json').read_text())
lines=['# 翻袋镜像与位置变体结果','',f"原始基础 {m['bases']} 题；保留 **{m['selected']} 题**。所有保留题经过正向生产物理模拟、独立原生重放及Python几何/事件/完整评分审核。",'','|库数|中袋|底袋|合计|','|---|---:|---:|---:|']
for n in [1,2,3]:
 a=m['counts'][f'{n}-middle'];b=m['counts'][f'{n}-corner'];lines.append(f'|{n}库|{a}|{b}|{a+b}|')
lines+=['',f"- 原题及镜像：{m['kindCounts']['original']}题；其中3993题原形全部保留。镜像候选{m['originalMirrorCandidates']}题，未通过{m['originalMirrorCandidates']-m['kindCounts']['original']}题。",f"- 位置扰动尝试{m['perturbationAttempts']}次，选出{m['canonicalPerturbations']}个原方向变体；变换并复验后保留{m['kindCounts']['perturbation']}题。",f"- {m['physicalReplays']}杆独立原生精确重放（翻袋和直打参考各一）；审核拒绝{len(m['negativeCasesRejected'])}种构造性错误。",f"- 8进程峰值，250批全部完成；生成至批次结束{ s['elapsedSeconds']/60:.2f}分钟（不含编译、最终归并和图册检查）。",f"- 精确球位/目标袋/库序去重删除{len(m['duplicateIDs'])}题；不折叠不同镜像朝向。",'', '每原题两个位移候选，最多留一个。目标球沿原反射线移动1–3cm；母球调整两球球心距3–8cm、几何切角1–3°。符号随机，目标球两个方向各一次。重新检查六袋直打、翻袋实际切角、出杆空间、球距、连续垂直库序和中袋末段35°限制。','', '## 可复核证据','',f"- 全量：`formations.jsonl.gz`，{export['bytes']}字节，SHA256 `{export['sha256']}`。",'- 每批完整事件、评分、独立重放回执：`batches/`；每次候选与镜像取舍：`decisions.json.gz`。','- 展示轨迹约10Hz且保留全部事件时刻；重放、评分使用压缩前的完整模拟，全部事件和中袋33个速度样本保留。','- 编译物理源码：`frozen-source.tar.gz`；最终研究脚本：`final-harness.tar.gz` 与 `harness-binding.json`。','- 数值预飞：`preflight.json`；审核与全量统计：`manifest.json`；原始浅角中袋回归：`regression.json`。','','## 未保留原因','', '扰动候选（有限预算内未通过，不等同该位置不存在打法）：','```json',json.dumps(m['perturbationRejections'],ensure_ascii=False,indent=2),'```','镜像复验：','```json',json.dumps(m['mirrorRejections'],ensure_ascii=False,indent=2),'```','','## 范围','', '只生成离线研究资源，未替换App正式题库。位置变化验证不代表击球瞄准／力度／加塞误差容错；未新增近似去重、少库替代全搜索或实台标定。图册为36题对照抽样，每行原题、位置扰动、扰动后上下镜像；完整底袋数据还包含左右与双轴镜像。']
(OUT/'REPORT.md').write_text('\n'.join(lines)+'\n')
files=[p for p in HERE.iterdir() if p.is_file()];binding={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(OUT/'harness-binding.json').write_text(json.dumps(binding,indent=2))
with tarfile.open(OUT/'final-harness.tar.gz','w:gz') as tar:
 for p in files:tar.add(p,arcname=p.name)
print('\n'.join(lines[:16]))
