# 开发进度（PROGRESS）

> Orchestrator 每次会话开始时读取本文件，结束时更新。
> 另须读取 `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（若存在）。

> **全面质量诊断专题：已暂停（2026-09-06，用户决定）**：因工作量较大，余下工作上线后再议；不自动恢复。已保存训练/历史、内容工具、账号、本地StoreKit、真实Mongo及代表设备/Release局部证据，重点QD007/008/012/021等未修复。M1深色测试已按要求中断；整体诊断与最终报告未完成。见[暂停记录与阶段结果](quality-diagnosis/PAUSE-SUMMARY.md)。

> **GitHub 提交检查（2026-09-07）**：按用户“当前代码提交到 GitHub 并 push”授权，收录训练输入/布局、账号同步选择、引导与 Pro 第一版、3D 辅助线及相关测试/正式资源/文档；排除本地 `output/`、`tmp/` 与已忽略构建产物。Debug 构建 `BUILD SUCCEEDED`、完整 `verify-gate` 通过；凭据模式与大文件扫描未发现问题。首轮路由台账漂移，经逐入口审计后同步覆盖表和签名，复验 FAIL 0。证据 `build/commit-push-20260907/`。本轮未重跑完整测试矩阵；引导第二版规划、v57未完项与质量诊断暂停状态保留，下方“未提交”属于各任务原始记录，本次提交范围以 Git 记录为准。下一步完成 commit/push 并核对远端同步；结果以本次交付和 Git 为准。

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

- **角度训练辅助线延伸 ✅（2026-09-07，DR-117）**：2D/3D点击辅助后白线沿母球→假想球继续到台呢边界。Debug BUILD SUCCEEDED，6单测（含144组方向边界断言）及1项双模式辅助开关UI测试通过；17Pro/iOS26.2四张截图已目视。证据 `output/angle-assist-rail/REPORT.md`；前后随机题不同，3D无本轮改前图，真机/iPad未验，未提交。 DR-118后续：假想球圆环/中心点抬至球心高度；测试构建及6单测/1双模式UI通过，2D/3D辅助截图已目视，见output/ghost-center-height/REPORT.md；其他共享节点消费者未逐页复验。

> **引导与 Pro（2026-09-07，DR-119）🔄 引导第二版规划；第一版实现与局部自动化完成**：用户要求重排引导叙事，并明确高级球形仅用于合适页面、选图须进入动作详情。已实看横向蛇彩围 8、高级蛇彩双球形/精讲全屏及 K球吃库球形 1/2；第二版建议“学习 → 推演 → 训练 → 记录”，详见 `tasks/ui-reviews/PLAN-20260907-onboarding-v2.md`。本轮仅方案文档，待补拍工具/训练/记录并排版预览，未改 App；Pro 保持列表。以下为第一版历史验证，不代表设计认可：四页真实截图引导接入“我的 → 认识球迹”；Pro 五项权益列表、三套餐、全局浅深色，游客登录返回保留选择。保持启动直达首页与现有权益门控。17 Pro / SE（iOS26.2）关键流程通过，包括翻页/跳过/看完不改账号、套餐选择、本地 StoreKit 月度购买与恢复；最终两设备浅深色 24 图已目视并校验尺寸/唯一 SHA，小屏竖图标记遮挡已修复。最终 Debug BUILD SUCCEEDED、diff --check 通过；详见 `tasks/ui-reviews/UR-20260907-onboarding-pro-v1.md`，预览 `output/onboarding-pro-v1/preview.html`。真机、真实付款、iPad/完整 AX 未验；未提交，保留并行修改。早期讨论记录 `UR-20260907-onboarding-pro-planning.md` 已注明被最终列表方案替代。

- **DR-113 模版卡片与紧凑新建按钮（2026-09-06）✅**：横向双列、七字宽、≤6项预留三行动作/标签第四行，名称与方图顶边对齐，去掉标题下空白；新建按钮改为居中内容宽度、最小44pt高。8项计数单测沿用通过证据，17Pro浅色两项UI通过并核对实际图；SE八种布局通过、菜单单项复跑通过并核对实际图。菜单/新建/编辑返回均保留；中间导航与滚动失败记录保留。见output/template-card-layout/REPORT.md；未提交，保留并行修改。

- **五 Tab 几何线稿背景 ✅（2026-09-06，DR-114）**：共享 BTBlueprintBackground 接入训练、动作库、练习、记录、我的；训练构图沿用，记录/我的降低图案密度，固定底层、不占布局、不响应点击。最终 iOS26.2 SE浅色/17 Pro深色/iPad mini深色各1 UI通过（含目标页面身份断言），15图已目视并通过数量/解码/唯一哈希/实际外观校验；Debug测试构建通过。旧SE误页截图已排除并补身份断言复验。证据 `output/tab-blueprint/verified/`，报告 `tasks/ui-reviews/UR-20260906-tab-blueprint.md`；原有及并行变更保留，未commit/push，真机/VoiceOver实听未验。

- **启动直达首页与云同步选择（2026-09-06）✅ 自动化范围**：RootView 直达主界面，后台认证不提示；云同步按账号明确选择、设置可关闭，游客合并独立；旧身份/凭证响应不能覆盖新登录。最终47单测 + 标准/小屏共4次UI通过（TEST SUCCEEDED），8张改后截图已目视；真实Apple/双设备、深色同步控件/iPad/AX未验。ADR-P2-20260906 / DR-115，证据 `output/account-sync-choice/REPORT.md`。保留其他并行修改，未提交。 补充（2026-09-07）：我的普通菜单图标统一neutral，头像/会员/订阅强调保留；Debug BUILD SUCCEEDED，iPhone17Pro浅深色前后截图已目视，未测真机，DR-116；output/profile-neutral/。

- **3D训练默认中档试调（2026-09-06）**：按用户最新要求，3D瞄准训练/3D瞄准点训练共用 `enterAiming` 默认改为 zoom=0.5，沿用现有曲线（高出台面0.975m、半径1.85m、俯角27.75°、FOV45°）；每题确定性复位，手势上下限不变。X1_CameraAndAngleArcTests 3项通过（TEST SUCCEEDED），覆盖高/低起点入场与持续帧稳定，日志 `/tmp/qiuji-camera-midpoint-tests.log`。未做本轮画面/真机验收，待用户试看；未提交，保留原有并行修改。

> **2026-09-06 训练滑动方向纠正 ✅**：按用户纠正，第一项右滑回动作列表、左滑到第二项，第二项右滑回第一项。生产仅修改首项返回方向判断；iPhone SE/iOS26.2标准字号浅色连续手势UI 1/1通过（TEST SUCCEEDED），改前及改后三态截图已目视。证据 `output/training-swipe-direction/REPORT.md`；真机未验，原有并行修改保留，未提交。

> **2026-09-06 上方开始进入动作训练 ✅**：ActiveTrainingView 顶部计时按钮开始/继续成功后同步切换单项训练，保留当前动作索引（新会话默认第一项）；暂停不切页。iPhone SE/iOS26.2 定向UI回归1/1通过（TEST SUCCEEDED），总览→开始→单项及暂停留页已截图核对；证据 `output/start-opens-drill/`。本次仅新增按钮行为与定向测试，保留原有并行变更；未验证真机。

> **保存分享图后关闭页面（2026-09-06）**：`TrainingShareView` 在相册 `performChanges` 成功返回后调用 `dismiss()`，移除本页成功 toast；权限拒绝/渲染失败/写入失败保留错误提示及页面。既有 W1 UI 测试改为断言回到训练总结。Debug 构建 `BUILD SUCCEEDED`（`/tmp/qiuji-share-dismiss-build.log`）；本轮未执行相册 UI/真机流程，未提交。

> **滚动归档纪律（强制）**：本区只保留**最近 10 条以内**（或最近 3 天）条目；更早条目移入 [`tasks/archive/PROGRESS-当前状态-归档.md`](archive/PROGRESS-当前状态-归档.md)（新条目插到归档文件说明块之后的顶部，保持时间倒序）。每次追加新条目时顺手检查：超过 10 条即归档最旧的。历史检索一律去归档文件，勿在本区堆积。

- **Pro角标与会员权益统一 ✅（2026-09-06）**：计划详情导航栏右上角共享锁+PRO（iOS26去额外玻璃底）；计划卡、动作库/收藏、练习及统计按SubscriptionManager显示闭锁/开锁。独立Debug构建通过，最终2 UI/12图全部通过且目视，额外深色详情1图已目视；初轮键盘测试前置问题已复验。真机交易/全矩阵未验。DR-096，证据 `output/pro-lock-unification/REPORT.md`。原有并行修改保留，未commit/push。 补充退出修复：认证会话绑定、同步清空权益/有效期、旧请求版本校验、重登刷新；最终11单测（含本地StoreKit）+1退出UI通过，2图已目视，见 `output/pro-logout/REPORT.md`；真实Apple/真机未验。

- **课程右侧完成进度 ✅（2026-09-06，二次调整）**：每阶段右侧1pt细线贯穿课程区域顶部到底部，8pt圆点位于每张课程卡片中心；完成及提前练过品牌绿，其余白心，原课内点线保留。Pro详情角标字号10→15pt并增加内边距。独立Debug `BUILD SUCCEEDED`，iPhone17Pro Pro详情浅/深色前后截图已目视；未运行自动化测试/真机验收。DR-095；最新证据 `output/lesson-progress-right/revision2/REPORT.md`，原SE/折叠证据仅对应首版。并行改动保留，未commit。 第三次补充：右侧灰线按连续完成进度覆盖品牌绿，部分完成止于圆心、全完成贯穿；独立Debug通过，三态首屏截图已目视，未测真机/阶段底部，见 `output/lesson-progress-green/REPORT.md`。

- **问题集合 v57 🔄 实施中（2026-09-05，Orchestrator → SwiftUI Developer）**：用户已授权全部 W0–W8。W0 ✅ 62 单测/2 UI/build；W1 ✅ 50 单测含磁盘恢复；W2 ✅ 三源首页、自由训练闭环、模版编辑/加入、计划状态及滚动稳定，八单元 48 次测试/240 图 + 三尺寸补验 6 次/21 图通过并已目视，FL-039/040/041 已复验收口，证据 output/v57/W2/REPORT.md。原 60 封面与诊断测试基线保留。W3 ✅ 日序/51短标题/同栈详情返回，七单元35 UI/98图均通过并目视，非标题字段指纹不变，FL-039/042/043最终复验；完整内容门禁通过。W4 ✅ 已练次数/菜单/加入按钮；31聚焦单测、12渲染图、最终六单元24 UI/54图通过并审查，标准Debug build通过；FL-044/045原场景已收口，output/v57/W4/REPORT.md。W5 ⚠️ 返工：用户否决放大球体和增高底栏造成的比例失衡，已保存补丁并恢复6文件至W4指纹；恢复构建通过。DR-090新方案保持30/36球体与94/140底栏，最大球库宽352、行间距0；SE 14单测/1 UI通过，改前后台呢边界与球库顶部相同；iPad 1 UI/2图亦通过，前后台呢/底栏边界一致；待全部消费者和3D，见output/v57/W5/proportion-preserving/REPORT.md。W6 ✅ 中性游客卡/Pro状态行；最终27单测、四组16 UI/44图通过并目视，标准build/完整门禁通过；FL-048虚拟身份网络隔离，固定字体与真实StoreKit边界见output/v57/W6/REPORT.md。W7 🔄：旧休息结束延迟回调误关新休息已复现并修复；修前3用例中2失败，修后完整57单测通过，证据output/v57/W7/REST-RACE-REPORT.md。加时改为完整ContentState，截止时间重算及缩短/过期边界已覆盖，最新63单测/标准Debug build通过，见output/v57/W7/REST-STATE-REPORT.md。用户真机复测确认>1分钟锁屏数字正常，当前缺陷为左侧进度不随时间比例变化、灵动岛文字遮挡；已撤去临时单因素变体，系统时间进度及锁屏完整文字已通过r4系统截图复验；用户再次指出展开上方空白，r5改为leading/trailing同一行、bottom仅进度，移除额外展开边距；r5 iPhone17Pro/iOS26.2系统UI测试1例通过，4张截图已目视：上方两侧呈现标题/时间、锁屏2:47→2:05进度同步且全文字保留；外壳由系统决定，真机仍待复验。系统异步交付仍待验。W8 待实施。球库覆盖全部相关页面含练习页；锁屏进度与灵动岛仍待最终真机复验。未 commit/push。下一步：W5 先重审整页占比；用户再次指出球库/球桌比例失衡，DR-090的不缩桌证据不等于视觉验收。已复看原图与SE图并核算352×88最小命中网格、等比台面与底栏约束，见output/v57/W5/proportion-preserving/PROPORTION-REVIEW.md；本次只读诊断，未改生产布局。三目标诊断r8已通过1例/36组/21档，预设安全区下10组无现有可行档；独立数值草稿1794组通过但最大距离8.065m可读性未验，未接入生产，见output/v57/W5/CAMERA-DIAGNOSTIC-REPORT.md。DR-092已接生产三目标拟合与真实键盘高度避让，辅助/答题局部44pt高/15pt字号；SE2 UI/9图与标准手机最终4单测+1 UI/6图通过且已目视，见output/v57/W5/FRAMED-IMPLEMENTATION-REPORT.md。新增iPad1单测+2UI/9图与SE17两单测+1UI/6图通过且15图已目视；生产固定种子215场景、16模型球顶点核验已通过，母球表面标记纳入0.25mm渲染余量，最终3单测复验通过。仍需极端小球题面截图、窗口变化/真实环绕UI与全页面球库整改。2026-09-06用户真机打回DR-092：默认3D视角更低，纵向滑动失去高度/俯仰调节并表现为缩放。已读码确认framedAimingPose分支固定pitch、同比缩放radius/height，纵向交互回归未被原横向环绕测试覆盖；相机项保持返工。用户随后否决新增叠加曲线，要求恢复最初效果但保留自动取景；已撤销40°–75°候选与额外俯仰增量，恢复原22°–45°/40°–50°曲线，自动取景只求观察端的距离/居中。最终 original-curve-tests-raw.log：4单测+1 UI通过（TEST SUCCEEDED）；包含215几何场景、18姿态、原曲线五档对拍、升降往返和生产renderUpdate持续帧保留手动状态。3张场景原图与6张真实训练页图已目视；仅iPhone SE/iOS26模拟器，真机手感待复验。 W5整体仍未完成，见FL-051。 最新用户裁定：自动取景也撤销，恢复原始相机（2026-09-06）。CameraRig/AngleSceneView已恢复HEAD原文，SceneAiming恢复enterAiming及母球锚定；求解器和专用诊断测试移至output/v57/W5/withdrawn-camera归档，DR-092相机方案及FL-051后续方案均撤销。回退验证完成：原相机3项单测通过；最终重新编译并运行3题真实训练页UI通过，6截图已核对。CameraRig/AngleSceneView与修改前HEAD逐字一致，证据camera-rollback-source.json、camera-rollback-tests-raw.log、camera-rollback-final-ui-raw.log。恢复旧视角与键盘覆盖行为，不再保证三目标自动入镜。 2026-09-06 训练 Tab 周天数显示修正：分母取实际训练天数与偏好天数较大值，屏幕文字与无障碍标签共用 displayedWeeklyGoalDays；偏好 4 天、实际 5 天显示 5/5，偏好不回写。Debug build 通过（/tmp/qiuji-weekly-days-build-approved.log）；未做模拟器截图/VoiceOver 实听。 计划封面状态角标按用户要求统一右下角（TrainingHomeView / PlanListView）；iPhone SE iOS 26.2 改前/改后同一计划状态切换 UI 回归各 1/1 通过，已目视共享角标左右位置变化，证据 output/plan-badge-corner/；计划列表未另做截图。 所有官方计划详情移除封面下灯泡训练提示条及专用引用提取逻辑，保留动作训练要点；iPhone SE iOS26.2 计划切换/编排 UI 1/1 通过并目视课程安排直接承接封面（output/plan-detail-remove-tip/）。 2026-09-06 动作卡“已练 N 次”按用户要求移至底部行右侧，与卡片右内边距对齐（DR-093）；仅增加弹性留白。iPhone SE iOS26.2模拟器组件渲染改前1/1、改后2/2通过（TEST SUCCEEDED），前后图片已目视，证据output/drill-badge-trailing/；未做整页UI/真机验收。 训练HUD统一✅：五态44pt高/12pt边距，详情/试打操作栏避让及返回Tab跟踪；最终SE 4 UI、17 Pro 2 UI、计时2单测通过，截图已核对，output/hud-unification/REPORT.md；保留既有与并行改动，未提交。 2026-09-06 记分键盘按用户纠正改为内部“完成”（DR-097）：撤销上方toolbar按钮；两列使用UITextField自定义UIInputView，底行完成/0/删除。最终Debug BUILD SUCCEEDED；SE/iOS26.2 Light已目视最终键盘并验证7→删除→5→完成，数值保留、键盘收起、0/5组不变；总球绑定同样验证保留。证据output/score-keyboard-done/INTEGRATED-REPORT.md；真机/最终Dark未验，未commit/push。 HUD后续收紧✅：带时间的两态隐藏可见标题，仅图标+时间；44pt高和避让不变，SE 2 UI通过并目视，output/hud-unification/icon-time-only/。 2026-09-06 训练输入与心得DR-098：取代仅补完成键的交付口径；数字/文字统一键盘下收图标，软件键盘展开时底栏与休息浮层退场，整场心得独立sheet返回训练且保留计时状态及草稿。65单测通过；SE两项UI通过，增强键盘存在/编辑区边界后心得复验通过；标准手机两项UI通过，最终数字键盘≥44pt复验通过，SE最终数字键盘复验亦通过。FL-052修复sheet键盘工具栏缺失，改safeAreaInset入口。证据output/training-input-flow/REPORT.md；真机中文九宫格、iPad及最终Dark未验。未commit/push。 2026-09-06 DR-099覆盖输入确认及心得旧语义：数字键盘收起时确认当前未完成组并按设置休息；整场心得改本地草稿，收起后显示保存，保存写回并返回，直接返回放弃本次修改。最终66单测、SE/17Pro各2 UI通过，保存页与完成组截图已目视；证据output/training-input-confirm/REPORT.md。真机中文输入法待验，未提交。 DR-100训练精简与动作衔接已实现：心得保存改右侧120pt、多行取消上限、移除顶部进度细节、序号品牌绿、末组完成立即下一动作、首项右滑返回总览（按用户后续纠正，左滑进入第二项）。68单测/标准3 UI通过；小屏双动作返回1 UI及暂停计时文字/数字2 UI通过并目视。小屏运行计时文字测试因动画通知等待中止，保留边界；证据output/training-refinement/REPORT.md。未提交。 DR-101未开始训练退出已完成：选择动作但未计时/记录数据，确认显示继续训练/退出，退出直接返回且不走心得。71单测及17Pro真实自由训练退出1 UI通过，弹窗已目视；证据output/unstarted-training-exit/REPORT.md。未提交。 DR-102两层心得自动编号已完成：空心得1.起、回车续号、空行回车/退格退出、自动折行/粘贴不重排、保留旧文本和显式保存。最终5编号单测、17Pro默认字号及SE恢复默认字号/计时运行各1 UI通过并目视。用户指出并核验普通SE残留最大AX字号，已恢复large；暂停计时隔离已撤。FL-053记录环境遗漏，真机中文输入法待验。证据output/numbered-notes/REPORT.md，未提交。 本项心得文档图标改为首行顶部对齐；17Pro默认字号下1项心得UI回归通过，六行截图已目视，证据output/note-icon-top/。未提交。 DR-100按用户纠正恢复球形/杆数进度，仅去掉第几颗，会话组数/项目数行仍隐藏；3项进度单测及1数字录入UI通过，截图已目视，证据output/training-progress-restore/。未提交。 DR-103标题改为本次计划/模版名称，自由训练保留；冻结payload取计划全名而非课程名。2聚焦单测及双来源启动1 UI通过，基本功/赛前热身截图已目视；output/training-source-title/，未提交。 2026-09-06 DR-106后续尺寸微调：用户认为28pt偏大，已将三处共享图标改为24pt，56×44pt点击区不变；新版两个心得截图及边缘收起已核验，完整保存重开回归因XCTest动画等待中止，不计通过。此前28pt验证记录：2026-09-06 DR-106键盘收起入口放大：整场/本项心得及数字键盘统一28pt半粗图标，心得56×44pt完整命中；独立17Pro/iOS26.2标准字号浅色2 UI通过（TEST SUCCEEDED），留白点击与三处截图已核对。见output/keyboard-dismiss-size/REPORT.md；小屏/深色/真机未复验，未提交。
- **问题集合 v56 全 App 色彩与 Pro 材质 W0–W7 自动化范围 ✅（2026-09-04，Orchestrator）**：真源 `问题集合_v56.md` v56.8，实施报告 `tasks/ui-reviews/UR-20260904-v56-color-implementation.md`。保留原布局、卡片与 `star.fill` / `crown.fill`，品牌绿仍为 Light `#1A6B3C` / Dark `#25A25A`；生成细拉丝香槟只进入原 SF Symbol mask。筛选统一弱绿，warning/success/teaching/physics/data 与 Premium 解耦，Guest 仅保留一个主登录行动，固定暗场 Chrome 集中化；DR-084 以 `btPremiumOnDark #E7D3A0` 修正 Light 页面内炭黑 Pro 卡对比。v56 截图冻结指纹 `20f603c8dd6b6dbc83dc37821821550dd9cc8bd9e437793f6b919db43ed4b25f`；iPhone SE / 标准 iPhone / iPad mini × Light/Dark 6/6、396/396 主截图与六张联系表通过，聚焦色彩、品牌登录 Light/Dark、高对比 Dark、AX XXXL Light 通过，`AtmosphereCatalogTests` 11/11 和 Debug build 通过。截图后并行 v54 仅修改其独立 UI test，导致全仓指纹漂移但未改变 v56 生产/截图输入。60 张封面仍是未批准随机试装，v56 只做中性遮罩与只读审计；OLED 低亮度和 Reduce Transparency 真实系统态转 H-28，不宣称人工全量验收。未 commit。
- **问题集合 v55 统计页纯训练数据方向 W0 + W0.1 + G1 ✅ / W1 待开始（2026-09-03，Orchestrator）**：真源 `问题集合_v55.md` v55.6。用户在周/月/年共 9 张候选后接受“C 双训练域骨架 + A 顶部总览/留白”；详细方案已将页顶周/月/年固定为球台与屏内两域唯一时间维度，补齐 rolling 区间、完整分箱、稳定分类行、Free 权益边界、全状态矩阵、断言失效机理、写盘测试盘点和并行冲突台账，拆为 W1–W5 五个可独立验收批次。本轮只更新方案/进度，未改 SwiftUI、ViewModel、schema 或测试。prompt / fixture / SHA-256 仍在 `output/imagegen/statistics-v55-built-in/MANIFEST.md`。未 commit。

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

> 2026-09-06 DR-110 / FL-054返工结果：最终按图片列/文字列重排，名称和剂量共用左对齐线；SE深色3 UI及17Pro浅色4 UI通过，关键原图目视，证据output/drill-layout-aligned/REPORT.md。此前两版视觉通过已撤回；本结果仅覆盖上述模拟器样本，真机/iPad/AX仍未验，未提交。
