# 训练页分段图标局部审查

日期：2026-09-09。当前执行者承担 SwiftUI Developer / UI Reviewer。

- 变更：TrainingHomeView 的 BTSegmentedTab 调用新增一项 systemImage 参数，官方计划 BTIcon.emptyDoc（doc.text），我的模版 BTIcon.editPad（square.and.pencil）。沿用共享字号、选中颜色和4pt间距，无组件API变更。
- 构建：make -f scripts/Makefile build SIM_DEVICE=QiuJi-Onboarding-Pro-SE，exit0 / BUILD SUCCEEDED（xcpretty缺失后Makefile回退原始输出）。日志 output/training-tab-icons/build.log。
- 功能：标准iPhone/iOS26.2 实际官方计划→我的模版切换成功，选中语义及空态正确；无新增数据逻辑测试。
- 视觉：已目视完整 after-official.png / after-custom.png / after-dark.png，四字标题与前置图标完整对齐，浅深选中颜色正确。标准设备large字号，最终恢复light。
- 基线：before-se.png（默认字号浅色），改后为标准手机，因此不作像素级跨设备比较。原模拟器在其他操作中关闭，未继续干扰；最终小屏/iPad/真机及完整VoiceOver未验证。
- 证据目录：output/training-tab-icons/。仅本次一行图标配置属于本任务，保留TrainingHomeView原有并行修改；未提交。
