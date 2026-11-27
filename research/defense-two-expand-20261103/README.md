# 两球遮挡扩展：长库与离库回藏

沿用首批两球的合法性、进攻困难、完整直击遮挡和8个微调探针要求。本轮每个球形类别分别覆盖我方1号/对方8号、我方8号/对方9号。

- `longRail`：我方球起始球面距长库0.02–0.16米，离短库≥0.3米。
- `openTable`（r2）：我方球起始距各库≥0.22米。由母球或目标球完成碰后碰库，母球是否首碰后碰主库由真实事件索引0–5单独记录。r1的`openBank`额外要求母球吃库，其有限搜索只找到一个分支；原5道合格个案和配额失败记录保留。
- 每组拟选四题，每分支两题。生成参数是候选提议，完整三球模拟和独立审计才决定资格；不保证有限搜索一定填满。
- 追加两档方向/速度联合扰动各8杆，原始结果全部保留，不把8杆计数解释为成功概率或正式题目难度。

运行前遵循模拟器使用技能。默认使用large-phone核心角色；繁忙时入口拒绝，禁止抢占或新建独立池。所有源码冻结在受管工作目录，退出成功自动回收，证据另存。

```sh
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-expand-next" DEFENSE_SIM_ROLE=large-phone python3 scripts/local_test_lifecycle.py run --task defense-expand-next -- python3 research/defense-two-expand-20261103/run.py
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-expand-next" python3 research/defense-two-expand-20261103/review.py
```

从仓库根运行；绘图依赖rsvg-convert。review复用前轮单球Python舒适度纯函数，与生产Swift独立；源码哈希写入review-source.json。冻结生产源码、资产、c060战术来源与逐题事件/轨迹均归档。研究图册不属于App页面，不改正式题库或动作库录制。

结果与范围以[本轮卡](../../tasks/DEFENSE-TWO-EXPAND-20261103.md)为准。完整遮挡100仅代表直击目标达成；吃库解球、跳球、弧线和后续回合未评估。


## 本轮交付

r1有5个物理合格个案但未满离库配额，退出码1保留；r2有8个物理合格个案。合并按角色几何去重后仍8题。教学筛选为5道优先待审、3道袋角诊断暂缓；参考与小扰动中碰袋角的题不能混入基础组。

```sh
python3 research/defense-two-expand-20261103/assemble.py
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-two-expand-20261103/review" python3 research/defense-two-expand-20261103/review.py
```

最终`review/source-map.json`绑定原始路径、题号与文件SHA-256；审计核对整题记录。8次精确回放、64个小扰动、128个较大扰动均保留。最终图册在`output/defense-two-expand-20261103/review/review.html`。主图与露球对照已目视；不将静态图核验宣称为浏览器交互或App验收。
