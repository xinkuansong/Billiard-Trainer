# UR-20261103 · 两页开球设置即时应用

范围：打一走二想三P05、正式分离角与走位composer。局部复核TP19/20、25/26、14/28、30、35；完整适配沿原页面卡。用户要求选玩法立即更换球形、移除两页取消开球。

## 原生验证
Mac mini队列break-settings-live-r2-20261103，iPhone 17 Pro / iOS 26.2。UnifiedBreakFlowUITests实际执行5项全部通过：P05、composer各2D/3D，以及每日清台菜单名称。各页面先由普通态设置选4球，再连续9/15/6/5/4切换，确认即时准备、菜单选择与runner玩法一致；随后重开、实际开球并等待停稳自动返回。测试显式进入2D/3D。

共保存34张原生PNG及对应AX附件；已目视16张关键图（四种页面/视角各设置切换、无取消项、准备态、完成态）。设置选4球与场上4球球架一致；两页取消开球条目消失；开球后自然停稳，恢复普通操作。合图仅供快速审阅，原始证据未修改。

证据：`output/break-settings-live-20261103/r2/evidence/tests.xcresult`；图像与原附件清单在`r2-images/`；review-1至4.jpg为审阅合图。P05 2D切换现场原图`5C170CFA-79FA-47CB-8E32-2321F89D1600.png`。

## 边界
本轮没有布局尺寸变化，仅标准手机定向复核，不重复SE/iPad矩阵；真机、VoiceOver、全App回归未验。r2同时运行的composer单元因初始计算未就绪失败，UI通过不能覆盖该失败；r4两项单元均通过，0失败/跳过。补验结论见[执行卡](../table-page-adaptation/BREAK-SETTINGS-LIVE-20261103.md)。
