# v47 W0 可复现基线契约

状态：W0 已冻结（2026-08-30）。本文件固定后续真实 App 截图、交互测试与性能对拍的输入。Stitch 图只能作为设计输入，不属于此基线。

## 1. 只读代码基线与分支

- 基线提交：`4ea85a0b021d5807366335323e9e3d6431c45c70`。
- 执行分支：`codex/v47-ui-redesign`，从上述提交创建。
- 创建分支时保留的用户工作区内容：`tasks/PROGRESS.md`、`问题集合_v47.md` 的未提交改动，以及 `tmp/cover-*`、`tmp/plan-cover-validation/`、设计师截图日志等未跟踪文件。它们不属于 W0 提交，不得清理或顺手 stage。
- 每批只提交该批明确登记的文件；W15b 前不合入 `main`。

## 2. 工具链与固定设备

| 角色 | 设备 / UDID | Runtime | 用途 |
|---|---|---|---|
| 主设备 6.3 英寸 | iPhone 17 Pro / `9B456D2E-C90E-4324-8E98-51A4CCA930A1` | iOS 26.2 | 全批主截图、单元测试、性能对拍 |
| 窄档 6.1 英寸 | iPhone 15 Pro / `4EDDB52C-BBF2-44B2-A52F-081448BE0BAE` | iOS 17.0 | 布局下界、Dynamic Type |
| 宽档 6.9 英寸 | iPhone 17 Pro Max / `897D4818-96AD-4A14-B56D-9AE036D44333` | iOS 26.2 | 宽屏与安全区 |
| UI 隔离设备 | iPhone 17 / `16F181F1-0F1B-4307-8EC8-C1DE22896F20` | iOS 26.2 | 长 UI 巡游，避免与单测重装 App 互杀 |

- Xcode：26.2（Build `17C52`）。
- SDK / Simulator Runtime：主基线 iOS 26.2；兼容下界另跑 iOS 17.0。
- Scheme：单元与普通 UI 用 `QiuJi`；长巡游可用 `QiuJiUITour`，但必须显式 `-only-testing`。
- DerivedData：`build/DerivedData-v47-baseline`（W0）或 `build/DerivedData-v47-<batch>`（后续），不得复用其他会话目录。
- 跑 UI 测试前先检查并行 `xcodebuild`；长巡游固定 UI 隔离设备，禁止用设备名模糊匹配。

## 3. 区域、时间、身份与数据

| 维度 | 固定值 |
|---|---|
| 语言 | `-AppleLanguages (zh-Hans)` |
| 区域 | `-AppleLocale zh_CN` |
| 时区 | `Asia/Shanghai` |
| 计时制 | 24 小时制 |
| 设计冻结日期 | `2026-08-30` |
| 截图稳定时刻 | 页面稳定条件满足后截图；禁止仅靠一个固定 sleep 判断网络/求解/动画完成 |
| Onboarding | 常规场景传 `-hasCompletedOnboarding YES`；首次引导场景显式不传 |
| 订阅 | `guest-empty` / `free-standard` 传 `-resetDebugPremium -forceNonPremium`；`pro-standard` 传 `-resetDebugPremium -forcePremium` |
| 网络 | `normal`、`offline-error` 均由可控 fixture/launch hook 触发；禁止真的断网碰运气 |
| 数据 | fixture ID + seed 一并写入每批截图 manifest；禁止沿用模拟器上次运行的 SwiftData/UserDefaults 状态 |

W0 固定四套场景名：

- `guest-empty`：游客、Free、空训练/历史数据。
- `free-standard`：登录 Free、固定训练/历史样本、固定长文本。
- `pro-standard`：登录 Pro、与 `free-standard` 同一数据 seed。
- `offline-error`：登录 Free、固定数据、网络请求确定性失败并提供重试。

现有 `launchClean` 已固定语言、区域、Onboarding 和清理模拟器 Pro 持久位。四套数据/网络 fixture 在后续页面批次首次消费前必须以显式 launch argument 落地；在此之前，66 张 W0 图片只作为结构/视觉参考，不能做盲像素回归。

## 4. 外观、字体和辅助功能

- 每批至少：Light + Dark、默认字号 + 一档 Accessibility Dynamic Type。
- W15a：Reduce Motion、Reduce Transparency、Increase Contrast 均纳入巡游。
- 背景或装饰图形不得进入 VoiceOver 树，也不得截获触摸。
- 截图目录必须是 `build/v47-*` 或 `tmp/`。`ScreenshotTourUITests` 默认写 `build/v47-screenshots/{light|dark}`；环境变量 `UI_POLISH_SHOT_DIR` 或 `/tmp/qiuji-uitest/shot_dir` 可显式覆盖。
- `snap` 的建目录和 PNG 写入错误必须 `XCTFail`；完整巡游结束后按 `baseline-screenshots.sha256` 的 66 个文件名检查缺图。

## 5. W0 冻结的 66 张 Light 参考图

- 目录：`tmp/designer-screenshots/`。
- 数量：66；全部为 1206×2622（iPhone 17 Pro 6.3 英寸像素档）。
- 采集时间：2026-08-30 02:56–03:19（Asia/Shanghai）。
- 外观：Light；语言/区域：`zh-Hans` / `zh_CN`；设计师巡游使用 Pro 解锁参数。
- 哈希真源：`baseline-screenshots.sha256`。已删除旧路径 `12b-theory-t03.png` 不得恢复或计入 67。
- 限制：这批图是在固定 fixture 契约建立前采集，数据/日期不是机器注入，因此只用于结构与视觉对照。新实现的“完成截图”必须另存到每批 `build/v47-*`，并附完整输入 manifest。

## 6. 测试与性能命令

```bash
make -f scripts/Makefile verify-gate
xcodebuild -project QiuJi.xcodeproj -scheme QiuJi -configuration Debug \
  -derivedDataPath build/DerivedData-v47-baseline \
  -destination 'platform=iOS Simulator,id=9B456D2E-C90E-4324-8E98-51A4CCA930A1' \
  build-for-testing
xcodebuild -project QiuJi.xcodeproj -scheme QiuJi -configuration Debug \
  -derivedDataPath build/DerivedData-v47-baseline \
  -destination 'platform=iOS Simulator,id=9B456D2E-C90E-4324-8E98-51A4CCA930A1' \
  -only-testing:QiuJiTests test-without-building
```

核心 UI smoke 固定在 UI 隔离设备，至少包含五根页无标题、训练入口、历史/统计、订阅，以及截图写盘/缺图门禁。W0 与 W15a 必须使用同一设备、Runtime、fixture 和命令形状对比。

性能记录对象：训练根页、历史页各做一次静态 10 秒和连续滚动 15 秒采样；记录主线程热点、峰值内存、是否持续刷新、滚动可见卡顿。模拟器仅作同机趋势证据，发布结论优先真机。

## 7. 当前真实基线结果

| 检查 | 结果 |
|---|---|
| `verify-gate` | PASS；C1–C4、I5–I13、发布链路与双端对齐均 FAIL 0；v47 截图/路由/写盘门禁 FAIL 0 |
| `build-for-testing` | PASS；当前 W0 源码 `** TEST BUILD SUCCEEDED **` |
| 全量 `QiuJiTests` | 基线失败：终端最终汇总 822 tests / 11 skipped / 16 failure events / 705.0s；xcresult 聚合为 1055 total / 10 failed test cases / 12 skipped（测试宿主崩溃后重启导致计数口径不同） |
| Bake gate 回归 | PASS；陈旧 flag 边界测试 1/1；普通全量前 `build/.run-bake-runners` 必须不存在 |
| 五根页无标题 | PASS；`testV47TabRootsHaveNoNavigationTitle` 1/1，39.9s |
| 66 页巡游 | PASS；`testDesignerPageDump` 1/1、0 failure，1348.019s；`build/v47-screenshots/light` 含 66 个 manifest 必需文件，另有兼容入口 `12b-theory-t03.png` 1 张；xcresult：`build/v47-w0-66-tour-safe.xcresult` |
| 性能采样 | PASS；训练/记录各静置 10s + 滚动 15s，计量轮 60.754s；App CPU 6.460s；物理内存增量 3,358.720KB；峰值 593,415.936KB；滚动/减速 signpost 2.566s |

全量基线的 10 个失败测试如下，均发生在 v47 视觉生产改动之前或与其无关；W15a 必须逐条复测，不得用“无新增失败”替代：

1. `AimCloseupEvidenceTests/test_writeCompositeEvidence`：左右特写断言两值同为 253.135。
2. `DrillBakeRunnerTests/test_bakePilotDrills_areFeasibleAndPrintBakedAnimation`：陈旧 Bake flag 误开门后无法加载 `drill_c002`；W0 已增加 30 分钟新鲜度门禁并补回归。
3. `DrillBoardBuilderTests/test_c042_multiShot_withObstacles_usesFirstShotOnly`：期望 3 杆，实际 1 杆；随后路径 unwrap 失败。
4. `DrillContentValidationTests/test_allDrills_pocketValueIsValid`：`c022/c045/c049/c054/c055/c060` 的 pocket 为空。
5. `DrillContentValidationTests/test_index_totalDrillCount_is84`：索引 74，期望 84。
6. `DrillContentValidationTests/test_loadedDrillCount_matches84`：Bundle 载入 74，期望 84。
7. `DrillTryoutBoardStoreTests/test_briefLines_withoutFormation_unchanged`：期望 3 杆路径。
8. `BankKickAdjustmentDraftLayerTests/test_bank_adjustDraft_doesNotMutateCatalog_andCycleRestoresOriginal`：测试宿主崩溃。
9. `V30X1TutorialEmptyContentRenderTests/test_targetDrills_containContentlessItemsSections`：`c003/c024/c033` 不再含预期的 content 缺省节。
10. `V30X1TutorialEmptyContentRenderTests/test_tutorialPage_rendersContentlessSections_lightAndDark`：`c003` 对应纯 items 节 unwrap 失败。

测试开始时发现 2026-08-26 遗留的 `build/.run-bake-runners`，它曾让常规全量测试改写 15 张跟踪缩略图。W0 已从 Git 精确恢复这些资源、移走陈旧 flag，并让 file gate 仅接受 30 分钟内创建的标记；当前 `QiuJi/Resources/DrillThumbnails` 与 `QiuJi/Resources/Drills` 均无测试污染。

任何既有失败或 warning 必须在此表逐条保留到 W15a；不得写成“无新增失败”而省略基线事实。
