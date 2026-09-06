# SC36 千场真实历史/统计 UI 数据准备选项

只读评估 snapshot-002；新增未执行草稿 `ThousandHistoryFixtureTests.swift`。未操作设备、未启动App/测试/构建、未创建任何数据库。**有条件可行，但不应直接向正常运行宿主的默认库播种。** 千场压力数据必须来自独立专用空设备，不能复制用户数据库或SQL伪造关系。

## 冻结入口核对

- `QiuJi/App/QiuJiApp.swift:16–18`：只有`-v50.inMemoryStore`切内存，否则`ModelContainerFactory.makeContainer()`默认磁盘库。未找到正常App接受自定义storeURL或seed1000的启动hook。
- `QiuJi/Data/Models/ModelContainerFactory.swift:11–28,35–48,56–75`：默认URL由当前schema的`ModelConfiguration`决定；显式URL入口仅为迁移测试方法，App不调用。内存工厂仍会获得DeviceGuestIdentity并执行归属/版本规范化，不能称纯无副作用。
- `QiuJi/Data/Models/OwnerIdentity.swift:21–36,41–68`：`auth.deviceGuestID`持久在App UserDefaults；guest owner=`guest:<id>`；正常bootstrap无凭证恢复该guest。随便用`guest:quality-cross-data`会被正常仓储过滤，数据存在也可能UI为空。
- `QiuJi/Data/Services/AuthState.swift:139–174`：没有refresh凭证时走guest，不发起该账户恢复；**这不是全进程断网保证**。
- `QiuJiApp.swift:58–83,103–109`：启动配置同步、认知回填、bootstrap、StoreKit权益查询；活跃时尝试syncActiveAccount。默认构造其他服务与共享对象仍存在。`-forceNonPremium`可跳过App这一处checkEntitlements task，但不能等同全域网络禁用；`-forcePremium`还写debug偏好（SubscriptionManager.swift:140–198）。
- `…/History/ViewModels/HistoryViewModel.swift:491–510`、`StatisticsViewModel.swift:417–436`：loadFallbackDrills是Bundle fallback（DrillContentService.swift:491），然后LocalTrainingSessionRepository.fetchAll按当前owner取真实本地数据。正常MainTab传入模型容器，因此默认disk+正确guest可让真实历史/统计读取。
- `QiuJiUITests/Helpers/XCUIApplication+Extensions.swift:52–60`的launchClean设置语言/locale、跳过onboarding与debugPremium reset，并没有抹整个数据域；名称不是“数据库已清空”的证据。

## 选项比较

| 方案 | 可行性 / 限制 |
|---|---|
| 既有`-v57.practiceCountFixture` | 1session×1000entry且仅动作库宿主，不能完成本目标。 |
| 普通hosted单测直接开默认库 | **不推荐**：QiuJiApp已持有该默认库并执行启动tasks；另一container同时写、owner切换/回填/查询竞态使证据边界复杂。即使空设备也应避开。 |
| 独立单测host使用内存，单测向同App sandbox的空默认disk写SwiftData | **推荐最小候选**：只利用冻结现有开关，不改业务；然后彻底结束host，正常App无内存参数重开。默认磁盘路径与guest必须显式核准。草稿即此路线。 |
| 单测在任意temp路径生成store再搬入App | SwiftData可生成，但需要完整关闭与sidecar处理，store外部数据/迁移元数据和安装container变化都增加风险；不优先，不能只复制一个sqlite文件。 |
| 新独立全Tab fixture host | 能明确控制容器，但必须改诊断宿主装配，不是当前冻结正常App路径。可作为后备，不把它偷偷称正常启动。 |

## 推荐路线的必要前提（未实施）

1. **专用新设备/专用App数据容器**，主控持有确切UDID与bundleID。不能复用既有用户设备，也不在当前正式run数据库旁覆盖。新安装后不要先正常disk启动，否则默认文件已生成，草稿会拒绝。安装重建可能改变App container路径，路径要在本次安装后解析。
2. 在独立诊断scheme/test-plan中给**测试宿主App**预先传`-v50.inMemoryStore`，不能在test方法里事后设置。临时测试装配可做，业务源不动。环境变量传给测试runner而未传到host也不够：草稿检查宿主ProcessInfo实际参数，不符硬失败。
3. 专用guest身份由该App内存宿主正常创建，并读取其非敏感`auth.deviceGuestID`。先记录guest，再显式传`QD_EXPECTED_GUEST_OWNER`；不覆盖identity、不调用setOwnerKey伪造UI owner。host无登录/Keychain凭证需外部事先核实，不能等test体再检查来阻止已经发生的bootstrap。
4. **不联网约束需要外部保证**（专用离线测试环境/已验证的进程或设备网络隔离），目前未发现冻结App全域禁网开关。无refresh token只阻断用户同步入口，不能证明StoreKit、其他启动服务绝无网络。不能用主机级改网络影响其他任务。若没有隔离办法，先保留此实施阻碍，不执行播种宿主。草稿授权变量是操作前提声明，不是断网检测器。
5. 主控明确三个专用绝对路径/值：`QD_EXPECTED_DEFAULT_STORE_PATH`（本App configuration实际url）、`QD_FIXTURE_MANIFEST_PATH`（同sandbox新文件）、`QD_EXPECTED_GUEST_OWNER`，以及`QD_EXPECTED_LOCAL_DAY=yyyy-MM-dd`与`QD_ALLOW_THOUSAND_DISK_SEED=DEDICATED_EMPTY_OFFLINE_SIMULATOR`。路径不应靠手猜Library位置；草稿将actual config.url与expected精确比对，要求位于NSHomeDirectory，并拒绝已有store/-wal/-shm/manifest。

以上任一条件不足时不运行。尤其**同一个刚安装App的宿主scheme必须从首次启动就用内存**；需要先探测guest/path时可另跑只读诊断方法，但不能普通启动创建disk后再删除它绕过护栏。

## 草稿做什么与不做什么

选择器`QiuJiTests/ThousandHistoryFixtureTests/testSeedDedicatedEmptyDefaultStoreForNormalHistoryUI`，尚未编译。直接当前SwiftData schema+迁移计划创建空默认磁盘容器，通过对象关系插入1000 TrainingSession，每场1DrillEntry/1DrillSet，不通过SQL、不调用同步仓储、不创建queue、不复制用户内容。显式owner和note `QD-1000-i`便于识别。以今天零点后1000个不同毫秒排序，全部drill：每场2分钟8/10；期望1000场、1000条目、1000组、1训练日、2000分钟（33h20m）、8000/10000=80%。

**这是synthetic stress fixture，同日重叠/总2000分钟不代表合理真实日程**；为最坏同日列表密度而设。它不证明跨天/混合kind统计，后者由DATA1账本另行验证；不要为了压力数据逼真性悄悄缩小到每天几条从而绕过长列表。若主控希望更真实多日分布，应在独立新版本fixture说明中固定分布与新expected，不能混用证据。

草稿只拒绝已有文件，不删除/替换；若中途保存失败或跨午夜，设备视为无效样本，主控另建专用设备，不自动清库重播。模型关系数量保存后fetchCount核对，manifest显式输出预期和store/owner。Manifest创建失败不是成功播种报告。代码内不声称整个进程无网络，也不通过模拟器完成UI。

## 正式可验证步骤

1. 前置环境与路径/owner核准→只跑该单测→原始exit/xcresult与manifest归档。单测通过只证明播种对象与数量，不证明冷重启读回。
2. **结束整个host进程**，保持同安装和guest defaults；不要搬运行中的sqlite或删WAL。正常App启动去掉`-v50.inMemoryStore`及所有deep link/状态fixture参数，仍受已验证离线环境约束。可正常通过onboarding，或记录使用既有onboarding launch override；不得触发新guest覆盖。
3. 用正常记录Tab进入今天：验证一组实际QD note/8/10/2分钟明细；滚动至首末代表记录（同毫秒时间差UI可能不显示，但note可辨），不能只看“页面存在”。查询真实磁盘数量/owner可用独立只读SwiftData方法（不要在App写库时复制sqlite）；若读回0先查owner与store路径，不把它立刻判产品加载丢失。
4. 正常切统计：预期1天/33h20m/1000组；准度80%，工具0。再返回历史验证仍可操作。个人自然月1天/33h20m可补跨页，但首屏未必展示所有数字，AX和截图对应取证。
5. 性能单独记录：固定设备/runtime/Build/数据哈希，预热与冷启动分组；按PLAN-v2固定轮次报告中位/最大耗时、超时、crash与内存峰值来源。无需编造通过阈值。加载完成标志需真实数据数值/列表，不以进程launch返回代替；滚动卡顿不能靠静态截图判定。
6. 独立设备归档后再讨论清理，不在本任务修改任何现有设备。压力fixture不是SC36冷启动/工具10次所有项闭环，正常UI未实际执行前一律“准备可行/前提未落实”。
