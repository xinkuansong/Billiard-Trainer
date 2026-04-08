# 人工测试计划 — Phase 8 Profile Sub-pages & Settings（个人中心子页面）

> **使用方式**：在模拟器或真机上逐条执行，通过则勾选 `[x]`，失败则记录问题描述。
> **时机**：P8 Polish 阶段，5 个新增子页面 + 引导流程更新后。
> **创建记录**：2026-04-06 — 覆盖 PersonalInfoView / TrainingGoalView / SettingsView / SubscriptionStatusView / AboutView / OnboardingView

---

## 前置条件

- [ ] Debug 构建成功（Scheme: QiuJi, Destination: iPhone 17 Pro Simulator）
- [ ] 全新安装（删除已有 App 后重新安装）

---

## 一、视觉与 UI

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| V-01 | PersonalInfoView | 导航标题「个人信息」、inline 大标题、进入子页后 TabBar 隐藏 | [ ] |
| V-02 | PersonalInfoView | 顶部卡片：80×80 圆形头像底（btPrimary 15% 填充）+ `person.fill` 图标 | [ ] |
| V-03 | PersonalInfoView | 默认态：昵称行可点，展示 `displayNameOrDefault`（默认「球迹用户」）+ 铅笔图标 | [ ] |
| V-04 | PersonalInfoView | 编辑态：居中 Capsule `TextField`（占位「输入昵称」）+「完成」按钮（btPrimary） | [ ] |
| V-05 | PersonalInfoView | 已登录时昵称下方显示 `ID: ` + 用户 id **前 8 位**（btCaption 次要色） | [ ] |
| V-06 | PersonalInfoView | 「球种与水平」分组：`BTTogglePillGroup` 主打球种 = 中式台球 / 9球 / 两者 | [ ] |
| V-07 | PersonalInfoView | 「球种与水平」：`BTTogglePillGroup` 当前水平 = 入门 / 初级 / 中级 / 高级 | [ ] |
| V-08 | PersonalInfoView | 「球龄」单选列表 4 行：不到 1 年、1–3 年、3–5 年、5 年以上；选中行右侧 **checkmark**（btPrimary） | [ ] |
| V-09 | PersonalInfoView | **未登录（含匿名）**：不显示「账号绑定」整段 | [ ] |
| V-10 | PersonalInfoView | **已登录**：「账号绑定」三行 — Apple ID（已绑定/未绑定）、微信（即将支持、置灰）、手机号（有号码显示号码 / 否则即将支持+置灰） | [ ] |
| V-11 | TrainingGoalView | 导航标题「训练目标」、TabBar 隐藏 | [ ] |
| V-12 | TrainingGoalView | 顶部进度环：底圈 10pt 描边 + 进度弧动画；中心 **大号数字 = 本周已练天数**，其下「/ N 天」（N = 每周目标天数） | [ ] |
| V-13 | TrainingGoalView | 环下方 HStack：`本周训练` 显示「X / N」+ 竖分割线 + `本月达成率` 百分比（btAccent） | [ ] |
| V-14 | TrainingGoalView | 「每周训练天数」1…7 单行列表，选中项右侧 checkmark | [ ] |
| V-15 | TrainingGoalView | 「每次训练时长目标」：不限、30、45、60、90、120 分钟；选中 checkmark | [ ] |
| V-16 | TrainingGoalView | 「训练提醒」：`开启提醒` + 右侧 `Toggle`（tint btPrimary）；关闭时无时间行 | [ ] |
| V-17 | TrainingGoalView | 开启提醒后展开「提醒时间」+ `DatePicker`（仅时分，labelsHidden，tint btPrimary） | [ ] |
| V-18 | SettingsView | 导航标题「偏好设置」、TabBar 隐藏 | [ ] |
| V-19 | SettingsView | 「外观」：`BTTogglePillGroup` 跟随系统 / 浅色 / 深色 | [ ] |
| V-20 | SettingsView | 「清除缓存」行：标题 + 右侧动态 **缓存大小**（先「计算中…」→ KB/MB）+ chevron | [ ] |
| V-21 | SettingsView | 「数据导出」行：详情「即将推出」、整体 **opacity 0.5**（dimmed），无点击跳转（非 Button） | [ ] |
| V-22 | SettingsView | **已登录**：「账号安全」内「注销账号」标题/详情为 **btDestructive** + chevron | [ ] |
| V-23 | SettingsView | **未登录**：不显示「账号安全」/ 注销区块 | [ ] |
| V-24 | SubscriptionStatusView | 导航标题「订阅管理」、TabBar 隐藏 | [ ] |
| V-25 | SubscriptionStatusView | 状态卡：金色圆底 `crown.fill` + 标题「Pro 会员」+ 副标题类型（终身买断 / 年度订阅 / 月度订阅 / 兜底「Pro 会员」）+ 到期/续费说明（终身「永久有效」，订阅「自动续费中」） | [ ] |
| V-26 | SubscriptionStatusView | 「管理订阅」：信用卡图标 + 文案，浅绿底胶囊按钮（btPrimary 10% 背景） | [ ] |
| V-27 | SubscriptionStatusView | 「恢复购买」：次级文字按钮，全宽 | [ ] |
| V-28 | SubscriptionStatusView | 「已解锁功能」**6** 行：完整动作库(72) / 统计与趋势 / 自定义计划 / 无限角度测试 / 分享卡全样式 / 云端同步；每行左侧圆底 checkmark | [ ] |
| V-29 | AboutView | 导航标题「关于与反馈」、TabBar 隐藏 | [ ] |
| V-30 | AboutView | 身份卡：绿色圆角「QJ」徽章 72×72 +「球迹」+ 副标题「专为台球爱好者设计的训练工具」+ `CFBundleShortVersionString`/`CFBundleVersion` 版本串 | [ ] |
| V-31 | AboutView | 「联系与反馈」：信封「意见反馈」、星星「给个好评」；带彩色圆标 + chevron | [ ] |
| V-32 | AboutView | 「法律信息」：`doc.text` 用户协议、`shield` 隐私政策 → URL `https://qiuji.app/terms` / `https://qiuji.app/privacy` | [ ] |
| V-33 | AboutView | 页脚居中「© 2026 球迹」（btCaption 次要色） | [ ] |
| V-34 | OnboardingView | 全屏 `TabView` 3 页、**系统页指示关闭**（自定义底部 **Capsule** 指示条：当前页拉长高亮） | [ ] |
| V-35 | OnboardingView | 第 0 页：大圆 + `figure.pool.swim`，标题「动作库与训练记录」，双行副标题 | [ ] |
| V-36 | OnboardingView | 第 1 页：大圆 + `angle`，标题「角度感知训练」，双行副标题 | [ ] |
| V-37 | OnboardingView | 第 2 页：圆形 Logo（QJ 方块）+「球迹」+「你的台球训练伙伴」+ 3 条 `OnboardingFeatureRow`（动作库 / 角度训练 / 数据统计与复盘） | [ ] |
| V-38 | OnboardingView | 第 0–1 页底部：**primary「继续」** + 次级「跳过」 | [ ] |
| V-39 | OnboardingView | 第 2 页底部：**primary「开始使用」** + 次级「登录已有账号」 | [ ] |
| V-40 | OnboardingView | 整页 **`.preferredColorScheme(.light)`**：系统深色模式下引导页仍为浅色 | [ ] |

---

## 二、Dark Mode

> 使用 **iOS 系统外观 = 深色**（或 Settings 内「外观 → 深色」若已与全局主题联动）后，从「我的」进入各子页逐屏检查。Onboarding 为强制浅色，本节可标 **N/A** 或仅确认仍为浅色。

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| D-01 | PersonalInfoView | btBG / btBGSecondary 卡片层次清晰，昵称与列表文字可读 | [ ] |
| D-02 | PersonalInfoView | `BTTogglePillGroup` 选中/未选中态在深色下对比足够 | [ ] |
| D-03 | TrainingGoalView | 进度环、统计数字、列表分隔线在深色下清晰 | [ ] |
| D-04 | TrainingGoalView | `Toggle` / `DatePicker` 控件深色下可辨 | [ ] |
| D-05 | SettingsView | 外观 Pill、清除缓存/数据导出行、注销（若可见）destructive 色正确 | [ ] |
| D-06 | SubscriptionStatusView | 金色 crown 与浅绿按钮底在深色下不过曝、列表可读 | [ ] |
| D-07 | AboutView | QJ 绿块、各行图标底、法律链接行在深色下可读 | [ ] |
| D-08 | OnboardingView | 仍为浅色外观；文字与主色按钮对比正常 | [ ] |

---

## 三、用户流程

### 流程 1：PersonalInfo — 昵称 + 球种 + 水平 + 球龄

**步骤**：
1. 完成引导进入主界面 →「我的」→「个人信息」（或已登录点头像区「修改信息」）
2. 点击昵称 → 输入新昵称 → 点「完成」或键盘 **Return**（`onSubmit`）
3. 依次切换主打球种、当前水平 Pill
4. 点选不同球龄行，观察 checkmark 跟随

**预期结果**：昵称保存后退出编辑态；Pill 与球龄选中态即时更新；偏好持久化（可杀进程复验）。

- [ ] 编辑昵称 +「完成」后列表顶显示新昵称
- [ ] `onSubmit` 与「完成」行为一致
- [ ] 球种 / 水平 Pill 互斥选中正确
- [ ] 球龄四选一，动画与 checkmark 正确
- [ ] 杀进程重开「我的」→ 个人信息，上述选项仍为上次值

### 流程 2：TrainingGoal — 周目标 + 时长 + 提醒

**步骤**：
1. 「我的」→「训练目标」
2. 修改「每周训练天数」为不同值，观察环上「/ N 天」与中间数字联动
3. 选择「每次训练时长目标」任一项
4. 打开「开启提醒」，调整「提醒时间」；再关闭 Toggle

**预期结果**：周目标与时长立即生效；提醒区展开/收起带动画；时间可选。

- [ ] 修改每周天数后进度环比例与文案「X / N」一致（X 为本周有记录的去重天数）
- [ ] 本月达成率显示百分比或合理占位（月初等边界见第五节）
- [ ] 时长列表 6 档可选
- [ ] Toggle 开 → 显示 DatePicker；关 → 隐藏；杀进程后状态保持

### 流程 3：Settings — 外观 + 清除缓存

**步骤**：
1. 「我的」→「偏好设置」
2. 切换「外观」三种 Pill
3. 点击「清除缓存」→ 阅读 Alert 文案（含当前缓存大小）→「确认清除」

**预期结果**：Alert 文案与 `URLCache` 清除一致；清除后该行右侧大小更新（通常变小）。

- [ ] 三种外观选项 Pill 选中态正确
- [ ] 若工程已在根视图绑定 `UserPreferences.appearanceMode`，全 App 深浅色随选项变化
- [ ] 若尚未绑定全局主题，至少验证选项 **持久化**（重进设置仍为上次选择）
- [ ] 清除缓存 Alert：取消不清理；确认后缓存数字变化且训练记录仍在（文案说明不影响记录）

### 流程 4：Settings — 注销账号（需已登录，两步确认）

**前置**：使用 Sign in with Apple 等方式 **非匿名** 登录。

**步骤**：
1. 「偏好设置」→ 点「注销账号」
2. 首屏 Alert：阅读说明（永久删除账号与云端数据、本地保留、不可撤销）→「取消」验证可退回
3. 再次进入 →「确认注销」
4. 若后端失败：应出现「注销失败」Alert（重试 / 取消），取消后清理错误状态

**预期结果**：确认后调用 `BackendSyncService.deleteAccount()`，成功则 `logout()`，回到未登录态；失败可重试。

- [ ] 未登录时不出现注销入口
- [ ] 第一步 Alert 文案与 destructive 按钮符合预期
- [ ] 成功路径：注销后「我的」为游客 UI，`isLoggedIn` 为 false
- [ ] 失败路径：错误 Alert 可重试或取消，不卡死

### 流程 5：SubscriptionStatus — Pro 用户管理与恢复

**前置**：Sandbox 或真机已购 **Pro**（`SubscriptionManager.isPremium == true`）。未订阅时「我的」中该入口为打开订阅 Sheet，**不**进入本页。

**步骤**：
1. 「我的」→「订阅管理」（应 `NavigationLink` 进入 `SubscriptionStatusView`）
2. 核对状态卡类型文案与当前购买一致（月/年/终身）
3. 点「管理订阅」→ 应打开 App Store 订阅管理页（`https://apps.apple.com/account/subscriptions`）
4. 点「恢复购买」→ 结束后弹出 **Alert**（成功或失败文案）

**预期结果**：管理订阅外链可开；恢复结果以 Alert 展示（成功「已恢复购买…」，失败带 `errorMessage` 或默认未找到记录）。

- [ ] 仅 Pro 用户从菜单进入本页
- [ ] 状态卡 copy 与购买类型匹配
- [ ] 管理订阅、恢复购买 + Alert 行为正确

### 流程 6：AboutView — 反馈、评分、法律链接

**步骤**：
1. 「我的」→「关于与反馈」
2. 点「意见反馈」→ 应尝试打开 `mailto:feedback@qiuji.app`（模拟器可能无邮件客户端）
3. 点「给个好评」→ 触发系统评分请求（`requestReview`，可能不每次弹出）
4. 点「用户协议」「隐私政策」→ Safari 打开对应域名

**预期结果**：URL/mailto 构造正确；无崩溃。

- [ ] mailto 含主题与设备信息后缀（真机有邮箱客户端时）
- [ ] 评分请求不崩溃（无弹窗亦可能为系统策略）
- [ ] 两个 https 链接可打开

### 流程 7：Onboarding — 三页滑动与匿名开始

**前置**：清除 App 数据或卸载重装，使 `hasCompletedOnboarding == false`。

**步骤**：
1. 启动 App，确认首屏为 Onboarding（非 Tab）
2. 左右滑动 `TabView` 与点「继续」切换 0 → 1 → 2
3. 在第 0 或 1 页点「跳过」，或第 2 页点「开始使用」

**预期结果**：调用 `loginAnonymously()`，进入 `MainTabView`；底部 Capsule 指示与页码一致。

- [ ] 三页内容与文案与源码一致
- [ ] 手势滑动与「继续」均能换页
- [ ] 「跳过」/「开始使用」后进入主界面且再次冷启动不再显示引导（除非清除数据）

### 流程 8：Onboarding — 登录 Sheet → 关闭

**步骤**：
1. 进入 Onboarding 第 2 页
2. 点「登录已有账号」→ 弹出 `LoginView` sheet
3. 下拉关闭或点取消（以 LoginView 实际 UI 为准）**不登录**

**预期结果**：Sheet 关闭后仍停留在 Onboarding 第 2 页，可再次打开 Sheet。

- [ ] Sheet 可重复打开/关闭
- [ ] 误关 Sheet 不会误触发完成引导（除非用户点了开始使用/跳过）

---

## 四、交互响应

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| I-01 | PersonalInfo 昵称 | 点昵称进入编辑后键盘弹出，`TextField` 可聚焦；完成/失焦后退出编辑 | [ ] |
| I-02 | PersonalInfo 列表 | 球龄行、`BTTogglePillGroup` 点击热区完整，无「点不中」 | [ ] |
| I-03 | TrainingGoal 列表 | 7 天 + 6 档时长滚动流畅，快速切换选中无卡顿 | [ ] |
| I-04 | TrainingGoal 提醒 | Toggle 切换有即时反馈；DatePicker 滚轮/转盘操作跟手 | [ ] |
| I-05 | Settings 行 | 「清除缓存」「注销账号」整行可点；数据导出行无导航跳转 | [ ] |
| I-06 | Subscription 按钮 | 「管理订阅」「恢复购买」点击后 UI 不阻塞（恢复可短暂等待） | [ ] |
| I-07 | About 行 | 意见反馈 / 好评 / 法律链接整行响应，chevron 不误触空白 | [ ] |
| I-08 | Onboarding | 「继续」primary 样式；「跳过」「登录已有账号」次要样式；指示条动画与页同步 | [ ] |
| I-09 | 子页导航 | 各子页从「我的」push 进入，**左滑返回**与导航栏返回一致，回到「我的」后 TabBar 恢复 | [ ] |

---

## 五、边界场景

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| E-01 | PersonalInfo 昵称为空 | 编辑态清空后点「完成」：应 **不** 把昵称改为空（trim 后为空则保持原显示名），并退出编辑 | [ ] |
| E-02 | PersonalInfo 匿名用户 | 匿名完成引导后进入个人信息：无「账号绑定」；昵称修改仍作用于 `anonymous` 用户 | [ ] |
| E-03 | TrainingGoal 无训练记录 | 本周天数为 0，环为 0%；本月达成率可能为 0% 或「—」（依月初/目标计算） | [ ] |
| E-04 | TrainingGoal 超额完成 | 当周训练天数 > 每周目标时，环应为 **满圈**（不超过 100% 弧） | [ ] |
| E-05 | Settings 清除缓存 | 极低缓存时仍显示合理 KB 文案；连续清除不崩溃 | [ ] |
| E-06 | Settings 注销网络失败 | 断网点「确认注销」→ 失败 Alert；恢复网络后「重试」可再次请求 | [ ] |
| E-07 | About mailto | 无邮件客户端时系统提示或静默失败，**不崩溃** | [ ] |
| E-08 | About 外链 | 飞行模式下打开链接：系统错误提示，返回 App 状态正常 | [ ] |
| E-09 | 训练提醒 | 当前实现主要为 **偏好存储**；若无本地通知排程，不将「未弹通知」记为 UI 缺陷，但需在问题表备注期望 | [ ] |
| E-10 | Onboarding 深色系统 | 系统深色模式下引导页仍为 **强制浅色**，进入主界面后尊重系统或用户外观设置 | [ ] |

---

## 六、设备矩阵

> 在以下设备上各执行：**流程 1 + 流程 3 + 流程 7**（或等价覆盖子页导航与 Onboarding）。

| # | 设备 | 核心流程通过 | 布局正常 | 备注 |
|---|------|------------|---------|------|
| DM-01 | iPhone SE（4.7"） | [ ] | [ ] | Onboarding 长文案、TrainingGoal 多列表是否换行溢出 |
| DM-02 | iPhone 17 Pro（6.3"） | [ ] | [ ] | |
| DM-03 | iPhone 17 Pro Max（6.9"） | [ ] | [ ] | |

---

## 七、可访问性

| # | 检查项 | 通过 |
|---|--------|------|
| AC-01 | **Dynamic Type** 较大字号：`PersonalInfoView` 编辑行、`TrainingGoalView` 列表、`SettingsView` 行不重叠溢出 | [ ] |
| AC-02 | **Dynamic Type** 较大字号：`SubscriptionStatusView` 功能列表、`AboutView` 多行标题可读 | [ ] |
| AC-03 | **VoiceOver**：Onboarding 每页标题/副标题/按钮可读，顺序合理 | [ ] |
| AC-04 | **VoiceOver**：`TrainingGoalView` 中 Toggle 与 DatePicker 有明确标签（若缺失需记缺陷） | [ ] |
| AC-05 | **VoiceOver**：`SettingsView` 注销 destructive 操作朗读正确 | [ ] |

---

## 八、性能

| # | 指标 | 阈值 | 通过 |
|---|------|------|------|
| PF-01 | 从「我的」push `PersonalInfoView` 首帧可交互时间 | < 0.5 s | [ ] |
| PF-02 | push `TrainingGoalView`（含 SwiftData `@Query`）首帧可交互时间 | < 0.6 s | [ ] |
| PF-03 | push `SettingsView`（`task` 计算缓存）无可见卡顿 | 无明显掉帧 | [ ] |
| PF-04 | `OnboardingView` 滑动 TabView 与指示条动画 | >= 55 FPS 体感流畅 | [ ] |

---

## 九、测试结果

| 项目 | 内容 |
|------|------|
| 测试人 | |
| 日期 | YYYY-MM-DD |
| 设备 | [型号 + iOS 版本] |
| 构建版本 | [Build number] |
| 总体结论 | 通过 / 有问题（详见下方） |

### 发现的问题

| # | 严重程度 | 页面/流程 | 描述 | 关联检查项 |
|---|---------|----------|------|-----------|
| | | | | |
