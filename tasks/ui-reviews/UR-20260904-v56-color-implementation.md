# UR-20260904 — v56 全 App 色彩语义与 Premium 材质实施复验

## 结论

v56 保留原有页面布局、卡片样式、`star.fill` / `crown.fill` 轮廓与品牌绿动态色；本轮只整理颜色职责和付费材质。品牌绿仍为 Light `#1A6B3C`、Dark `#25A25A`。Pro 改为炭黑表面、分层香槟金与生成的细拉丝纹理；纹理仅通过原 SF Symbol mask 显示，不引入新的生成图标。

实现后的整体关系为：品牌绿负责导航与操作，弱绿负责高频筛选，香槟金只负责 Pro，橙色负责 warning，success / teaching / physics / data 各有独立语义。固定暗场工具继续使用原黑底、球色、白色瞄准线和红绿物理信号。

## 实施范围

- 新增 `btPremiumForeground`、`btPremiumOnDark`、`btPremiumSurface`、`btPremiumBorder`、`btTeachingGuide`、`btPhysicsAdjustable`、`btBrandSignature`、`btDataSecondary` Token；`btPremiumOnDark` 专门保证 Light 页面内炭黑 Pro 卡和黑底 badge 使用浅香槟前景。
- `BTFilterChip` 统一为弱绿表面 + 品牌绿文字/边框；`BTTogglePillGroup` 统一为关键选中的品牌绿实底，并保留 `.isSelected` 第二编码。
- `BTPremiumMaterialSymbol` 以现有 SF Symbol 为 mask，仅在尺寸不小于 24pt、未开启增强对比度、未开启降低透明度时使用生成纹理；其他状态回退为纯色香槟金。
- `BTProBadge`、个人页 Pro 卡、订阅状态与订阅页共用同一 Premium 家族；Guest 个人页只保留一个主要登录行动，warning 与 Pro 不再共用金色。
- warning、success、教学提示、可调物理值、数据系列与收藏等从旧 `btAccent` 拆回各自语义。
- 通过共享 `btDarkToolChrome` 维持内容页进入固定暗场工具页时一致的导航与工具栏语法，不改变轨迹、几何、球号和求解逻辑。
- 60 张现有试装封面只做只读曝光审计和共享中性遮罩分档；没有替换、重选或批准任何封面源图。

## 生成材质证据

| 外观 | 母版 | 用法 |
|---|---|---|
| Light | `docs/design/v56-color-calibration/21-premium-material-master-light.png` | 经裁切后写入 `btPremiumTexture.imageset` 的 Light 槽，仅在原 star/crown mask 内显示 |
| Dark | `docs/design/v56-color-calibration/22-premium-material-master-dark.png` | 经裁切后写入 `btPremiumTexture.imageset` 的 Dark 槽，仅在原 star/crown mask 内显示 |

母版和生产裁切图 SHA-256 记录在 `docs/design/v56-color-calibration/MANIFEST.md`。小图标、增强对比度与降低透明度均不依赖纹理细节。

## 自动矩阵

冻结源码指纹：`20f603c8dd6b6dbc83dc37821821550dd9cc8bd9e437793f6b919db43ed4b25f`。该指纹由 `scripts/run_simulator_matrix.py:source_fingerprint` 按 `scripts/simulator-matrix.json` 计算，覆盖 App、unit/UI test、工程与矩阵输入；下列六组最终截图均来自该源码状态。

截图与专项测试收口后，共享工作区中的并行 v54 会话于 14:18 单独修改了 `QiuJiUITests/V54ScheduleUITests.swift`（新增 single / disclosure 断言），因此全仓全局指纹随后漂移。该文件不属于本轮 42 个 ScreenshotTour 分组、聚焦色彩、品牌登录或 App build 输入；v56 的生产文件与 `ScreenshotTourUITests.swift` 未在证据后变化。这里保留截图当时真实的 `20f603…`，不把后来的无关测试改动冒充为同一源码快照。

| 设备 | 外观 | 主巡游 | PNG / manifest | 图像审计 | 联系表目视 |
|---|---|---:|---:|---:|---:|
| 标准 Pro iPhone（约 393 × 852pt） | Light | 7/7 分组通过 | 66/66；1178 × 2556 px | 通过 | 通过 |
| 标准 Pro iPhone（约 393 × 852pt） | Dark | 7/7 分组通过 | 66/66；1178 × 2556 px | 通过 | 通过 |
| iPhone SE（第 3 代，375 × 667pt） | Light | 7/7 分组通过 | 66/66；750 × 1334 px | 通过 | 通过 |
| iPhone SE（第 3 代，375 × 667pt） | Dark | 7/7 分组通过 | 66/66；750 × 1334 px | 通过 | 通过 |
| iPad mini（744 × 1133pt） | Light | 7/7 分组通过 | 66/66；1488 × 2266 px | 通过 | 通过 |
| iPad mini（744 × 1133pt） | Dark | 7/7 分组通过 | 66/66；1488 × 2266 px | 通过 | 通过 |

主矩阵只统计 manifest 中的 66 张：64 个生产独立状态、1 张启动过程证据 `00-launch`、1 张测试专用保留页 `71-phone-login`。订阅弹窗、超时态和自由记录会话 3 张放在各矩阵 `_supplemental/`，不混入 396 张主证据。

每个目录均由 `scripts/design/audit_v56_screenshot_matrix.py` 检查：文件名精确匹配、PNG 可解码、像素尺寸一致、无近纯色页、无未批准重复哈希，并生成 `image-audit.json` 与 `contact-sheet.jpg`。

最终主证据目录：

- iPhone SE：`build/v56/w7/full/375x667/light/`、`build/v56/w7/full/375x667/dark/`
- 标准 iPhone：`build/v56/w7/full/392x852/light/`、`build/v56/w7/full/392x852/dark/`
- iPad mini：`build/v56/w7/full/744x1133/light/`、`build/v56/w7/full/744x1133/dark/`

矩阵共 396 张主 PNG。这里的“66”明确拆为 64 个生产可达状态、1 张启动过程证据 `00-launch`、1 张测试专用保留页 `71-phone-login`；它不是“66 个生产页面”的同义词。`70-login` 已有登录页身份锚点，Dark 不再误截个人页。

CoreSimulatorService 在长矩阵运行期间出现过启动/连接中断：SE Dark 第 2 组在第 2 次成功，标准 iPhone Dark 第 1 组在第 3 次成功、第 6 组在第 2 次成功，另有一次 iPad Light boot wait 恢复。失败均发生在服务连接、测试 bundle 或 App 启动阶段，没有产品断言失败；报告只将最终成功 attempt 计入 7/7。

## 目视结论

- 训练 / 计划 / 动作库：高频筛选不再出现 Light 黑块、Dark 白块；选中项统一为较弱的品牌绿表面，主 CTA 仍保持最高强度。
- 练习大厅 / 理论：侧栏导航、标签、warning 与教学图解职责分开；相邻页面不再交替出现无语义的金、黄、橙强调。
- 暗场工具：黑底、球桌绿、球色、白线、红绿接触点与控制条没有被全局换色；Light 内容页进入暗场后的标题、返回、更多和主操作关系稳定。
- 历史 / 统计：保持既有中性层级和 v55 owner；没有借 v56 重排统计信息架构。
- 个人 / 订阅：Guest 登录是唯一首要行动；Pro 卡由炭黑承载，生成香槟纹理只出现在原星形/皇冠内部；warning 使用橙色，不再与付费身份混淆。
- 登录 / Onboarding：Apple 黑白品牌按钮、现有 Hero 与页面结构均未改变；生产登录仍为 Apple + 匿名，手机号表单只保留测试专用深链。

## 可访问性与专项状态

| 状态 | 证据 | 结论 |
|---|---|---|
| AX XXXL | `build/v56/w7/focused-variants/ax-xxxl-light/`；`special-focused-ax-xxxl-light.xcresult` | 1/1 通过；Guest 唯一主登录、warning、Pro 第二编码、筛选与订阅入口均可达，无文字遮挡主行动 |
| High Contrast | `build/v56/w7/focused-variants/high-contrast-dark/`；`special-focused-high-contrast-dark.xcresult` | 1/1 通过；Premium 回退清晰纯色，皇冠/`Pro 会员` 双编码成立，筛选仍有形状/选中 trait |
| Reduce Transparency | H-28 | 代码已实现纯色回退，但未取得可信系统态截图：当前 `simctl ui` 无此开关，候选偏好虽可回读为 1，LLDB 实测 `UIAccessibilityIsReduceTransparencyEnabled()` 仍为 `NO`，已清理；不记自动通过 |
| 颜色外第二编码 | `.isSelected`、`PRO` 文本、lock/star/crown、warning 图标与固定位置 | 通过 |

标准状态聚焦色彩 Light/Dark 各 1/1，通过证据在 `build/v56/w7/focused-variants/standard-light/` 与 `standard-dark/`。`testV47BrandSample` Light/Dark 各 1/1，确认生产登录仍是 Apple + 匿名，微信/手机号只是“暂未开放”说明，手机号表单仅测试深链可达。

## 构建与测试

- 标准 Debug build：`make -f scripts/Makefile build`，`BUILD SUCCEEDED`。
- `QiuJiTests/AtmosphereCatalogTests`：11/11 通过；结果包 `build/v56/w7/unit-DD/Logs/Test/Test-QiuJi-2026.09.04_03-06-53-+0800.xcresult`。
- v56 聚焦颜色 UI：Light 1/1、Dark 1/1；品牌登录 Light 1/1、Dark 1/1；High Contrast Dark 1/1；AX XXXL Light 1/1。
- 最终 6 组主巡游：42/42 分组通过；图片审计 6/6、396/396 通过。
- `btAccent` 扫描仅剩 v55 冻结的 `AngleHistorySection`、`btChartSeries` 与兼容定义；`.toolbarColorScheme(.dark)` 仅剩共享 `btDarkToolChrome` 的单一集中消费点。
- `make -f scripts/Makefile verify-gate` 通过：内容/发布/DTO/文案/v47 UI 基线均 FAIL 0。
- `git diff --check` 通过；本报告无待填占位。工作区原有并行/未跟踪文件未被回退或清理。

## 证据边界

- 本报告的 396 张主矩阵与专项辅助功能截图均为模拟器证据；不替代 OLED 真机在低亮度下的黑位、浅灰文字和暗部封面检查。
- 当前 60 张封面仍是此前固定随机种子的试装集合，未获得素材级 G1 批准；v56 只统一了无彩色共享遮罩，不把随机选择写成正式设计裁定。
- 未修改品牌绿 Asset Catalog、Apple 登录品牌按钮、球号/球色、轨迹几何、训练数据、登录能力或 Pro 权益。
- `btPremiumOnDark` 是 DR-084 的局部背景修正：Light 页内固定炭黑表面不再使用对 `#1C1C1E` 仅约 `3.45:1` 的深金，而改用 `#E7D3A0`（约 `11.52:1`）；随页面外观变化的普通表面仍使用动态 `btPremiumForeground`。
