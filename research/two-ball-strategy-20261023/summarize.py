#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import json,math
P=Path(__file__).resolve().parent
rd=lambda n:json.loads((P/n).read_text())
scan=rd('scan-results.json');s=rd('summary.json');v=rd('viewer-data.json');items={x['id']:x for x in v['items']};paired=rd('paired-comparison.json');sample=rd('sample.json')
names=v['names'];n=len(items);nominal=[x for x in scan['candidates'] if x['status']=='nominal_both_passed']
lines=['# 固定两球：顺序、袋口与杆法对比','', '2026-10-23。离线研究；正式App、准度库与用户成绩未改写。','', '[打开图册](report.html) · [逐方案CSV](comparison.csv) · [实验协议](EXPERIMENT.md)','', '## 本轮结论范围','',f'同一固定C/A/B球形，540个首杆参数槽位；{len(nominal)}个名义两杆候选，{n}个进入48次设计＋128次留出复验，共{n*176}个含两杆独立误差的序列输入。首杆失败即结束，不能把这个数当作实际第二杆执行次数。','', '首杆五类打点与九档速度；第二杆从12组参数中选定速度/打点。实际停点改变后只重瞄第二杆方向，再加独立执行误差，不在留出集换袋或换杆法。切角≤75°、球心距15–254cm、离库≥5cm，范围不同于上一轮35°/120cm，不横比两轮比例。','', '## 设计集预选的两种顺序','', '|顺序|首袋 → 次袋|首杆参数|第二杆参数|设计两杆|留出两杆|留出首杆有效|有效首杆后完成|','|---|---|---|---|---:|---:|---:|---:|']
for order in ['AB','BA']:
 cid=s['winnerByOrder'][order]
 if not cid:lines.append(f'|{order}|预算内未找到名义两杆见证|||||||');continue
 x=items[cid];h=x['holdout'];d=x['design'];t=x['secondControl']
 lines.append(f"|{order}|{names[x['p1']]} → {names[x['p2']]}|{x['styleLabel']}，{x['v']}m/s，X/Y={x['sx']}/{x['sy']}|{t['v']}m/s，X/Y={t['sx']}/{t['sy']}|{d['complete']}/48|{h['complete']}/128（{h['rate']:.1%}）|{h['firstPass']}/128|{h['complete']}/{h['firstPass']}|")
if paired:
 lo,hi=paired['bootstrap95'];lines += ['',f"配对差值A→B减B→A为{paired['differenceABminusBA']*100:.1f}个百分点；同一组128个8维误差的配对自助法95%区间为{lo*100:.1f}～{hi*100:.1f}个百分点（固定种子、10,000次重采样）。仅A→B成功{paired['ABonly']}次，仅B→A成功{paired['BAonly']}次，两者均成功{paired['both']}次。",'', '区间跨过0，本轮不能明确区分先后。' if lo<=0<=hi else '这个差异只适用于本固定球形、有限候选与规定误差模型，不能推广为普遍顺序规则。']
lines += ['', '## 通过率口径', '', '本轮主指标要求指定袋进球、母球不落袋、接触与静止状态合格，并排除目标球途中碰库边或袋嘴。因此它是严格路线通过率，不是普通进球率，也不是已标定的真人成功率。', '', 'A→B预选方案首杆进指定袋且母球不落袋为108/128，严格首杆合格53/128；这53次接续中第二杆进袋且母球不落袋53/53，但严格两杆完成48/128。B→A对应首杆90/128、严格首杆31/128，接续第二杆29/31，严格两杆完成16/128。', '', '首杆严格不合格的样本没有继续执行第二杆，因此这些辅助计数不能换算为整套打法的普通两杆进球率。']
lines += ['', '默认赢家及排序均由48次设计结果确定。留出结果只能评价，不能在本报告中重新挑赢家。各方案共享标准化误差，不独立汇总置信度；图册每方案Wilson区间描述单方案二元结果。','', '## 六袋与杆法覆盖','', '|顺序|第一袋|几何切角|首杆名义通过 / 槽位|名义两杆候选|已复验方案|','|---|---|---:|---:|---:|---:|']
for order in ['AB','BA']:
 for pk in range(6):
  f=[x for x in scan['firstRows'] if x['order']==order and x['p1']==pk];good=[x for x in nominal if x['order']==order and x['p1']==pk];tested=[x for x in items.values() if x['order']==order and x['p1']==pk]
  lines.append(f"|{order}|{names[pk]}|{f[0]['cutDegrees']:.1f}°|{sum(x['status']=='nominal_first_passed' for x in f)}/{len(f)}|{len(good)}|{len(tested)}|")
lines += ['', '图册矩阵保留全部72种顺序/袋口组合；未入选、名义失败和几何排除不能叫物理无解。若某首袋几何不符合，参数槽位仅记录排除，没有运行对应物理。','', '## 两杆失败分解','', '|方案|首杆失败|接续范围不符|第二杆执行失败|两杆完成|','|---|---:|---:|---:|---:|']
for x in v['items']:
 f=x['holdout']['failures'];lines.append('|'+x['id']+'|'+'|'.join(str(f.get(k,0)) for k in ['first_failed','second_geometry_excluded','second_execution_failed','complete'])+'|')
lines += ['', '四类互斥且合计128。图册还展示每杆失败的固定优先级归因及9点单轴探针。轴向边界通过不证明完整连续容错窗口；不同杆法同时改变名义停点与第二杆条件，不能把表中的差异全部归因于打点本身。可以在图册选择相同顺序和袋口对，观察各首杆打法的区别。','', '## 球形与证据','']
for k in ['cue','a','b']:lines.append(f'- {k}: X/Z={sample[k]}m。')
lines+=['- 选用上一轮已有接续见证的B#1233，当前研究前固定；不是随机样本，也不证明对任意球形都有效。','- 生产物理源码使用受管冻结副本；源码身份与Git差异见snapshot-hashes.json、source-base.json及frozen-source-delta/。','- 原始scan/design/holdout JSON、输入种子、候选与排名哈希均保留。实际日志位置见run-paths.json。','- 第二杆独立扰动的方向、速度、横纵打点由analyze.py逐条重建检查；完整成功必须同时满足首杆资格、另一球未动和第二杆资格。','- 构建、XCTest、浏览器与资源收尾的最终结果见FINAL-AUDIT.md；未执行原生App页面验收、真机或真人误差标定。','- 本轮不是全杆法最优搜索；第二杆速度/打点固定的策略可能低估允许临场更换杆法的打法。几何与求解器可达性不能替代真人持杆难度。']
(P/'REPORT.md').write_text('\n'.join(lines)+'\n');print('Report written')
