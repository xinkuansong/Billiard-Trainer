# 三颗目标球：双方各一颗加8号

研究样题，我方1号/对方9号/公共8号，母球另计。用己方球、8号或两球共同遮挡9号。本批不推动8号/9号、不允许参考与小扰动碰袋角；必须合法首碰1号、无入袋、碰后有球碰库、完整停稳。

`proposals.json`绑定前轮几何及杆法的来源哈希，仅作新布局提议。`main.swift`冻结生产引擎进行完整四球复验、精确回放和小/大扰动。`review.py`独立连续区间减法证明与4097条射线核验，并生成真实轨迹图。两侧边缘被挡不代表中间没缝，包含专门反例。

```sh
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-three-20261103" DEFENSE_SIM_ROLE=large-phone python3 scripts/local_test_lifecycle.py run --task defense-three-20261103 -- python3 research/defense-three-20261103/run.py
python3 research/defense-three-20261103/review.py
```

先按模拟器技能检查租约和资源。图形渲染依赖rsvg-convert；运行从仓库根执行。禁止覆盖运行中的源码快照，改版另建输出目录。原始配额失败保留，不删断言凑满。

范围、实际数量及验证结果以[任务卡](../../tasks/DEFENSE-THREE-20261103.md)为准。正式动作库、题库和App不变；100是直击遮挡达成，不是难度/解球难度/胜率。


首批结果：6道（三类各2），1267次模拟、6次精确回放、48小扰动、96大扰动；独立审计通过。6主图/6对照图已审，正式题目难度未校准。母球与1号起点使用前轮长库种子，重点对照新增8号的作用，不宣称覆盖全部三球球形。
