# 每日清台手动选袋与推荐隔离（2026-10-01）

用户确认分析方案，并明确“不要动求解球”（本轮按不修改求解器理解）。

根因：selectPocket以isStraightPocketAvailable作为准入，后者复用dailyPocketCandidate推荐候选，返回nil就拒绝用户选择且未调用求解器。selectBestPocket无几何候选时又调用临时自由模式，替换进袋意图。

生产变更仅PositionPlayViewModel：每日手动选袋跳过推荐几何准入；选袋后按原路径recompute/currentShotIntent/PositionPlayShotSolver.solve运行。推荐无候选时保留原袋，初始未选袋则用最近袋心，不强制切换自由模式。显式自由模式与其他页面原有几何准入/自由回退保留。

75°和乘积评分、自动传球复核不变；ShotPredictor、PositionPlayShotSolver、物理引擎、力度与旋转求解算法本轮未修改。求解器自己的prepareAim提前退出仍存在，本轮不宣称解决其内部全部误拒绝。

验证覆盖：几何不推荐袋口仍提交手动意图并得到真实求解结果，同一盘面/参数独立调用原求解器的feasible、原因和进袋结果相同；参数变化/手动所有权保持；几何全部堵塞目标仍保留进袋模式；既有四角64组贴库物理进袋与手动贴库成功进入求解回归；非每日的拒绝选袋与自由模式回退保留。测试结果及日志待本轮完成后补充。未验用户当前具体盘面及真机，未提交发布。

测试夹具返工：首轮33测中3断言失败，首次几何拒绝袋是背向袋，页面现有翻袋备选成功，但测试错误地只对比独立直击结果。保留test.log；修正夹具为明确被9号挡住的P1，新增无翻袋目录断言，仍完整对拍原直击求解。生产求解/翻袋路径未改。

最终结果：test-r2.log，33项0失败（DailyShotRanking18、DailyCombination4、DailyAimSelection4、DailyPowerRelease7），TEST SUCCEEDED，包含真实异步手选与独立求解对拍。verify-doc-size-r2与git diff --check通过。verify-gate未通过：工作区无关新增QiuJiTests/ShotAudioTests.swift未登记写盘面（extra），本轮未修改该文件或其登记。

测试构建已安装并启动iPhone17Pro模拟器，未代用户击球；原生触摸及用户当前盘面未验。

收尾体积门禁再次超限，已将另一条旧头部注释原文移入既有头部归档，保留全部历史，重新检查见doc-size-final-r2.log。
