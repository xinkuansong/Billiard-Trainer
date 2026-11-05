# 两页开球统一与每日玩法改名 · 2026-11-02

> 11-03用户修订：设置选择立即更换球形，两页设置移除取消开球。下述“仅影响下次/当前不变”保留为历史，不再有效；现行合同见[即时应用卡](BREAK-SETTINGS-LIVE-20261103.md)。

用户本轮明确授权：分离角与走位及打一走二想三统一左上开球、设置选玩法、过程静默；P05平时开球下方展示解，开球期间解移除而方向尺出现，球停后自动恢复。每日清台“临时换玩法”改“开球玩法”。

## 真实入口与边界

- 分离角与走位正式路由是 AngleHome.positionPlayComposer → PositionPlayComposerView → FreePlayView(editor:)，身份composer。旧ShotSimulationView已退役，不据同名旧源实施。
- P05使用PlanThreeView/BTTeachingTablePage。开球物理与取消快照沿BreakFlowRunner/原VM。
- 每日清台只改菜单与子菜单名称，换玩法现有进度确认/额度/规则保持。
- 动作试打、自定义球形、思路训练、退役自由击球不接入新玩法偏好/静默合同。

## 本轮合同

两页各自记住开球玩法（composer.breakGameBallCount／planThree.breakGameBallCount），默认中式八球；选择仍为中八、9/6/5/4球。设置只决定下一次进入开球时的球架，当前球形和正在准备的球架不变。左上开球直接摆架；当前开球内重开仍按本次runner玩法；改变玩法要完成/取消当前流程再开球。

P05普通态左侧开球＋解、底部上一步/重打及回放；开球态左侧重开＋方向尺，不保留不可见的解热区。右下手动开球，实际回放停稳后自动交付球形，无需完成按钮；取消恢复原桌及计划。正式composer同样用左上重开、右下开球，停稳自动结束，保持原方向尺；不显示额外居中完成/重开条。

两页不显示摆架说明、计算中、运杆、开球中、已停稳等过程文案；保留模拟未完成、打点不可行等需要用户处理的消息。动画本身与实际禁用态保留。按钮字号、桌体、HUD背景与球库不变。

## 影响项复核（沿原P03/P05完整判定）

|TP|适用性/本轮检查|
|---|---|
|01|继承正式composer/P05路由；历史旧入口不作为证据。|
|07/08/10|按业务调整：同六球glyph/顶部尺寸；解与方向尺互斥，底部槽保持；原杆速10与手动调参不变。|
|16/17|继承2D/3D与母球开球区交互；不修改几何或相机算法。|
|19/20/21|按业务调整：同DailyHUDMenuPanel玩法子菜单；当前选择和返回/关闭，选择不重摆。每日换玩法仅改名。|
|24|按业务调整：过程静默，仅保留可操作错误。|
|25/26|继承取消快照；按业务调整停稳自动交付；禁用开球期间重打回放。|
|28|继承个人布局；P05补break.entry、composer补break.confirm能力，已有模板不重置。|
|35/36|源码/原图/功能/真机分列；本轮验证见下。|

## 源码、证据与当前状态

- 用户两张原图和修改前5文件在output/break-unification-20261102/before；用户图不是本轮同设备技术before。
- 初版语法解析通过；完整App编译、真实开球/取消/自动结束、两维与小屏/Pad定向验证进行中。
- 私有副本4302文件逐文件SHA和执行位与采集前后共享源一致；来源commit 85fe3a59，副本独立Git仅用于队列冻结，不是生产提交。copy-audit.json记录实际字节与来源；之后3个owned文件的修改记录private-owned-delta.json。
- Mac mini首轮任务break-unification-r1-20261102；SE3/iOS17，UnifiedBreakFlowUITests五项＋开球状态/失败/镜头取消/布局能力定向逻辑。
- 真机、VoiceOver、完整App回归、用户体验未验；未提交/安装真机/发布。

首轮构建失败：并行翻袋质量改动中的BankKickDifficulty调用尚未纳入快照的bankPocketContactCount，未进入测试。r2仅在私有验证副本用output/bank-jaw-quality-20261102/before/BankKickDifficulty.swift替换，该文件SHA=3b31430…与已通过r9报告一致；其余9个相关物理/消费者/manifest/测试源也逐项SHA一致。共享翻袋源码不动，不绕过指纹。r1证据已回传/校验，complete已回收临时构建与远端快照。r2 snapshot acf0034b6eb3eea4dab0f5a40fccada72d48658e73771ae25517fa236181f863。

r2完整构建通过；首轮UI脚本在主菜单错误寻找子菜单的关闭按钮，开球交互尚未执行即失败。r3改为主菜单点击现有外部关闭层，子菜单仍点关闭；只修改测试操作，不改产品/断言。r2/iPad尚未执行的排队任务已取消避免重复无效验证。r2→r3源清单差分仅S6_BreakUniversalUITests.swift。

用户追加：两页球停后自动结束，不再手动点完成。P05 runner开启autoDeliverOnSettle，正式composer调用manualDeliver:false；其他宿主保持原合同。r3旧合同测试结束，6项逻辑通过，Daily改名通过；P05测试的启动参数把玩法锁在15导致改值断言失败，修复测试初值注入；composer首个入口按全部AX元素匹配并增加启动截图诊断。r4使用实际停球后自动恢复断言，加入两宿主交付逻辑测试。

r4：snapshot 2581ca5d329821f2adca92fb0a1f46ca1da2e060125cf5d274c5a665a99edfb8；SE3/iOS17及iPad mini6/iOS26.2队列，Pad覆盖P05 3D与composer 2D横竖。当前10个本任务源/测试文件与快照逐字节相同（owned-source-match-r4.json）。verify-gate全门禁通过，v47路由签名仅PlanThreeView变化：已审核删除开球玩法sheet、改设置子菜单；路由CSV同步正式两个宿主及wrapper的状态/测试/证据入口。

r4实测：7项逻辑全部通过；SE3 composer 2D/3D完整开球和Daily名称3项UI通过，截图已目视核对。P05 2D失败是测试将布局ID break.strike误当实际AX ID（实际planthree.strike），未执行击球；P05 3D启动后XCTest注入框架在广泛标识查询期间出现runtime_issue_os_log_fault_callback空指针，堆栈为XCTAccessibilityFramework及高频日志隔离（r4-planthree-crash.ips），无开球实现栈。r5仅修测试：真实主按钮标识、精确identifier谓词，生产源不变；定向补P05两维及Pad 3D。

原生图审查入口：[UR-20261102](../ui-reviews/UR-20261102-break-unification.md)。Pad r4 composer 2D实际自动收尾、旋转竖屏再摆架通过；P05仍因旧主按钮定位脚本失败，r5补测已排队。

远端前序任务为长时间全网格回归，r5两项尚未执行即取消并回传收尾。改用同一只读snapshot-r5b在本地一次构建串行补测：fleet compact-phone-floor（SE3/iOS17）与compact-pad（mini6/iOS26.3.1），Xcode27.1，受管本地运行71d56582ad014c93a96514e81f927534。未新建设备，不覆盖数据保留例外；真源与两页源码不变。

## 最终结果（覆盖上方进行中记录）

已完成用户最终合同：两页停稳自动结束，无完成步骤；其余布局、设置、静默及Daily改名均完成。7逻辑＋7界面定向检查通过，见[原生审查](../ui-reviews/UR-20261102-break-unification.md)及[图册](../../output/break-unification-20261102/review.html)。P05本地SE17两维＋Pad26.3.1既有窗口/竖屏通过；composer远端SE17两维＋Pad26.2横竖通过。当前10个owned文件与验证源一致。Xcode27完整测试构建受无关BankKickSolverOptimizationTests类型检查超时影响，临时UI-only scheme完成本轮UI补验，生产代码未变；远端Xcode26.2完整构建和7逻辑已通过。真机、VoiceOver、完整共享树App回归和用户体验认可未验；未提交/发布。唯一下一步为用户实际体验反馈。
