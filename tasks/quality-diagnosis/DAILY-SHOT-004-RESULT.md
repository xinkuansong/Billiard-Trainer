# 每日清台实际击球与失败恢复 — snapshot004

## 预先范围与保护

原SC23正常未完成分支，复用daily-normal001专用磁盘游客9A9EBD8F-2D89-4E98-A035-B71752FAB8D3，未重置种子/玩法/草稿。运行前实际plist仅提取dailyClearance.activeDraft.v1到archive/quality-diagnosis/observations/daily-shot001-before/activeDraft.json；仍seed8016700117247144671、phase playing、14球0杆0犯规。旧原PNG/AX已主控完整查看，8号球框(89.9,225.6,11.1,11.1)、左上袋(71.6,201)；测试先核实际球框与HUD一致才操作。屏幕402×874点；不据屏幕位置预报物理必进，不修改球位或使用fixture。

候选：正常选8球/左上袋并击球。只有实际出现dailyClearance.rerack才继续失败链；若候选未进袋则保留真实终态与失败断言，不把它判成产品不支持失败。随后失败返回/再入HUD一致，重新开球确认→取消保持，再确认放弃并正常自动开球，预期新局0杆0犯规可玩。允许专用测试局正常重开，原草稿已保留；没有已完成当日记录，因此不宣称完成标记保留。

formal-004-daily-shot-001运行中，连续录像/PID采样已启；待终态和实际图审，不计完成/失败。

001终态1失败23.402秒，1179文件归档，runner2/recorder0。执行尚未点球，_8通用subscript命中paletteBall__8的label，框中心47而台面球95.45。完整当次PNG与AX已主控核对：台面_8框仍(89.9,225.6,11.1,11.1)、HUD14球0杆0犯。这是测试选择器歧义，非产品缺陷。002仅改matching(identifier: "_8")精确ID，位置和全部业务断言不变；无重置或换种子。

002终态1失败20.804秒，仍未击球；matching(identifier:)便利查询同样命中palette的label。003从当前实际debugDescription准确identifier提取SceneKit台面框，再保留原中心±1点和小球宽<20断言后点击当前框中心。不改期望值，不移球/重开；原失败已归档。

003实际1失败35.305秒，1185文件归档。已正确点台面8，但未击球：当次AX明确“按当前规则不能打 8 号球”，FreePlayView.handleTargetTap在pocket模式按daily legalTargetKeys拦截非法目标。主控完整PNG和原AX已审。这是实际正常规则保护，不是产品击球失败；原提前8失败分支仍未达。新独立daily-legal-shot001选择当前黄1球(约310.2,371.1)与右中袋(333,454)，实际一杆后核计数/正常重入和重开取消，保留原测试，不把新合法旅程替代未达失败终态。

每日清台补证（2026-09-08）：legal-shot001实际击球后14球/1杆/0犯规，退出重入保持，录像运动帧已审；方法1失败61.717秒发生在不存在的取消按钮，1217文件归档。rerack001弹层外关闭保持1杆，再明确确认后实际新摆架；方法1失败99.647秒源于错误等待自动开球，实际PNG/AX是待手动开球，与DailyClearanceController.resetAndBeginManualRack一致。1281文件及连续录像归档，终态磁盘seed10241297249008912792/phase manualRacked/0杆0犯规，原1杆草稿单独保留。二者不是新增产品缺陷，SC23仍partial，正常失败/胜利/完成标记仍未验。独立manual-break001继续从该真实磁盘新摆架点击开球，尚待终态。详DAILY-SHOT-004-RESULT.md。

manual-break001终态1失败84.376秒，1139文件归档，runner2/recorder0。实际开球已散开，终态完整PNG/AX已审，底部是“完成”；FreePlayView文件首部与PositionPlayViewModel:1972明确手动开球停稳后须点击完成交付。测试漏该步骤，不能把HUD等待超时报成产品失败，也不能称手动重开完整通过。下一步先完整核对BreakFlowRunner及现有X3测试的正常交付流程，再独立补开球→完成→HUD；原失败保留，不改生产代码。

manual-break002终态1失败31.475秒，1125文件/observer已归档；未进入清台，日志通用switchTab点击训练但完整终态PNG与AX仍我的Selected。原辅助函数仅查同名hittable不核selected。003仅把本条入口改为真实tabBars训练按钮，并严格selected谓词前置；原HUD/球数/重入断言及原失败均保留，不改业务或全局辅助函数。运行session54566。

manual-break003终态1失败43.116秒，1137文件与observer归档，runner2/recorder0。训练标签selected断言已过；实际点击dailyClearance后未进入，终态完整PNG/AX仍首页且继续清台按钮在(263.7,144,110.3,44)。未击球，不能判手动交付失败。停止继续相同UI重试，交互未响应原因未定；宿主未见锁屏标志、无并行xcodebuild，CUA只读Simulator当前为另一专用ContentBundle窗口，不据此推断唯一根因。原实际散球/待完成证据与manualRacked磁盘保留，完整交付缺口不关闭。转包7注入日历两方法补验，PHOTO准备并行只读进行。
