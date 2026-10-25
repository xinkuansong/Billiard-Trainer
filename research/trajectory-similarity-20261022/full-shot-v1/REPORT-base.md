# 母球二维轨迹相似度技术验证

日期：2026-10-22。范围：研究验证；没有修改现有物理引擎、业务代码或正式测试文件。所有新增可执行研究代码位于本目录；测试插入冻结源码副本。交互入口：[report.html](report.html)。

## 结论与采用建议

建议采用 **离散 Fréchet 为主，平均 DTW 与双向 Chamfer 分列辅助**，目前没有依据确定一个最优加权分数。三者测量不同性质；合并会掩盖有用的分歧。方向反转、重复走同一条线路、交叉处次序变化等反例，证明 Chamfer 不适合单独作为母球完整轨迹评分。DTW 会以一对多匹配压缩局部异常的平均影响，需与最大偏差一起解释。

512 是合理的初始计算密度，不是固定精度承诺。保留起点、终点、球球碰撞和碰库折点，再按弧长均匀采样；实际点数为基础 N 加上未重合的事件点。长线路按物理间距和误差上界加密。不要为了“每条恰好 512 点”丢掉关键点。

本研究检验算法的几何合理性和实现一致性；不重新证明物理模型对真实台球的准确性，也没有真人相似度标注。因此不能声称得到感知或教学意义上的最优权重、正式分档阈值或真实设备性能结论。

## 数据来源与复现

- 当前主仓库 HEAD：`8264960b91f45f67ef9249ec1e237491b00e4ffb`。工作树已有其他任务改动；实际快照身份以 `source-hashes-before.json` 和 `snapshot-hashes.json` 为准，不等同于纯 HEAD 构建。
- `Research.swift` 在冻结副本中追加到 `PhysicsEngineTests.swift`，通过 iOS 模拟器实际运行 `TrajectorySimilarityResearchTests/testExport`。
- 使用正式 `ShotPredictor.predict` 为不同力度/打点求瞄向，再由 `ShotPredictor.simulateFree` 重新完整仿真。后者采用 `.appDefault`、`highFidelityBounds=true`、`includePresentation=false`；`maxEvents=2000`、`maxTime=90`，不以截断运动冒充停球。
- 生成 9 条目标球击打轨迹（包括一次完全相同输入重复运行）和 6 条自由母球轨迹。参考图启发了“同球形、不同打点/力度”的实验设计，但没有反推截图中的精确世界坐标；这不是三张截图的精确复刻。
- 目标球案例：母球 XZ=(-0.40,0)m，目标球=(0.55,-0.18)m，袋口 index=1。自由球从 (-0.80,-0.25)m 出发，基准方向 22°。高力度 5.21m/s 与用户示例对应，为引擎实验参数，不据此认定每个页面均开放该上限。
- 导出原始帧、事件、终止状态、实际输入和方向；所有球坐标使用世界 X–Z 平面。1ms 间隔按当前帧运动状态调用生产 `AnalyticalMotion` 重建事件之间的连续运动，同时保留每个原始记录点。重建终点与下一真实帧独立对照，误差不超过测试断言的 0.0001m；实际最大值见补充实测结论。
- 捕获终点取 `PocketEntrySnapshot`，排除收球动画、袋下呈现和消失后的移动；本批实际是否出现 scratch 由目录和原始文件给出。未来涉及飞行/三维落袋，二维投影不能代表完整三维相似性。
- 不使用 `TrajectoryRecorder.stateAt` 进行插值（该接口返回相邻帧），也不使用展示层简化后的 `cuePath` 作为几何真源。

复现命令（仓库根目录；需要本机 Xcode/已安装模拟器，设备经统一租约入口）：

```sh
python3 scripts/local_test_lifecycle.py run --task trajectory-similarity-research -- python3 research/trajectory-similarity-20261022/run.py work '{work}' '{evidence}'
xcrun clang++ -O2 -std=c++17 -shared -fPIC research/trajectory-similarity-20261022/metrics.cpp -o research/trajectory-similarity-20261022/metrics.dylib
build/break-potting-research-20261002/plot-venv/bin/python research/trajectory-similarity-20261022/analyze.py
build/break-potting-research-20261002/plot-venv/bin/python research/trajectory-similarity-20261022/diagnostics.py
build/break-potting-research-20261002/plot-venv/bin/python research/trajectory-similarity-20261022/report.py
xcrun swiftc -O research/trajectory-similarity-20261022/TrajectorySimilarity.swift research/trajectory-similarity-20261022/main.swift -o research/trajectory-similarity-20261022/swift-check
research/trajectory-similarity-20261022/swift-check research/trajectory-similarity-20261022/swift-fixtures.json > research/trajectory-similarity-20261022/swift-validation.json
build/break-potting-research-20261002/plot-venv/bin/python research/trajectory-similarity-20261022/finalize.py
```

离线分析仅用 Python 标准库、NumPy、Matplotlib 和本机编译器；没有新增 App 依赖。上述 Python 路径使用现有绘图环境，其他安装了 NumPy/Matplotlib 的 Python 也可运行。

## 坐标、预处理与关键点

以 `BTPhysicsConstants.swift` 的 2.540m × 1.270m 为台内框尺寸。输入物理点转换为 `p=(100·X,100·Z)`，单位 cm；中心为 (0,0)。横桌图中 +X 向右、+Z 向下。几何文档中“+Z 顶视图向上”的早期表述与当前横桌投影不符，本报告采用代码/适配技能中的实际投影，物理运算不依赖屏幕上下。

若输入为 Canvas 归一化坐标 `(u,v)`，则 `X_cm=254u−127`、`Z_cm=254v−63.5`。v 的范围为 0…0.5，不能错误乘以台宽 127。禁止分别中心化、旋转拟合、长度归一化和镜像对齐；这些操作会消除球桌位置和方向的真实差别。两条轨迹同时换坐标系的刚体变换不影响结果，已另行验证。

预处理规则：

1. 拒绝空数组、NaN、Infinity、未完成且仍在移动的模拟；不能返回“100 分”或伪造终点。静止轨迹合法，去重后为单点。
2. 按记录顺序处理同刻帧，保留物理提交顺序；仅去掉**连续且位置完全相同**的点，不全局去重，不删除反向经过同一点或自交点。
3. 累计弧长 `s₀=0, sᵢ=Σ‖pₖ−pₖ₋₁‖`。在 `kL/(N−1)` 处沿原折线作线性定位；禁止跨碰库点用直线“抄近路”，禁止样条平滑改变反弹形状。
4. 合并起终点和真实碰撞事件的弧长位置，再排序；点位置完全保留，事件元数据独立保留，不因同点合并丢掉事件身份。本批事件位置与源点一一核对。
5. 曲线段以源轨迹为参照计算单调同弧长对应的最大重建误差 ε；它比仅用点到线最近距离更能发现顺序上的误差。对原折线与新折线，这个对应的差在每个分段内为仿射函数，范数最大值可在分段端点检查。

“严格全局等弧长且固定 N”与“完整保留任意折点”一般不能同时成立。本实验明确选择 **N 个等弧长点与事件点的并集**。事件插点会轻微改变 DTW/Chamfer 的点权重，因此另计算弧长加权 Chamfer 检查偏差；若未来事件极多，建议 Chamfer 采用弧长积分权重或点到原折线距离辅助，不应静默更换定义。

## 三种算法的精确定义

令 `dᵢⱼ=‖pᵢ−qⱼ‖₂`，单位 cm。匹配从 `(1,1)` 到 `(n,m)`，允许步长 `(1,0),(0,1),(1,1)`，不倒退、不开放起终点、不限定对角窗。

**离散 Fréchet**：

```text
F(i,j) = max(d(i,j), min(F(i−1,j), F(i−1,j−1), F(i,j−1)))
F(1,1) = d(1,1)
第一行/列只能沿该行/列推进；越界值为 +∞。
D_F = F(n,m)
```

它最小化所有保序匹配中最大的距离，不是逐一同索引差值的最大值，也不是 Hausdorff 距离。端点自然提供下界 `D_F≥max(‖p₁−q₁‖,‖pₙ−qₘ‖)`，因此无需再把终点距离重复计权。局部最大偏差敏感是定义本身；应保留这个信息，不用“去异常”随意删掉真实局部线路。[Eiter & Mannila 原论文](https://www.kr.tuwien.ac.at/staff/eiter/et-archive/files/cdtr9464.pdf)。

**平均 DTW（本实验主口径）**：

```text
C(i,j) = d(i,j) + min(C(i−1,j), C(i−1,j−1), C(i,j−1))
π* = 最小总成本路径
D_DTW = C(n,m) / |π*|
```

同总成本时选较短路径，保证归一化结果确定；同成本同长度再按固定步骤顺序选择。**这是先最小化总和再除路径长度，不是最小平均成本路径。** 两个目标不能混称。对角步与横纵步权重均为 1，匹配长度范围 `max(n,m)…n+m−1`；报告同时保留路径长度/总和与反例的回溯路径。

为检查归一化敏感性，还计算 `symmetric2`：横纵步局部成本 d、对角步 2d，初值 2d₁₁，再除以 `n+m`。其分母独立于路径；可作为未来需要单一平均量时的候选，但本批仍保留用户要求的路径均值 DTW，不悄悄替换。DTW 的归一化与步型选择存在实质差别。[DTW 官方 FAQ](https://dynamictimewarping.github.io/faq/)。

**双向 Chamfer（本实验厘米版本）**：

```text
D_C = ½ [(1/n) Σ_i min_j ‖p_i−q_j‖₂ + (1/m) Σ_j min_i ‖q_j−p_i‖₂]
```

两方向各取均值，再取均值；使用未平方欧氏距离。不采用平方距离、平方后再开根或两方向直接相加，这些实现的数值/单位不同。点云库的 Chamfer 选项未必对应此口径，不能只凭函数名替换。[PyTorch3D 官方接口与源码入口](https://pytorch3d.readthedocs.io/en/latest/modules/loss.html)。它不要求运动顺序，因此同一空间集合反向走过时可为零。重复经过同一区域也很容易被低估；不能视作完整运动轨迹相同。

三种主指标在本实现中对交换两条输入对称；单条反转会改变保序指标，两条同时反转则保留几何问题的对应关系（平均 DTW 对浮点并列路径仍按确定规则处理）。平均 DTW/Chamfer 不应被当作具有全部度量公理的数学距离。

## 分数映射与权重研究

原始厘米值应始终保留。建议先用透明的单调映射用于比较：

```text
S(d; T50) = 100 · exp(−ln(2) · d/T50) = 100 · 2^(−d/T50)
S_F = S(D_F), S_DTW = S(D_DTW), S_C = S(D_C)
```

`T50` 表示“多大偏差对应 50 分”，不是概率、球桌对角线百分比或自动学习到的常数。报告默认 `T50=10cm` **仅为可读示例**，交互页可切 5/10/20cm；同一尺度便于横向解释物理偏差，但不表示三种指标具有相同统计分布。

对照候选：线性截断 `100·max(0,1−d/(2T50))` 在大偏差区域会饱和为零，丢失排序；高斯 `100·2^{−(d/T50)²}` 对小偏差更宽容、对大偏差衰减更快。指数映射连续、无硬阈值、含义清晰，所以用于本次展示。哪一种符合教学体验，仍需要用户/教练对几何案例的盲评标定。

若未来必须合成，至少明确两种不同语义：

```text
分数加权：S_mix = wF·S_F + wD·S_DTW + wC·S_C
距离加权后映射：S_dist = S(wF·D_F + wD·D_DTW + wC·D_C)
wF,wD,wC ≥ 0，且和为 1。
```

两者不相等。分数平均可让 Chamfer 的高分显著抬高反向/错序轨迹；距离平均会折减 Fréchet 的局部最大偏差。研究脚本扫描纯 F、0.7/0.2/0.1 和等权，并跨三个 T50 比较，只作**消融反例**，没有认定这些是最终候选权重。没有人工标签就不能从自定义案例“优化出正确权重”。当前最佳可解释输出仍是核心 F 分＋三个厘米值＋碰库诊断。

## 收敛与精度解释

执行 128、256、512、1024，并额外用 2048 基础点作经验参考。不同 N 的均匀网格并非嵌套，因此不能要求每次加密结果严格单调；应观察绝对差值、排序变化和几何误差界。

对重建后的折线，记最大相邻边长为 `h=max(hP,hQ)`。原论文给出 `D_cont≤D_discrete≤D_cont+h`。若两条源曲线的单调重建误差分别为 εP、εQ，则源曲线连续 Fréchet 位于：

```text
[max(0, D_F−h−εP−εQ), D_F+εP+εQ]
```

这才是针对当前折线近似的保守界；另外仍有物理记录/解析重建及 Float 数值误差。512 与 1024 很接近只是经验收敛，不能单独证明精度。

实现建议：512 起步，检查到 1024 的差值；按业务能解释的厘米容差控制最长间距和重建误差，需要时继续 2048/4096 或更高。示例工程目标可先用 0.1cm 的相邻密度差和 0.5cm 的保守区间宽度，二者是待评审的精度要求，并非本实验反推出来的评分阈值。若预算上限仍不满足，返回“精度未达标”和区间，不能硬报稳定。固定 N 可改为 `N≥ceil(L/hTarget)+1` 再补关键点。

指数映射导数绝对值至多 `100 ln2/T50` 分/cm；可把距离区间直接映射为分数区间 `[S(D_upper),S(D_lower)]`。例如 T50=10cm 时，0.1cm 距离误差的全局分数误差上界约 0.693 分。

## 适合当前 iOS 项目的落地方式

1. **输入层**：冻结两条物理轨迹及事件，明确完整击球或碰球后片段的比较合同。本实验比较完整轨迹；若以后比较走位段，两条都从同一业务语义的首碰截起，否则共同进球前路段会稀释 DTW/Chamfer 的差异。不将这个合同变化偷偷放入算法。
2. **独立纯计算模块**：使用 `SIMD2<Double>` 表示厘米坐标，保留源时间/事件用于诊断。计算层不依赖 SceneKit、SwiftUI 或物理引擎可变状态。参考实现为本目录 `TrajectorySimilarity.swift`，尚未添加至 App target。
3. **计算流程**：验证输入 → 连续重复点处理 → 关键点保留/弧长采样 → 质量检查 → 三指标 → 精度复算 → 可选映射。`TrajectorySimilarity.compare` 是核心距离参考，不包含完整生产集成的质量结果类型和自动加密控制；后者需按本报告合同封装。
4. **结果结构建议**：原始厘米距离、采样预算/实际点数、最长边、重建误差、收敛差、F 区间、算法/采样版本、T50、三项分数、终止完整性及碰库序列。不要只保存一个不可解释总分。
5. **复杂度**：F/DTW 均 O(nm)，滚动数组 O(m)；Chamfer 暴力 O(nm)，本场景足够。若需要可视化匹配路径，另保留 O(nm) 的回溯信息。512² 约 26 万、1024² 约 105 万匹配格，不需近似 FastDTW/KD-tree 才能上线；本次不对实际手机耗时作未测承诺。
6. **线程与一致性**：在后台任务中比较不可变值快照，返回前核对轨迹版本/任务取消状态，避免旧分数覆盖新球形。先确定 Double/欧氏距离/步型/并列路径规则及版本，跨平台以本批 fixtures 作一致性校验。
7. **异常边界**：静止点与线、重复点、极短轨迹、全长高精度轨迹均合法；空/非有限/未完成模拟明确报错。不能对不同起点独立归零，也不能因不同吃库次数先判零分。撞库次数/次序、末端距离仅显示为诊断。

## 验证证据与适用边界

- C++ 实验内核对 60 对小轨迹穷举全部保序匹配，独立确认 F 与平均 DTW 最优总成本定义；另核交换对称、端点下界、已知答案、角点保留和非法输入拒绝。
- 30 组随机双轨迹验证同时平移/旋转不变和统一缩放比例；与自动对齐单条轨迹是不同操作。
- Swift 独立实现对 105 对真实轨迹的 512 点结果逐项核对，结果见 `swift-validation.json`；包括关键折点和重复点处理。
- 原始轨迹、输入、诊断、全矩阵 CSV 和脚本均保留。数值结果不是由截图测量，也没有手工硬塞预期值。
- 没有进行 App UI 集成、真机性能、用户评分体验或全项目回归验收；模拟器测试只为研究生成及校验轨迹。没有提交或发布改动。

## 附件

- [真实轨迹对比图](engine-comparisons.png)、[反例图](counterexamples.png)、[三种相似度矩阵](similarity-matrices.png)、[收敛和映射图](convergence-and-score.png)。
- [原始引擎轨迹](engine-trajectories.json)、[全部指标](metrics.json)、[匹配/加权诊断](diagnostics.json)、[采样元数据](sampling.csv)。
- 全量矩阵：`matrix-frechet-cm.csv`、`matrix-dtw-cm.csv`、`matrix-chamfer-cm.csv`；对应 `*-score-t10.csv` 为示例分数。

---
