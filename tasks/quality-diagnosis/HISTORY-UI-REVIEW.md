# SC12 历史编辑与删除 UI 草稿

2026-09-05：仅准备，未编译、未运行、未改 snapshot 或业务文件。主控独立审核与执行。修改范围：`QualityDiagnosticUITests.swift` 与本文件。

## selector 与步骤

`QiuJiUITests/QualityDiagnosticUITests/testHistoryEditCancelSaveRejectAndDeleteOwnSample`

1. 复用本轮已经运行过的正常创建过程：自由训练→中袋直线出杆→单项视图→完成首组→输入本次唯一 `QD-<UUID前8位>` 本项心得→正常保存→杀进程重开→记录详情。必须核对本次心得后才能开始编辑。
2. 编辑器读取首组 made/target/duration 的原始值；改成7/9、150秒→取消→重开编辑器，逐字段等于原值。
3. 同样修改→保存→详情7/9→杀进程重开同一标记样本→编辑器仍是7/9、150秒。
4. made改99→行内错误「进球数不能大于总数」→保存弹「无法保存」→确定后编辑器仍开且保留99→取消→重开确认持久值仍是7/9。
5. 当前详情再次核对本次唯一心得→更多操作→删除→标题「删除这条训练记录？」→取消，原详情/心得仍在。
6. 再次核对本次唯一心得→删除确认→编辑数据入口消失、无操作失败、回记录→杀进程重开。若仍有同名记录，打开最新剩余条目确认不是刚删除的心得；若无条目必须是记录空态。

## 原方法保留与数据保护

- `testNormalFreeTrainingPersistsAfterProcessRestart` 仅改为调用 `createNormalTrainingAndReopen()`。原主体的操作、前提、断言均保留；默认截图名也保持不变。抽取 helper 最后返回原有唯一 marker。
- 新方法传入独立 `history-<完整UUID>-` 截图前缀，避免与旧方法证据同名覆盖。已有 capture 输出仍由 `QD_SHOT_DIR` / `TEST_RUNNER_QD_SHOT_DIR` 决定，没有硬编码工作区写盘。
- 新方法创建自己的样本，不使用已有记录作编辑/删除目标；列表最新条目只用于寻找候选，进入后必须用精确等于本次 marker 的 AX note 做 throwing `XCTUnwrap` 身份检查，再允许编辑或打开删除确认。
- `QD-3A760F98` 是现有 QD-012 证据样本，显式排除作本测试目标。不清空 App、不删除其它记录、不执行 blanket cleanup。若中途失败，新建样本保留供诊断，不用 teardown 删除。
- 本测试使用真实本地磁盘；仅可在诊断专用模拟器执行。`launchClean` 不清理磁盘或全部 UserDefaults，须由主控确保设备/账户隔离。
- 首组 made 继续遵循既有 `QD_FIRST_MADE` / `TEST_RUNNER_QD_FIRST_MADE` 入口；无此变量也读取真实初值，不硬编码初始0或5。

## 依据与未验证点

- snapshot-002 `TrainingDataEditorView.swift` 明确 `dataEditorSave`/`dataEditorCancel`、`editSetMade_1`/`editSetTarget_1`/`editSetDuration_1`/`editSetError_1`；非法提交弹「无法保存」，编辑草稿取消不应用。
- `TrainingDetailView.swift` 底部「编辑数据」与「更多操作」→删除确认；`BTOverflowMenu.swift` 给菜单「更多操作」AX label。
- 数字输入参考旧V29W2b的真实字段右端落光标方法，但未复用其过时“自由记录”入口、guard-return或固定截图写盘。新方法每次替换后严格比较字段实际value，不按数字过滤掩盖残留字符。
- 本项心得是单独Text，草稿要求AX精确label匹配marker；如果系统把它与标题合并，测试应失败并先取证调整定位，不可放松身份要求后直接删除。
- iOS确认框的按钮/静态标题与菜单AX、sheet遮挡键盘状态仍需真实运行确认。失败先保留截图与AX，不能把脚本前提失败计为业务缺陷。
- 删除后仅验证页面退出和重启后最新同名记录不是目标。这不能严格证明数据库没有残留、关联行全部删除、同步墓碑正确，亦不能独立证明QD-012所有字段未变化。建议主控以本次唯一marker+实际sessionID做前后只读SQLite核对，并确认QD-3A760F98仍在；不要将这一步省略后宣称全量删除一致性通过。
- 本草稿不覆盖多球形切换、多Entry同组号歧义、负数/空值/小数/溢出、保存真实I/O失败、云同步恢复等，SC12仍需结合单测与存储证据汇总结论。

## 静态检查

只做文本/格式检查；没有宣称编译通过或测试通过。主控复制新诊断文件至snapshot测试目标时应记录叠加层指纹，业务指纹保持原基线。
