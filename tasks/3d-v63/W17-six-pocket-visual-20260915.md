# W17 六袋近景采样验收

2026-09-15，继续普通击球范围；未修改生产代码/资产，仅新增 `TrajectoryRendererTests.testSixPocketRailCloseupSequences`。

## 当前证据

- 手机 iPhone16Pro，iOS26.6.2，UDID 00008140-0009682918A2201C；Makefile test，Debug -O / coverage NO。
- 最终 `device-r2/test.log`：实际命中 1 项，12.320 s，0 失败，退出0。xcresult：`build/DerivedData-v63-device/Logs/Test/Test-QiuJi-2026.09.15_01-40-10-+0800.xcresult`。
- 证据根：`output/3d-v63/six-pocket-20260915/`。首轮 `device/` 功能通过，但测试没有切3D模式，房间被隐藏；保留该轮诊断图，不作为最终环境证据。r2补 `setCameraMode(.perspective3D)` 后重新全跑。
- 六袋各执行三次默认平面预测 + 正式 `TrajectoryPlayback` SCNAction + 共享库存；共18次，656个1/30秒时间采样渲染帧。每次实际入袋ID与目标袋一致，稳定球号集合依次为1/2/3颗，原桌面节点隐藏。未手工伪造尾段或强制摆入最终槽位。
- 输出86张800×800原图：68张首球下落/滚动采样（10Hz）+18张逐球驻留。全部可解码，56个不同SHA-256。重复组逐组保留于 `device-r2/duplicate-groups.json`，仅同袋起始遮挡/停稳重复画面，没有跨袋复用；不以重复图冒充不同运动状态。
- 六张联系表全部打开逐状态目视，另打开角袋0和中袋4三球原图。在这组固定机位下未见明显穿出支架、异常消失或额外光照遮挡；三球有正常的前后遮挡，不能把不可见面积当球被删除。

## 配置与边界

几何采用 `TableGeometry.chineseEightBallQiuJi(surfaceY:)`，SceneKit X–Z水平、Y向上、米。射向取实际袋中心，角袋沿两轴等量向内退0.35m，中袋沿Z向内退0.35m；1.1m/s，无旋转输入。编号球使用单球自由模拟记录的cueBall别名绑定到实际_1/_2/_3节点，验证呈现共享别名/身份链路，不是18次多球碰撞求解。

正式 `AngleTrainingScene.setupScene(mobileRendering:true)` + 3D房间，默认球桌/球材质，保留contactOcclusion delegate。仅相机为桌外诊断近景（不是用户观察菜单可达性证明），未改资产/灯光/支架参数。旧文档袋编号可能与当前代码顺序不同，证据直接使用实际pocket_ID，不把旧方位名字硬套到截图。

采样渲染时间不是测得的屏幕FPS；10Hz截图不能证明帧间毫秒级无穿透，且本轮只覆盖正入袋、零旋转、固定机位、三球容量。偏入/高低速、旋转绕桌、连续实看滚速满意度、VoiceOver与持续性能仍保持待验。此前资产几何门禁及四档实时/导出对照证据不由本图替代。

源码指纹运行后无漂移；verify-gate FAIL0、verify-doc-size/diff通过。手机测试结束后已正常启动，见 normal-launch.log。v63整体仍未完成。
