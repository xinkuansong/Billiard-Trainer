# UI 审查报告 — 图标系统专项（Light）
日期：2026-06-01
角色：UI Reviewer
设备/来源：`screenshot-v4/`（00–25 帧，iPhone 17 Pro · 浅色 · 游客态）+ 图标资产源码审查
约束：**App Icon（`AppIcon.png` 绿底 Q）与品牌 Logo（`BrandLogoMark` / `BTLogoMark` / `BTBrandLogo`）本轮不动**，仅审查「App 内功能/分类图标层」。

> 核心结论：问题不是"单个图标丑"，而是**全 App 同时存在 4 套互不统一的图标语言**（SF Symbols 细线 / 自研 Canvas 品牌图标 / Profile 彩虹圆底 / 角度页单色淡底圆徽），缺少统一的「容器规则 + 颜色收口 + 线宽网格」，导致整体观感"乱、廉价"。
> 北极星：建立一套 **球迹 Icon System**，全 App 收敛到「单色图形 + 统一淡色圆底」（即角度训练首页已验证的那套），颜色仅保留 **品牌绿（主）+ 金 btAccent（唯一强调）**。

---

## 一、问题清单

### U-I01 Profile 列表图标"彩虹圆底"色相失控
- **类别**：Design Token / 视觉打磨
- **严重程度**：P1
- **位置**：我的（`18` / `19`）
- **现状**：一列里出现 红心(粉底) / 蓝人(蓝底) / 绿靶(绿底) / 金冠(金底) / 灰齿轮(灰底) / 绿盾(绿底) / 品红 info(紫底) 共 7 种色相、7 个彩色圆底。蓝色与品红与品牌绿强烈冲突；金色与「Pro/皇冠」语义撞车。属 iOS 设置页彩色块的劣化版（无规律、不克制）。
- **预期**：列表入口图标统一为「单色图形 + 统一淡色圆底」，色相收口到品牌绿（次要项可用中性灰）；金色仅留给强调项（如订阅/收藏）。
- **修复方向**：抽出统一 `BTListIconBadge`（圆底色 = btPrimary.opacity(0.12) 或 btBGTertiary，图形 = btPrimary 单色），Profile 各行替换；金色仅保留订阅/收藏。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Profile/Views/ProfileView.swift`、`SettingsView.swift`、`AboutView.swift`

### U-I02 训练 Tab 自研图标与其余 4 个 SF Symbol 视觉重量不一致
- **类别**：视觉打磨 / 一致性
- **严重程度**：P1
- **位置**：全局 Tab 栏（`01` / `05` / `08` / `16` 等所有页底部）
- **现状**：训练（`BTTrainingIcon` 自研"球+弧"）线条比动作库(列表)/角度(三角板)/记录(时钟)/我的(人物) 4 个 SF Symbol 更细、形态偏抽象，小尺寸下辨识模糊（似音符/σ），明显"不合群"。Tab 栏常驻，问题被反复感知。
- **预期**：5 个 Tab 图标视觉重量、线宽、留白统一；训练图标要么对齐 SF Symbol 线宽，要么 5 个全部自研同一套。
- **修复方向**：① 短期——加粗 `BTTrainingIcon` 描边/简化造型至与 SF Symbol 等重；② 中期（推荐）——5 个 Tab 全用同一自研网格图标，统一线宽与圆角。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Core/DesignSystem/BTTrainingIcon.swift`、`QiuJi/App/MainTabView.swift`、`AppTab.icon`

### U-I03 Drill 分类图标小尺寸不可读 + "基础功"渲染成橙色方块
- **类别**：视觉打磨 / 缺陷
- **严重程度**：P1
- **位置**：动作库侧栏 + 分组 Header（`05`）
- **现状**：8 个自研 `BTDrillCategoryIcon` 在 24–28px 下线宽不一、隐喻晦涩（分离角像眼镜、走位像钥匙、特殊球路像句号）；**选中态"基础功"在 Header 与侧栏均渲染为一个橙色填充方块、几乎看不到图形**，疑似 fill 态下图形被主色块吞没，观感像加载失败占位。橙/金色与整体绿主题脱节。
- **预期**：8 个分类图标在小尺寸清晰可读、线宽一致、隐喻统一（围绕 球/台/轨迹）；选中态图形清晰可见，不出现纯色块。
- **修复方向**：重做 8 个分类图标，统一 24pt 网格 + 固定线宽 + 固定球半径；修复 `filled` 态主色块吞没图形的问题（图形改用反白或描边对比）；分类色去橙、统一绿+金。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Core/DesignSystem/BTDrillCategoryIcon.swift`、`DrillListView.swift`

### U-I04 空状态 Hero 图标语义离题（健身小人 / 锤子）
- **类别**：产品规格 / 视觉打磨
- **严重程度**：P2
- **位置**：训练首页空状态(`01` 举杠铃小人)、自定义模版空状态(`02` 锤子)
- **现状**：训练空状态用举杠铃健身 figure（健身房语义）；自定义计划空状态用锤子（通用施工语义）。两者为大尺寸 Hero 图、最定调，却与台球无关。注释曾记录训练 Tab 已弃用 `dumbbell.fill`，但空状态仍是健身语义。
- **预期**：空状态图标收敛到台球语义（球/球杆/球台/计划），优先复用自研矢量。
- **修复方向**：替换为 `BTLogoMark(.markOnly)` 或新增台球语义空状态图（球+虚线轨迹）。
- **路由至**：SwiftUI Developer
- **代码提示**：`TrainingHomeView.swift`、`CustomPlanBuilderView.swift`、`BTEmptyState.swift`

### U-I05 缺少统一容器规则：圆底/无底/彩底混用
- **类别**：视觉打磨 / 一致性
- **严重程度**：P2
- **位置**：跨页对比（角度`08` 单色淡绿圆底 ✅ / Profile`18` 彩色圆底 ✗ / 动作详情`06` 灰圆底 / Tab 无底 / 侧栏`05` 选中橙底）
- **现状**：同类"图标入口"在不同页用了完全不同的容器处理，无单一规则。角度页那套（淡绿圆底+单色图形）是全 App 最干净的范式，但未被复用。
- **预期**：建立单一容器规则——列表/入口图标统一容器；Tab 无底；正文内 inline 图标统一线宽。
- **修复方向**：以角度页徽标为基准，抽 `BTIconBadge` 复用到 Profile / 动作详情 / 各列表入口。
- **路由至**：SwiftUI Developer
- **代码提示**：`AngleHomeView.swift`（参考实现）、`Core/Components/`（新增组件）

### U-I06 SF Symbols 散落字面量未收口，权重/渲染模式不统一
- **类别**：Design Token / 一致性
- **严重程度**：P2
- **位置**：全局（50+ 文件、180+ 处 `Image(systemName:)`）
- **现状**：`IconToken.swift` 的 `BTIcon` 仅部分收口，大量旧 View 仍直写 `systemName:` 字面量；未全局统一 `.fontWeight` / `.symbolRenderingMode`，导致同屏 SF Symbols 粗细深浅不一。
- **预期**：全量迁移到 `BTIcon`；统一一处设定 symbol weight 与 rendering mode。
- **修复方向**：增量迁移裸字面量到 `BTIcon`；封装统一 `.symbolRenderingMode(.monochrome)` + weight 的 modifier。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Core/DesignSystem/IconToken.swift` + 各 `Features/*/Views/*`

---

## 二、推荐行动方案（已替用户定方向：A → B）

> 容器基调采用 **「统一淡绿圆底 + 单色图形」**（角度页范式），最克制、最品牌化。

**阶段 A — 治理层止血（约 1–2 天，立竿见影）**
1. 新建统一组件 `BTIconBadge`（淡绿/中性圆底 + btPrimary 单色图形），替换 Profile 彩虹圆底（U-I01）。
2. 全局图标颜色收口到 绿 + 金（金仅强调）（U-I01 / U-I05）。
3. 修 3 处缺陷/离题：基础功橙块（U-I03 渲染 bug 先修）、健身小人、锤子（U-I04）。
4. 封装统一 SF Symbol weight/rendering modifier（U-I06 治理半量）。

**阶段 B — 重做核心自研图标（约 3–5 天，定型）**
5. 重画 8 个 Drill 分类图标，统一网格/线宽/隐喻（U-I03）。
6. 训练 Tab 图标对齐其余 4 个重量，或 5 个 Tab 统一自研一套（U-I02）。
7. SF Symbols 裸字面量增量迁移到 `BTIcon`（U-I06 收尾）。

**（可选）阶段 C — 完整 Icon System 规范**：成文设计规范 + 全量自研核心图标，SF Symbols 仅兜底。投入最大，留作后续迭代。

---

## 三、审查总结
- 问题数量：6 项（P0: 0 / P1: 3 / P2: 3）。
- 最突出：Profile 彩虹圆底（U-I01）、Tab 训练图标不合群（U-I02）、Drill 分类图标不可读+橙块缺陷（U-I03）。
- 总体评价：品牌资产（App Icon / Logo）干净同源、无需改；"乱/丑"集中在 App 内功能图标层缺乏统一系统。**先做阶段 A 即可消除大部分"乱"，阶段 B 完成"高级感一致性"。**
- 现有最佳范式：角度训练首页的「单色图形 + 统一淡绿圆底」徽标，应作为全 App 收敛目标。

### 截图索引
01 训练首页(健身小人空状态) · 02 自定义模版(锤子空状态) · 05 动作库(分类图标/橙块) · 06 动作详情(灰圆底) · 08 角度首页(范式✅) · 16 历史(Tab 栏) · 18/19 我的(彩虹圆底) · 24 订阅 Paywall

---

## 四、阶段 A 修复记录（2026-06-01 同日修复并截图回归）

| 编号 | 状态 | 修复要点 | 改动文件 |
|------|------|----------|----------|
| U-I01 | ✅ | 新增统一 `BTIconBadge`（淡绿/中性/金 圆底 + 单色图形）；Profile `ProfileMenuRow` 去掉每行 iconBG/iconColor，收口到品牌绿，仅"订阅管理"保留金色强调；图标字面量迁移至 `BTIcon` | `IconToken.swift`、`ProfileView.swift` |
| U-I03 | ✅ | `BTDrillCategoryIcon.drawFundamentals` 修复 `r = env.ballRadius * s * 1.4` 重复乘 scale 的 bug（env.ballRadius 已含 scale），母球/中心点不再爆框成橙块 | `BTDrillCategoryIcon.swift` |
| U-I04 | ✅ | 训练首页空状态 `figure.strengthtraining.traditional`(举杠铃)→ `BTLogoMark(.markOnly)`(品牌球+轨迹)；自定义计划空状态 `hammer`→`list.bullet.clipboard`；"自定义"标签 `hammer`→`slider.horizontal.3` | `TrainingHomeView.swift` |
| U-I02 | ⏳ | 训练 Tab 图标与 SF Symbol 重量对齐 — 阶段 B | — |
| U-I03(重画) | ⏳ | 8 个分类图标统一网格/线宽/隐喻 — 阶段 B | — |
| U-I05/06 | ⏳ | 统一容器组件全量复用 + SF Symbol 字面量全量迁移 — 阶段 B | — |

- 验证：`QiuJiUITour` 截图巡游重跑（233s/261s，0 失败），`screenshot-v4/` 26 帧已更新；Profile（18/19）彩虹圆底→统一绿、训练首页（01）→品牌 Logo、动作库（05）"基础功"橙块→正常绿球，均已肉眼回归通过。
- 构建：`make build` BUILD SUCCEEDED；改动文件 lint 0 错误。
- 备注：`BTIconBadge` 暂置于 `IconToken.swift`（已登记文件），避免为单文件重生成 pbxproj；阶段 B 如扩大复用可拆分为 `Core/Components/BTIconBadge.swift` 并 `make xcodegen`。

---

## 五、阶段 B 修复记录（2026-06-01 出图评审通过）

| 编号 | 状态 | 修复要点 | 改动文件 |
|------|------|----------|----------|
| U-I03(重画) | ✅ | `BTDrillCategoryIcon` 整体重写为统一系统：双线宽（`stroke`/`strokeThin`）+ 标准球半径（`ballR`）+ 单一金色强调（绿在金前绘制，金恒在最上层）。8 个分类构图：基础功=母球+金十字 / 准度=同心靶环+金心 / 杆法=母球+高中低三击点 / 分离角=两球相切+金 90°V / 走位=母球+金虚线+目标环 / 控力=仪表弧+金针 / 特殊球路=母球+金旋转弧箭头 / 综合=6 球三角 rack（金顶球） | `BTDrillCategoryIcon.swift` |
| U-I02 | ✅ | `BTTrainingIcon` 加重：弧 `0.08→0.115`、端点 `0.06→0.08`、球 `0.21→0.235`，Tab 栏与其余 4 个 SF Symbol 重量对齐 | `BTTrainingIcon.swift` |
| U-I05/06 | ⏳ | 容器组件全量复用 + SF Symbol ~180 处字面量全量迁移 `BTIcon` — 增量收口（IconToken 设计即"新增优先用 BTIcon、旧 View 常规重构时替换"），列入 backlog，非阻塞 | — |

- 验证：`make build` BUILD SUCCEEDED（修复两处 Swift 类型推断超时：复杂数组字面量拆为显式计算）；截图巡游重跑 0 失败；`screenshot-v4/` 已刷新；8 分类图标（05/08）+ 训练 Tab（01）肉眼回归通过；lint 0 错误。
- 关联缺陷登记：FL-015（drawFundamentals 重复乘 scale 致爆框橙块，P1）。
