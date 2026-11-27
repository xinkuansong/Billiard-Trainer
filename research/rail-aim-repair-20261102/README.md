# 近库瞄准补偿回归

固定样本来自正式准度题库的 50 个球形，保留原始 Float 坐标与题号；每题 15 组力度/横塞，共 750 组。`baseline.json` 固定修复前两条预测入口的合法直进结果，以及诊断确认的微调可救回样本。不是随机总体进球率估计。

```sh
python3 scripts/simulator_fleet.py run --role large-phone --task rail-aim-repair -- \
  python3 scripts/local_test_lifecycle.py run --task rail-aim-repair -- \
  python3 research/rail-aim-repair-20261102/run.py '{udid}'
python3 research/rail-aim-repair-20261102/check.py
```

运行前归档已有 `output/rail-aim-repair-20261102/results.jsonl`，脚本拒绝追加不同轮结果。工作目录由生命周期管理器创建/回收。编译冻结全部生产 Swift 源码及诊断 main，仅在快照中去掉 App 的 `@main`；SDK/target 为 iOS Simulator，执行真实生产物理与求解代码。无需安装或改写现有 App 数据。

检查：

- 普通预测与走位预测：所有原成功样本保留，44 个已证实半贴库漏解全部恢复。
- 750 组搜索/完整模拟合法进球一致；固定 offset 回放事件、时刻与方向不变。
- 96 组高低杆、左右塞及两轴镜像：种子成功不退步，新增补偿必须合法，搜索/完整模拟一致。
- 显式旧方向仍保留原 miss；取消与截断不伪造成功；拒绝二次目标碰球和其他袋嘴。
- 正式 `PositionPlaySolver.solve` 的固定力度/杆法网格确实消费新补偿，并找到实际目标落区。

`check.py` 输出分层配对统计及模拟器热耗时，并报告源码漂移。不是完整 XCTest/App UI/真机或发布验收。

`frozen/run.py` 另对 10 个贴库球形的 50 组输入做完整引擎 ±6° 宽扫，跳过已合法进袋的输入；用同一受管命令替换脚本路径运行，结果写入 `output/rail-aim-repair-20261102/frozen/`，用 `frozen/check.py` 汇总。它是排查工具，不要求所有给定杆法必然能进，也不将有限扫描失败当作无解证明。
