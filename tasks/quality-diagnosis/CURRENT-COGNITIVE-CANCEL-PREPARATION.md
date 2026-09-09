# 六种认知训练：未提交退出准备

2026-09-07，snapshot-003，仅独立草稿。修改 `CognitiveJourneyDiagnosticUITests.swift`，保留原五个提交方法及其断言，新增唯一方法：

`QiuJiUITests/CognitiveJourneyDiagnosticUITests/testSixCognitiveEntriesReturnWithoutSubmissionAndLeaveHistoryEmpty`

**未注册、编译、运行；当前磁盘不足，本批禁止构建。** 本文不是六类型通过证据，不提高覆盖等级。

## 真实路径与预期来源

只读核对 `AngleHomeView.swift:195–202` 六卡与 `MainTabView.swift:176–188` 路由：角度预测、2D角度训练、3D角度训练、瞄准点训练、2D瞄准点训练、3D瞄准点训练。沿用正常练习Tab“练”入口，无 deeplink/几何seed。

2D/3D角度训练实际先弹“训练设置”，点击“开始训练”后调用 `AimingQuizViewModel.startTest`，只重置内存题目/分数并出题。注意：设置sheet直接下滑也会自动 startTest，并不是取消；故草稿不把下滑设置当作取消开始。它明确开始题面后不作答退出。

其余四入口 onAppear 只 configure、generateRandomAngle/nextQuestion/setupScene；角度预测正常随机范围1..<90，因此“答题”应可用。瞄准点普通版就绪控件为“提交瞄准点”，场景2D/3D为“提交”。草稿只核这些控件可用，**从不点击答题/提交/下一题**，也不改瞄准。

持久化实际收敛点 `LocalAngleTestRepository.save` 才调用 `CognitiveSessionRecorder.resolveSession` 并存成绩/会话。四类VM（几何、场景角度、普通瞄准点、场景瞄准点）的持久化由 submit 路径触发；本次核对未见入页/退出直接创建认知会话。因此“未提交退出后无历史”有当前实现支持，不能仅凭产品直觉预设。若首次运行产生记录，保留失败与题型，核对是否新增正常语义或真正空会话问题，不删除空态断言喂绿。

## 有界步骤及证据

同一进程、同一空内存库先核游客与空历史；逐个真实入口→设置如需→标题/真实题面操作就绪→截图+AX→正常返回练习卡→截图+AX→历史可见空态→截图+AX。六个类型阶段名带序号和真实标题。最后切我的再回历史复核，**中途不重启、不清库**，避免将错误记录随内存重置而消除。

沿用现有 ready（12秒）、导航（20秒）、空历史（10秒）、最多5次滚动；失败即停。新增证据helper独立写PNG/AX同stem、UUID且不覆盖，另附xcresult keepAlways。共预期20对PNG/AX，磁盘恢复后再运行；父任务正在收口时不生成任何图片。

草稿的返回仍沿用已有 navigationBars.buttons.firstMatch helper，并检查正常“练”分区与对应卡重新可用。实际AX就绪/导航需要首跑证据，若导航结构不匹配应保留失败，不用坐标盲点或弱化标题检查。

## 不能宣称的覆盖

这是受控Premium解锁、真实游客、内存存储的**可见历史边界**；不是正常磁盘冷启动、数据库原始session/AngleTestResult/队列数量为0的证明。空态可见不能排除隐藏孤儿数据，应由独立仓储检查另补；当前没有安全UI读取原始数据库能力，明确保留缺口。

本方法不测试已输入数字未提交、键盘取消草稿清除、提交后中断异步保存、30分钟会话合并、后台/杀进程恢复、真正会员或六类答题准确性。20次截图有存储成本，当前仅完成准备，后续可由主控按磁盘容量选择更细批次；不得以删除题型或取消失败断言假装六类型已测。
