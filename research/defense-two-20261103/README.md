# 两颗目标球：遮挡防守样题

[任务卡](../../tasks/DEFENSE-TWO-20261103.md)。这是独立研究生成器，不修改动作库录制或App题库。

两分支：A我方1号、对方8号；B我方8号、对方9号。合法碰我方球后，让它成为母球与对方目标之间的挡球。输入包括母球共三球；不能先碰对方球，也不能通过入袋制造继续进攻。

`run.py`冻结当前QiuJi Swift源码、真实球杆/球桌资产和c060来源记录，通过受管模拟器运行CLI。`main.swift`先提出布局，再完整模拟三球、核出杆避让、合法性、精确回放和8个方向/速度联合探针。`review.py`独立用二次方程扫描完整直击角域，复核分数和事件，输出研究图册。

从仓库根运行，先遵循模拟器使用技能和生命周期规则。指定新的输出目录，保留既有失败和成功证据：

```sh
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-two-next" python3 scripts/local_test_lifecycle.py run --task defense-two-next -- python3 research/defense-two-20261103/run.py
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-two-next" python3 research/defense-two-20261103/review.py
```

绘图依赖rsvg-convert；独立舒适度算术复用前轮`research/defense-pilot-20261103/review.py`中的纯函数（通过AST提取，不执行前轮IO），review-source.json记录两者哈希。

完整遮挡采用保守充分条件，并独立扫描4097条射线：母球中心无法沿直线先碰到对方目标球任何薄边。它不评价吃库解球、跳球、弧线和后续回合。100是本轮遮挡目标达成，不能当赢球概率或题目难度；探针保持遮挡也不是实台容错率。

产物包含questions.json、少量未通过稳健性筛选的diagnostics.json、summary.json、源码与资产清单、源码快照、执行漂移记录、audit.json、逐题SVG/PNG及review.html。初轮编译命名冲突失败保留在根输出，r2为重跑目录。最终状态以任务卡为准。
