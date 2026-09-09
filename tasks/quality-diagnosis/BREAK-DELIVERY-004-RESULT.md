# 普通九球开球交付诊断

2026-09-08；snapshot004，SC21/L4。正常游客→练习→打→自由击球→开球玩法9球→真实开球→手动完成已取得当前证据。只诊断，未改业务。

## 原始执行与整方法状态

| Run | 真实结果 | 含义 |
|---|---|---|
| formal-004-break-mode-observation-001 | 失败24.283秒，runner2/recorder0；1405运行文件及6观察文件 | 未进自由击球；脚本错把左侧打按钮当内容上边界，又错误要求全页唯一ScrollView。完整PNG/AX显示卡片实际完整可见，定位失配。 |
| formal-004-break-mode-observation-002 | 通过30.516秒，runner0/recorder0；82运行文件及6观察文件 | 修正为唯一含自由击球卡的内容列，正常进入并打开玩法。主控终态PNG确认完整面板及9球按钮；点击后第一PNG为动画过渡帧，后续终态图补足。 |
| formal-004-break-delivery-001 | **失败70.967秒**，runner2/recorder0；1415运行文件，加6观察文件及3独立复核文件，共1424文件 | 正常选9球、摆架、实际开球、停稳、完成与返回普通宿主已发生；后续脚本等待击球按钮enabled超时。内联JSON比较及返回练习没有执行，不能写整方法通过。 |

设备9DC47676-D81A-4F3D-AF31-352180B69344，专用iPhone17Pro/iOS26.2；中文、onboarding完成、内存库、跟随系统外观参数，无账号/权益/盘面fixture。复用同一专用游客设备，各方法独立App进程，无真实用户磁盘重置。

## 独立验收已发生的交付

归档 `archive/quality-diagnosis/runs/formal-004-break-delivery-001/`；xcresult为 `Test-QiuJi-2026.09.08_20-23-07-+0800.xcresult`。t36.70点击break.strike，t50.58点击break.confirm，终态普通HUD为“对局开始：玩家A先击球”，break.entry恢复、完成消失。

主控检查球架、停稳、完成后3张完整PNG，及连续录像49–64秒的每秒采样联系表，确认实际母球运动、球堆散开、逐渐停稳与手动完成态。录像原件保留；不是逐帧物理准确性鉴定。

另从三阶段完整AX独立解析同级最外层语义球根（缩进42，与tableVisual同级），不采用隐藏球的小mesh或paletteBall标签：

- 球架：cueBall及_1至_9，共10个真实在桌根。
- 停稳：cueBall、_1、_2、_4、_5、_6、_7、_8、_9，共9个；_3离台。此处确认离台，不从1fps联系表断言其精确入袋路径。
- 完成后：同一9个ID，8个目标球AX中心差均0；母球中心差−0.05/−0.1pt，符合重新朝向带来的包围框轻微差异。stage/table框完全相同。

数值原件 `observations/independent-delivery-comparison.json`，主控复核 `root-review.json`，动作联系表 `break-delivery-motion-sheet.jpg`。这是运行后独立比较成立，**不冒充未执行到的XCTest断言**。核心球形交付缺口因此获得直接证据；原SC21总体仍partial。

## 失败与尚未验证

失败点是无条件要求交付后“击球”立刻可用。实际按钮disabled，画面为90°极薄球且无预测轨迹。生产FreePlayView.swift:620–621要求 `!isPlaying && !isComputing && isFeasible`；PositionPlayViewModel.swift:934从预测结果赋isFeasible。因此完成交付不保证当前默认瞄准可击，预飞中此额外前提未成立。没有据此新增产品bug，也没有删除原失败断言或换随机盘重试到绿。此源依据解释前提不足，不等于已测完调整瞄准后的后续击球。

本轮未执行完成后正常返回练习，也未测试本局后续整场规则、每日清台终态、其它玩法/其它宿主、所有seed或真实球桌精度。已补齐的核心玩法→实际开球→球形交付不再重复；剩余边界保留在最终38场景报告。

下一步处理Release优化包普通运行、每日清台有限终态与最终证据整理；详FINAL-DELIVERY-GAPS-004.md（其开球“未交付”历史判断由本文更新）。
