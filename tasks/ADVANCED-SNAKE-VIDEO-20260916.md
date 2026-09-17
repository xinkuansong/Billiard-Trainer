# 高级蛇彩15球视频

- 用户要求：动作库高级蛇彩15球清台，每杆击球前瞄准视角，并参考已有视频制作封面。
- 源序列：`content/position_play/sequences/drill_c071__manual02-高级蛇彩贴库综合 · 球形2-15杆.json`。
- 产物目录：`output/advanced-snake-video-20260916/`。
- 专用模拟器：`F0E8AA36-1FDC-405F-B098-D171FA5FCB19`，iOS 26.3，iPhone 17 Pro。
- 逐帧路径：SceneKit / SequenceVideoExporter；新增可选 aimingHold，复用 CameraRig 瞄准姿态；默认旧预设不开启。
- 已验证：原始15杆逐杆求解均进球、无白球落袋、模拟完整；XCTest 1项0失败，preflight.json保存结果。
- 已完成：连续15杆清台、17张静帧、1080×1920/60fps/116.6秒MP4（无音轨）、封面、编码与45张实际MP4抽帧验证。详产物目录REPORT.md及verification.json。
- 未修改原始内容球形或击球参数，未发布。

## 用户修订与返工
- FL-077：原导出器旧外观漏背景/灯光，已接回当前App全套外观，静帧通过；黑底版废弃。
- 用户追加：瞄准视角白球旁增加打点盘与力度条，已实现，15杆投影避让断言与实际MP4瞄准画面检查通过。
- 连续清台：原参数直接串联在第10杆失误；生产求解器数值校准视频副本后15杆连续全进。所有高低杆/速度修改保存于calibration.json；遵守生产打滑极限。

- 最终导出XCTest：Executed 1 test，0 failures；15杆连续性、进球、剩球数及瞄准段断言通过。FL-077本地成片返工完成。

- 兼容回归：SequencePerspectiveFitTests 5项 + SequenceStillCueTests 1项，Executed 6 tests，0 failures（regression-retry-build.log）。首次模拟器启动Busy未执行测试，自动重试后通过。

## r2 用户修订（本地完成）
- 炭黑木纹/赛事蓝/墨龙；1440×2560原生120fps。
- 宽视野；去参数卡背景及底部重复黑栏；当前瞄准→当前观察→下一杆观察→下一杆瞄准连续相机。
- r1保留为历史，新产物在 output/advanced-snake-video-20260916/r2/。
- 已复用r1校准副本，原动作库与击球参数未修改。静帧1测、转场1测、最终全片1测及兼容回归7测均通过。21286帧、177.383333秒；15段瞄准、44段相机缓动、89张MP4抽帧与编码验证通过。封面已同步更新，详r2/REPORT.md。
