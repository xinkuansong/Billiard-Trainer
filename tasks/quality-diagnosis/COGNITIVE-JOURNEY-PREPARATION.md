# 其余五种认知成绩正常旅程准备

2026-09-06。新增 `CognitiveJourneyDiagnosticUITests.swift` 五方法草稿，未复制快照、注册、构建或运行 UI。所有判断基于 snapshot-002 冻结源码和已有 ToolDiagnostic 正常角度旅程。正常练习 Tab→练→卡片入口；独立新启动内存空库先核对无历史，再各提交一次、返回、进入该题型历史详情，核对恰1题/#1且无#2及实际输入值的显示。截图唯一名与 keepAlways；没有真实账号、上传、制作或设备操作。

## 五种输入及独立预期来源

| 方法/题型 | 正常输入与反馈 | 保存/回读预期的源码来源 |
|---|---|---|
| testAngle2DAnswerSaveAndHistory / 2D角度 | 训练设置→开始训练→答题→27→提交，下一题按钮出现后返回 | AimingQuizViewModel.submit（约193–216行）允许0…90，存userAngle=用户输入；类型由设置页2D路径决定。AngleSessionDetailView.questionRow将userAngle显示为整数度数，应读27° |
| testAngle3DAnswerSaveAndHistory / 3D角度 | 相同正常设置流程，输入38；不要求随机题目答对 | 同VM的3D类型路径；38在独立允许范围内；详情应读38°。不复用2D历史满足3D断言 |
| testAimPointDefaultAnswerSaveAndHistory / 瞄准点 | 正常初始姿态不拖动，先核对“当前偏移 0.0 mm”；提交瞄准点，核对“你的偏移 0.0 mm”和下一题 | AimPointTrainingView VM.nextQuestion重置userPhi=0；userOffsetMM几何计算初始0；submit存userAngle=userMM、quizType=aimPoint、errorMM。当前详情实际格式0°仅作为回读表示，单位问题见下文 |
| testAimPoint2DDefaultAnswerSaveAndHistory / 2D瞄准点 | 正常初始瞄准→提交→按钮消失→物理验证自动下一题后提交按钮重现；不第二次提交 | AimPointSceneTrainingView.nextQuestion约118行aimDir=cue→target中心，signedOffset为0；submit约189–247行将sUser×1000存userAngle，quizTypeLabel=aimPoint2D。历史应恰1题，当前格式0° |
| testAimPoint3DDefaultAnswerSaveAndHistory / 3D瞄准点 | 同上正常3D入口，不拖动/注入球形；等物理验证结束再返回 | 同VM、is3D配置约662行置aimPoint3D；空间布局初始中心瞄准同样0偏移。正解取决随机题，不假定0是正确答案 |

`HistoryViewModel.AngleQuizType`（约134–169行）给出五种独立历史名及瞄准点分类；`HistoryCalendarView`认知点击实际打开 `AngleSessionDetailView`。每题均 `Task { await persist(result) }` 自动保存，不存在统一结束确认按钮，因此采用“提交→可观察反馈→返回→历史”真实生命周期，不能虚构“结束保存”UI。只做一次提交，自动下一题本身不应生成第二题成绩。

## 已发现的单位语义问题，不能随测试绿而消失

瞄准点三个VM保存的 actualAngle/userAngle 实际为 **mm偏移**，并另存errorMM；`AngleSessionDetailView.questionRow`（约146–162行）却无题型分支地使用 `%.0f°` 显示实际/你答，`errorBadge`约178行还统一显示 `±%.1f°`。因此草稿的0°断言是**当前存储值在现有页面中的回读证据，绝不是单位语义通过**。本发现尚未执行UI复现，不在此创建正式缺陷编号；主控执行后应对照截图单列问题，不能让五个方法通过覆盖它。没有修改业务或将错误单位称为正确产品规格。

## 限制与待实测

- 这是UI→当前存储→历史路由回读，使用内存库隔离历史；不证明进程重启/磁盘持久化。forcePremium仅让五工具功能可测，不证明购买。
- 正确数值来自输入范围/初始几何/存储字段及详情格式的交叉检查；不猜随机正解、成功率或物理进袋。三种默认零偏移是正常可提交操作，不代表已覆盖拖动瞄准输入。
- 详情无每行/每值独立AX identifier；当前组合“唯一1题、你答、预期数值”查询仍可能在实际值恰好相同的随机题下缺乏单字段归属证据。需要主控保留AX/截图审阅，不能声称穷尽字段映射验证。3D数值浮点可能显示-0°，若出现应先核实真实userAngle而非盲目放宽断言。
- 场景提交按钮在异步物理验证后回归，沿用已审正常操作。若设备过慢超过35秒，保留失败并判别等待预算，不删断言或guard return。
- 当前草稿沿用现有截图helper，没有额外AX文件写盘；XCTest失败附件及主控提取AX用于诊断。按钮文字、导航标题取冻结现有测试与源码，仍需首次编译/运行确认实际AX。
- 尚未覆盖“未答返回不新增”、重复结束/重复提交不重存、保存失败重试、所有有效答案/错误输入；本轮5条不冒充这些后续缺口已完成。
