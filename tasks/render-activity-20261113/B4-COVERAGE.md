# B4 共享集成与遗漏核对（2026-11-13）

组合为 B1 按变化更新 HUD + B2 共享场景维护；B3 已淘汰，因此材质、shader 身份和缓存配方没有新增变化。此文件区分源码接入与实际运行，不把 27 组历史推广清单等同本轮 27 页实测。

## 实际接入机制

- `AngleSceneView` 8 处生产调用全部继承 B2 viewport；其中启用 adaptive diagram labels 的页面才使用标注缓存。所有调用均明确传入 contentIsAnimating；nil 兼容仍保留，但不存在需要本轮冒称实测的 nil 生产宿主。
- `BTAimCloseupOverlay` 5 处调用默认使用 B1：FreePlay 普通、FreePlay 每日、BTTeachingTablePage、AimPointSceneTrainingView、BatchAuthoringView。无需逐页实验开关。
- 共享 `BTTeachingTablePage` 15 处直接调用含 Accuracy、AngleDynamic、CushionEnglishAtlas、SeparationAngleAtlas、SolverStageChrome、Bank、Defense、KBall、Kick、PocketTolerance、PlanThree、Silu、Separation、ThreeBall、TwoBall。是否实际显示 HUD 仍由业务 snapshot/偏好/答题阶段控制；颗星解球明确不提供该直接碰球特写。
- 图解标注 opt-in：Silu、PlanThree、BankShot、DiamondSystem、AimingQuiz、SeparationAngleAtlas、AngleDynamic、CushionEnglishAtlas。缓存球成员顺序，保留真实投影和球态检查。
- 原始逐点搜索含行号/哈希：[B4-call-sites.json](B4-call-sites.json)。raw configure/reference 命中包含定义与条件，不能当独立消费点数。

| AngleSceneView 直接宿主 | B1 | B2 | 本轮验证层级 |
|---|---|---|---|
| FreePlayView | 普通、每日两处继承 | 继承 | B1 每日 2D/3D；B2 分离角与走位真实两杆/撤销/后台/重进 |
| BTTeachingTablePage | 按业务 snapshot 继承 | 继承 | B2 角度动态；B4 翻袋与颗星 |
| BatchAuthoringView | 继承 | 继承 | B4 编辑控件定向复验 |
| AimPointSceneTrainingView | 继承，保留答题后强制特写 | 继承 | B4 瞄准点 2D/3D 定向复验 |
| SceneAimingView | 无此 HUD，不适用 | 继承 | 源码/编译，未单独 UI |
| DrillSceneView | 无此 HUD，不适用 | 继承 | 源码/编译，未单独 UI |
| BallExtractionView | 无此 HUD，不适用 | 继承 | 源码/编译，未单独 UI |
| BatchBallExtractionView | 无此 HUD，不适用 | 继承 | 源码/编译，未单独 UI |

## 27 组材质消费族逐项判断

以下 27 组入口源文件逐一核到与 `f516e36b4` 字节一致，哈希见 [B4-material-consumers.json](B4-material-consumers.json)。这证明本轮没有顺带改动其接线，行为通过仍以实际测试为准。原有 R/guard 安装保持；B3 没有候选进入 App。

| 消费族 | 本轮安装与适用性 | 验证层级 |
|---|---|---|
| 每日清台 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | B1 每日原生 UI；B5 固定输入对照 |
| 分离角与走位、试打、蛇彩、多球、自定义球形、编排台 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | B2 分离角与走位 2 杆、模式/临时俯视、后台/退出 |
| 批量动作工作台 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | B4 定向 UI，最终结果见下文 |
| 角度动态教学 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | B2 动态教学原生 UI |
| 角度练习/场景瞄准 | 继承 B2；该独立答题宿主没有共享近景 HUD | 源码/编译；不计作本轮单页 UI 通过 |
| 瞄准点练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | B4 定向 UI，最终结果见下文 |
| 准度练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 分离角练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 两球练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 三球练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| K球练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 解球练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 翻袋练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 防守练习 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 翻袋求解 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | B4 定向 UI，最终结果见下文 |
| 颗星体系/解球工具 | 继承 B2；业务特例：颗星解球明确无直接碰球 HUD | B4 定向 UI，最终结果见下文 |
| 思路训练 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 打一走二想三 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 分离角图谱 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 加塞吃库图谱 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 袋口容差 | 共享实时宿主继承 B2；有 HUD snapshot 时继承 B1 | 源码/编译；不计作本轮单页 UI 通过 |
| 球形提取预览 | 继承 B2；提取预览不新增 HUD | 源码/编译；不计作本轮单页 UI 通过 |
| 动作详情/训练记录嵌入预览 | 继承 B2；没有近景 HUD | 源码/编译；不计作本轮单页 UI 通过 |
| 设置外观组合预览 | 不适用 B1/B2：独立预览或离屏消费者；原材质配方不变 | 源码/编译；不计作本轮单页 UI 通过 |
| 引导外观选择预览 | 不适用 B1/B2：独立预览或离屏消费者；原材质配方不变 | 源码/编译；不计作本轮单页 UI 通过 |
| 瞄准特写台呢底图 | 不适用 B1/B2：独立预览或离屏消费者；原材质配方不变 | 源码/编译；不计作本轮单页 UI 通过 |
| 明确匹配App的视频/静帧导出 | 不适用 B1/B2：独立预览或离屏消费者；原材质配方不变 | 源码/编译；不计作本轮单页 UI 通过 |

## 构建、身份与限制

- 最终 App 源码是 B1 提交 `4b222f35c` + B2 两个生产文件差分；模拟器 App SHA256 `8e6dcf74bb807aefc9b76d0a346a24fa517ab38b46eaf77838b0ff5deb7ebecb`。
- 已签名 iPhone Debug 候选构建成功，`codesign --verify --deep --strict` 成功；身份与路径见 [B4-device-build.json](B4-device-build.json)。用户表示手机暂不方便，未覆盖安装。
- 正常 Release 构建被既有 API_BASE_URL HTTPS/cuephys.com 规则拒绝；未改生产 API 配置绕过。独立 Debug 配置去掉 Swift DEBUG 条件的 App 构建通过，仅覆盖非 DEBUG 编译分支，**不是完整 Release 通过**。Swift 条件与二进制身份见 [B4-nondebug-build.json](B4-nondebug-build.json)。原始日志：`output/render-activity-20261113/b2/release-build.log`、`output/render-activity-20261113/b4/nondebug-build.log`。
- 本轮可用核心设备为 13 英寸 iPad / iOS26.3.1。其他核心手机受占用/保护，未抢占；iPhone 尺寸和最低 iOS17 的本轮 UI 仍待验。手机构建不等于手机交互通过。

## 环境与旧用例失败保留

第一轮 App 原构建路径消失，后续 launch 失败；此前同一 DerivedData 上并行运行不同输出配置构建，未取得确切删除者证据。停止已核身份的测试进程与遗留 diagnose，保存日志/原图；结果包不完整，不能报通过。随后从已安装 App 读回相同 SHA，冻结 App+runner+xctestrun 到独立目录。

第二轮已解决包路径问题；旧用例仍错误要求颗星解球出现已取消的特写设置，另一个用例仍用旧方向尺标识。代码确认 `SolverStageChrome` 明确禁用颗星特写、瞄准点尺当前为 `aimPointTraining.aimWheel`。修正测试合同并保留原失败；没有改 App 去迎合旧测试。详 FL-269 与后续最终复验。

本轮普通入口检查 `testDefaultRecipeOnDailyAndOrdinaryFreePlay` 已通过：无 shader 实验参数，实际 installed guard 身份及容量为预期，2D/3D 切换保留 rendererID。首页进入每日与普通 FreePlay 均有运行证据；这不是仅看请求 flag，也不代替其他页面 UI。原件 `output/render-activity-20261113/b4/ui-final/ui.xcresult`。

最终组合轮的普通入口、翻袋/颗星例外两项通过；瞄准点用例仍停在现行“训练设置”首屏，先前仅修尺标识不足。原失败 AX 已有 `aimPointTraining.start`，据此补真实开始训练与显式选视图，并用内存训练存储隔离两臂；只补跑受影响的 quiz/batch selector，其他两项不重跑。此为测试入口修正，不改产品入口。

B4 另审 B2 第二杆停稳原图：球、球影、轨迹、球库与控制列存在；当前 iPad 竖屏低位相机本来包含较多天花/墙面，本轮不改相机布局，不能据截图宣称新的构图改善。

quiz 复验已实际完成 2D/3D 调方向、提交与常驻答案特写，但随后 batch 关闭失败：AX 中“关闭打点”是覆盖全桌的背景按钮，中心点被打点盘挡住，旧 `.tap()` 实际打在盘内。原图和层级保留；改点同一背景按钮的可见空白处，关闭断言保持不变，没有改生产手势。

原图审阅包括翻袋 2D/3D 启用状态、瞄准点 2D/3D 提交后常驻对比特写、批量编辑打点盘以及 B2 停稳页。图中显示目标/实际线、球号、落位及控制列；仅认定这些原图未见本轮显示缺失，不作为逐像素等价或所有页面审查结论。

## 最终集成结论

三个目标 selector 均有有效通过记录：[B4-ui-results.json](B4-ui-results.json)。普通安装/切模式（54.819 秒）和翻袋/颗星显隐（130.785 秒）在 ui-final 通过；瞄准点 2D/3D 的实际开始训练、调向不提交、显式提交后保留特写，以及批量编辑打点/回中/关闭在 ui-quiz2 通过（63.036 秒）。旧失败与结果包不改写成通过。

本地集成通过并交付 B1+B2 默认组合；“iPhone 尺寸、最低 iOS17、完整 Release、手机温升”仍未通过，不能将此阶段局部交付等同全量发布验收。局部页面合同 TP15/16/17/18/23/27/29/30/35 继承，其他条款未因本轮代码改变。
