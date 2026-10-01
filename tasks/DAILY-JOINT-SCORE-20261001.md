# 每日清台联合评分（2026-10-01）

用户确认：舒适切角由60°改为75°，选袋评分 S=(1-θ/90)×(1-d母目标/L)×(1-d目标袋/L)，L=innerLength=2.54m。

距离为SceneKit X/Z球心平面距离；目标到袋距离使用固定袋口中心，切角继续使用候选瞄点及假想球计算。距离因子钳制到[0,1]，不把超长距离当不可选。相同分数按较小切角、袋号、目标键确定排序。

每颗目标优先在≤75°候选中选最高分；仍按母球距离逐颗考虑，发现舒适候选即停止。所有目标都难时按同一评分兜底。传球后的逐个换球复核共用此排序。手动选球/袋可选择难球，参数改变不重新选球袋，物理预测参数及力度不变。几何挡球判定、延长线未在本轮修改。

验证：iPhone17Pro/iOS26.3模拟器，DailyShotRankingTests 17、DailyCombinationRecommendationTests 4、DailyAimSelectionTests 4、DailyPowerReleaseTests 7，共32测试0失败，TEST SUCCEEDED。覆盖评分公式、距离钳制、75°边界、较大切角短路程胜出、舒适候选优先、全难评分兜底、真实距离来源、传球换10号及手动/力度隔离。

证据：build/daily-joint-score-20261001/test.log；results.json和8组case图片、index.html（生产几何输出的静态图，不是App截图或物理进球验证）。真机及用户盘面排序体验待验。未提交发布。

收尾：verify-gate（FAIL 0/WARN 0）、verify-doc-size、git diff --check均通过。测试构建的App已安装并启动iPhone17Pro模拟器；未代用户击球，未验原生触摸排序体验。为维持文档体积门禁，将一条旧头部注释原文移到既有tasks/archive/PROGRESS-头部注释-归档.md。
