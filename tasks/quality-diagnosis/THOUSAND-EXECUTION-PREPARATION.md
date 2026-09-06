# 千场播种与正常 UI：执行准备草稿

2026-09-06；3个Swift文件均未编译/运行，无scheme/设备/业务修改。本次仅将既有fixture授权字符串从DEDICATED_EMPTY_OFFLINE_SIMULATOR改为DEDICATED_EMPTY_GUEST_SIMULATOR，并同步拒绝文案。原路径、owner、已有store/sidecar/manifest拒绝约束未降低。

## 首启动序

1. 主控建立专用新模拟器、无真实登录/Keychain/购买凭据，固定UDID与当前安装。此环境条件来自设备流程，probe不读Keychain，也不以打印owner假装证明无凭据。普通启动查询允许，不要求全域断网。
2. 独立hosted unit-test scheme在首次启动前给宿主-v50.inMemoryStore；按THOUSAND-SEED-SAFETY-REVIEW.md核对实际生成的TestAction及继承关系，仅选择probe。不得先普通disk启动，不得在setUp补参数假装首启内存。
3. `QiuJiTests/ThousandStoreProbeTests/testReportInMemoryHostAndEmptyDefaultStore`：传`QD_PROBE_ENVIRONMENT=DEDICATED_EMPTY_GUEST_SIMULATOR`。只读args的必要事实、真实Bundle/Home/defaultURL、现有guest与store/-wal/-shm存在性，输出JSON附件/日志。只创建ModelConfiguration，不开disk ModelContainer。App本身可能创建guest偏好，probe代码不写偏好。失败即停，不自动清库重跑。
4. 从本次probe核准路径/owner，在相同安装与身份中仅选择原seed方法；测试宿主仍必须首次参数内存。传`QD_ALLOW_THOUSAND_DISK_SEED=DEDICATED_EMPTY_GUEST_SIMULATOR`和原有`QD_EXPECTED_DEFAULT_STORE_PATH`、`QD_EXPECTED_GUEST_OWNER`、`QD_EXPECTED_LOCAL_DAY`、`QD_FIXTURE_MANIFEST_PATH`。后者是App sandbox内此前不存在的文件。归档原始结果与真正生成的manifest；未生成不得进入UI。
5. 彻底结束整个host；不重装、不搬sqlite、不清guest。将刚生成manifest内容作为JSON提供给UI runner，不手写一个符合预期的假manifest。UI runner环境：`QD_UI_ENVIRONMENT=SEEDED_DEDICATED_GUEST_SIMULATOR`、`QD_EXPECTED_MANIFEST_JSON`、同值`QD_EXPECTED_GUEST_OWNER`和`QD_EXPECTED_DEFAULT_STORE_PATH`。UI runner与App sandbox不同，JSON参数避免其擅自读取另一个沙盒文件；主控负责manifest来源链。
6. 只选`QiuJiUITests/ThousandHistoryUIDiagnosticUITests/testNormalHistorySamplesAfterScrollingAndStatisticsTotals`。草稿直接XCUIApplication正常disk启动，中文/跳过onboarding/forcePremium，**不调用launchClean重试逻辑、不用inMemory/deeplink/data fixture**。forcePremium仅本机订阅门控，不是authenticated账户。测试不把manifest参数传给业务App。

## UI断言与证据范围

- 通过正常记录Tab进入当天历史。列表行显示动作名“半台直线球”和“2 分钟”；打开可操作行，从真实详情核对8/10与QD-1000-i。关闭详情后滚动6次，再打开可见行，要求i落在0…999且比首个样本小。列表按日期降序；毫秒间隔会导致相同显示时刻，note才区分样本。
- 首个可操作行可能不是绝对第999条，末个样本也不保证第0条。本草稿明确是两个真实样本及长列表滚动，不声称逐1000条或首末完整巡检。列表全量计数来自播种/持久读回证据；统计1000组对本fixture的一场一组有映射，但不是直接读取UI记录计数。
- 正常“统计”切换后检查训练概况2000/分钟·总时长、1000/训练组数、1/天；下滚核对80%、8000/10000 球、1000组，再返回历史验证仍有可操作样本。原源码概况显示2000分钟，不是33h20m字符串。
- 每一阶段唯一截图+AX保留在xcresult附件，主控正式执行后统一导出。附加manifest校验只能验证预期输入形状，不能证明当前App确实读取同一路径/owner；后者依靠probe→seed→不重装→冷启动的证据链与数据内容交叉核对。
- “1”“天”等独立AX值存在歧义，主控必须审阅overview截图确认其确属训练天数；本草稿不把孤立数字存在当视觉语义已验。所有选择器依据冻结源码，尚未实机确认AX组合形式；如果row label或sheet关闭按钮类型不符，记为草稿适配问题，不能先判业务故障。
- 当前未加入性能计时、内存峰值、全1000条遍历或冷启动多轮；这些是正式性能批次的单独工作，不能用该UI方法一次通过宣称SC36完成。

## 未作额外变更

原seed仍仅按原要求改授权字符串/文案；本轮未新增之前审计建议的SyncPendingItem==0和逐owner保存后检查，主控可独立决定下一步审查或加入。所有方法的断言失败均应使该样本无效；不覆盖store、不自行迁移、登录、购买、删除、编辑记录或分享。

## 安装路径变化补充：probe与seed之间的合法失配

主控实际观察：再次xcodebuild测试可能重装宿主，App data container UUID及绝对路径随之变化。因此前文“保持同安装”是必须验证的条件，不是调用方式天然保证；**不能保证test-without-building不重装**。当前seed仍严格比较绝对expected路径，合法重定位也会拒绝。这是环境身份核验失败，不直接判产品数据故障；不得删除数据库或改成接收任意storeURL来绕过。

### 方案A：维持原草稿绝对路径约束

主控在固定专用UDID、bundleID上，每次安装/测试调度后重新用`simctl get_app_container <UDID> <bundleID> data`读实际沙盒路径，并与probe报告的NSHomeDirectory对照。记录构建版本、当前guest和store不存在性。只有seed真正启动时其NSHomeDirectory/config.url仍与预期相符，原草稿才继续写入；若调度过程中又重装导致失配，就保留拒绝结果。外部在启动前查一次路径不能证明随后未重装。

可用条件：主控已验证本轮probe与seed共用同一安装与路径，且seed内原有owner/path/store护栏全部通过。不能以“使用相同DerivedData”“使用相同bundleID”或“test-without-building”代替该证据。probe运行后再多跑一次probe也不能从逻辑上保证下一次seed安装不变。

### 方案B：审核后支持受约束的沙盒重定位（后续草稿修改建议，本次未改）

1. 外部继续固定专用UDID与准确bundleID，并通过本轮`get_app_container`记录变化。允许变化的仅为该专用安装的沙盒根；不允许改设备、账户或将输出写到任意绝对URL。
2. probe从真实`ModelConfiguration(...).url`相对其真实`NSHomeDirectory()`提取组件形式的相对路径，例如记录`defaultStoreRelativePath`，**不预先猜测Library位置**。必须确认config.url位于当前沙盒内，拒绝绝对relative值、空值、`..`组件；必要时对父路径解析符号链接，防止词法前缀掩盖越界。
3. seed在自己的真实宿主进程重新取得`NSHomeDirectory()`和同schema的默认`ModelConfiguration.url`，重新计算相对路径，与probe声明的相对路径严格一致；同时要求bundleID与现有guest owner完全一致。默认config.url是唯一数据库目标，传入的相对路径仅用于**比较**，不据其创建自定义storeURL。
4. 对本次实际默认URL及-wal/-shm重新执行不存在检查，不沿用旧目录的不存在结果。guest缺失/变更、schema或相对路径变化、任一文件已存在均拒绝；不自动恢复旧guest、不setOwnerKey、不删文件。
5. manifest也只允许当前沙盒内经过同样组件/越界检查且尚不存在的预定相对路径；记录最终实际绝对store路径、相对路径、bundleID、guest、此次NSHomeDirectory以及外部RUN/UDID关联。旧绝对expected值只能留作probe历史证据，不能继续伪称最终路径。
6. 主控取得真实生成manifest后再次解析当前App容器；UI准备使用**最终seed实际路径**及原guest，不能仍填旧probe绝对路径。若UI测试调度又重定位，需再核对相对默认路径、guest与数据存续，不能凭UUID变了认定数据清空，也不能忽略数据确实丢失。该观察应作为单独环境事件记录。

这一方案放宽的是操作系统合法移动沙盒根，未放宽“专用设备、指定App、同guest、固定默认库、此前为空、禁止覆盖”的边界。UI runner无法仅靠自己的NSHomeDirectory证明App沙盒；其manifest断言仍依赖主控解析的App容器证据及正常UI真实数据核验。

若后续希望减少两次宿主启动间竞态，可设计一次启动中先执行同等只读前置核验、再在已授权情况下播种的单方法；但不能从一次运行里自行生成期望然后立刻把它当独立授权。外部预先声明的UDID/bundle/guest/默认相对路径与空库条件仍须存在，改变执行方式应有新草稿版本与diff。本次仅补说明，原Swift草稿保持不变。

## 主控执行修订（overlay待注册）

采用上述方案B：probe另报默认相对路径；seed只比较本进程默认ModelConfiguration路径，核对组件、解析符号链接后在真实home内、固定bundle与原guest、store及sidecar均不存在。固定manifest为本App Documents/qd-thousand-manifest.json且不覆盖。保存后新增1000条owner一致、同步队列0断言。OS沙盒根允许重定位，数据库目标不能由外部参数指定。旧绝对路径流程保留作历史准备，实际以本段为准。运行器只允许新增QiuJiDiagnosticMemoryHost scheme且只选unit，额外scheme哈希入每轮inputs。尚未运行。
