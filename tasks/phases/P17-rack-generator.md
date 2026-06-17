# P17 球形生成器（开球 / 追分开球）

> 来源：用户 idea「走位与分离角、走位编排台、思路训练器里的球形基本靠手摆或导入；想加**中式八球开球**
> 和**追分开球（4/5/6/9 球）**——给普通用户一个『球形生成』入口」。本质是把「真实开球后的散开球形」
> 一键灌进现有反解/编排工具的入口。

## 目标

提供一个「选玩法 → 摆球架 → 真实物理开球 → 散开球形」的生成器，产出标准 `BoardSnapshot` 直接喂给
现有工具（走位编排台、思路训练器）。开球用**端上真实物理**（livesim），所见即所得。

## 用户拍板（2026-06-17）

| 决策点 | 拍板 |
|--------|------|
| 开球方式 | **端上真实物理 livesim**（非参数化散布、非预烘焙）：复用 `EventDrivenEngine` |
| 玩法范围 | 中八 15 球、9 球、追分 4/5/6 球（首版全做） |
| 实现顺序 | **中八 15 球先行**（最大未知，先去风险） |
| 结果取舍 | **WYSIWYG**：不做「可玩性」筛选/重摆；不满意用户手动「换一局」 |
| 消费端 | 走位编排台 + 思路训练器（已有 `loadBoard`/`initialBoard`）|
| **斯诺克** | **不加开球功能**（用户复盘后明确排除）|
| 分离角 | 后续再接（需适配层），首版不含 |

## 前置去风险（已完成 ✅）

`QiuJiTests/BreakRackPhysicsTests.swift`：在写任何生成器/UI 前，先用真实输出回答最大未知——
**P13 引擎能否把 15 球开球跑到完全停稳/不出界/不互穿/确定性？**
- 移植 01 `setupRackLayout` 三角阵（gap=1mm）+ 母球开球区，跑 3.0–8.0 m/s 多档。
- 结论：**可行**。所有档位 settled（终速<0.3）、0 出界、0 互穿、跨运行确定性（≤1e-4m）；
  事件数实测仅 ~80–140（`maxEvents=8000` 头寸充裕，远未触顶）。
- 诊断（`test_break15Ball_diagnoseSpread`）：散布非哑火（目标球铺开 ~1m×0.8m，母球行程 ~1–1.5m），
  但散开强度随力度非单调——**真实感对标**留作后续（可与 pooltool 跨引擎校准，01 有现成夹具）。

## 阶段 1（本次 ✅）：Core 生成器 + 测试

新增 `QiuJi/Core/Rack/`：

### `RackLayout.swift`
- `enum RackGame { chineseEightBall | nineBall | zhuifen(balls:) }`，`ballCount` 派生。
- `RackLayout.make(_:seed:surfaceY:) -> Rack`（SceneKit 世界系，球心 Y=surfaceY+R）：
  - 几何移植自 `BreakRackPhysicsTests` 已验证的三角阵：置球点 `−innerLength/4`、向 −X 展开、`gap=1mm`、
    `rowOffset=(2R+gap)·√3/2`，每排 z 居中。
  - 排型：中八 `[1,2,3,4,5]`、9 球钻石 `[1,2,3,2,1]`、追分 = **整三角点阵前 N slot**
    （末排取真实 nestle 位再按 N 截断；**不重新居中**——等数相邻排会在 z 对齐 → 排间距退化 0.866·2R 互穿，
    本轮测试一次抓出并修正）。
  - 球号规则（非随机部分钉死，随机部分由 `seed` 决定 → 确定性）：
    - 中八：8 号居中（第 3 排中点 idx4），底两角**一花一色**（1–7 全色 / 9–15 花色），其余随机。
    - 9 球：1 号顶角、9 号中心、2 号尾点，其余随机。
    - 追分：1 号最前（先打），其余随机。
- `Rack.boardSnapshot`：经 `AngleSceneCalculator.sceneToNormalized` 转归一化，供静态预览/动画起始帧。
- `SeededGenerator`（SplitMix64，`RandomNumberGenerator`）：球号洗牌的确定性随机源（App target，与测试网种子习惯一致）。

### `BreakSimulator.swift`
- `BreakSimulator.breakShot(rack:cuePosition:power:spinX:spinY:maxEvents:maxTime:) -> BreakResult`：
  与 `BreakRackPhysicsTests` 同路径——`highFidelityBounds`、`maxEvents=8000`。瞄准**自动锁顶球**
  （`aimAtApex`：母球指向球堆 x 最大的顶角球心；母球居中退化为标准 −X 正中开球）——母球位置即开球角度
  的唯一控制（阶段 2 方案 a）。`cuePosition=nil` 时用球架默认开球点。
- `BreakResult`：散开归一化 `board`（母球未刮+未落袋目标球）、`recorder`（球名=在桌键，供开球动画回放）、
  `pocketed`、`cueScratched`、`eightOnBreak`（中八 8 号开球落袋废局信号）、`settled`（未被截断）。
- 引擎球名直接用在桌键（`cueBall`/`_n`），recorder 帧与场景节点键一一对应，UI 回放映射零转换。

### 验证 `QiuJiTests/RackGeneratorTests.swift`（**8/8 ✅**）
- 摆架规则：中八 8 号居中 + 底角一花一色 + 1…15 不重不漏；9 球三锚点；追分 1 号最前。
- 几何：球架不互穿（≥2R−1e-5）、全在界。
- 确定性：同 seed 同架、异 seed 异架。
- 开球：中八/9 球产出 settled 且合法（球数=16/10−落袋、归一化不互穿在界）；同输入两次开球逐球一致（≤1e-4）。
- `make build` 编译通过、lint 0。回归：开球物理本身由 `BreakRackPhysicsTests` 守。

## 阶段 2（本次 ✅）：入口 UI + 接入

新增 `QiuJi/Features/RackGenerator/`：

### `RackGeneratorViewModel.swift`
- 状态机 `Phase{racked|computing|breaking|settled}`；复用 `AngleTrainingScene`+`AngleSceneView`。
- 玩法选择：UI 大类 `中式八球 / 追分`，追分球数 chip `[4,5,6,9]`（9→`nineBall` 钻石、4/5/6→`zhuifen(N)`）；
  改玩法/球数即重摆架（`rebuildRack`，seed 复位）。
- **母球钳在开球区**（`clampToBreakBox`：厨房半区 `x∈[innerLength/4, halfL−R]`、z 在界，避开袋口），
  拖动即更新**锁顶球瞄准线**（母球→顶角球 + 绿色方向短杆）——方案 a：母球位置驱动开球角度。
- 力度滑杆（`power` 3.0–8.0，默认 6.0 中大力）+ 打点（`spinX/spinY`，接 `BTSpinPadCard`）。
- 「开球」：后台 `breakQueue` 跑 `BreakSimulator.breakShot` → `TrajectoryPlayback` 回放散开（球名=在桌键，
  零映射）→ 收尾把存活球钉到散开终点；**刮杆补母球**回开球区（既能交付也便预览）。
- 「换一局」：`seed&+=1` 重摆（WYSIWYG）。废局（`cueScratched`/`eightOnBreak`）只在状态栏提示 + 结果摘要，
  不自动筛选/重开。
- `deliveredBoard()`：停稳板（母球刮杆已补回）供交付。

### `RackGeneratorView.swift`
- 布局语言对齐编排台/拍照建球形：黑底 + 顶部玩法分段 + 主区 2D 真台 + 底部条（力度滑杆/打点图标 +
  开球/换一局；停稳后切「送入编排台 / 送入思路训练器 / 换一局」）。
- 路由 `navigationDestination(isPresented:)` → `PositionPlayComposerView(initialBoard:)` /
  `SiluTrainerView(initialBoard:)`（与 P15 拍照建球形同范式）。

### 接线
- `AngleRoute.rackGenerator` + 角度 Tab「工具」海报卡「开」(chip「物理」) + `MainTabView.angleDestination`。

### 验证
- `make xcodegen`+`make build` **BUILD SUCCEEDED**、lint 0；`RackGeneratorTests` **8/8 ✅**
  （`breakShot` 改 `cuePosition`+锁顶球后回归仍 settled/合法/确定性）。
- **⏳ 待人工**：真机/模拟器走查（拖母球开球角度感、各玩法散开、刮杆/8-on-break 提示、交付编排台/思路）。

## 阶段 2.1（本次 ✅）：开球随机性 + 9 球少球摆法 + 力度上调

用户走查后四点反馈（2026-06-17）：①随机性只来自球号排序——物理确定性 ⇒ 同开球点/力度/打点散开**逐毫米一致**，「换一局」只换号码不换形；②部分球完全不动（正中锁顶对称破不开）；③力度想再大点；④「追分」改名「9 球」，4/5/6 用 9 球系少球摆法。

- **随机性根因 + 修复**：`seed` 仅喂 `assignNumbers`（贴号码），slot 几何写死、引擎里所有球物理全等 ⇒ 号码不影响散开。
  在 `RackGeneratorViewModel.breakNow` 注入 **seed 驱动**的「一点点」扰动（`breakJitter`，绑定当前 rack `seed` ⇒ 同局可复现、换一局即变）：
  - 上下塞 `spinY ±0.15`、左右塞 `spinX ±0.10`（接触点偏移/R），叠加用户打点后 `clampSpin` 钳到 miscue 极限 0.5。让「换一局」真正换形（治①）。
  - ~~撞顶球偏摆 `aimJitter ±1.5°`~~ **已于本轮移除**（用户拍板不要）：阶段 2.2 的 gap 修复已让球堆稳定炸开，无需再靠瞄准偏摆破对称；`BreakSimulator.breakShot` 的 `aimJitter` 参数随之删除，恢复纯锁顶球瞄准。
- **力度上调**（③）：`powerRange 3.0–8.0 → 4.0–9.0`、默认 `6.0 → 7.0`。注：母球出射 ≈1.54×杆头速度（杆-球碰撞，正中无塞）；默认 7.0 ⇒ 母球 ~10.8 m/s、KE ~9.9 J（很强）。
- **改名 + 9 球少球摆法**（④）：UI「追分」→「9 球」（`RackGeneratorView`、`AngleHomeView` 海报副标题）。`RackLayout` 的 `zhuifen` 改为**显式布局 + 9 球系编号**（替换原「三角前缀」）：
  - **4 球**：小菱形 `[1,2,1]` — apex=1、中行=2/3、底（正对 1）=9。
  - **5 球**：菱形 `[1,2,1]` + 一颗**共线相切**尾球（x 间距=spacing 非 rowOffset）— apex=1、中行=2/3、菱形底=4、尾=9。
  - **6 球**：三角 `[1,2,3]` — apex=1、中行=2/3、底两角=4/5、底排中点=9。
  - **9 球**：保持钻石 `[1,2,3,2,1]`、9 居中（不动）。
  - 几何收口到新 `makeSlots`（删旧 `rowCounts`）；号码集不再连续（4=`{1,2,3,9}` / 5=`{1,2,3,4,9}` / 6=`{1,2,3,4,5,9}`）。
- **验证**：`make build` **BUILD SUCCEEDED**、lint 0；`RackGeneratorTests` **8/8 ✅**（`test_zhuifenRacks` 改断言新编号 + 9 号锚点）。`breakShot(aimJitter:)` 默认 0 ⇒ 既有调用与 `BreakRackPhysicsTests` 路径不变。
- **⏳ 待人工**：真机走查——换一局是否真的换形、4/5/6 摆法是否符合预期、加大力度后散开/停稳手感、随机塞/偏摆量级是否「一点点」合适（可再调）。

## 阶段 2.2（本次 ✅）：开球缝隙 gap 1mm→0.2mm（治「球开不开」根因）

用户真机走查：中八满力（9 m/s）开球**经常散不开**——球堆只裂开几颗、母球带着大半能量跑很远。怀疑球间距过大。

- **测量优先（非拍脑袋）**：新增诊断 `BreakRackPhysicsTests.test_break15Ball_gapSweep`——母球对准顶角全砸（`aimAtApex` 等价）、v=7、对 5 个瞄准偏角取均值，扫 gap∈{0.1,0.2,0.3,0.5,1,2}mm：

  | gap | 均散开>30cm | 均位移 | 终态停稳/不互穿 |
  |-----|-----------|--------|------------------|
  | 0.1mm | 10.2/15 | 659mm | ✅（终态最小球距≈2R） |
  | **0.2mm** | **9.6/15** | 580mm | ✅ |
  | 0.3mm | 5.8/15 | 368mm | ✅ |
  | 1.0mm（旧） | 5.2/15 | 318mm | ✅ |
  | 2.0mm | 3.6/15 | 235mm | ✅ |

  趋势单调且在 0.2↔0.3mm 间有明显拐点：**gap≤0.2mm 时球架近似「冻结」，动量链能传遍球堆（~2× 球数散开>30cm）**，且仍完全停稳/不互穿。坐实用户判断：**1mm 缝隙过大是「开不开」的根因**（动量逐颗传递时被缝隙+摩擦耗散，母球留太多能量）。
- **修复**：`RackLayout.gap` `0.001 → 0.0002`（同步 `BreakRackPhysicsTests.gap`）。取 0.2mm 而非 0.1mm：同在强开球区间，但留一丝数值余量（终态最小球距 57.40mm vs 0.1mm 的 57.16mm，离 2R=57.15mm 更稳）。
- **验证**：`BreakRackPhysicsTests` + `RackGeneratorTests` **14/14 ✅**。`diagnoseSpread`（现 gap=0.2mm）：v=6 散开>30cm **2/15→12/15**、铺开包围盒 X **108cm→246cm**（近满台）；全程仍 settled/不互穿/确定性。
- **⏳ 待人工**：真机复看满力/中力开球是否稳定炸开、各玩法（含 4/5/6 少球）散开手感。

## 阶段 3（后续 ⏳，非阻塞）

- 开球真实感对标（与 pooltool 跨引擎校准散布度，01 有夹具）；随机扰动量级标定。
- 分离角接入适配层（其输入模型与编排台/思路不同）。

---

## ADR-P17-01：球形生成器 = 摆架 + livesim 开球，产出 BoardSnapshot

- **状态**：已采纳（2026-06-17）。阶段 1（Core）+ 阶段 2（UI/接入）已落地，阶段 3 待续。
- **背景**：用户要开球/追分开球的「球形生成」入口；现有工具全部以 `BoardSnapshot` 为输入货币
  （P11 编排台、P13 思路、P15 拍照建球形）。
- **决策**：
  1. **livesim 而非参数化/预烘焙**（用户拍板）：复用已验证的 `EventDrivenEngine`，开球结果即真实物理散开。
     去风险测试 `BreakRackPhysicsTests` 先行确证引擎扛得住 15 球开球（停稳/不出界/不互穿/确定性）。
  2. **Core 与 UI 分层**：`Core/Rack/{RackLayout,BreakSimulator}` 纯逻辑可单测，UI/路由后续增量接入；
     生成器输出标准 `BoardSnapshot` + `TrajectoryRecorder`，不发明新货币。
  3. **WYSIWYG，不做可玩性筛选**（用户拍板）：废局（刮杆 / 8-on-break）只上报 flag 由 UI 决定提示+重开，
     引擎不自动重摆——避免「悄悄改球形」的隐式行为，也回避「可玩性」无可证伪的调参泥潭。
  4. **斯诺克不接入**（用户拍板）：消费端仅走位编排台 + 思路训练器；分离角因输入模型不同留待适配层（阶段 3）。
  5. **追分小球堆取整三角点阵前 N slot**：4/5/6 球无刚性国标，采「1 号最前、其余紧贴」的偏好惯例
     （非杜撰标准）；末排走真实 nestle 位而非重新居中（后者会令等数相邻排互穿，已由测试抓出）。
  6. **确定性随机**（`SeededGenerator`/SplitMix64）：同 seed 同架/同开球，便于「换一局」可复现与测试。
- **影响**：新增独立 Core 模块 `QiuJi/Core/Rack/`（不改既有引擎/编辑器）；阶段 2 将新增一处 Feature 页
  + `AngleRoute`/`MainTabView`/`AngleHomeView` 各一处入口（与 P15/P16 同范式）。
- **未选**：①参数化散布（不真实、与「物理升级」主线背离）②预烘焙固定球形（违背 livesim「换一局」诉求）
  ③开球结果自动筛选可玩性（违 WYSIWYG + 调参泥潭）④塞进斯诺克/分离角（用户排除 / 输入模型不匹配）。
- **遗留**：开球真实感（散布随力度非单调）待跨引擎校准；分离角适配层；UI 开球动画与废局兜底（阶段 2）。
