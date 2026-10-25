from pathlib import Path
import json,html
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
s=json.loads((OUT/'summary.json').read_text());rs=s['rounds'];best=min(rs,key=lambda r:r['computeAndWriteSeconds'])
rows=[]
for r in rs:
 rows.append(f"| {r['workers']} | {r['computeAndWriteSeconds']:.2f}秒 | {r['includingStartupSeconds']:.2f}秒 | {r['peakRSSGiB']:.2f} GiB | {r['speedupVs8']:.2f}× | {r['fullBankEstimatedHours']:.2f}小时 |")
text=f'''# 125组单次击球：8 / 12 / 16进程对照

同一批1,000球形、每球形同样125组，依次8、12、16进程，各测一次。每轮125,000次尝试，100,061个有效组合；三轮逐字段核对与原先测试的物理结果、母球落点、参数和2mm关键点完全一致（排除耗时字段）。不微调方向，失败不补抽。

| 进程 | 计算＋压缩写入 | 含设备与worker启动 | 峰值RSS合计 | 相对8进程吞吐 | 全库计算线性估算 |
|---|---:|---:|---:|---:|---:|
{chr(10).join(rows)}

本轮最快为 **{best['workers']}进程**。全库估算按135,700/1,000倍换算，不含全库审计，未验证小时级持续运行的温度与频率变化；单次测量不能证明稳定最优。

## 内存口径

每100毫秒目标间隔调用ps读取RSS，取同一时刻所有原生worker、Python控制/JSON处理/压缩写入进程、simctl包装进程的RSS合计最大值。单位GiB=2^30字节。包括测试监控线程本身，不含共享CoreSimulator服务、系统及其他应用；共享映射页可能被重复计入，不等于整机新增物理内存。该值是采样峰值，不是系统保证的精确最高水位。实际采样间隔与逐PID记录均归档。

## 计时与一致性

- 与原测试复用同一冻结原生二进制、同一输入SHA和采样种子，未重编译或改动物理规则。
- 每轮独立控制进程和新worker，100个10球形任务动态派发；每轮同样保留前20球形的100条完整轨迹审计fixture。
- 为消除原脚本5秒轮询造成的结束计时误差，三轮统一100毫秒轮询；因此以本次8进程为比较基准，不混用旧70.08秒。
- 每轮已有的61条同时间戳吃库事件，比较时按原始事件顺序应用与先前一致的元数据归一化；原始文件不覆写，轨迹坐标与物理结果无变化。
- 所有375,000条记录、3,000球形、每轮125组不重复、gzip SHA、原生进程数和正常退出均通过审计。模拟器由统一fleet持有租约，三轮后关机归还。
- 仅测试1,000球形，没有启动135,700全量。

[结构化统计](summary.json) · [测试代码](../../research/{HERE.name}/run_round.py) · [内存采样](p16/memory.json)
'''
(OUT/'README.md').write_text(text)
trs=''.join(f"<tr><td>{r['workers']}</td><td>{r['computeAndWriteSeconds']:.2f}秒</td><td>{r['peakRSSGiB']:.2f} GiB</td><td>{r['speedupVs8']:.2f}×</td><td>{r['fullBankEstimatedHours']:.2f}小时</td></tr>" for r in rs)
page=f'''<!doctype html><meta charset="utf-8"><title>8 / 12 / 16进程对照</title><style>body{{font:18px -apple-system,sans-serif;max-width:1100px;margin:50px auto;padding:24px;background:#f5f7fa;color:#203342}}h1{{font-size:32px}}table{{width:100%;border-collapse:collapse;background:white}}td,th{{padding:20px;text-align:left;border-bottom:1px solid #dde3e8}}p{{line-height:1.8}}.small{{color:#5e6b77;font-size:15px}}</style><h1>同一批1,000球形 · 并发性能对比</h1><p>每球形125组，不微调方向；成功保存2mm关键点。每轮有效组合100,061个，三轮物理结果和关键点完全一致。</p><table><tr><th>进程数</th><th>计算与写入</th><th>峰值RSS合计</th><th>相对8进程吞吐</th><th>全库计算估算</th></tr>{trs}</table><p>本轮最快：<b>{best['workers']}进程</b>。测试范围为1,000球形，尚未启动全量。</p><p class="small">RSS每0.1秒目标间隔采样，包括计算worker、Python控制和写入、simctl包装进程，不含共享模拟器服务和其他应用。共享映射页可能重复计数。全库耗时为线性估算，不含全库审计；三档各测一次，尚未测试长时间温升影响。</p>'''
(OUT/'index.html').write_text(page)
gallery=ROOT/'output/two-ball-multi-position-top10-20261024';(gallery/'concurrency125.html').write_text(page)
print(text)
