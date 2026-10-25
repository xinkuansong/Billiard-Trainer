from pathlib import Path
import json,hashlib
import numpy as np
OUT=Path(__file__).resolve().parent
D=json.loads((OUT/'metrics.json').read_text());diag=json.loads((OUT/'diagnostics.json').read_text());summary=json.loads((OUT/'convergence-summary.json').read_text());raw=json.loads((OUT/'engine-trajectories.json').read_text())
checks=json.loads((OUT/'swift-validation.json').read_text());assert checks['passed']
def table(headers,rows):return '| '+' | '.join(headers)+' |\n|'+'|'.join(['---']*len(headers))+'|\n'+'\n'.join('| '+' | '.join(map(str,r))+' |' for r in rows)+'\n'
rows=[r for r in D['engine'] if r['budget']==512]
assert len(rows)==105
assert next(r for r in rows if r['a']=='pot_center' and r['b']=='pot_repeat')['frechet']==0
pts=json.loads((OUT/'display-trajectories.json').read_text());dom=0
for r in rows:
 a=np.array(pts[r['a']]);b=np.array(pts[r['b']]);end=max(np.linalg.norm(a[0]-b[0]),np.linalg.norm(a[-1]-b[-1]));dom+=abs(end-r['frechet'])<.01
for name,p in pts.items():
 assert all(np.isfinite(p).flat)
maxgap=max(r['maxReconstructionGap_m'] for r in raw['rows'])*100
sec=f'''## 本轮实测判断（先看这里）

1. **确定性**：同样输入两次独立引擎运行，三项距离均为 0。几何上平行偏移 2cm 时，三项均为 2cm；同一路径改变原始点密度，经正确重采样三项均为 0。
2. **局部最大偏差**：20cm 窄尖峰得到 F=20.001cm、平均 DTW=1.604cm、Chamfer=0.971cm。以 T50=10cm 示范，分别为 25.0、89.5、93.5 分。DTW 对齐中约 86% 的匹配距离低于 1cm，解释了大偏离如何被大量重合段稀释。这是不同统计语义，不是 DP 计算错误。
3. **长度与终点**：同一路线截短 60cm，F=60cm，而平均 DTW=7.036cm、Chamfer=4.593cm。完整路线任务中，保序端点约束能明确保留少走一大段的差别；无需再额外加入终点罚分。
4. **方向/顺序**：200cm 直线路径反向，F=200cm、平均 DTW=100.196cm，Chamfer≈0。重复往返得到 F≈100.196cm，而 Chamfer≈0。交叉闭环交换遍历次序，F≈72.111cm，Chamfer 仅约 0.431cm（有限采样误差；连续空间支撑集相同）。
5. **真实同球形比较**：中杆与小右塞 F=4.424cm；中杆与高杆 F=1.926cm；中杆与右塞 F=81.553cm。后者有较长共同前段，DTW=11.044cm、Chamfer=6.913cm，进一步说明仅用平均空间偏差会给出更宽松的判断。
6. **不同碰库/交叉线路**：真实中杆主库 1 次，5.21m/s 右高杆主库 2 次，F=105.145cm；自由球 4.50m/s 轨迹总长 636.82cm。库次数未加到分数。本批自由球包括袋嘴反弹，主库/袋角事件分开列示，不能把袋角事件误标为标准主库次数。
7. **小输入变化不保证小几何变化**：自由球方向由 22° 改为 22.5° 后母球落袋，完整轨迹 F=156.283cm。此处低相似度来自真实仿真结局改变；不应为了“只差 0.5°”调评分使其显得接近。
8. **512 点的局限**：105 对真实线路中，512 对照 2048 的最大 F 差为 {summary['512']['frechet']['max']:.6f}cm，平均 DTW 差为 {summary['512']['dtw']['max']:.6f}cm，Chamfer 差为 {summary['512']['chamfer']['max']:.6f}cm。F 看起来特别稳定，部分原因是 {dom}/105 对由起终点下界主导（差≤0.01cm）；不能据此推广到所有中段复杂偏离。512 的最长边仍有 {summary['512']['maxEdge']:.3f}cm，保守界明显宽于经验差。
9. **辅助量加密**：1024 对照 2048 的最大平均 DTW 差仍为 {summary['1024']['dtw']['max']:.4f}cm。若要求辅助量 0.1cm 精度，不能说 1024 已全部达标，应继续加密。symmetric2 在 512/1024 的最大参考差约 0.3545/0.1181cm，较好但仍不是无误差。
10. **点权重与排序**：512 时弧长加权 Chamfer 与普通点平均的最大差为 {max(abs(x['difference']) for x in diag['weightedChamfer']):.4f}cm。对参考差超过 0.1cm 的成对排名，平均 DTW 在 512 出现 2 次次序翻转，1024 为 0；F 各档为 0。本批没有证明普通路径均值 DTW 比 symmetric2 更稳定，建议保留定义与收敛元数据。

源轨迹解析重建与实际引擎帧的最大端点差为 {maxgap:.6f}cm，远小于主采样间距。它是 Float 推进/碰撞位置修正等记录差的观测值，不是物理模型的真实世界误差保证。

## 加权组合消融（T50=10cm，仅展示为什么暂不定权重）

'''
comb=[]
for name in ['local_spike','reverse','truncated','loop_order']:
 vals=[r for r in diag['weightSensitivity'] if r['id']==name and r['t50']==10]
 comb.append([name]+[f"{r['scoreBlend']:.2f}" for r in vals]+[f"{vals[1]['distanceBlendScore']:.2f}"])
sec+=table(['案例','纯 F','分数权重 .7/.2/.1','分数等权','距离权重 .7/.2/.1 后映射'],comb)
sec+='\n对反向路线，分数加权中的 Chamfer 权重会直接贡献接近满额的高分；局部尖峰同样被平均量抬分。当前选择纯 F 作为主评价，同时保留辅助解释，不宣称其他权重没有任何用途。\n\n'
base=(OUT/'REPORT-base.md').read_text()
base=base.replace('## 结论与采用建议',sec+'## 结论与采用建议',1)
base+='\n'+(OUT/'RESULTS.md').read_text()
run=json.loads((OUT/'run-paths.json').read_text());record=json.loads((Path(run['work']).parent/'run.json').read_text())
inv=json.loads((OUT/'final-inventory.json').read_text());device=next(x for x in inv['devices'] if x['udid']=='16D968CB-FA14-4E00-B79F-0D675D80179E')
assert device['state']=='Shutdown' and not any(x.startswith('leased:') for x in device['reasons'])
base+=f'''\n## 本轮执行与收尾记录

- 设备：iPhone 16 Pro Max，iOS 26.3 Runtime（本机配置实际为 26.3.1）；UDID `{device['udid']}`。
- 实际结果：`TEST BUILD SUCCEEDED`；`TrajectorySimilarityResearchTests/testExport` 执行 **1 项，0 失败**，导出 15 条轨迹。105 对 × 5 密度 = 525 组真实比较；12 反例 × 5 密度 = 60 组构造比较。
- Swift 对拍：105 对、3 项距离，最大差 {checks['maxErrorCM']}cm；60 对穷举与 30 组坐标变换检查通过。浏览器中的反向/尖峰案例、采样和映射切换已核对。
- 日志与 xcresult：`{run['evidence']}`；对应 `run.json` 状态为 `{record['state']}`。
- 构建工作目录已由生命周期入口回收。模拟器最终 Shutdown，无本任务租约；设备与数据保留。脚本的额外 shutdown 返回“已经 Shutdown”，该返回本身不是成功关机证据，最终状态和租约检查另存 `final-inventory.json`。
- 运行期间其他会话修改了 20 个业务/展示文件，见 `source-drift.json`；没有本轮物理源码漂移。结果只绑定冻结快照，不声称覆盖之后的共享工作树。
'''
(OUT/'REPORT.md').write_text(base)
manifest={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in OUT.iterdir() if f.is_file() and f.suffix in ['.py','.swift','.cpp','.json','.csv','.png','.html','.md'] and f.name!='manifest.json'}
(OUT/'manifest.json').write_text(json.dumps({'files':manifest,'testRun':str(Path(run['work']).parent),'engineCount':15,'realComparisons':525,'syntheticComparisons':60,'productionPhysicsChanged':False},indent=2))
print('final report',len(base),'characters; files',len(manifest))
