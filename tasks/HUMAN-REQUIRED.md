# 人工操作清单（HUMAN REQUIRED）

> Orchestrator 每次会话开始时读取本文件。
> **你完成操作后，将对应项的状态从 `⏳ 待完成` 改为 `✅ 已完成`。**

---

## [BLOCKING] H-01 — Apple Developer 账号激活

- **状态**：✅ 已完成
- **做什么**：登录 developer.apple.com，确认账号状态为 Active（有效期内）
- **在哪里**：[https://developer.apple.com/account](https://developer.apple.com/account)
- **预计时长**：5 分钟（已有账号）/ 最长 48 小时（新注册需等待审核）
- **影响任务**：T-P1-01（Xcode 项目初始化必须有有效开发者账号签名）
- **完成标志**：将本条状态改为 ✅

---

## [BLOCKING] H-02 — Xcode 安装 + iOS 17 Simulator

- **状态**：✅ 已完成
- **做什么**：确认 Xcode 已安装且包含 iOS 17 Simulator
- **验证方式**：`xcodebuild -version` 返回 Xcode 15+ 版本
- **影响任务**：P1 全部任务

---

## [BLOCKING] H-03 — App Store Connect 创建 App 记录

- **状态**：✅ 已完成
- **做什么**：
  1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
  2. 点击「我的 App」→「+」→「新建 App」
  3. 填写：名称（球迹）、Bundle ID（与 Xcode 一致）、SKU（自定义唯一字符串）
  4. 选择平台：iOS
- **在哪里**：[https://appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
- **预计时长**：30 分钟
- **影响任务**：T-P7-01（StoreKit 2 需要 App 记录关联 IAP 产品）
- **前置条件**：H-01 完成

---

## [BLOCKING] H-04 — IAP 产品在 App Store Connect 创建

- **状态**：✅ 已完成
- **做什么**：在 App Store Connect → App → 内购买项目中创建以下 3 个产品：
  | 类型 | 产品 ID | 参考价格 |
  |------|---------|---------|
  | 自动续期订阅（月度） | `com.yourname.billiardtrainer.premium.monthly` | ¥18/月 |
  | 自动续期订阅（年度） | `com.yourname.billiardtrainer.premium.yearly` | ¥88/年 |
  | 非消耗型（终身） | `com.yourname.billiardtrainer.premium.lifetime` | ¥198 |
- **注意**：产品 ID 需与代码中 `StoreKit` 配置一致；定价需在 App Store Connect 价格表中选择
- **在哪里**：App Store Connect → 你的 App → 内购买项目
- **预计时长**：1 小时
- **影响任务**：T-P7-01（StoreKit 2 Product 加载依赖真实产品 ID）
- **前置条件**：H-03 完成

---

## [BLOCKING] H-05 — 微信开放平台申请移动应用资质

- **状态**：🔜 推迟至 App 主体开发完成后（用户决定，2026-03-29）
- **做什么**：
  1. 注册/登录 [微信开放平台](https://open.weixin.qq.com)
  2. 创建移动应用（填写 App 名称、简介、图标）
  3. 提交审核（需要：App Store 链接或 TestFlight 链接/截图，目前可先提交 TestFlight 内测截图）
  4. 审核通过后获得 **AppID** 和 **AppSecret**
- **在哪里**：[https://open.weixin.qq.com](https://open.weixin.qq.com)
- **预计时长**：提交 15 分钟，等待 1–3 个工作日
- **影响任务**：T-P1-08（微信登录集成需要 AppID）
- **完成后**：将 AppID 填入 `Config/Debug.xcconfig` 的 `WECHAT_APP_ID` 字段
- **备注**：已有 Sign in with Apple，微信登录为增强功能，推迟不影响核心开发

---

## [BLOCKING] H-06 — ~~LeanCloud 账号注册~~（已取消）

- **状态**：✅ 已取消（ADR-001，2026-03-29）
- **原因**：LeanCloud 停止国内新用户注册；已改用自建 REST API 后端（见 H-14 ~ H-16）

---

## [BLOCKING] H-07 — ~~CloudKit 容器创建 + Schema 初始化~~（已取消）

- **状态**：✅ 已取消（ADR-002，2026-03-29）
- **原因**：公开 Drill / 官方计划内容改由 **Bundle 离线保底 + 自建 REST API OTA**（如 `GET /drills`）提供；不再使用 CloudKit 公开库，避免双云栈与额外人工配置。

---

## [BLOCKING] H-08 — Sign in with Apple 能力开启

- **状态**：✅ 已完成
- **做什么**：
  1. Developer Portal → Identifiers → 你的 App ID
  2. 勾选「Sign In with Apple」→ Save
  3. 在 Xcode → Target → Signing & Capabilities → 添加「Sign In with Apple」
- **预计时长**：10 分钟
- **影响任务**：T-P1-06（Sign in with Apple 实现）
- **前置条件**：H-01 完成、T-P1-01 完成

---

## 非阻塞操作

以下操作不阻塞当前 Phase，但需在标注的节点前完成：

---

### H-09 — 隐私政策页面创建

- **状态**：⏳ 待完成（P8 前）
- **做什么**：创建一个可公开访问的隐私政策网页（必须包含中英双语，说明数据收集/使用/删除政策）
- **⚠️ 内容必须包含（D-v29-4 裁定，2026-08-06）**：「使用数据/产品交互」类信息——练习工具（自由走位/自由击球/打一走二想三/动作库试打）的使用日期与停留时长会上传后端用于产品优化（契约 §5.3）
- **推荐方式**：GitHub Pages（免费）或任何静态托管
- **参考内容**：数据收集范围见 `tasks/compliance-checklist.md`
- **预计时长**：1 小时
- **影响任务**：T-P8-10（App Store 提交必须提供隐私政策 URL）

---

### H-10 — App Store 截图拍摄

- **状态**：⏳ 待完成（P8 前）
- **做什么**：在 iOS 模拟器（iPhone 16 Pro Max / 6.9"）上截取5张核心功能截图
- **截图内容**：见 `tasks/appstore-assets.md`
- **工具**：`xcrun simctl io booted screenshot screenshot.png`（可脚本化）或 `make screenshot`
- **预计时长**：2 小时（含文案设计）

---

### H-11 — Drill 内容技术验证

- **状态**：⏳ 待完成（P3 每批 Drill 完成后）
- **做什么**：由你（熟悉台球技术）核查每批 Drill 内容的技术准确性：
  - 动作描述是否正确（高杆/低杆/加塞定义）
  - 达标标准是否合理（进球数参照）
  - Canvas 示意图坐标是否合理
- **预计时长**：每批约 30–60 分钟
- **影响任务**：Content Engineer 等待验证通过后再生产下一批

#### Batch 1 ✅ 已验证（2026-03-29）
- **fundamentals**（5 条）：drill_c006 握杆稳定性、drill_c007 站位对齐、drill_c008 手架练习、drill_c009 直线出杆检验、drill_c010 中杆定杆
- **accuracy**（5 条）：drill_c001 半台直线球、drill_c002 斜角入底角袋、drill_c011 近台底袋直线、drill_c012 中袋直线入袋、drill_c013 底袋小角度入袋
- 全部 L0 级别，`isPremium: false`
- 坐标自检通过 ✅
- 人工内容核查通过 ✅（2026-03-29）

#### Batch 2 ⏳ 待验证
- **cueAction**（8 条）：drill_c014 中杆定杆基础（L0）、drill_c015 高杆远台跟进（L1）、drill_c016 斯登角度停球（L1）、drill_c017 低杆远台缩杆（L2）、drill_c018 左塞一库变线（L2）、drill_c019 右塞一库变线（L2）、drill_c020 高杆加塞走位（L2）、drill_c021 低杆加塞回位（L3）
- **fundamentals**（2 条）：drill_c022 远台直线出杆检验（L1）、drill_c023 五分点瞄准线练习（L1）
- 级别分布：L0 ×1、L1 ×4、L2 ×4、L3 ×1
- `isPremium` 分布：free ×6（L0–L1 全免费 + L2 ×1）、paid ×4（L2 ×3 + L3 ×1）
- 坐标自检通过 ✅
- 人工内容核查：⏳ 待验证

#### Batch 3–7 ⏳ 待验证（52 条，2026-03-29 一次性生成）
- **Batch 3** · separation 8 + accuracy 2：drill_c024–c033
- **Batch 4** · positioning 9 + fundamentals 1：drill_c034–c043
- **Batch 5** · forceControl 8 + accuracy 2：drill_c044–c053
- **Batch 6** · specialShots 8 + accuracy 2：drill_c054–c063
- **Batch 7** · combined 8 + accuracy 1：drill_c064–c072
- 级别分布：L1 ×11、L2 ×24、L3 ×11、L4 ×1（不含 Batch 2 的 5 条 L1）
- `isPremium` 分布：free ×15、paid ×37
- 坐标自检通过 ✅（全部 52 条）
- 人工内容核查：⏳ 待验证

#### shotIntent 全量补齐（2026-06-04，DR-017 后续）⏳ 待物理核查
- **背景**：动作库轨迹/走位现由物理引擎 `ShotPredictor` 真算（DR-017）。已为全部 72 条 Drill 补齐 `shotIntent`（5 试点 + 本轮 67 条），其中 67 条的 velocity/spin 由 8 个 content-engineer 子智能体按各 Drill 描述/杆法**自动推断**。
- **物理可行性扫描结果**（`DrillThumbnailBakeRunnerTests/test_scanFeasibility`）：67/72 在引擎中干净落入选定袋；**5 条特殊球路单杆直瞄物理模型本就无法干净进**，需人工确认其处理方式或等待烘焙器增强：
  - `drill_c055` 翻袋入中袋（bank）— v1 烘焙器只直瞄、不算翻袋 → 退回手画轨迹（正确的翻袋路径）。
  - `drill_c057` K球吃库（kick）— 需绕库击打，直瞄打不进。
  - `drill_c058` 贴库球处理（rail）— 目标球贴库，薄切 rattle。
  - `drill_c061` 解球/逆境球（escape）— 解球本就不一定进袋。
  - `drill_c066` 开球训练（break）— 散球非单杆进袋。
- **本轮人工微调（需复核合理性）**：
  - `drill_c039` 直线球组合走位：原 cue 在 target 下方却选底中袋（几何颠倒）→ 改选**上中袋** + 低杆。
  - `drill_c062` 远台中袋直线：原 cue 与 target 水平、选正下方底中袋（cut 90°）→ 母球移到 target 正上方做真·竖直远台直线。
  - 6 条走位/清台（c035/c037/c065/c067/c068/c070）自动推断的「高杆 follow」致母球打偏/目标球乱弹 → 改**中心球**（c070 另加力至 4.6）后干净落袋。
- **需你核查**：① 67 条自动推断的杆法（高/低/塞）与力度档是否符合该 Drill 的教学意图；② 上述 5 条特殊球路的呈现方式是否可接受；③ c039/c062 的摆位/选袋调整是否合理。
- **预计时长**：约 60–90 分钟（可对照动作库内每条详情页的 live 轨迹动画核查）。

---

### H-17 — 人工测试计划执行（TP-P2 ~ TP-P7）

- **状态**：🔄 进行中（5/6 已执行，仅剩 TP-P7）
- **做什么**：在模拟器或真机上逐条执行以下 6 份测试计划，通过则勾选 `[x]`，失败则记录问题：
  | 文件 | 覆盖范围 | 预计时长 | 状态 |
  |------|---------|---------|------|
  | `tasks/test-plans/TP-P2.md` | 数据层、离线、登录迁移 | 30 分钟 | ✅ 已执行（2026-04-10，3 项已修） |
  | `tasks/test-plans/TP-P3.md` | 动作库列表、详情、收藏、锁定 | 30 分钟 | ✅ 已执行（2026-04-10，FL-003~005 已修） |
  | `tasks/test-plans/TP-P4.md` | 训练记录全流程、自定义计划、分享 | 45 分钟 | ✅ 已执行（2026-04-11，92/98） |
  | `tasks/test-plans/TP-P5.md` | 角度测试、对照表、每日限制 | 30 分钟 | ✅ 已执行（2026-06-02，用户确认通过） |
  | `tasks/test-plans/TP-P6.md` | 历史日历、统计图表、60 天限制 | 30 分钟 | ✅ 已执行（无功能性问题） |
  | `tasks/test-plans/TP-P7.md` | 订阅购买、恢复、过期降级 | 30 分钟 | ⏳ **待执行**（需 StoreKit sandbox / 真账号） |
- **在哪里**：Xcode → iPhone 16 Pro Simulator（或真机）
- **预计时长**：剩余约 30 分钟（仅 TP-P7）
- **影响任务**：T-P8-12、QA-P8 最终验收
- **完成后**：在每份 TP 文件底部「测试结果」区填写结论；如有问题填写「发现的问题」表。**仅剩 TP-P7 执行完即可将本条改为 ✅。**

---

### H-12 — App Store 审核问卷填写

- **状态**：⏳ 待完成（P8）
- **做什么**：App Store Connect 提交审核时填写：
  - 内容权利（IAP 订阅说明）
  - 年龄分级问卷
  - 隐私数据声明（按实际收集填写）——**⚠️ 须勾选「产品交互」类使用数据**（D-v29-4：tool 使用时长上传后端，契约 §5.3）
  - 中国区内容合规说明（如适用）
- **预计时长**：1 小时
- **前置条件**：H-09 完成（需要隐私政策 URL）

---

### H-13 — 微信 SDK Universal Links 域名部署

- **状态**：⏳ 待完成（P2 前，与 H-05 配合）
- **做什么**：
  1. 准备一个可 HTTPS 访问的域名
  2. 在域名根目录部署 `apple-app-site-association` 文件（微信 iOS 回调要求）
  3. 在微信开放平台填写 Universal Links 地址
- **注意**：若暂时没有域名，可先使用 URL Scheme 方式（`wx{AppID}://`）作为临时方案，Universal Links 在 App Store 版本前补充
- **预计时长**：视域名情况，30 分钟 – 2 小时

---

### H-18 — 击球音效素材下载（真实 CC0 录音）

- **状态**：⏳ 待完成（P14；非阻塞——缺素材时回放正常、仅无声）
- **背景**：音效代码已完成（`Core/Audio`），按命名约定放入音频文件即生效。AI 无法自主下载——
  优质「真实球桌实录」均在 Freesound 等站，**下载需登录账号**；免登录站疑似 AI 合成、不满足「真实」要求。
- **做什么**：
  1. 登录 [Freesound](https://freesound.org)（免费注册）。
  2. 下载以下 **CC0（免署名可商用，逐个确认页面 license 图标为 CC0）** 真实录音：
     - 球-球：[juskiddink #108615《Billiard balls single hit-dry》](https://freesound.org/people/juskiddink/sounds/108615/)；
       再从 [CC0 台球搜索页](https://freesound.org/search/?q=billiard&f=license:%22creative+commons+0%22) 多挑 2–3 条不同力度的真实撞击。
     - 击球 / 吃库 / 落袋：同页挑选 "cue/strike"、"rail/cushion"、"pocket/drop" 类的真实录音。
  3. 按命名约定放入 `QiuJi/Resources/Audio/`（详见该目录 `CREDITS.md`）：
     - `sfx_cue_strike.caf`、`sfx_ball_hit_1.caf`…`sfx_ball_hit_4.caf`（按力度弱→强）、`sfx_cushion.caf`、`sfx_pocket.caf`。
     - 其他格式可用 `afconvert -f caff -d LEI16@44100 in.wav sfx_xxx.caf` 转换（示例见 `CREDITS.md`）。
  4. 在 `CREDITS.md`「已采用文件登记」表填写每个文件的来源 URL / 作者 / 许可（合规留痕）。
- **完成后**：`cd scripts && make build && make run` 在模拟器/真机听 4 类事件音效；满意后把本条改为 ✅，并把 P14 的 T-P14-07/08 标 ✅。
- **预计时长**：30–45 分钟

---

### H-23 — v26 全量 drill 内容人工审核（非阻塞）

- **状态**：⏳ 待完成（非阻塞——门禁已绿、C4 已转阻塞；本条是技术/教学验收，不挡代码合入）
- **背景**：问题集合 v26（W0–W13）已把 77 条 drill 的精讲与元数据按序列真源对齐；契约 §8.1/§8.2/§8.15 债务已销账。机械门禁不能替代逐 drill 读感与示范质量判断。
- **做什么**：
  1. 在 App 动作库逐条打开 77 条 drill 的精讲页，对照示范图/序列抽查：袋口名（屏幕系）、力度杆法定性词、形态（走位链 vs 独立阶梯）、意图块角标是否与首杆一致。
  2. 处理待重录清单（精讲已按用户视角写「母球留台为合格」等，未硬圆；重录后按契约 §六.1 增量更新精讲）：
     - **T-v26-5**：`c012` 全杆 freeAim+cuePocketed（母球进袋训练）
     - **T-v26-6**：`c078` manual01 第 8/10/12/14/16 杆 scratch
     - **T-v26-7**：`c003`/`c004` m02/`c015` 多杆 scratch
     - **T-v26-8**：`c073` m01 全 7 杆、`c074` m01 全 6 杆 freeAim 母球进袋；`c075` m01 第 6 杆 scratch
     - **T-v26-10**：`c047` 第 1–3、8–9 杆 scratch；另 `c045`/`c049` freeAim 无进袋（停点阶梯，非必重录）
  3. 处理 **T-v26-3 改名待批**（D-v26-2：`nameZh` 未写回）：
     - `c010` 与 `c014` 同名「中杆定杆基础」→ 建议 c014→「直线定杆距离阶梯」；跨 drill 引用（c006/c008/c009 进阶）批准后一并扫改
     - 另见 **T-v26-12**：建议 `c057` nameZh→「障碍旁进攻·杆法三形」（示范为直接进攻非先碰库）
- **预计时长**：分日审核，全量约数小时；重录另计
- **完成后**：将本条改为 ✅；需要改名/重录的条目可开后续增量批
- **证据入口**：`问题集合_v26.md` §八；各批日志 `build/v26-w*-logs/`；W13 收尾 `build/v26-w13-logs/`

---

### H-22 — v21 加塞 drill 示范击打录制（非阻塞）

- **状态**：✅ **已关闭（2026-08-07，D-v26-1）**——以现状序列为定稿；c073–c078 与 c016/c018/c020/c021 均已有多杆人工录制序列，无需再按本条补录 initial-only 示范。精讲/元数据按序列重写归 v26 内容批（W4/W5 等）。
- **过时原因**：本条声称上述 drill「仅 initial-only、示范待录」，但 2026-08-07 实测这些 drill 均已有多杆人工录制序列（如 c073 7/8 杆、c016 6 杆、c020 16 杆等）；与 H-21 同类过时。D-v26-1 裁定「以现状序列为准写」。
- **下方原文保留供追溯，其描述的文件状态已不成立。**
- **背景**：v21 新增 c073–c078（≈30 球形）+ R4 重构 c016/c018/c020/c021（18 球形）；均按红线须编排台人工录制，禁止从 shotIntent 反推。
- **做什么**（建议分子批）：
  1. **优先子批 A**：`drill_c073`（挤偏认知·直球近台，免费钩子）+ `drill_c076`（小角度带塞进袋）— 逐球形加载 initial → 录 1 杆示范 → 回写序列 → `make tryout-sync`。
  2. **子批 B**：c074 / c075 / c077 / c078。
  3. **子批 C（R4）**：c016 / c018 / c020 / c021。
- **预计时长**：子批 A ~30–45 分钟；全量约 2–3 小时（可分日）
- **影响任务**：加塞课序列示范模式、精讲配图；**不阻塞** v21 W5 收官 / v22 计划货架

---

### H-21 — drill_c053 中袋角度球 8 球形示范击打录制（B4）

- **状态**：✅ **已关闭（2026-08-06，用户裁定）**——A1–A8 序列已随 `8293ef4` 退役删除，c053 现有人工录制的 manual01（10 杆）/ manual02（13 杆）示范；无需重录。c053 精讲按序列重写归 v26（契约 §8.1/§8.4）。
- **过时原因**：本条要求录制的 A1–A8 八条序列已于提交 `8293ef4`
  （`content: retire legacy initial-only sequences in favour of manual recordings`）
  全库退役删除；drill_c053 现为出片台人工录制的 `manual01`（10 杆）/ `manual02`（13 杆）两球形。
  `content/drill_profiles/drill_c053.profile.json` 与精讲 `tutorial.formations` 中的 A1–A8
  随之成为孤儿，需按 `.kiro/steering/content-data-contract.md` §1.1「以序列为准」重写精讲。
- **下方原文保留供追溯，其描述的文件状态已不成立。**
- **背景**：B4 已把 drill_c053 重构为 8 球形变量覆盖版（A1–A8，切角 15°/30°/45°/60° × 左右切，见 `content/drill_profiles/drill_c053.profile.json`）。按红线（2026-06-13 拍板），示范击打序列必须在走位编排台**人工录制**，禁止从 shotIntent 反推或脚本伪造——当前 8 条序列均为 initial-only（`steps: []`）。旧 3 杆录制序列（Snipaste_2026_06_19，3 球连排旧球形）已随重构退役删除。
- **做什么**：
  1. 打开走位编排台，逐一加载/摆出 A1–A8 球形（坐标见 profile；`content/position_play/sequences/drill_c053__A<N>-*.json` 的 initial 已摆好 cueBall + 8 号球）。
  2. 每球形录制 1 杆示范击打（打进下中袋 bottomCenter；velocity/spin 按教学意图定）。
  3. 录制结果回写对应序列文件，然后 `cd scripts && make tryout-sync`。
  4. （可选，与录制同批）出片补精讲配图与示范视频；旧 `videos/take_01–03`（旧单球形 topCenter 演示）已从 drill JSON 摘除，待新示范录好后重挂。
- **预计时长**：约 40–60 分钟（8 球形）
- **影响任务**：drill_c053 序列示范模式、精讲配图、示范视频；不阻塞 B5b/B6+

---

### H-20 — 反解求解器真机性能基线（B0/B5）

- **状态**：⏳ 待完成（非阻塞——B1–B4 优化已按模拟器口径收官；B5 于 2026-07-08 收尾时设备仍 unavailable，真机对照表为唯一遗留项，连接后随时可补）
- **背景**：反解求解器优化方案（`docs/research/20260708-反解求解器性能优化方案.md`）B0 已建好四条基准（`QiuJiTests/SolverPerformanceTests`），模拟器基线已落档；真机（iPhone）无可用连接未测。
- **做什么**：
  1. iPhone 连接 Mac 并信任，确认 `xcrun devicectl list devices` 显示 available。
  2. 运行：`xcodebuild -project QiuJi.xcodeproj -scheme QiuJi -destination 'platform=iOS,name=<你的 iPhone 名>' -only-testing:QiuJiTests/SolverPerformanceTests test`（或告知 AI「跑真机求解器基准」由其代跑）。
  3. 把测试输出中 4 行 `⏱️ [PERF-B0]` 数字填入方案文件 §1 表格（新增「真机」列）。
- **预计时长**：15 分钟
- **影响任务**：优化方案 B5（真机验收门：情形 A/B <0.5s、斯诺克 <1s）

---

## [BLOCKING] H-14 — 腾讯云轻量服务器购买与初始化

- **状态**：✅ 已完成（2026-03-29）
- **做什么**：
  1. 登录 [腾讯云控制台](https://console.cloud.tencent.com)
  2. 购买「轻量应用服务器」（推荐：2核2G，香港节点或上海节点，约 ¥50/月）
  3. 选择镜像：Ubuntu 22.04 LTS（或 Node.js 应用镜像）
  4. 配置安全组：开放 80、443、22 端口
  5. 绑定已备案域名（或先用 IP 开发）
- **在哪里**：[https://console.cloud.tencent.com/lighthouse](https://console.cloud.tencent.com/lighthouse)
- **预计时长**：30 分钟
- **完成后**：将服务器 IP / 域名填入 `Config/Debug.xcconfig` 的 `API_BASE_URL` 字段
- **影响任务**：T-P2-05（后端同步服务）

---

## H-15 — 腾讯云短信服务申请

- **状态**：🔜 推迟至 App 主体开发完成后（用户决定，2026-03-29）
- **做什么**：
  1. 腾讯云控制台 → 短信 SMS → 开通服务
  2. 创建「国内短信」签名（签名内容：球迹）
  3. 创建验证码模板（内容：「您的验证码为 {1}，5分钟内有效。」）
  4. 提交审核（通常 2 小时内通过）
  5. 获取 SDK AppID 和 AppKey
- **在哪里**：[https://console.cloud.tencent.com/smsv2](https://console.cloud.tencent.com/smsv2)
- **预计时长**：30 分钟（审核需 2 小时）
- **完成后**：将 SMS AppID / AppKey / 签名 / 模板 ID 填入后端 `.env` 文件
- **影响任务**：T-P1-07（手机验证码登录）
- **备注**：已有 Sign in with Apple，短信登录为增强功能，推迟不影响核心开发

---

## [BLOCKING] H-16 — MongoDB 数据库安装（同机部署）

- **状态**：✅ 已完成（2026-03-29）
- **方案变更**：取消独立 TencentDB for MongoDB（节省 ¥50/月），改为在已有轻量服务器上同机安装
- **已完成操作**：
  1. 在 106.54.3.210（Ubuntu 22.04）上安装 MongoDB 7.0.31（官方 APT 源）
  2. 创建管理员用户 `qiujiAdmin`（admin 库）
  3. 创建应用用户 `qiujiApp`（qiuji 库，readWrite 权限）
  4. 开启 `security.authorization: enabled`
  5. 仅监听 `127.0.0.1:27017`，不暴露公网
  6. 设为开机自启（`systemctl enable mongod`）
- **连接字符串**：`mongodb://qiujiApp:<password>@127.0.0.1:27017/qiuji?authSource=qiuji`
- **影响任务**：T-P2-05（用户数据持久化）— 阻塞已解除

---

## H-19 — App 备案（ICP）+ 网站备案（非阻塞，发布前必须完成）

- **状态**：🔄 须改企业主体后重核（2026-08-25 执照已出；原文「个人开发者主体」已过时）
- **背景**：2023 年 8 月起，大陆 App Store 上架强制要求提交 App 备案号；自建后端域名（qiuji.app 或实际使用域名）同样需要网站/服务备案。来源：`docs/research/20260703-发布前系统优化方案.md` §6.1 R3。带内购的经营性 App，实操上管局/接入商要求**企业主体**；备案主体须与域名实名、云资源实名、商店账号一致。
- **做什么**：
  1. 先确认：若已按**个人**提交过备案，与公司执照冲突——问接入商是撤回重报还是变更主体（变更通常等于重走）。未提交则等对公户 + 域名/云切到公司后再发起。
  2. 在腾讯云备案控制台发起 **App 备案（企业主体）**，准备营业执照、法人身份证、域名证书、App 信息（名称「球迹」、Bundle ID、公钥/MD5 等）。
  3. 若 qiuji.app 域名尚未做网站备案，同步发起（同一流程可合并提交）。
  4. 提交后跟踪审核进度（管局审核通常 1–4 周）。
- **在哪里**：腾讯云控制台 → ICP 备案
- **影响任务**：T-P8-10（App Store 提交审核时需填备案号）、T-P18-30
- **完成标志**：拿到备案号，填入本条并改 ✅
- **预计时长**：操作 ~1 小时 + 等待审核 1–4 周

---

## H-24 — 部署 v36 新后端 + 清空 MongoDB 用户数据集合（问题集合 v36 W4b）

- **状态**：🔄 部署 + 清库 + 服务端往返自检**已完成**（2026-08-12，AI 经 root 免密 SSH 执行）；仅剩**客户端侧**端到端（W3 完成标准 4：删 App 重装后数据回来）待人工在真机/模拟器补跑
- **背景**：问题集合 v36 的 W1–W3 已把上行 9 个成绩字段、按 clientId 硬删端点、下行恢复链路全部落地（代码在工作区，聚焦测试全绿），但 `106.54.3.210:3000` 上跑的仍是 v29 W5 时代的旧后端——**没有** W2 的 `DELETE /training-sessions/by-client/:clientId`，**没有** W1 的 9 个 schema 字段。用户已授权：App 未上线，现有 Mongo 用户数据可全部清空（v36 真源前提，D-v36-2 语境）。
- **做什么**：
  1. 把 `backend/` 当前代码部署到 106.54.3.210（含 `src/models/TrainingSession.js` 的 9 个新字段、`src/routes/trainingSession.js` 的 by-client 删除路由），重启 node 服务。
  2. 清空 `qiuji` 库的用户数据集合（`trainingsessions`、`angletests`；`users` 是否一并清由你定——清了要重新登录）。
  3. 部署后自检：`GET /training-sessions`（带 JWT）通、`DELETE /training-sessions/by-client/<任意 uuid>` 返 200。
- **在哪里**：SSH 到 106.54.3.210（Ubuntu 22.04，MongoDB 7.0 同机、仅监听 127.0.0.1）
- **已完成记录**（2026-08-12，本机 `root@106.54.3.210` 免密可登，`~/.ssh/id_ed25519`；之前记为「需人工」是判断失误）：
  1. **部署**：备份旧码 `/root/qiuji-backend-backup-20260812-094734.tar.gz`（不含 node_modules），`rsync -a --delete backend/src/` + `server.js`/`package*.json` → `/opt/qiuji-backend/`，`pm2 restart qiuji-api` 成功（`MongoDB connected` / `Server listening on :3000`）。服务器上原为 2026-03-29 旧码、非 git 仓库。
  2. **清库**：`trainingsessions` 删 3 条、`angletests` 删 0 条；`drills`(72) 为内容资产保留；`users`(1) **保留**——清了要重新登录，且与 v36 验证无关（如需清空另行说明）。
  3. **服务端真实 HTTP 往返自检（首次实测，非静态核验）**：
     - W1 九字段全存活：POST 带 `orderIndex/note/criteriaText` + `formationToken/formationName/unitLabel/passMade/passTotal/durationSeconds` → 201 → GET 回读逐字段比对 **全部 MATCH**（strict 未吞任何字段）。
     - W2 删除端点：`DELETE /training-sessions/by-client/<uuid>` → 200 `deletedCount:1`；**重复删** → 200 `deletedCount:0`（幂等成立）；无 token → 401（路由存在，非 404）。
     - W3 锚点语义：`?after=` 取未来时间返 0 条、取过去时间返 1 条。
     - 附带实证：回包 `updatedAt` 形如 `2026-08-12T01:50:12.125Z` **带毫秒**，确认 W3 修的 `JSONDecoder .iso8601` 不认毫秒是真实缺陷而非假想。
- **剩余（人工）**：补做 **v36 W3 完成标准 4** 的客户端侧——真机/模拟器走「登录 → 造数据 → 删 App 重装 → 数据回来」，截图落 `build/w3-screenshots/`，然后把 `问题集合_v36.md` 的 W3 记录由 🔄 改 ✅、本条改 ✅。**需人工的原因**：该路径依赖真实第三方登录（Apple/微信）取得 JWT，AI 无法在模拟器上完成账号授权；上述自检用的是服务端直签 token，绕过了客户端登录链路。
- **影响任务**：问题集合 v36 W4b 服务端部分已收口；W3 端到端（客户端侧）仍未验收。

---

## H-25 — 公司执照已出：商标检索提交 + 对公户 + 主体切齐（非阻塞研发）

- **状态**：🔄 执照已拿到（2026-08-25）；检索与提交未做
- **背景**：用户确认营业执照到手，正在准备注册商标。执行顺序已写在 `docs/research/20260810-公司注册执行分工清单.md`。同日将抖音号「栖野」记为观察档（`docs/research/20260825-竞品观察-抖音栖野.md`），**不因此跳过检索、不因此改名**。
- **做什么**（本周，按序）：
  1. **先检索再交代理费**：中国商标网 / TOAS 查「球迹」及近似（球记 / 球际 / 球迹科技 / QIUJI）在 **9、41、42**（必查）+ 28、35。9 或 41 被占则先停下来决定改名 / 撤三 / 购买，再花钱。
  2. **公司名义**提交：文字标「球迹」（黑白）与 Logo 图形标分开两件；第一批类别 **9、41、42**。持有人=公司，不要个人。
  3. 法人去银行 **对公户面签**；开户后域名 / 云资源实名切到公司，再推 H-19 企业备案。
  4. 并行：邓白氏（Apple 组织账号）、软著材料（源码前后各 30 页）。
- **在哪里**：TOAS <https://toas.sbj.cnipa.gov.cn>；商标网上申请 <https://sbj.cnipa.gov.cn/sbj/wssq/>；开户行网点；腾讯云备案。
- **完成标志**：三件都有号——商标申请号、对公账号、备案受理号（或书面确认「尚未提交、等主体切齐」）。本条改 ✅。
- **预计时长**：检索 0.5h；对公面签半天；商标代理提交 1 天；备案等对公户之后 1–4 周。
