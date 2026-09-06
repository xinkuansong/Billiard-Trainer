# 诊断执行记录

> 用户已要求先完善方案再正式执行。RUN-001～004统一视为探索记录，保留证据但不自动迁移为正式覆盖。该暂停已由用户“按方案执行”解除，正式运行见文末与PLAN-v2.md。

## RUN-001：后端单元与静态规则，2026-09-05

状态：已执行；非 App 功能总验收。

### 后端

- 命令：在 backend 执行 `npm test`；实际入口 node --test。
- 结果：15 tests，15 pass，0 fail，0 skip；退出码 0。
- 核对范围：资料 DTO、输入校验、头像临时目录、删除依赖顺序/失败保留、法律文档模板、训练来源 schema。
- 数据条件：模拟依赖、内存 Mongoose 对象、临时头像目录；未启动真实 HTTP 服务、未连接数据库、未调用真实账号。
- 执行前后 backend/src、backend/test、package 文件 SHA-256 一致。
- 原始日志：[backend-tests.log](../../build/quality-diagnosis/run-001/backend-tests.log)；时间/Node版本/输入哈希/退出码：[backend-run.json](../../build/quality-diagnosis/run-001/backend-run.json)。

### 静态规则

| 命令 | 结果 | 证据边界 |
|---|---|---|
| python3 scripts/verify_tutorial_sync.py --gate | exit 0，FAIL 0 | 有提示和豁免；不代表内容全部正确或已实测渲染 |
| python3 scripts/verify_sync_schema_alignment.py --gate | exit 0，FAIL 0 / WARN 0 | 字段登记对齐，不代表数据往返无丢失 |
| python3 scripts/verify_billiard_copy_terms.py | exit 0，PASS | 指定禁用术语扫描，不等于教学质量验收 |

完整命令和日志路径：[static-runs.json](../../build/quality-diagnosis/run-001/static-runs.json)。内容门禁包含 C1 新鲜度 95 条提示、I7 11 条提示、I9 三项豁免与五项提示；需逐类确认意义，不能隐藏在 FAIL 0 后面。I10 为脚本模型镜像验证，最终仍需宿主 App 的真实解码测试。

### 环境和副作用盘点

- Xcode 26.2 / 17C52；已查询到 iOS 17.0 与 26.2 设备。
- 首次沙箱 simctl/pgrep 不可访问服务；提升权限只读查询成功，因此不是设备缺失或产品故障。
- audit_simulator_test_writes 首次因沙箱 simctl 失败 exit 1，保留其部分产物；随后只读提升权限运行成功。
- [有效写盘盘点](../../build/quality-diagnosis/run-001/write-audit-verified/write-test-inventory.json)：133 个文件命中写盘模式，6 个标为 tracked_repository_destination，12 个标为 legacy_absolute_repository_path。分类为启发式筛查，须对计划执行的用例逐项检查，不能以分类计数认定真实破坏行为。
- 外部 v57 UI 测试正在运行，本轮未启动本专题模拟器测试。

### 仍待完成

静态运行期间源输入缺少独立前后完整指纹，故作为初始观察保留；最终内容证据须在完整快照下复核。未执行 iOS 测试、UI、真实网络、购买和性能测量。


## RUN-002：iOS 聚焦单元，2026-09-05（已完成，输入有漂移）

- 专用新设备：928FAAE6-4AAC-44F8-AA45-C51F0EBF2A25，iPhone 17 Pro / iOS 26.2。
- 通过 scripts/Makefile test 执行；独立 DerivedData：build/quality-diagnosis/DerivedData。
- 选择器：V54TrainingTransactionTests、V54ScheduleDomainTests、StatisticsViewModelTests、DrillContentValidationTests。
- 排除 test_renderProfileMonthlyOverviewCard_afterEvidence：会写旧 build/w6-screenshots，不覆盖历史截图。
- SwiftData 内存或 UUID 临时磁盘容器；未选择制作 runner。并行 testing 关闭。
- [输入快照](../../build/quality-diagnosis/run-002/baseline.json)含 4624 文件哈希；[选择器](../../build/quality-diagnosis/run-002/selectors.txt)。运行后必须核对变化，尤其正在并行开发的 v57。
- 原始日志：[xcode-test.log](../../build/quality-diagnosis/run-002/xcode-test.log)；[make.log](../../build/quality-diagnosis/run-002/make.log)。
- make/xcodebuild exit 0，75 tests / 0 failures；四套件分别 20、28、21、6 项。
- 完成后比对发现 RootView.swift 与 BTDrillCard.swift 在运行期间改变；结果仅说明当时构建通过，最终当前快照须复验。
- [汇总与变化清单](../../build/quality-diagnosis/run-002/result.json)。会话 65642 已正常结束。
- 附加 Debug 包静态检查：六个已下架盘面 JSON 确实在 .app/DrillBoards，见 [包内清单](../../build/quality-diagnosis/run-002/retired-bundle-audit.json)；用户可达性未验证，不外推 Release。


## RUN-003：隔离 HTTP 路由诊断，2026-09-05

- 新诊断脚本：[backend-route-diagnostic.test.cjs](backend-route-diagnostic.test.cjs)。用实际 Express 路由与 JWT 中间件；模型操作为进程内替身，仅监听 127.0.0.1 临时端口，结束即关闭；未连接 MongoDB、未操作真实用户。
- 命令：`node --test tasks/quality-diagnosis/backend-route-diagnostic.test.cjs`，exit 1。
- 4 个子检查中 2 pass / 2 fail；Node 总计 5 tests / 3 fail 包含父测试失败，不能误报三个独立缺陷。
- pass：无 token 被拒绝；不同 owner 拉取不到本账号夹具。
- fail：PUT body.userId 进入 findOneAndUpdate 并返回新归属；501条夹具仅返回500，取最大 updatedAt 后继续拉取0条。
- [原始日志](../../build/quality-diagnosis/run-003/route-tests.log)。证据证明路由层缺口，尚无真实数据库持久化/真实客户端端到端复现。
- 交叉读取：训练/角度 GET 均 limit(500)；SyncRestoreService 每类只 fetch 一次，advanceAnchor 使用最大 updatedAt，BackendSyncService 无分页参数。生产代码未修改。

## RUN-004：首次使用与基础 UI 场景，2026-09-05（已完成）

- 专用设备同 RUN-002；已确认此前 xcodebuild 全部结束后启动。exec session_id：7050。
- 三个选择器见 [selectors.txt](../../build/quality-diagnosis/run-004/selectors.txt)：首次引导并重启、游客免费/forced Pro 门控、完成态再自由训练保存及重新开始。
- 使用现有测试，明确内存 fixture 与 forced Pro；不代表真实购买、不证明完整磁盘训练恢复。
- 输出注入 TEST_RUNNER_V50_SHOT_DIR 到独立 [截图目录](../../build/quality-diagnosis/run-004/screenshots)；不得复用其他任务截图。
- [输入快照](../../build/quality-diagnosis/run-004/baseline.json)；[原始日志](../../build/quality-diagnosis/run-004/xcode-test.log)。完成后核对退出码、截图、源码变化。

- RUN-004 阶段结果：引导完成与重启 31.267s 通过，已目视 onboarding-completed 截图；游客边界在旧文本断言失败，见 QD-010。训练保存后再开始场景 58.087s 通过（两个内存 fixture）；整体 3 tests / 1 failure，make exit 2 / xcodebuild exit 65。会话7050已结束。

- 完成时 [结果和截图manifest](../../build/quality-diagnosis/run-004/result.json) 已保存；源码变化 ['QiuJi/App/RootView.swift', 'QiuJiUITests/V54ScheduleUITests.swift']。截图仅已抽查引导完成图，其余待目视，不能全数声称视觉通过。


## 正式阶段

用户已于2026-09-05明确“按方案执行”。FORMAL-B1-001已按冻结snapshot-002启动，卡片和恢复句柄见[B0-B1.md](B0-B1.md)。不与RUN-001～004探索统计合并。

### FORMAL-B1-001（已结束）与002（运行中）

001：make=2/xcodebuild=65；内容20通过，UI2通过1失败。独立训练用例漏切单项视图；保存/磁盘未执行。源指纹零漂移。截图另有键盘系统提示和详情未稳定渲染，不能算视觉通过。详B0-B1.md。
002：只复跑独立训练用例，测试步骤修订与哈希记录formal-b1-002/input-change.json；当前exec35665，禁止重复启动。

### FORMAL-B1-003（已结束） / FORMAL-B2-001（运行中）

003 make0、1/1UI、53.822秒；备注真实重启保留。保存前1/8组与历史8组全勾的截图差异独立诊断。输入复核仅诊断文件预期变化。
B2-001已启动171个具体方法，exec52440，见B2.md。

FORMAL-B2-001已结束：171/171，make0。FORMAL-B2-002非零部分完成样本运行中，exec80940。

FORMAL-B2-002已结束：make0，1/1备注重启断言；视觉复现QD-012 5/120/4%。FORMAL-B3-001：31/31，make0。B3静态门禁前提缺两参考文档造成90失败，补同B0 HEAD文档后FAIL0；schema及术语通过。B3-002运行中exec1526，见B3.md。

FORMAL-B4-001四组41/41，002三组20/20，全部make0；两旧句柄25875/42786已结束。FORMAL-B4-ROUTES exit1，叶子17项10通过7失败，复现QD007/008。当前FORMAL-B3-003正常工具三旅程exec73160。

FORMAL-B3-003已结束2/3，测试回放预期失配；004已结束8/8、make0。FORMAL-B2-003历史编辑运行中exec71187，测试前只读SQLite备份before.sqlite；仅新建唯一标记样本允许编辑删除。

## FORMAL-B5-M1-LIGHT / M2-LIGHT-ROOT（2026-09-06）

M1 Light/large根入口+计时/最小化/球桌/休息共5/5，make0，113.024秒；14 PNG及frames位于formal-b5-m1-light，图审另记。M2专用SE3/iOS17.0首次boot完成，Light/large/contrast disabled读回归档，根入口1方法exec33817运行中。均沿用snapshot-002与每run inputs；M1结束后才启动M2。

M2-root结束1/1 make0；M2-core结束2/3 make2/xcode65；定位失配证据与单方法复验exec37307见B5.md。未修改业务；overlay007保存诊断变更和仅两文件的工程注册diff。

## M2剩余批次结果（2026-09-06）

Light persistence002 1/1 make0 42.314秒；AX5 root1/1 25.119秒；AX5 core4/4 140.764秒；unit20/20 0.042秒，均make0。RootReachability2/2 make0 32.444秒。INPUT001昵称通过/模板在顶部菜单hittable失败，make2；模板002追加截图AX仍失败make2 17.324秒。实际图审及失败边界见B5及独立图审文件；QD019搜索图标裁切单列，未把整个大字号标通过。

### 2026-09-06 M3 Light/Dark与Release补记

- FORMAL-B5-M3-LIGHT-CORE N/D/S 3/3，138.746秒、make0；THEORY 1/1 30.009秒；ROTATION 1/1 26.404秒。61110队列终结；各运行独立日志、哈希和图证。L/P各1图在独立V50叶并保存external-screenshot-manifest。
- FORMAL-B5-M3-DARK四方法4/4、122.107秒、make0，16624终结；系统Dark读回已保存，图片独立审查中。
- FORMAL-B5-RELEASE-001 xcode0/make0，97725终结；Release禁签名双架构模拟器包，package-audit.json及RELEASE-RESULT.md已生成。API/legal空值需要结合快照裁剪归因，不能先判真实配置缺失。
- 当前M3 AX5 root/core/theory串行队列12583。

M3 AX5输入补验001配置中的昵称方法名不存在，日志Selected只执行MenuHit模板1项（50.093秒通过），SystemBoundary执行0项，不能按make0记两项通过。原配置/日志保留；单独002使用从源码核对的真实方法testGuestNicknameUsesNormalLocalEditorAndReopens。运行器新增执行前类文件/类声明/精确func存在性拒绝，避免Xcode静默漏测。

FORMAL-B4-REAL-MONGO-001五项2通过3失败、Node1，29653已终结；原始源/脚本/二进制哈希与自有mongod正常关闭证据已审。运行器外层Python正常返回不替代exit.json里的真实node_exit。M3 AX5 nickname002 1/1 34.643秒make0，18925关闭；当前M2 AX5 Menu003 exec29989。

FORMAL-EXTRA-M2-AX5-MENU-003两方法43.435s、make2：template31.011s在保存hittable断言失败，more12.424s通过且观测hittable=false/真实frame315,24,44,44中心点击后菜单出现。截图+AX保存按钮真实308,25.5,51,33.5可见。区分AX可命中性与实际触摸，004另立物理点击观测旅程，不修改原失败结论。

## 用户暂停 2026-09-06T03:50:29.619642+08:00

M1Dark10661向已核对的本轮xcodebuild83387发送SIGINT，并关闭本轮M1；句柄终结make2/xcode75，归类user-interrupted而非产品失败。pause-request.json/原始log/manifest保留。停止所有后续执行，状态见PAUSE-SUMMARY.md。
