# UI 审阅报告：v47 全 App 截图基线

> 日期：2026-08-30
> 角色：UI Reviewer
> 审阅对象：`tmp/designer-screenshots/` 现存 66 张、1206×2622 PNG
> 结论：**整体设计目标成立，但不支持全量重画。应保护成熟球桌视觉，针对浅色页面族和缺失状态做渐进精修。**

## 一、审阅口径

- 已逐张查看 66 张截图：先用 11 张 2×3 接触表检查全量一致性，再补看训练、计划、动作、长内容、暗场工具、历史、个人、认证与订阅代表原图。
- 依据当前 `Colors.swift`、`Typography.swift`、`Spacing.swift`、`docs/05-信息架构与交互设计.md` 与真实 SwiftUI 结构审阅，不把过期设计稿当现状。
- 七个维度：视觉层级、Token 一致性、组件复用、Light/Dark、交互可推断性、无障碍风险、跨页面一致性。
- 静态截图不能证明业务故障；本报告未把推测性问题升级为 P0/P1。

## 二、66 张截图覆盖台账

| 组 | 截图 | 结论 |
|---|---|---|
| 1 | `00-launch`、`01-training-home`、`02-training-custom-tab`、`03-plan-list`、`04-plan-detail`、`04b-custom-plan-builder` | 启动与计划详情基础成熟；训练根页、计划列表和 Builder 需调整层级与空白节奏 |
| 2 | `05-drill-library`、`06-drill-detail-top`、`07-drill-detail-bottom`、`07b-drill-tutorial`、`08-angle-home-all`、`08a-angle-home-learn` | 真实球形与内容辨识度强；网格重复偏重，精讲存在连续卡片墙 |
| 3 | `08a2-angle-home-theory`、`08b-angle-home-train`、`08c-angle-home-play`、`08d-angle-home-solve`、`09-aiming-principle`、`09b-aiming-methods` | 练习根页结构一致；学页容器主导、阅读节奏单一 |
| 4 | `09c-aiming-correction`、`09d-spin-and-english`、`09e-separation-angle-atlas`、`09f-cushion-english-atlas`、`10-angle-dynamic`、`11-ball-feel` | 两个暗场图谱应保持；其余长内容做编辑式精修，不重写内容 |
| 5 | `12-contact-point-table`、`12c-theory-t01`、`12d-theory-t02`、`12e-theory-t03`、`12f-theory-t04`、`12g-theory-t09` | 图解专业，但命题、图、正文、结论的主次仍被相似白卡削平 |
| 6 | `12h-theory-t05`、`12i-theory-t06`、`12j-theory-t07`、`12k-theory-t08`、`12l-theory-t10`、`12m-theory-flow` | 同上；共享 Chrome 已存在，应从 Chrome 层渐进处理 |
| 7 | `12n-theory-quickref`、`13-geometric-quiz`、`14-scene-aiming-2d`、`15-scene-aiming-3d`、`16-aimpoint-training`、`17-aimpoint-scene-2d` | Quickref 需强化速查语法；暗场测验/场景主体成熟，3D 部分截图被门控遮挡 |
| 8 | `18-aimpoint-scene-3d`、`19-shot-simulation`、`20-position-play-composer`、`21-free-play`、`22-ball-extraction`、`23-batch-drill-studio` | 球桌与轨迹是最强产品资产；多个页面被同一 Paywall 遮挡，`23` 为 simulator-only |
| 9 | `24-silu-trainer`、`25-plan-three`、`26-snooker-tactics`、`27-bank-shot`、`28-diamond-system`、`40-history-calendar` | 暗场工具保持为主；历史日历数据叙事偏弱、空白和容器比例失衡 |
| 10 | `41-history-statistics`、`50-profile-top`、`51-profile-scrolled`、`52-profile-personal-info`、`53-profile-training-goal`、`54-profile-settings` | 统计和个人根页优先精修；三个表单子页基本保持原生语法 |
| 11 | `55-profile-about`、`56-profile-favorites`、`57-subscription-status`、`70-login`、`71-phone-login`、`72-onboarding` | 子页可轻调；登录/手机号/引导缺少“球路计算与训练复盘”的专属性 |

## 三、保护清单

以下能力是 v47 的基座，不应被统一背景或全局 Token 修改误伤：

1. `PlanDetailView` 的计划 Hero、`DrillDetailView` 的真实球形和球桌内容。
2. `GeometricAngleQuizView`、`ShotSimulationView`、两个 Atlas、翻袋/钻石与其他暗场工具中的球桌、轨迹、瞄准点和击球工具。
3. 现有 `BTButtonStyle`、`BTFilterChip`、等级徽章、`BTContentGridCard`、搜索栏、Section Header 与 Design Token。
4. 五个根页已经取消大标题的结构。
5. v46 管辖的逐卡封面、图片映射与球形资产。

## 四、问题清单

### U-01 浅色页面缺少共同的产品签名

- 严重程度：P2
- 证据：`01`、`40`、`41`、`50`、`70`、`71`、`72`。
- 现象：Token 一致，但用户离开球桌页后，背景、指标和分隔语言更像通用 iOS 工具。
- 影响：跨页面品牌识别弱。
- 最小方向：在页面族明确的局部区域使用 `subtle / editorial / hero` 强度的球路工程语言；暗场工具强度为 `none`。

### U-02 浅色内容被连续白卡主导

- 严重程度：P2
- 证据：`07b`、`09`–`12n`、`41`、`50`–`57`。
- 现象：大量 `btBGSecondary + RoundedRectangle` 连续出现，标题、数据、正文与结论被压成同一表层等级。
- 影响：数据扫描和长文持续阅读效率下降。
- 最小方向：先用对齐、留白、细分隔和字号层级组织；只有确有独立容器语义的内容继续使用卡片。

### U-03 根页首屏主次不稳定，底部安全区需要专项验证

- 严重程度：P2（含验证风险）
- 证据：`01`、`05`、`08*`、`40`、`41`、`50`。
- 现象：训练根页顶部空白与首要状态脱节；动作/练习网格信息密集；多张根页截图末行被浮动 Tab Bar 覆盖或淡出。
- 影响：首屏任务感不足，末项可见性存在风险。
- 最小方向：不恢复根页大标题；逐页明确一个首要状态/动作，并用真实设备验证 scroll content inset 与 Tab Bar 安全区。

### U-04 历史与统计的“数据优先”语法尚未形成

- 严重程度：P2
- 证据：`40`、`41`。
- 现象：日历占据大块白色容器；统计以多张大卡和左绿轨为骨架，核心数值、趋势、周期和分类的优先级不稳定。
- 影响：用户不能迅速回答“练了多少、趋势如何、下一步练什么”。
- 最小方向：先确定首要指标和比较关系，再决定卡片；复用 Charts 与现有数据，不改统计口径。

### U-05 登录、手机号登录与引导过于通用

- 严重程度：P2
- 证据：`70`、`71`、`72`。
- 现象：Logo、系统图标、按钮和表单可用，但没有把球路计算、训练计划、复盘进步串成明确记忆。
- 影响：首次接触的产品承诺与专业度不足。
- 最小方向：以冷深绿/石墨 Hero 和真实球路元素建立记忆，保持登录方式、协议、键盘与验证流程不变。

### U-06 精讲、学页和理论页缺少训练手册式节奏

- 严重程度：P2
- 证据：`07b`、`09`–`12n`。
- 现象：专业图解和文字本身质量高，但各段落外壳相似，命题、解释、图解、错误提醒、结论和练习提示之间层级不足。
- 影响：长文扫描和复习效率下降。
- 最小方向：从 `LearnDocChrome`、`TheoryPageChrome` 的 opt-in 变体入手；内容、几何结论和图像不动。

### U-07 计划、动作与练习网格的高重复度造成视觉疲劳

- 严重程度：P2
- 证据：`03`、`05`、`08*`。
- 现象：两列图片卡本身成熟，但连续绿色球桌封面、角标和元信息形成高密度重复；不同页面的列表/网格节奏也不完全同构。
- 影响：分类识别和快速定位成本上升。
- 最小方向：先调整密度、Section 节奏、元信息和筛选层级；v47 不修改 v46 的逐卡封面。

### U-08 订阅存在两套视觉语言

- 严重程度：P2
- 证据：`15`、`18`、`20`、`22`、`24`、`26` 的暗场门控，以及 `50`、`57` 的浅色 Pro/订阅状态。
- 现象：工具页深色 Paywall 与个人中心浅色订阅状态各自成立，但品牌承诺、权益层级和状态反馈不像同一套系统。
- 影响：从功能锁定到订阅管理的连续性较弱。
- 最小方向：统一权益命名、Pro 标识、主 CTA 和状态层级；保留 StoreKit 与门控逻辑。

### U-09 当前截图不能闭合全 App 状态验收

- 严重程度：P2（证据缺口，不是已确认视觉缺陷）
- 证据：66 张以 Light 常规态为主；部分暗场页只看到 Paywall。
- 缺失：训练进行中/记录/心得、总结/分享、历史详情/编辑、完整 Subscription Paywall、错误/空态、键盘态、最新 Dark Mode、Accessibility Dynamic Type，以及 Batch Studio 后两层。
- 影响：无法据此判断所有生产路由和状态已经达到 v47 标准。
- 最小方向：按 `route-coverage.csv` 的 `planned:*` 与 states 列补齐；同设备、Runtime、fixture、身份和订阅状态固定取证。

## 五、分级结论

| 级别 | 页面族 | 裁定 |
|---|---|---|
| 保持并保护 | 暗场测验/场景/工具、两个 Atlas、球桌/轨迹、计划 Hero、动作详情真实球形 | 不加统一装饰背景；只验 chrome、状态与可达性 |
| 轻调 | 训练首页、计划列表/详情/Builder、动作库/详情、练习根页、个人子页、订阅状态 | 现有组件内调整层级、密度、留白和状态；不重构流程 |
| 重点调整 | 历史/统计、Profile 根页、登录/手机号/Onboarding、精讲/学页/理论页 | 重点是页面构图与信息语法，仍复用现有 Token/组件，不等于重做设计系统 |
| 先补证据 | 训练闭环、历史详情、完整 Paywall、错误/空态、Dark/AX、被门控遮挡的工具 | 截图齐全后再定“保持/轻调/重点调整” |

## 六、优先顺序与门禁建议

1. 先在真实 App 做三个独立家族样板：训练根页（根页语法）、统计页（数据语法）、登录/引导（品牌语法）。每个样板单独截图、单独确认、可单独回退。
2. 样板确认后才把共通规则扩到同页面族；不先改全局 `btBG`、圆角、字体或共享卡片默认值。
3. 长内容从共享 Chrome 的 opt-in 能力开始，不逐页复制新布局。
4. 暗场页以保护性回归为主；截图被 Paywall 遮挡的页面先补取证再判断。
5. 本轮没有可由静态截图确认的 P0/P1，因此不写入 `tasks/FAILURE-LOG.md`。

## 七、结论

旧问题模型是准确的：强视觉集中在球桌页、浅色页由容器主导、认证缺少专属性、长内容卡片化偏重、页面族缺少共同签名、状态截图不足。需要重写的是执行方案——从“全量重设计”改为“全量审计 + 保护成熟资产 + 三个真实 App 样板门禁 + 页面族渐进迁移”。
