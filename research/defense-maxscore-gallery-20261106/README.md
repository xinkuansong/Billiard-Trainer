# 按最高防守分筛初始球形（2026-11-06）

输出六档70／75／80／85／90／95，每档10图。目标是比较球形的区域防守潜力，不做击球求解或题库替换。

口径：固定对方9号位置，扫描母球位置；使用冻结的现行生产 `DefenseEffect` 合法结束态分支、PocketPipe及球桌几何。在每个位置先取对方六袋最佳进攻机会对应的防守分，再取可用扫描点的最大防守分。原题8号和母球只作显示参照，不参与遮挡。

- 排除母球与9号球心距不足30cm的位置，防止仅靠极近球点得出高分。30cm是本次研究暂用参数，不是已确认产品规则。
- 各档为目标分±2.5，左闭右开，不将分数取整后冒充实际最高分。
- 5cm粗网格；分类变化、分数变化、近库及最高24格加密至≤2cm；最高8个叶格进一步细采样至≤5mm。最高分取粗、细、峰值样本的并集。并未证明连续全局最大值；不是最优落点求解。
- 每个镜像等价目标位置只保留一个朝向（绝对坐标保留5位小数去重）。原始两球题优先；缺额从其他题型保留原始坐标、显式调整角色：两球1/8改为8/9，或三球1/8/9去掉1号。每例保存原题、适配说明及原始ID。补充图不是未经改动的原始训练题。
- 不加入面积或区域宽度淘汰标准，不预设杆法、吃库数，也不证明母球能打到高分区域。

运行环境：macOS、Xcode iOS Simulator、Python3。绘图Python环境需安装numpy、matplotlib。

```sh
python3 scripts/local_test_lifecycle.py run --task defense-maxscore-gallery-20261106 -- python3 research/defense-maxscore-gallery-20261106/workflow.py /path/to/plotting-python
```

`workflow.py`依次准备原题、冻结和编译生产源、受管模拟器运行、补充原始坐标样本、审计60图、渲染。共享模拟器由fleet申请/释放，运行前后boot/shutdown。成功后local-test生命周期回收工作副本，保留证据与源快照。

结果入口：`output/defense-maxscore-gallery-20261106/index.html`；六张10图总览 `class-*.png`；单图 `images/*.png`；`gallery.md`、`selected.json`、`validation.json`、两轮原生逐点数据和日志。

本轮首次编译成功，但研究脚本曾命名为`select.py`遮蔽Python标准库，导致启动worker失败；已重命名为`select_cases.py`，复用同一已编译二进制完成两轮原生运行。保留首次失败日志与恢复执行证据，不重复编译或改生产评分。
