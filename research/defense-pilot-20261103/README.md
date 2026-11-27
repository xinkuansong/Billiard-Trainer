# 单8号纯防守样题试验

内容与结果：[任务卡](../../tasks/DEFENSE-PILOT-20261103.md)。本目录不接入App或正式题库。

`main.swift`复用冻结的生产物理、进攻几何候选、舒适度与球杆避让；`run.py`负责源码/资产清单、受管构建和模拟器CLI；`review.py`用独立算术复核记录并绘制引擎轨迹。当前生成器为r2；根输出目录保留r1，r2目录为本轮审阅版本。

从仓库根运行。重新生成时指定新输出目录，避免覆盖既有证据；需按模拟器技能和生命周期规则执行：

```sh
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-pilot-next" python3 scripts/local_test_lifecycle.py run --task defense-pilot-next -- python3 research/defense-pilot-20261103/run.py
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-pilot-next" python3 research/defense-pilot-20261103/review.py
```

绘图依赖`rsvg-convert`。输出包括questions.json原始题目/事件/轨迹、源码快照、资产清单、执行漂移检查、独立审计、审阅状态、HTML与逐题SVG/PNG。复核已有r2只需第二条命令改用已有r2路径。

本次r2六道候选：D1-01/02/04/06可审阅；D1-03/05暂缓。评分为100减对方最好直攻舒适度，不是进球概率或全面战术评价；无直攻候选单列未评分，不强行赋100。搜索有限，参考杆未证明全局最优。方向与速度各两次单变量扰动不代表完整容错验证。研究图册非App界面，不作为真机或实台验收。
