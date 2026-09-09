# 诊断证据可用性复核

2026-09-07 11:28（Asia/Shanghai）只读观测。**核查时仓库 `/Users/song/projects/13.billiard_trainer/build` 不存在。** 这不是“历史测试没有执行”，而是先前报告引用的多数原始证据目前无法在原路径重新核验。本报告不推测由谁、何时或通过什么操作移除，也不将历史测试改成未执行。主控另行确认磁盘已恢复约 151 GiB；本次只核对证据路径，不测量容量、不执行测试。

范围：`tasks/quality-diagnosis` 文档/草稿及文档已经明确给出的三个 `/private/tmp` 路径。有界读取，没有全盘搜索、访问账号目录、启动数据库或操作模拟器。本报告只新增自身，不修改主报告或台账。

## 当前不可用的原始证据

原 `build/quality-diagnosis` 整棵路径不可用，因此下列不是逐个重新读取结果后得出的结论，而是其父目录不存在导致原路径不可达：

| 范围 | 目前不能重读的材料 | 历史记录仍在哪里 |
|---|---|---|
| 正式基线与恢复基线 | snapshot-002/003、B0 formal-baseline/copy-verification、resume-20260907 的输入指纹/复制前后核对/容器链/overlay diff，原始运行选择器与配置 | B0-B1、EXECUTIONS、RESUME-DRIFT、README 等 Markdown 的版本/核对记录 |
| 原正式训练/历史/工具/设备批次 | formal-b1/b2/b3/b5 等 run 的 make/xcode 日志、inputs/exit、xcresult、截图与 AX manifest | B2/B3/B5、视觉复核及具体 RESULT 文档、ISSUES |
| 当前 QD012 模型与正常 UI | formal-resume-partial-save-002、current-journey-probe/ui-001/ui-002 的真实执行日志、结果包、7+1+2 图像及 AX/视频 | CURRENT-PARTIAL-RESULT、CURRENT-JOURNEY-RESULT、CURRENT-JOURNEY-VISUAL-REVIEW；测试草稿仍在 |
| 当前千条/跨页面账本 | formal-resume-thousand-*、formal-resume-data1-* 的 probe/seed/UI 原始结果、磁盘 manifest 与容器链、截图、日志 | THOUSAND-RESUME-RESULT/REVIEW/OBSERVATIONS、DATA1-20260907-RESULT |
| 当前同步/通知 | formal-resume-current-sync-* 和 notification-allow-probe-001/002 日志/输入/退出码、environment-failure、cache-cleanup | CURRENT-SYNC-RESULT/SELECTORS、CURRENT-NOTIFICATION-RESULT/PREPARATION |
| 真实 Mongo 与隔离路由 | formal-b4-real-mongo-001 的 inputs/command/node-test/exit/shutdown-evidence、runtime manifest；formal-b4-routes 结果及脚本指纹 | REAL-MONGO-RESULT、B4、ISSUES；另有下节部分临时原材料 |
| Release 包审计 | 原 Release 产品、package-audit、构建日志和精确产物配置/资源结果 | B5、ISSUES、暂停记录、主报告草稿及 RELEASE-REVIEW 准备文档 |

其中 xcresult 原来位于 build 下各 DerivedData/Logs/Test，因此不是“日志在 run 目录丢失但结果包默认仍存在”的情形。截图原来采用 xcresult attachments 的批次也不能因 Markdown 列了 PNG 文件名就当图仍可打开。

本次扫描现有 Markdown 的本地链接：70 次链接引用中有 25 次目标不可达，均指向原 build 路径（主要在 B0-B1、EXECUTIONS 和 PARTIAL-TRAINING-FINDING）。这是**显式 Markdown 链接**的计数，不包括大量普通文本写出的证据路径，不是全部缺失证据数量。主报告到其他 Markdown 的链接仍存在，但“能打开报告”不等于“能打开报告的原始证据”。

另外 `tasks/quality-diagnosis/RELEASE-RESULT.md` 本次未找到；不能据此断定它曾存在后被删除。其结论在 ISSUES/B5 等文字中有记录，具体原始包审计现在同样不可重核。

## 仍保留的材料

`tasks/quality-diagnosis` 当前有 119 个直接文件，包含 25 份 Swift 诊断测试源码和 1 份 Python runner。方案、38 场景覆盖、问题台账、执行记录、当前主报告草稿以及本轮关键 RESULT/视觉审查文档仍存在。

- **记录层**：PLAN-v2、COVERAGE-PLAN、COVERAGE-STATUS、EXPECTATIONS、ISSUES、EXECUTIONS、PAUSE-SUMMARY，以及 CURRENT-PARTIAL/JOURNEY/SYNC/NOTIFICATION、THOUSAND、DATA1、REAL-MONGO 等观察结果。它们保留历史执行内容、数值、方法限制和审阅说明。
- **可复用方法层**：CurrentPartialSaveDiagnosticTests、CurrentTrainingJourneyUITests、QualityDiagnosticUITests、ThousandStoreProbe/Fixture/UI、Data1September7Fixture/UI、NotificationPending、SystemBoundary 等源码，以及各 PREPARATION/SELECTORS 文档。源码保存下来并不证明其 SHA 与每次历史已执行版本完全相同，因为 run inputs 已不可取。
- **计划层**：未运行的学习/认知/通知/性能等草稿仍可重新审查适配新快照；不需要为了恢复而重新发明整套诊断系统。

### 明确查到的临时原材料

仅检查报告中已知的路径，实际存在：

| 路径 | 本次确认 | 不据此推断 |
|---|---|---|
| `/private/tmp/qiuji-v50/quality-b5/formal-b5-m3-light-theory/shots/12j-theory-t07.png` | PNG 存在，381393 字节 | 本次没有重新目视图审，缺少原 manifest/hash 时不宣称再次验证历史输入指纹 |
| `/private/tmp/qiuji-v50/quality-b5/formal-b5-m3-ax5-theory/shots/12j-theory-t07.png` | PNG 存在，381411 字节 | 不把单图当整组 AX5 通过 |
| `/private/tmp/qiuji-v50/quality-b5/formal-b5-m3-rotation/shots/00-portrait-only-after-landscape-request.png` | PNG 存在，920453 字节 | 不把旋转后画面当完整旋转交互验收 |
| `/private/tmp/qd-mongo-real-fiIKkm/` | `mongod.log`（49915 字节）及 `db` 目录存在；日志可读，含 shutdown complete 文本 | 未打开数据库、未重新启动服务，不能由此复建 node:test 的全部断言结果或证明当前进程状态 |
| `/private/tmp/qd-formal-routes-tod9u1dk/` | `src`、`node_modules`、`package-lock.json` 存在 | 未复验内容指纹，不可直接当 snapshot-002 真源或重新连接现有服务运行 |

没有检查用户设备内部数据或其他临时目录，所以此处不是全机证据存量清单。设备是否仍有训练样本、其他任务是否有副本应由主控在明确范围内另核，不应臆测都已丢失或都能恢复。

## 如何表述既有结果

正确表述示例：

> 历史诊断记录显示 snapshot-003 的正常训练输入和心得磁盘重启读回已有实测，并有独立视觉复核记录；2026-09-07 11:28 再核查时原 build 证据路径已不可用，当前无法重新打开对应日志/结果包/图片。

不能改成“当时未测”，也不能继续说“原始附件现可追溯打开”。QD007/008/012/022 的历史发现继续保留，可信度来源须明确为已保存的历史结果记录；对于需要当前重新决策的关键点，用新快照、新运行号取证，不能根据旧 Markdown 手工生成一份仿真的 exit.json、输入 manifest 或截图。

## 恢复优先级

1. **先记录新的基线边界。** snapshot-004 应从主控选定的当前工作区独立冻结，重新记录 source/config/dirty 输入；不能叫它 snapshot-003 的原样恢复。保留此可用性说明，与旧报告并列，不回写“旧原始证据仍保留”。
2. **优先继续原来未执行的通知范围。** 重新核验专用设备当前权限，不相信旧 notDetermined 记录自动代表今天；使用新 run 保存探针、真实允许/拒绝及 pending 结果。无需为继续通知先重跑整套训练、内容或数据库。
3. **关键问题如需用于当前处置，再定向重新取证。** 优先 QD012 模型/正常磁盘关键观察、QD007/008 隔离数据库边界、QD022 独立账本的统计标签和数值。每次明确是新版本复验，不覆盖历史测试失配或声称找回旧结果。
4. **恢复后建立独立的持久证据位置。** 主控可将需要保留的结果摘要、源指纹、退出码和关键图片放在与可清理构建缓存分离的位置，记录其对应原始结果；大体积 DerivedData 与需要长期保留的证据分开管理。此处仅建议，本次没有拷贝或清理。
5. **最终报告同时列两种限制。** 一种是功能尚未测试或只局部验证，另一种是历史已测试但原始材料当前不可重核。这两种不确定性不能合并，也不能靠重新编号隐去。
