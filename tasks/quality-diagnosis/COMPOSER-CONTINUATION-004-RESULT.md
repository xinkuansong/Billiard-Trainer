# 自由走位两杆推进与单级重打结果

2026-09-08 自由走位普通未录制两杆→重打补验1/1通过67.041秒，runner0/recorder0，1457运行文件及6观察文件归档；主控4张完整球形PNG已审。初始母球/1/2，首杆后黄1离台回库，第二杆移动母球/蓝2，单级重打恢复第二杆输入的球ID、中心≤2pt及按钮态。见COMPOSER-CONTINUATION-004-RESULT.md；不覆盖玩法切换、录制多级撤销或物理精度。

唯一selector：ComposerContinuationDiagnosticUITests/testNormalTwoShotsThenSingleUndoRestoresSecondShotInput。新设备89625133-53C9-4CAF-B587-6628568CDAC9/iPhone17Pro/iOS26.2，Light/large配置，工具实际固定深色；正常游客、inMemory/forcePremium仅隔离与访问，无盘面/结果种子，无录制或资产写入。原始run formal-004-composer-continuation-001，xcresult Test-QiuJi-2026.09.08_19-35-05-+0800.xcresult，session32730终态0。

完整图1默认3球；图2首杆后2球，黄球回库亮起、自动选蓝2；图3第二杆后仍2球、两球位置改变；图4恢复与图2一致，包括预测路径及右中袋标记。图2的“未进袋”是当前下一杆预测摘要，源码finishStrike最后recompute，不能将其误解为已结束黄球一杆未进袋。当前有限图审未新增问题。

AX外层黄1在离台后变为大区域框，脚本将非球尺寸框排除；仅AX全局exists不证明球仍在台，已结合完整PNG。母球重打前后中心差约0pt（球框尺寸受球杆展示影响），蓝2中心完全相同。2pt仅屏幕重复性，未验证世界米制/独立物理金样。未录制只缓存最近一杆，不要求再退回第一杆。

运行/源/xcresult在archive/quality-diagnosis/runs/formal-004-composer-continuation-001；连续视频及PID/RSS在archive/quality-diagnosis/observations/formal-004-composer-continuation-001。视频已保留，本轮没有逐帧运动分析或FPS结论；四张完整终态图审的SHA记录composer-continuation001-review.json。5350冻结业务输入19:36:13复核改变0/缺失0，source-recheck-composer001.json。

SC21保持partial：这条有限两杆推进/最近一杆恢复已验证。玩法开球选择与交付、录制相关原约定项仍按原覆盖表，不由此通过替代。思路实打、真正空解、每日正常终局、查看器及Release运行仍另列。
