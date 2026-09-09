# 认知未提交返回视觉复核（snapshot004）

日期：2026-09-08。角色：UI Reviewer。只读落盘截图/AX/测试输入与日志，没有操作设备或修改测试。

## 已核实的执行身份

- run：`formal-004-cognitive-cancel-001`；snapshot004；scheme QiuJi；UDID `CB246F30-E917-492B-B0C4-511F473D8C15`。
- `inputs.json` started 2026-09-08T11:06:07.428210+08:00，`exit.json` make_exit 0，finished 11:09:10.772642+08:00。
- `xcode-test.log` 946–952 行：精确方法 `testSixCognitiveEntriesReturnWithoutSubmissionAndLeaveHistoryEmpty` 通过，1 test / 0 failures / 155.951 秒。它是一个方法内六类循环，不是六个独立通过方法。此时间含自动化开销，不是性能指标。
- 已核对实际被测 Swift 源 SHA256 等于输入记录：`7e2b760b8c8339709ac9ab7b3ad3d72eab4117727a33c6b0594dd2450e667e15`。方法使用同一进程的 inMemoryStore、forcePremium、followSystemAppearance；先检查游客登录入口及空历史，再循环六入口，确认题面答题/提交控件可操作且无下一题，完全不点击提交，然后正常返回练习与历史，每轮断言空史，最后经我的再入历史。

## 实际图像复核：7 张 PNG 与同 stem AX

以下每张均经 view_image 实际打开；原图 1206×2622，显示工具缩放为 942×2048。每张同名 `.txt` 中已核对导航标题、HUD、答题/提交动作或历史空态；未用文件名代替看图。六题面为黑底球台，最终历史为浅色，不因 followSystemAppearance 启动参数把所有图统称 Dark。

### cognitive-cancel-1-角度预测-question-unsubmitted-AF71AD1E-F59D-4EE7-8892-530E76664AFD.png

角度预测：白球/目标球、竖直 0° 参考线及绿色角弧可见；HUD 次数 0、正确率 0%、平均 0.0°；底部为换题、显示参考、答题，未出现答题结果卡。

- PNG SHA256：`8eb45e9e0e55867e63f467eb28b8e9c8071fdec9faa6b3c18158742937fc409c`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-1-角度预测-question-unsubmitted-AF71AD1E-F59D-4EE7-8892-530E76664AFD.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-1-角度预测-question-unsubmitted-AF71AD1E-F59D-4EE7-8892-530E76664AFD.txt>)。

### cognitive-cancel-2-2D 角度训练-question-unsubmitted-9BA75F24-716C-4775-9DDF-35366E64A5B8.png

2D 角度训练：俯视完整球桌、白球与红球、右侧中袋标记；HUD 0/20、袋 右侧中袋、差 —；辅助及答题可见，无已提交误差或下一题。

- PNG SHA256：`c6f42f30ab9d48cbd8347bbb5dfefc7b946d51f9137d57b0885885ea49929a29`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-2-2D 角度训练-question-unsubmitted-9BA75F24-716C-4775-9DDF-35366E64A5B8.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-2-2D 角度训练-question-unsubmitted-9BA75F24-716C-4775-9DDF-35366E64A5B8.txt>)。

### cognitive-cancel-3-3D 角度训练-question-unsubmitted-9CB91AB6-5034-4A23-8715-BB52BBACB541.png

3D 角度训练：倾斜透视球桌、白球与目标球、左上角袋标记；HUD 0/20、袋 左上角袋、差 —；辅助及答题可见，无已提交结果。

- PNG SHA256：`8ff5ed85f30c51433b3c4e08f8e2a3921d72a264a80a2f1ee1117df0632055c0`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-3-3D 角度训练-question-unsubmitted-9CB91AB6-5034-4A23-8715-BB52BBACB541.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-3-3D 角度训练-question-unsubmitted-9CB91AB6-5034-4A23-8715-BB52BBACB541.txt>)。

### cognitive-cancel-4-瞄准点训练-question-unsubmitted-CCAD8B3F-F32A-424B-96F3-30A9EC41BCE9.png

瞄准点训练：目标球与绿色虚线假想球；题 0、均差 —；题面写切角 θ = 60° · 向左切、当前偏移 0.0 mm；仍是提交瞄准点按钮，无误差反馈/下一题。

- PNG SHA256：`2231fdb066088808755552b595361bb0baf44f33cc76ee8e7fd0e1899087350d`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-4-瞄准点训练-question-unsubmitted-CCAD8B3F-F32A-424B-96F3-30A9EC41BCE9.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-4-瞄准点训练-question-unsubmitted-CCAD8B3F-F32A-424B-96F3-30A9EC41BCE9.txt>)。

### cognitive-cancel-5-2D 瞄准点训练-question-unsubmitted-BC290982-FF8E-40E9-8A72-CD15947102CE.png

2D 瞄准点训练：俯视球桌、白球/目标球、球杆与瞄准参考线；题 0、均差 —；左侧调节刻度和提交可见；没有提交结果面。

- PNG SHA256：`1e6ae80340c5a894bc2ac616202090ca89269cccfffce20f1d84cd76657842a0`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-5-2D 瞄准点训练-question-unsubmitted-BC290982-FF8E-40E9-8A72-CD15947102CE.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-5-2D 瞄准点训练-question-unsubmitted-BC290982-FF8E-40E9-8A72-CD15947102CE.txt>)。

### cognitive-cancel-6-3D 瞄准点训练-question-unsubmitted-09F9700A-2116-4EEE-B40F-56C905E4A227.png

3D 瞄准点训练：透视球桌、球杆/白球/目标球、瞄准参考线；题 0、均差 —；右侧调节刻度、提交可见，无已提交反馈。

- PNG SHA256：`0975599f552c3b2e1494fe7fb1fe716d5f7f32c50600438dc9efd913f48e5c35`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-6-3D 瞄准点训练-question-unsubmitted-09F9700A-2116-4EEE-B40F-56C905E4A227.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-6-3D 瞄准点训练-question-unsubmitted-09F9700A-2116-4EEE-B40F-56C905E4A227.txt>)。

### cognitive-cancel-all-six-final-history-empty-D698BE3A-F12F-43A2-8FCF-604C7A2BAA5F.png

最终历史：浅色记录页、历史选中，2026 年 9 月，8 日选中；9 月 8 日 星期二下明确显示还没有训练记录和去开始第一次练球吧；五个 Tab 可见，记录选中，未见认知结果行。

- PNG SHA256：`de0cf3642602989ea0c37c95b081344fc25a53675fd0b7f63c986be9852a9c38`
- [截图](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-all-six-final-history-empty-D698BE3A-F12F-43A2-8FCF-604C7A2BAA5F.png>)；[AX](</Users/song/projects/13.billiard_trainer/build/quality-diagnosis/formal-004-cognitive-cancel-001/screenshots/cognitive-cancel-all-six-final-history-empty-D698BE3A-F12F-43A2-8FCF-604C7A2BAA5F.txt>)。

## 审查结论与边界

在这七帧中，题面确实已呈现、初始答题数为零、答题或提交动作仍在，未见已提交反馈；最后选中日期的历史明确为空。这与通过的六入口未提交返回方法一致，本项视觉复核完成。

- 所选图片未见标题/主动作文字截断、弹层遮挡、错误页或会员门控误入。3D 图包含大面积黑色场景背景与透视裁切；此处只确认目标题面存在，不评价完整球桌取景，也不据此推断几何或答案正确性。
- AX 中角度预测的答题约 68×30.7 pt、单图瞄准点提交约 120×30 pt、2D/3D 瞄准点提交约 46×30 / 56×30 pt，小于 44 pt 推荐高度；图中也呈紧凑按钮。记录为触摸目标需补验的观察，未测试框外命中区，不能据 AX frame 单独确认实际热区不合规。返回按钮 AX 44×44 pt。
- 不新增已确诊 P0/P1 视觉问题；没有像素对比度测量或完整 Token 消费审计，不声称全部 HIG/无障碍合格。
- 图像与 UI 空史只证明这个游客、同进程内存库、当前日期的可见边界；**不证明原始 AngleTestResult/TrainingSession/SyncPendingItem 为零**，不证明磁盘重启无幽灵记录。需由独立仓储/持久化证据补充。
- 本次仅看 7 张指定帧；循环内其余返回和中途空史图片未逐张视觉审查。自动化对每轮的断言通过与本次看图数量分别记录。
- 未覆盖提交途中返回、后台强杀、真实网络、真实账号/会员、Light/Dark 切换矩阵、Dynamic Type、VoiceOver 或其它尺寸。

参考：已读 57 规则、swiftui-design-system 技能及 snapshot004 Colors/Typography/Spacing 定义；docs/05 主导航、角度成绩与历史结构仅作背景，其旧 Tab 名不用于否定截图中当前“练习/记录”的命名。本报告按任务限定写入质量诊断目录，公共覆盖/问题台账由主控统一回写。
