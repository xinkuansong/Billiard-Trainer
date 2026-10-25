from pathlib import Path
import json,hashlib,csv
import numpy as np
OUT=Path(__file__).resolve().parent
D=json.loads((OUT/'metrics.json').read_text());diag=json.loads((OUT/'diagnostics.json').read_text());summary=json.loads((OUT/'convergence-summary.json').read_text())
raw=json.loads((OUT/'engine-trajectories.json').read_text());scope=json.loads((OUT/'scope-validation.json').read_text());checks=json.loads((OUT/'swift-validation.json').read_text())
assert checks['passed'] and checks['pairCount']==36 and scope['passed']
assert len(scope['included'])==9 and len(scope['excluded'])==6
assert (OUT/'engine-trajectories.json').read_bytes()==(OUT/'full-shot-v1/engine-trajectories.json').read_bytes()
def table(headers,rows):return '| '+' | '.join(headers)+' |\n|'+'|'.join(['---']*len(headers))+'|\n'+'\n'.join('| '+' | '.join(map(str,r))+' |' for r in rows)+'\n'
rows=[r for r in D['engine'] if r['budget']==512];assert len(rows)==36
repeat=next(r for r in rows if r['a']=='pot_center' and r['b']=='pot_repeat')
assert all(repeat[k]==0 for k in ['frechet','dtw','chamfer'])
pts=json.loads((OUT/'display-trajectories.json').read_text());dom=0
for r in rows:
 a=np.array(pts[r['a']]);b=np.array(pts[r['b']]);end=max(np.linalg.norm(a[0]-b[0]),np.linalg.norm(a[-1]-b[-1]));dom+=abs(end-r['frechet'])<.01
for audit in scope['included']:
 p=np.array(pts[audit['id']]);assert np.isfinite(p).all()
 assert np.linalg.norm(p[0]-np.array(audit['contactPosition_m'])*100)<1e-10
old=json.loads((OUT/'full-shot-v1/metrics.json').read_text());oldpairs={(r['a'],r['b']):r for r in old['engine'] if r['budget']==512}
comparison=[]
for r in rows:
 prev=oldpairs[r['a'],r['b']]
 comparison.append({'a':r['a'],'b':r['b'],**{f'{phase}_{k}':v[k] for phase,v in [('fullShot',prev),('postContact',r)] for k in ['frechet','dtw','chamfer']}})
with (OUT/'scope-comparison.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=comparison[0].keys());w.writeheader();w.writerows(comparison)
lengths=[x['removedApproachLength_cm'] for x in scope['included']]
sec=f'''## 比较范围修正：只比较击中目标球后的走位

上一版确实包含母球到目标球的来球段，不符合本次用户要比较碰后走位的要求。该版保存在 `full-shot-v1/`，其真实轨迹数值和采样结论不再作为当前任务结果。

现行范围：**从首次击中指定目标球时的母球球心位置开始，到该母球真实停球或落袋为止**。从原始模拟器记录裁切，未重新仿真，也未修改物理引擎或业务代码。先裁切再弧长重采样，全部三项距离、分数、9×9 矩阵、图形及密度收敛均已重算。

- 原始 15 条记录完整保留；9 条有目标球碰撞，形成 36 对 × 5 密度 = 180 组真实比较。6 条自由球没有目标碰撞，已移出主对比。
- 九条逐一核对精确碰撞时间/位置，删除的碰前长度范围 {min(lengths):.3f}–{max(lengths):.3f}cm。起点采用母球球心，不是目标球球心或球面接触点。
- 保留各自真实桌面位置，不独立归零，不平移对齐。所有原终点与碰后碰库事件保留。碰后若还有球球碰撞，继续保留；没有把相同运动位置全局去重。
- 固定仿真球形只有一颗目标球，故本批 `ball` 事件能确认目标身份。一般 App 场景必须传入目标球 ID，不能把任意首次碰球都视作指定目标。
- `scope-validation.json` 保存逐条裁切索引、起点、删去长度、终点不变及无碰前时间检查；另覆盖未碰球拒绝、同刻最后提交帧、碰后单点静止、后续碰库保留。原始 JSON 与归档逐字节一致。

## 修正前后对比（512 基础点，单位 cm）

'''
selected=[r for r in comparison if r['a']=='pot_center' and r['b'] in ['pot_side_small','pot_right','pot_follow','pot_draw','pot_fast','pot_multirail']]
sec+=table(['对比（均与中杆）','F 完整→碰后','DTW 完整→碰后','Chamfer 完整→碰后'],[[r['b']]+[f"{r['fullShot_'+k]:.3f} → {r['postContact_'+k]:.3f}" for k in ['frechet','dtw','chamfer']] for r in selected])
sec+='\n右塞等案例中，去掉较长的共同来球段后，DTW/Chamfer 变大，更明确地反映碰后差异。Fréchet 多数几乎不变，是因为原先的最大保序匹配偏差就在碰后段或终点。高杆的平均指标反而略降：裁切会同时改变归一化分母、匹配路径与采样网格，不能断言所有平均距离都必然增大。\n\n'
sec+=f'''## 修订后的算法判断与精度

仍建议 Fréchet 为主，DTW/Chamfer 分列辅助，不预设综合权重。构造几何反例与真实碰后仿真分开：20cm 窄尖峰在 512 时 F=20.001、DTW=1.604、Chamfer=0.971cm；200cm 同路反向的 Chamfer 近零；交叉闭环交换次序同样暴露空间最近邻匹配的局限。构造案例不声称都可由实际击球实现。

在 36 对碰后轨迹中，512 对照 2048 的最大差分别为 F **{summary['512']['frechet']['max']:.6f}cm**、DTW **{summary['512']['dtw']['max']:.6f}cm**、Chamfer **{summary['512']['chamfer']['max']:.6f}cm**；1024 时为 {summary['1024']['frechet']['max']:.6f}、{summary['1024']['dtw']['max']:.6f}、{summary['1024']['chamfer']['max']:.6f}cm。三项在本批 512 的经验差均低于 0.1cm。

这不是普适精度证明：{dom}/36 对 F 与起终点下界相差不超过 0.01cm，容易显得格外稳定；512 最长采样边 {summary['512']['maxEdge']:.4f}cm，最大同弧长重建差 {summary['512']['maxReconstructionError']:.6f}cm。未来更长/复杂的碰后轨迹仍需按误差界和收敛复算加密。2048 是经验参考，不是精确连续真值。

512 时弧长加权 Chamfer 与普通点平均最大差为 {max(abs(x['difference']) for x in diag['weightedChamfer']):.4f}cm；排序诊断详见 `diagnostics.json`。分数仍使用 T50=10cm 作展示，未标定训练等级。

## 加权消融（T50=10cm，纯几何反例）

'''
comb=[]
for name in ['local_spike','reverse','truncated','loop_order']:
 vals=[r for r in diag['weightSensitivity'] if r['id']==name and r['t50']==10]
 comb.append([name]+[f"{r['scoreBlend']:.2f}" for r in vals]+[f"{vals[1]['distanceBlendScore']:.2f}"])
sec+=table(['案例','纯 F','分数权重 .7/.2/.1','分数等权','距离权重 .7/.2/.1 后映射'],comb)
sec+='\nChamfer 高分会抬高反向/错序轨迹分数，平均指标也会弱化局部尖峰。当前保留分歧用于解释，不将某一组合宣称为最优。\n\n'
base=(OUT/'REPORT-base.md').read_text().replace('## 结论与采用建议',sec+'## 结论与采用建议',1)
base+='\n'+(OUT/'RESULTS.md').read_text()
run=json.loads((OUT/'run-paths.json').read_text())
base+=f'''\n## 执行证据与版本边界

- 原始数据来自此前冻结源码副本在 iPhone 16 Pro Max / iOS 26.3 Runtime 的真实模拟器测试：`TrajectorySimilarityResearchTests/testExport` 1 项，0 失败，导出 15 条轨迹。日志与 xcresult：`{run['evidence']}`。
- 本次是基于该批原始记录的离线范围修正，未再次启动模拟器。原运行的设备租约及构建目录已收尾，历史记录见 `final-inventory.json` 与 `run-paths.json`。
- 本次完成 9 条裁切审计、36 对 × 5 密度真实比较、12 反例 × 5 密度比较；60 对穷举与 30 组坐标变换检查通过。Swift 独立实现对拍 36 对 × 3 指标，最大差 {checks['maxErrorCM']}cm。
- 只绑定原始冻结快照及其源码哈希，不声称验证当前并发改动后的共享工作树、App 集成、真机性能或全项目回归。
- 新版静态轨迹图已目视核对，HTML 内嵌数据已解析核对。浏览器安全策略拒绝访问现有 file:// 标签页，本次未完成浏览器刷新/交互复验；旧截图明确归档。
- 当前报告、矩阵及图册全部使用碰后数据；修正前后 36 对结果见 `scope-comparison.csv`，旧版仅留作历史追溯。
'''
(OUT/'REPORT.md').write_text(base)
manifest={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in OUT.iterdir() if f.is_file() and f.suffix in ['.py','.swift','.cpp','.json','.csv','.png','.html','.md'] and f.name!='manifest.json'}
(OUT/'manifest.json').write_text(json.dumps({'files':manifest,'scope':'postTargetContact','rawEngineCount':15,'engineCount':9,'realComparisons':180,'syntheticComparisons':60,'productionPhysicsChanged':False},indent=2))
print('Finalized post-contact report:',len(base),'characters')
