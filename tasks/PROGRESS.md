# 开发进度（PROGRESS）

> Orchestrator 每次会话开始时读取本文件，结束时更新。
> 另须读取 `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（若存在）。

> **全面质量诊断专题：已暂停（2026-09-06，用户决定）**：因工作量较大，余下工作上线后再议；不自动恢复。已保存训练/历史、内容工具、账号、本地StoreKit、真实Mongo及代表设备/Release局部证据，重点QD007/008/012/021等未修复。M1深色测试已按要求中断；整体诊断与最终报告未完成。见[暂停记录与阶段结果](quality-diagnosis/PAUSE-SUMMARY.md)。

> **GitHub 提交检查（2026-09-06）**：按用户“当前所有代码提交并 push”授权，收录当前代码、测试、60张已暂存封面、计划内容、v57及质量诊断归档；排除本地 `output/`、`tmp/` 和已忽略构建产物。标准 Debug 构建 `BUILD SUCCEEDED`、完整 `verify-gate` 通过，凭据模式扫描未发现匹配，CSV仅统一换行。证据 `build/commit-push-20260906/`。本次未重跑完整测试矩阵；v57未完项与质量诊断暂停状态继续保留。提交后远端同步结果以 Git 提交记录及本次交付为准。

---

## 任务状态（四态）

| 符号 | 含义 | 使用说明 |
|------|------|----------|
| ⏳ | 待开始 | 尚未开工 |
| 🔄 | 进行中 | 附 DoD 进度，例：`🔄 进行中（DoD 2/5）`；会话可能中断时**必须**写入，便于恢复 |
| ⚠️ | 返工 | 附 `见 FL-xxx`，对应 [`tasks/IMPLEMENTATION-LOG.md`](IMPLEMENTATION-LOG.md) 条目；修复后改回 ⏳ 或 🔄 |
| ✅ | 已完成 | Phase 任务卡 DoD 全部满足 |

---

## 当前状态

> **滚动归档纪律（强制）**：本区只保留**最近 10 条以内**（或最近 3 天）条目；更早条目移入 [`tasks/archive/PROGRESS-当前状态-归档.md`](archive/PROGRESS-当前状态-归档.md)（新条目插到归档文件说明块之后的顶部，保持时间倒序）。每次追加新条目时顺手检查：超过 10 条即归档最旧的。历史检索一律去归档文件，勿在本区堆积。

- **问题集合 v57 🔄 实施中（2026-09-05，Orchestrator → SwiftUI Developer）**：用户已授权全部 W0–W8。W0 ✅ 62 单测/2 UI/build；W1 ✅ 50 单测含磁盘恢复；W2 ✅ 三源首页、自由训练闭环、模版编辑/加入、计划状态及滚动稳定，八单元 48 次测试/240 图 + 三尺寸补验 6 次/21 图通过并已目视，FL-039/040/041 已复验收口，证据 output/v57/W2/REPORT.md。原 60 封面与诊断测试基线保留。W3 ✅ 日序/51短标题/同栈详情返回，七单元35 UI/98图均通过并目视，非标题字段指纹不变，FL-039/042/043最终复验；完整内容门禁通过。W4 ✅ 已练次数/菜单/加入按钮；31聚焦单测、12渲染图、最终六单元24 UI/54图通过并审查，标准Debug build通过；FL-044/045原场景已收口，output/v57/W4/REPORT.md。W5 ⚠️ 返工：用户否决放大球体和增高底栏造成的比例失衡，已保存补丁并恢复6文件至W4指纹；恢复构建通过。DR-090新方案保持30/36球体与94/140底栏，最大球库宽352、行间距0；SE 14单测/1 UI通过，改前后台呢边界与球库顶部相同；iPad 1 UI/2图亦通过，前后台呢/底栏边界一致；待全部消费者和3D，见output/v57/W5/proportion-preserving/REPORT.md。W6 ✅ 中性游客卡/Pro状态行；最终27单测、四组16 UI/44图通过并目视，标准build/完整门禁通过；FL-048虚拟身份网络隔离，固定字体与真实StoreKit边界见output/v57/W6/REPORT.md。W7 🔄：旧休息结束延迟回调误关新休息已复现并修复；修前3用例中2失败，修后完整57单测通过，证据output/v57/W7/REST-RACE-REPORT.md。加时改为完整ContentState，截止时间重算及缩短/过期边界已覆盖，最新63单测/标准Debug build通过，见output/v57/W7/REST-STATE-REPORT.md。用户真机复测确认>1分钟锁屏数字正常，当前缺陷为左侧进度不随时间比例变化、灵动岛文字遮挡；已撤去临时单因素变体，系统时间进度及锁屏完整文字已通过r4系统截图复验；用户再次指出展开上方空白，r5改为leading/trailing同一行、bottom仅进度，移除额外展开边距；r5 iPhone17Pro/iOS26.2系统UI测试1例通过，4张截图已目视：上方两侧呈现标题/时间、锁屏2:47→2:05进度同步且全文字保留；外壳由系统决定，真机仍待复验。系统异步交付仍待验。W8 待实施。球库覆盖全部相关页面含练习页；锁屏进度与灵动岛仍待最终真机复验。未 commit/push。下一步：W5 先重审整页占比；用户再次指出球库/球桌比例失衡，DR-090的不缩桌证据不等于视觉验收。已复看原图与SE图并核算352×88最小命中网格、等比台面与底栏约束，见output/v57/W5/proportion-preserving/PROPORTION-REVIEW.md；本次只读诊断，未改生产布局。三目标诊断r8已通过1例/36组/21档，预设安全区下10组无现有可行档；独立数值草稿1794组通过但最大距离8.065m可读性未验，未接入生产，见output/v57/W5/CAMERA-DIAGNOSTIC-REPORT.md。DR-092已接生产三目标拟合与真实键盘高度避让，辅助/答题局部44pt高/15pt字号；SE2 UI/9图与标准手机最终4单测+1 UI/6图通过且已目视，见output/v57/W5/FRAMED-IMPLEMENTATION-REPORT.md。新增iPad1单测+2UI/9图与SE17两单测+1UI/6图通过且15图已目视；生产固定种子215场景、16模型球顶点核验已通过，母球表面标记纳入0.25mm渲染余量，最终3单测复验通过。仍需极端小球题面截图、窗口变化/真实环绕UI与全页面球库整改。2026-09-06用户真机打回DR-092：默认3D视角更低，纵向滑动失去高度/俯仰调节并表现为缩放。已读码确认framedAimingPose分支固定pitch、同比缩放radius/height，纵向交互回归未被原横向环绕测试覆盖；相机项保持返工。用户随后否决新增叠加曲线，要求恢复最初效果但保留自动取景；已撤销40°–75°候选与额外俯仰增量，恢复原22°–45°/40°–50°曲线，自动取景只求观察端的距离/居中。最终 original-curve-tests-raw.log：4单测+1 UI通过（TEST SUCCEEDED）；包含215几何场景、18姿态、原曲线五档对拍、升降往返和生产renderUpdate持续帧保留手动状态。3张场景原图与6张真实训练页图已目视；仅iPhone SE/iOS26模拟器，真机手感待复验。 W5整体仍未完成，见FL-051。 最新用户裁定：自动取景也撤销，恢复原始相机（2026-09-06）。CameraRig/AngleSceneView已恢复HEAD原文，SceneAiming恢复enterAiming及母球锚定；求解器和专用诊断测试移至output/v57/W5/withdrawn-camera归档，DR-092相机方案及FL-051后续方案均撤销。回退验证完成：原相机3项单测通过；最终重新编译并运行3题真实训练页UI通过，6截图已核对。CameraRig/AngleSceneView与修改前HEAD逐字一致，证据camera-rollback-source.json、camera-rollback-tests-raw.log、camera-rollback-final-ui-raw.log。恢复旧视角与键盘覆盖行为，不再保证三目标自动入镜。 2026-09-06 训练 Tab 周天数显示修正：分母取实际训练天数与偏好天数较大值，屏幕文字与无障碍标签共用 displayedWeeklyGoalDays；偏好 4 天、实际 5 天显示 5/5，偏好不回写。Debug build 通过（/tmp/qiuji-weekly-days-build-approved.log）；未做模拟器截图/VoiceOver 实听。
- **问题集合 v56 全 App 色彩与 Pro 材质 W0–W7 自动化范围 ✅（2026-09-04，Orchestrator）**：真源 `问题集合_v56.md` v56.8，实施报告 `tasks/ui-reviews/UR-20260904-v56-color-implementation.md`。保留原布局、卡片与 `star.fill` / `crown.fill`，品牌绿仍为 Light `#1A6B3C` / Dark `#25A25A`；生成细拉丝香槟只进入原 SF Symbol mask。筛选统一弱绿，warning/success/teaching/physics/data 与 Premium 解耦，Guest 仅保留一个主登录行动，固定暗场 Chrome 集中化；DR-084 以 `btPremiumOnDark #E7D3A0` 修正 Light 页面内炭黑 Pro 卡对比。v56 截图冻结指纹 `20f603c8dd6b6dbc83dc37821821550dd9cc8bd9e437793f6b919db43ed4b25f`；iPhone SE / 标准 iPhone / iPad mini × Light/Dark 6/6、396/396 主截图与六张联系表通过，聚焦色彩、品牌登录 Light/Dark、高对比 Dark、AX XXXL Light 通过，`AtmosphereCatalogTests` 11/11 和 Debug build 通过。截图后并行 v54 仅修改其独立 UI test，导致全仓指纹漂移但未改变 v56 生产/截图输入。60 张封面仍是未批准随机试装，v56 只做中性遮罩与只读审计；OLED 低亮度和 Reduce Transparency 真实系统态转 H-28，不宣称人工全量验收。未 commit。
- **问题集合 v55 统计页纯训练数据方向 W0 + W0.1 + G1 ✅ / W1 待开始（2026-09-03，Orchestrator）**：真源 `问题集合_v55.md` v55.6。用户在周/月/年共 9 张候选后接受“C 双训练域骨架 + A 顶部总览/留白”；详细方案已将页顶周/月/年固定为球台与屏内两域唯一时间维度，补齐 rolling 区间、完整分箱、稳定分类行、Free 权益边界、全状态矩阵、断言失效机理、写盘测试盘点和并行冲突台账，拆为 W1–W5 五个可独立验收批次。本轮只更新方案/进度，未改 SwiftUI、ViewModel、schema 或测试。prompt / fixture / SHA-256 仍在 `output/imagegen/statistics-v55-built-in/MANIFEST.md`。未 commit。
- **问题集合 v54 官方主线计划、今日编排与模版并行：代码完成 / H-27 人工待验（2026-09-03，Orchestrator + iOS Architect + SwiftUI Developer + Test Engineer + UI Reviewer）**：真源 `问题集合_v54.md` v54.10，W0–W9 代码完成。12 个官方计划已迁为 43 阶段/129 课；SwiftData V5、唯一官方主线、跨来源今日队列、来源快照、复练/连续推进/跨缺口预习、动态预计、scheduled block 原子保存与同步、计划详情/首页/模版/动作/历史 UI 均已落地。v54 XCTest 35/35、旧周结构回归迁移 8/8、backend 15/15、XCUITest 四设备外观组合 12/12（52 张）、通用模拟器构建与 verify-gate 通过。完整单测 1,279 项中 5 个 v54 旧契约失败已修复，剩余 10 项归属既有诊断资产/视觉布局/认证进程问题；H-27 仍需真实拖动、最大动态字体、VoiceOver、Reduce Motion、跨日/时区与真机离线恢复，因此未标全量人工验收完成。未 commit。
- **问题集合 v53「我的」账号资料、偏好与数据隔离，头像生产服务已部署 / 其余真实环境待验收（2026-09-03，Orchestrator + Data Engineer + Test Engineer）**：真源 `问题集合_v53.md` v53.9。W0–W6 代码与模拟器自动化完成；“每次训练时长目标”已删除，真实训练计时/历史/统计保留。真机头像上传 404 已定位为 `106.54.3.210:3000` 仍运行 2026-08-12 旧后端，缺 `/user/avatar` 与新 Profile 字段；已创建 `/root/qiuji-backend-backup-20260903-avatar-predeploy.tar.gz`，定向部署 v53 认证/资料/头像文件，配置 `/var/lib/qiuji/avatars`、重启 PM2，进程 online 且外部 `/health` 200。合成账号 Profile 五字段 PUT 与头像 PUT/GET/DELETE 均 200，revision/JPEG/文件删除一致，探针用户和文件遗留均为 0。当前 backend 15/15、iOS v53 unit 46/46、Profile/Settings 基础 UI 17/17、相册/通知系统权限各 2/2、本地 StoreKit 3/3、标准 build 通过。H-09 仍存在证书/Varnish/Cloudflare 521；H-26 仍需用户手机选图、退出重登、备份恢复演练、真实 Apple 首次/再次登录、真机到点通知与 App Store sandbox。未 commit。
- **新用户引导内容重构 / D 聚焦系列待反馈（2026-09-03，Orchestrator + UI Reviewer + SwiftUI/视觉设计）**：用户否决 A 真实台面、B 轻量 3D、C 几何编辑式三组三联稿，原因是“不好看、没有体现重点”。已停止继续堆风格，改为每页一个视觉命题：碰撞点、正在执行的训练、薄弱点直达下一项练习；内置 ImageGen 分别生成 3 张 1536×1024 独立横图，落盘 `docs/design/onboarding-concepts-20260903/series-d-focus/`。当前仅用于判断叙事重点，**尚未获用户认可、尚未做确定性几何/真实 App UI 合成、尚未改 SwiftUI/认证逻辑、尚未做模拟器验收**。未 commit。
- **问题集合 v52 每日清台 ✅（2026-09-03，Orchestrator）**：真源 `问题集合_v52.md` v52.1，W0–W4 全部完成。训练首页已接未开始/继续/今日已清三态入口；每日模式复用 `FreePlayView`，支持五玩法默认值、确定性自动开球、单人规则、恢复、重开/换玩法、失败/完成与再来一局；草稿/completion 本地保存，工具记录继续排除周目标与准确率。自动证据：单元/共享回归 90/90、v52 UI 9/9、普通自由击球/通用开球/两宿主/P5 入口 5/5，SE/17 Pro/iPad mini 的 Light/Dark/AX 聚焦矩阵全部通过；`make build` 与总门禁 FAIL 0。报告 `tasks/ui-reviews/UR-20260903-v52-daily-clearance.md`。未 commit。
- **“我的”本月概览接入真实统计 ✅（2026-09-03，Orchestrator + SwiftUI Developer + Data Engineer）**：`ProfileView` 已由固定占位符改为查询 `TrainingSession` 并实时显示本自然月练习天数、训练时长和最长连续训练天数；统一按训练数据契约计入 `drill + cognitive`、排除 `tool`，同一天多场只计 1 个训练日。新增自然月边界、训练类型、去重、时长与连续天数覆盖，`StatisticsViewModelTests` 29/29 通过；组件级修复前后截图已生成。独立 `make build` 当前被并行工作区既有的 `ShotTableLayout.Mode` 重复 raw value（`paletteOnly` / `composer` 均为 94）阻塞，与本项文件无关。未 commit。
- **问题集合 v51 紧凑手机响应式布局系统修复 ✅（2026-09-04，Orchestrator + Test Engineer + SwiftUI Developer + UI Reviewer）**：真源 `问题集合_v51.md` v51.8，W0–W5 全部完成。最终源码指纹下 A 级全页巡游 16/16、1,056/1,056，B 级合约 12/12、36/36，C 级 Light/Dark 聚焦 16/16、176/176，AX5 4/4、44/44；iOS 17/26 纯布局单测 26/26，双 Runtime 安全单测 2,270 项、失败 0、既有跳过 8。训练计时单行、五 Tab 浮标零相交、紧凑竖轨与球库、长状态和 Chip 风险均完成共享修复；16 张联系表及关键原图审查后开放 P0/P1/P2=0。Debug build、`verify-gate`、`verify-doc-size` 通过；结论仅覆盖 Simulator。未 commit/push，原有 v54/v56 等 dirty 工作保持不动。
- **封面提示词系统 v1 / 4 候选生成 + 随机 App 试装 ✅（2026-09-03，Orchestrator + Content Engineer + SwiftUI Developer）**：12 个官方计划、36 个练习入口与 12 个自定义模板均已各生成 4 张，共 240/240；60/60 张四选一联系表已落盘。按用户后续授权，以固定随机种子 `ec06c13311dea1f7894c6de81b6b374d` 从每组抽 1 张写入本地正式 Asset Catalog，分布 v01/v02/v03/v04 = 25/12/10/13；原 60 张完整备份，安装哈希 60/60 匹配。主工作区 `make -f scripts/Makefile build` 通过；iPhone 17 Pro Light 的计划、学、理、练、打、解 UI 截图测试 6/6 通过，前后截图及六页面总览已归档。随机抽中不代表视觉批准，当前保留试装状态等待用户选择；球号、六点红点、额外球杆及构图一致性仍须目视裁定。真源 `docs/design/20260902-card-cover-prompt-system-v1.md`，预览 `output/imagegen/cover-prompt-system-v1/20260903/app-preview/PREVIEW.md`。未 commit。
## R0 Design System Upgrade — ✅ 已完成

> **前置**：UI 设计全部完成。P4 暂停于 T-P4-04。详见 `tasks/phases/R0-design-system.md`。

| 任务 | 状态 |
|------|------|
| T-R0-01 创建 UI-IMPLEMENTATION-SPEC.md | ✅ 已完成（2026-04-05）|
| T-R0-02 Token 值审计 | ✅ 已完成（2026-04-05）|
| T-R0-03 BTButton 补全 7 种样式 | ✅ 已完成（2026-04-05）|
| T-R0-04 新建组件 Batch 1（导航/布局） | ✅ 已完成（2026-04-05）|
| T-R0-05 新建组件 Batch 2（训练） | ✅ 已完成（2026-04-05）|
| T-R0-06 新建组件 Batch 3（反馈/分享） | ✅ 已完成（2026-04-05）|
| T-R0-07 校验与更新已有组件 | ✅ 已完成（2026-04-05）|
| QA-R0 Phase R0 验收 | ✅ 附条件通过（2026-04-05）— 3 项 P2 改进记入下一迭代 |

---

## P1 Foundation — 部分完成（阻塞项已推迟）

| 任务 | 状态 |
|------|------|
| T-P1-01 Xcode 项目初始化 | ✅ 已完成 |
| T-P1-02 SPM 依赖初始配置 | ✅ 已完成（ADR-001）|
| T-P1-03 Design System Token | ✅ 已完成 |
| T-P1-04 5 Tab 导航骨架 | ✅ 已完成 |
| T-P1-05 登录流程 UI | ✅ 已完成 |
| T-P1-06 Sign in with Apple | ✅ 已完成 |
| T-P1-07 REST API + 手机验证码登录 | ⏳ 待开始（H-15 推迟） |
| T-P1-08 微信登录集成 | ⏳ 待开始（H-05 推迟） |
| T-P1-09 AppConfig + .gitignore | ✅ 已完成 |
| QA-P1 P1 验收 | ⏳ 待开始 |

---

## P2 Data Layer — 功能完成，待人工验收

| 任务 | 状态 |
|------|------|
| T-P2-01 SwiftData Schema | ✅ 已完成（2026-03-29）|
| T-P2-02 Local Repository | ✅ 已完成（自动化测试 42/42）|
| T-P2-03 ~~CloudKit~~ | ✅ 已取消（ADR-002）|
| T-P2-04 Bundle Fallback JSON | ✅ 已完成（2026-03-29）|
| T-P2-05 后端用户数据同步 | ✅ 已完成（2026-03-29）|
| T-P2-06 匿名用户本地模式 | ✅ 已完成（2026-03-29）|
| T-P2-07 SyncQueue | ✅ 已完成（2026-03-29）|
| QA-P2 验收 | ✅ 附条件通过（2026-04-10）— 235/235 自动化 + 31/31 人工测试；3 issue（FL-001/FL-002/B-03）已修复 + Code Review 确认；条件：用户重建后确认修复生效 |

---

## P3 Drill Library — ✅ 附条件通过

| 任务 | 状态 |
|------|------|
| T-P3-01 ~ T-P3-11 | ✅ 全部已完成（2026-03-29，自动化测试 47/47）|
| QA-P3 验收 | ✅ 附条件通过（2026-04-11）— 自动化 47/47；人工 TP-P3 50/53 执行，3 项失败（FL-003/FL-004/FL-005）已修复并验证；设备矩阵/可访问性/性能待补测 |

---

## P4 Training Log — ✅ 附条件通过

| 任务 | 状态 |
|------|------|
| T-P4-01 官方训练计划 JSON | ✅ 已完成（2026-03-29）|
| T-P4-02 训练 Tab 今日计划视图 | ✅ 已完成（2026-03-29）|
| T-P4-03 官方计划列表与详情页 | ✅ 已完成（2026-03-29）|
| T-P4-04 开始训练流程 | ✅ 已完成（2026-03-29）|
| T-P4-05 训练中 Drill 记录界面 | ✅ 已完成（2026-04-05，使用 BTSetInputGrid + BTExerciseRow）|
| T-P4-06 心得备注输入 | ✅ 已完成（2026-04-05，匹配 code.html 设计，DR-004）|
| T-P4-07 训练完成总结页 | ✅ 已完成（2026-04-05，匹配 code.html 设计，使用 BTLevelBadge 等 R0 组件）|
| T-P4-08 TrainingSession 持久化 | ✅ 已完成（2026-04-05，saveTraining 已在 T-P4-04 实现并测试通过 30/30）|
| T-P4-09 自定义训练计划 | ✅ 已完成（2026-04-05，匹配 code.html 设计，DR-007）|
| T-P4-10 TrainingShareView（新增） | ✅ 已完成（2026-04-05，BTShareCard 升级匹配 code.html + 定制面板 + 分享入口）|
| QA-P4 验收 | ✅ 附条件通过（2026-04-11）— 自动化 235/235 + 人工 TP-P4 92/98；FL-006/FL-007/FL-008 已修复，FL-009 P3 延后 |

---

## P5 Angle Training — ✅ 已完成

| Phase | 状态 | 备注 |
|-------|------|------|
| P5 Angle Training | ✅ 已完成（2026-04-05） | 代码审查 + 设计对齐 + 22 测试通过 |

---

## P6 History + Statistics — ✅ 已完成

| 任务 | 状态 |
|------|------|
| T-P6-01 历史 Tab 日历视图 | ✅ 已完成（2026-04-05）— BTSegmentedTab + 6 行日历 + 训练分类标签 + 设计对齐 |
| T-P6-02 训练详情页 | ✅ 已完成（2026-04-05）— Sheet 模态 + 统计横滚 + Drill 组明细 + 底栏操作 |
| T-P6-03 统计视图 | ✅ 已完成（2026-04-05）— BTTogglePillGroup + 三张统计卡片 + 左侧绿线装饰 |
| T-P6-04 训练频率柱状图 + 趋势线 | ✅ 已完成（2026-04-05）— Swift Charts BarMark + RuleMark，琥珀+品牌绿双色 |
| T-P6-05 各类别成功率对比 | ✅ 已完成（2026-04-05）— 2 列网格替代雷达图，环比变化 + 迷你柱状图 |
| T-P6-06 Freemium 历史查看限制 | ✅ 已完成（2026-04-05）— HistoryAccessController 60 天限制 + 锁定提示 |
| QA-P6 验收 | ✅ 附条件通过（2026-04-12）— 人工 TP-P6 日历/详情/动画/边界/性能全通过；统计 Pro paywall 正确生效（符合规格）；Pro 统计 UI + 60 天限制 e2e 待 TestFlight 补测 |

---

## P7 Subscription — ✅ 已完成

| 任务 | 状态 |
|------|------|
| T-P7-01 StoreKit 2 集成 | ✅ 已完成 — StoreKitService + Products.storekit 3 个 IAP |
| T-P7-02 订阅状态管理 | ✅ 已完成 — SubscriptionManager isPremium + Transaction.updates 监听 |
| T-P7-03 订阅页 UI | ✅ 已完成（2026-04-05）— 深色 #111111 全屏 + 金色编号功能列表 + 3 列方案卡 + 年订绿框推荐 |
| T-P7-04 恢复购买 | ✅ 已完成 — AppStore.sync() + 成功/失败 Alert |
| T-P7-05 Freemium 边界整合 | ✅ 已完成（2026-04-05）— 修复 AngleTestView limiter isPremium 同步 bug |
| QA-P7 验收 | ✅ 通过（2026-04-05）— 代码审查 + 234/234 自动化测试通过 |

---

## R-UI Existing Page Alignment — ✅ 附条件通过

> 详见 `tasks/phases/R-UI-alignment.md`

| 任务 | 状态 |
|------|------|
| T-RUI-01 TrainingHomeView 对齐 | ✅ 已完成（2026-04-05）— 今日安排卡片 + BTSegmentedTab 计划浏览 + 筛选 Chip + 固定底部按钮 + 空状态 |
| T-RUI-02 DrillListView + DrillDetailView 对齐 | ✅ 已完成（2026-04-05）— 灰色操作图标行 + 标签行 + darkPill/primary 固定底栏 + Pro 金色底栏 |
| T-RUI-03 ActiveTrainingView 对齐 | ✅ 已完成（2026-04-05）— 毛玻璃顶栏 4 图标 + 计划名进度条 + 5 键底栏带文字标签 + 橙色热身标记 |
| T-RUI-04 ProfileView + LoginView 对齐 | ✅ 已完成（2026-04-05）— 彩色圆底图标菜单 + 月度概览 + 游客警告/Pro 推广卡 + 三按钮登录 + 药丸验证码输入 |
| T-RUI-05 OnboardingView 对齐 | ✅ 已完成（2026-04-05）— 品牌绿圆底图标 + QJ Logo + 强制浅色 + 3 FeatureRow |
| QA-RUI 验收 | ✅ 附条件通过（2026-04-05）— D-1 已修复；8 项 P2 改进记入 P8 |

---

## P8 Polish & Release — 🔄 进行中

| 任务 | 状态 |
|------|------|
| T-P8-01 Privacy Manifest | ✅ 已完成（2026-04-05）— PrivacyInfo.xcprivacy 创建 + Xcode Target 添加 |
| T-P8-02 性能优化 | ✅ 代码审计通过（2026-04-06）— LazyVStack/Canvas/debounce 等已优化；4 项 Instruments 指标待人工验证 |
| T-P8-03 空状态与加载态全覆盖 | ✅ 已完成（2026-04-05）— BTShimmer 骨架屏 + 6 场景空状态/加载态全覆盖 |
| T-P8-04 首次引导流程完整版 | ✅ 已完成（2026-04-06）— 3 页 TabView + Capsule 页指示器 + 跳过/登录分页按钮 |
| T-P8-05 个人设置页 | ✅ 已完成（2026-04-06）— SettingsView（球种+周目标）+ 账号注销 + 隐私政策链接 |
| T-P8-06 账号注销与数据删除 | ✅ 已完成（2026-04-06）— 在 T-P8-05 中一并实现（二次确认 + DELETE API + 失败重试）|
| T-P8-07 XCTest 核心流程测试 | ✅ 已完成（2026-04-06）— 235/235 通过（+1 CRUD update 测试）|
| T-P8-08 TestFlight 内部测试 | ⏳ 待开始 |
| T-P8-09 App Store 资产准备 | ⏳ 待开始 |
| T-P8-10 App Store 提交审核 | ⏳ 待开始 |
| T-P8-11 Dark Mode 全面通刷 | ✅ 已完成（2026-04-05）— 21 Token 双值验证 + 14 文件修复 + D-1~D-7 全部确认 |
| T-P8-12 人工测试计划更新与执行 | ✅ 已完成（2026-04-06）— TP-P2/P3/P4 更新 + TP-P5/P6/P7 新建 + H-17 人工执行项 |
| T-P8-13 R-UI QA P2 改进项 | ✅ 已完成（2026-04-05）— 8 项全部处理（P8-A~H，详见下方） |
| QA-P8 最终验收 | ⏳ 待开始 |

---

## 阻塞项

| 阻塞 ID | 影响任务 | 描述 | 负责方 |
|---------|---------|------|--------|
| H-05 | T-P1-08 | 微信开放平台资质 — 🔜 推迟至 App 主体开发完成后 | 人工 |
| H-15 | T-P1-07 | 腾讯云短信服务 — 🔜 推迟至 App 主体开发完成后 | 人工 |

---

## Phase 完成记录

| Phase | 完成日期 | 备注 |
|-------|---------|------|
| R0 Design System | 2026-04-05 | 附条件通过（3 项 P2 改进记入 P8 Polish）|
| P1 Foundation | — | 部分阻塞（H-05, H-15 推迟）|
| P2 Data Layer | 2026-04-10 | 附条件通过（FL-001/FL-002/B-03 已修复，待用户重建确认）|
| P3 Drill Library | 2026-04-11 | 附条件通过（FL-003/FL-004/FL-005 已修复；设备矩阵/可访问性/性能待补测）|
| P4 Training Log | 2026-04-11 | 附条件通过（人工 92/98 + FL-006/007/008 已修复；FL-009 P3 延后）|
| P5 Angle Training | 2026-04-05 | 代码审查 + 设计对齐 + 22 测试通过 |
| P6 History | 2026-04-12 | ✅ 附条件通过（人工 TP-P6 + 234/234 自动化；Pro 统计 UI + 60 天限制 e2e 待 TestFlight 补测）|
| P7 Subscription | 2026-04-05 | 5 任务完成 + SubscriptionView 设计对齐 + Freemium 全整合 + 234/234 测试 |
| R-UI Alignment | 2026-04-05 | 附条件通过（D-1 已修复；8 项 P2 改进记入 P8-13）|
| R1 UI 逐页审查 | 2026-04-06 | 11 份报告完成，145 项偏差（P0:0 / P1:33 / P2:112）|
| P9 Aiming Expansion | 2026-06-02 | QA-P9 通过；241/241 自动化 + 人工功能验收；FL-016 + PD-007 修复；T-P9-D-REVIEW/T-P9-00 收尾 |
| P8 Polish & Release | — | 仅剩人工：H-17 人工测试 / TestFlight / App Store 资产与提交 |

---

## R1 UI 逐页审查 — ✅ 已完成

> 详见 `tasks/phases/R1-ui-review.md` + `tasks/ui-reviews/UR-20260406-*.md`（11 份）

| 任务 | 状态 |
|------|------|
| T-R1-01 TrainingHomeView 审查 | ✅ 已完成（2026-04-06）— 10 项（P1:3 / P2:7）|
| T-R1-02 ActiveTrainingView 审查 | ✅ 已完成（2026-04-06）— 16 项（P1:3 / P2:13）|
| T-R1-03 TrainingSummary + ShareView 审查 | ✅ 已完成（2026-04-06）— 17 项（P1:3 / P2:14）|
| T-R1-04 Plans（List+Detail+Builder）审查 | ✅ 已完成（2026-04-06）— 18 项（P1:7 / P2:11）|
| T-R1-05 DrillLibrary 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:6 / P2:7）|
| T-R1-06 AngleTraining 审查 | ✅ 已完成（2026-04-06）— 16 项（P1:1 / P2:15）|
| T-R1-07 History + Statistics 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:2 / P2:11）|
| T-R1-08 Profile + Settings 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:4 / P2:9）|
| T-R1-09 Onboarding + Login 审查 | ✅ 已完成（2026-04-06）— 7 项（P1:1 / P2:6）|
| T-R1-10 SubscriptionView 审查 | ✅ 已完成（2026-04-06）— 11 项（P2:11）|
| T-R1-11 全局 + 组件审查 | ✅ 已完成（2026-04-06）— 11 项（P1:3 / P2:8）|

**汇总**：全部 11 个审查任务完成，共发现 **145 项偏差**（P0: 0 / P1: 33 / P2: 112）。

---

## P9 Aiming Feature Expansion — ✅ 已完成（QA-P9 通过 2026-06-02）

> 详见 `tasks/phases/P9-aiming.md`

| 任务 | 状态 |
|------|------|
| T-P9-00 UI 设计交付文档更新 | ✅ 已完成（2026-06-02）— `09-UI设计交付文档.md` §3.3 补 5 页 + AngleHome 分组 + 对照表增强 + 导航树 + §7.5 |
| T-P9-D-01~06 UI 设计出图 | ✅ 已完成（2026-04-14，6/7 APPROVED） |
| T-P9-D-REVIEW 设计一致性审查 | ✅ 已完成（2026-06-02）— `ui_design/tasks/P9-REVIEW/consistency-review.md`，无 P1 偏差 |
| T-P9-01 SceneKit 场景基础设施 | ✅ 已完成（2026-04-14）— ADR-P9-01 |
| T-P9-02 数据层扩展 | ✅ 已完成（2026-04-14） |
| T-P9-03 AngleHomeView 导航重构 | ✅ 已完成（2026-04-14） |
| T-P9-04 瞄准原理页 | ✅ 已完成（2026-04-14） |
| T-P9-05 角度与打点动态关系页 | ✅ 已完成（2026-04-14） |
| T-P9-06 几何角度预测训练 | ✅ 已完成（2026-04-14） |
| T-P9-07 SceneKit 角度预测页（2D/3D） | ✅ 已完成（2026-04-14） |
| T-P9-08 SceneKit 角度预测增强 | ✅ 已完成（2026-04-14） |
| T-P9-09 进球点对照表增强 | ✅ 已完成（2026-04-14） |
| T-P9-10 浅淡球感页 | ✅ 已完成（2026-04-14） |
| T-P9-11 AngleHistoryView 增强 | ✅ 已完成（2026-04-14） |
| QA-P9 验收 | ✅ 通过（2026-06-02）— `tasks/qa-reports/QA-P9.md`；241/241 自动化 + 人工功能验收（用户确认）；修复 FL-016（几何训练 Freemium 闸门）+ PD-007（测试宿主/模块名，恢复命令行测试） |

---

## 执行顺序

```
R0 ✅ → P4 ✅ → P5 ✅ → P6 ✅ → P7 ✅ → R-UI ✅ → R1 ✅ → P9 ✅ → P8 🔄（仅人工）
```

---

## 下一步

- **【问题集合 v49 — W0–W22 ✅ 全案收官（2026-09-01，v49.31）】**：动作库与练习卡文案系统重写已完成；后续只在发现新的技术事实或用户训练意图变化时定向修订，不再保留 v49 执行批次。
- **【问题集合 v38 — 立档，待拍板（2026-08-14，v38.0）】**：v37 R4 内容层收口。真源 `问题集合_v38.md`。下一步：裁定 D-v38-1/2/3 后开 W0。v37 已提交 `7d229fa`。
- **【P18 发布收敛 — 当前主线】（2026-07-03 立卡）**：按 `tasks/phases/P18-release-convergence.md` 七批执行，**B1 ✅（2026-07-03）**，当前批 **B2**（T-P18-05 组件下沉 → T-P18-10 ShotControlBar，预估 2–3 会话）。人工并行项：**H-19 App 备案今天启动**、H-18 音效素材、H-09 隐私政策、TP-P7、ADR-P10-09 手感验收。
- **【P12 内容体系与理论挂接 — 规划已立，待执行】（2026-06-14，ADR-P12-01）**：单一真源 [`curriculum-map.md`](curriculum-map.md) + phase 卡 `tasks/phases/P12-content-system-theory.md`。**待用户拍板**：地图 §6 三参数（每格配额 / L4 是否进 v1.0 / 系统训练模式定位）。**第一刀（建议新会话）**：c042 竖切——扩 `DrillContent.theoremIds/moduleIds?` + `TutorialSection.theoremRefs?`（可选向后兼容）、vendor `16/contracts/*.json` 进 `Resources/Theory/`、c042 精讲三层披露 + 建 T01/T03 理论详情页（复用 `AngleTrainingScene` 标注图）+ 学习区"球理"入口卡、建 `THEORY-CONSUMPTION-LOG.md` 翻 16 中枢卡 v1.0 final（达成 16↔13 闭环）。
- **✅ 动作库内容管线 + 击球意图 schema 雏形（2026-06-04 完成）**：见上方 P10 Track A 条目 + `tasks/phases/P10-physics-content-pipeline.md`（ADR-P10-01）。**下一步**：~~① 把 `shotIntent` 推广到全量 72 条~~ ✅（见下）；② 废弃 `BTDrillPreviewPlayer` 的 PNG 帧序列、动画统一由烘焙轨迹驱动；③ 展示三件套（GIF 烘焙轨迹 / 精讲参数化对错对比 / 视频降级为真人身体动作）统一重构；④ 多杆球（`obstacles`/多 shot）+ **翻袋/吃库瞄准**烘焙支持（当前 v1 直瞄无法表达 c055/c057 等特殊球路）。
- **✅ shotIntent 全量补齐（2026-06-04，iOS Architect 调度 8×content-engineer 并行，DR-017 后续）**：为剩余 67 条 Drill 并行补 `shotIntent`（8 子智能体各管一 category，按描述/杆法推断 velocity+spin），+5 试点 = **72/72 全有 shotIntent**、JSON 全合法。新增可行性扫描 `test_scanFeasibility`：**67/72 引擎干净落袋**；修 2 条几何颠倒（c039/c062）+ 6 条 follow 误推乱弹（改中心球）。**5 条特殊球路**（c055 翻袋/c057 K球吃库/c058 贴库/c061 解球/c066 开球）单杆直瞄无法干净进 → c055 退回手画、余渲染真实物理近失（v1 烘焙器不支持翻袋/吃库瞄准，记 H-11）。72 缩略图全量重烘焙。详见 H-11 § shotIntent 全量补齐 待物理核查。
- **✅ P10 Track B-1 物理保真进球管线（2026-06-04 完成，ADR-P10-02）**：见上方 Track B-1 条目。USDZ 实测证伪「jaw 放错 17mm」预设（几何自洽）。用户复评后拒绝"放宽捕获半径"偷懒做法，改建**真实袋口物理（喉腔模型）**：jaw 库 + 实测 jaw 尖端挤出的喉腔侧壁/后壁（可反弹）+ 物理落袋孔，rattle 由几何涌现；配套稳健化闭环求解（采样寻优最优接触点）+ 画面=物理（objectPath 真实模拟、轨迹基进袋判定）。E-solver/中袋/c002 全绿，291/291。详见 `tasks/qa-reports/PHYSICS-PROBE.md` §USDZ 实测标定。
- **【P10 物理标定 — 剩余】**：① 中袋 jaw mouth ±0.035→对齐实测 ±0.046（非阻塞微调）；② **常量标定**（e_b/台呢库边摩擦/恢复系数，**需真实球俯拍视频**，用 `PhysicsBenchmarkTests` 钉死）；③ 朴素瞄准 E-geom 3/5 属窄喉口掠角真实物理（产品用求解器规避，非闸门）。

0. **全局字体密度优化已完成**（2026-05-26，DR-014 / PD-006）：
   - Typography Token 全局下调（btDisplay 48→44 / btDisplaySmall 36→30 / btLargeTitle 34→32 / btChapterNumber 32→26 / btTitle 22→20 / btTitle2 20→18 / btTitleMedium 19→17 / btStatNumber 28→24）
   - 页面级局部修正：TrainingHomeView 今日 Drill 卡标题降级 + 序号轻量化 + issueThumbnail 硬编码改 Token；PlanDetailView statCell 数字 + 描述 lead 句降权
   - SKILL.md 与 UI-IMPLEMENTATION-SPEC.md 字体规范同步更新，新增「使用原则」四条避坑指引
   - 实施日志新增 DR-014 + PD-006（双层修法模式）
   - 构建验证：`make build` 通过；ReadLints 无错误
   - **待人工复核截图**：训练首页、动作库、计划列表、计划详情、角度首页、我的、训练总结

1. **P9 实现任务全部完成**（2026-04-14）：
   - Wave 1：SceneKit 基础设施 + 数据层 quizType + 导航重构（7 功能分组）
   - Wave 2：5 独立页面（瞄准原理 / 角度与打点 / 几何训练 / 对照表增强 / 浅淡球感）
   - Wave 3-4：SceneKit 2D/3D 角度预测 + 增强（训练类型/自由练习/幽灵球/瞄准线）
   - Wave 5：AngleHistoryView quizType 筛选增强
   - **待人工验收**：模拟器运行验证 SceneKit 加载 / 2D↔3D 切换 / 角度计算 / Dark Mode
   - **ADR-P9-01**：SceneKit 引入决策已记录
2. **R1 审查 + 修复 + DrillLibrary 改造已完成**（2026-04-06）：
   - 11 份审查报告 → 145 项偏差 → 10 组并行修复 → 235/235 测试通过
   - **DrillLibrary 参照训记全面改造**（DR-011）：
     - 新建 `BTMiniTable.swift`（缩略图 Canvas：球径 3x + 路径 2x + 袋口高亮 + 无库边）
     - `BTDrillGridCard` 使用 BTMiniTable + 等级徽章/PRO/收藏叠加层 + 底部渐变
     - `DrillListView` 改为训记风格：左侧分类侧边栏（72pt）+ 右侧 2 列网格
     - `DrillDetailView` 新增：备注输入卡、训练维度 5 进度条、查看精讲按钮、真人示范占位
     - `BTDrillListSkeleton` 更新为 2 列网格骨架
   - **延后项**：TrainingHome「即将到来」Section、DrillRecordView 休息设置行、BTShareCard 备注 toggle、History 新增功能按钮
   - **下一步**：人工测试（H-17）→ TestFlight
2. **P8 待执行**：
   - **H-17 人工测试执行**：🔄 5/6 已执行（TP-P2/P3/P4/P5/P6 ✅），**仅剩 TP-P7 订阅**（需 StoreKit sandbox/真账号 — [HUMAN]，约 30 分钟）
   - T-P8-08（TestFlight 发布 — [HUMAN]）
   - T-P8-09（App Store 资产准备 — [HUMAN]）
   - T-P8-10（App Store 提交 — [HUMAN]）
   - QA-P8 最终验收
3. **人工测试**：6 份测试计划已就绪（TP-P2~P7），待人工在模拟器/真机上执行（见 H-17）。
4. **后端部署** ✅（2026-03-29）：已部署至 106.54.3.210:3000，72 条 Drill 已 seed。
5. **知识累积机制**：`tasks/IMPLEMENTATION-LOG.md`（FL/DR/PD 三类条目）+ `UI-IMPLEMENTATION-SPEC.md` Changelog 节跨会话保持实施知识。

---

## 已完成 Phase 归档

当某一 Phase **全部任务**均为 ✅ 后：

1. 将任务明细表剪切至 `tasks/archive/Pn-completed.md`。
2. 在「Phase 完成记录」表中填写完成日期。
3. 从下一会话起仅读当前 Phase 任务卡。
