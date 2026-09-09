# 恢复时的版本漂移与证据适用范围

2026-09-07，QA Reviewer 只读审查。用户已明确恢复诊断。本报告只比较当前工作区与 snapshot-002，不执行测试、不修改业务或冻结快照，不代替主控的运行验收。

## 当前观测

主控 `build/quality-diagnosis/resume-20260907/baseline-observation.json` 在 02:27:00 +08:00 核对原始 4841 个路径：冻结快照只存在既有独立 Quality 测试和工程注册两项差异；当前工作区相对原基线有 78 个对应路径不同，HEAD 为 `0c316e4f577ef393916066bf5e7ae6685b1cc918`。其中 54 个 App Swift 源码和 1 个扩展 Swift 源码已变。78 是对应路径差异数，包含测试/生成配置，不是产品缺陷数。

本次另有界枚举当前 `QiuJi`、`QiuJiLiveActivity` 和 `backend/src` 下的 Swift/JS 文件，发现原基线以外两个 App 文件：`BTBlueprintBackground.swift`、`BTNumberedNoteEditor.swift`。因此仅比较原 4841 路径不等于完整当前文件清单。没有打开 Secrets 内容、输出配置值或连接任何外部服务；这是非原子观测，后续并行修改仍可能发生。

## 旧问题仍有直接源码依据

| 问题 | 本次直接核对 | 当前可以说什么 |
|---|---|---|
| QD007 数据归属 | `backend/src/routes/trainingSession.js`、`backend/src/models/TrainingSession.js` 与 snapshot 字节相同；PUT 行 86–88 仍按现 owner 查询后将原始 req.body 交给更新。 | 冻结真实 Mongo 的复现证据与当前相同路由/模型相容，未见修复。不声称已检查线上部署或当前 App 会构造该请求。 |
| QD008 500 条恢复截断 | 两后端路由字节相同，GET 仍 limit(500)；`BackendSyncService.swift` 相同。当前 `SyncRestoreService.swift` 行 155–158/203–206 仍每类只取一次，之后推进最大 updatedAt 锚点。 | 新增 shouldContinue 取消检查不构成分页修复。同步明确开启后仍有原算法缺口的静态依据；当前新增同步选择会改变何时触发，须按新前提复验客户端，不能套用旧“登录即拉取”场景。 |
| QD012 未操作组保存 | 当前 VM 行 1146–1161 仍遍历全部 setData 建 DrillSet；`DrillSet.swift` 未变；历史行 357 仍无条件 checkmark，历史 diff 仅底栏浮层避让。 | 没有发现修复该保存/展示根因的变更。相同 VM 的完成推进、输入键盘、退出判断已变，当前 UI 复现步骤必须重审；旧截图不能代表现版训练页。 |
| QD019 大字体搜索图标 | `BTLibrarySearchBar.swift` 和 `Typography.swift` 与冻结版本字节相同。 | 共享组件未见直接修复，旧缺陷不销账。页面布局/背景已有改变，当前可见裁切仍需最大字号图审确认，不把源码相同称为现版视觉通过或失败。 |
| QD020 音效资源 | 当前和冻结 `QiuJi` 全目录支持格式 caf/wav/m4a/mp3/aiff 各为 0 文件；`ShotSoundBank.swift` 相同。 | 当前源码资源缺口仍适用。新构建实际包尚未本轮检查，也没有声音实听；首发范围仍待裁定。 |

## 可能被其他开发改变，必须重新取证

**QD021 Release 地址**：配置文件未出现在主控对应路径变化清单，`AppConfig.swift` 也字节相同；但工程注册和生成配置已变。本轮不读取 Secrets，不推定变量展开结果。旧 Release 包为空地址的证据仅归冻结产物，不能直接报告为当前 Release 产物结果，也不能因新提交自动销账。新基线需独立 Release 构建后，仅输出 URL 是否为空、是否绝对、是否有 scheme/host 的白名单审计结果。

实际审阅主要差异：

- **云同步产品预期已改变**：契约 §2.5 新增 ADR-P2-20260906，训练云同步须用户明确开启、按本机账号存偏好，未知/关闭不上传下载，游客归并另行确认。`AuthState`、`AccountDataCoordinator`、`SyncQueueManager`、`SyncRestoreService` 加入选择状态、revision 与中止保护；拒绝游客归并由只拉取改为账号 pushThenPull。旧 B4 测试不覆盖这些新行为，必须重新从现行契约定期望，不能仅调整断言让老 fixture 通过。
- **权益生命周期改变**：`SubscriptionManager` 绑定 AuthPhase，切换账号清权益，游客购买/恢复增加登录前置，异步权益结果按 sessionRevision 防过期写回。旧本地 StoreKit 底层产品交易证据仍可保留，但不等于当前 App 权益/登录门控验证；forced Premium fixture 也有新条件。
- **训练关键操作改变**：`ActiveTrainingViewModel` 完成最后一组即切下一动作；新增 hasStartedTraining 区分尚未开始退出，心得编辑不再直接结束训练。`ActiveTrainingView` 按键盘/备注状态隐藏底栏与休息浮层、增加滑动回总览。`BTSetInputGrid` 从 SwiftUI TextField 改为 UITextField + 自定义数字键盘，收起动作调用 onComplete。原训练/历史保存、错误输入、取消、中断继续、组间休息和最大字号测试需按当前真实入口重验。
- **跨页浮层及球库布局改变**：共享浮层障碍避让、休息 pill、球库宽度及多个消费者变化，旧小屏/iPad图审和命中区证据只证明旧快照。至少现版小屏/大字号训练输入与浮层、iPad工具球库做定向复验。
- **学习/工具/内容页面改变**：DrillDetail/List、AngleHome、多种工具页、CameraRig、AngleSceneCalculator/AngleTrainingScene 等有变化；不能将尚未执行的旧工具/多球形详情配置不经检查直接迁移。此报告没有完整审查新相机或角度算法正确性。

## 未查范围与建议

本轮没有完整审查全部 78 项 diff、新文件内部实现、所有新测试有效性、外部部署、实际 Release 包、实时 UI 或真机。业务变更数量不代表其质量差，也没有要求回滚并行工作。

**建议为当前版本建立 snapshot-003，保留 snapshot-002 全部证据，并停止继续扩大旧版测试。** 理由不是日期过去一天，而是训练录入/保存入口、同步选择契约、权益生命周期和共享布局均有实质变化；继续在旧版运行尚未完成的大批 UI 测试，会增加只能证明历史版本的工作量。

迁移时：

1. 新快照冻结当前完整源/资源/有效契约，记录当前提交、dirty 状态及源指纹；独立诊断 overlay 单列，生成工程配置两端审计。不得把其他开发改动复制进已有 snapshot-002。
2. 旧证据分三类：相同根因/依赖的静态及后端证据可引用；变化相关 UI/账户交互需新跑；尚未执行草稿仍为未验证。问题编号保持，不因换版本重复计数。
3. 优先现版数据可靠性：QD012 一组非零提前结束并磁盘重启、DATA1 独立跨页面账本、千条磁盘历史；同步补明确关闭/开启、关闭期间异步请求返回、账号切换与游客归并选择；这些要与 QD008 后端分页缺口分开记录。
4. 再做受变更影响的训练输入/备注/浮层、权益门控、小屏最大字号与 iPad 工具的有限矩阵；学习、工具边界与性能选择器按现版入口审查后继续。不要全量重复已经无依赖变化的内容资产抽样。
5. 新 Release 包白名单配置/资源检查，再形成带版本与证据边界的最终诊断报告。旧“约三分之二、还需3–5小时”为先前范围估算，不应当作当前已冻结承诺；主控据新基线实际批次重新估算。
