# W03 验收：台面辅助显示基础

2026-09-12。按问题集合v63 §8 W03验收，共享显示基础完成；页面正式接入、自然进袋、真机性能仍属后续批次。

| 完成标准 | 实证 |
|---|---|
| 原样与投影同机位 | footprint-r1/before.png、projected.png；testLoadedClothFootprintAndRenderEvidence固定同相机只更换线几何。此原型说明放置差异，最终生产由depth-policy-r1验证 |
| 六类平面辅助 | AngleTrainingScene瞄准/进球/分离/普通轨迹、SceneStroke圈与区域、网格/角度参考及PlanThree填充均显式投影；35处消费者审计见W03-working。bounds-r1相关域38测通过 |
| 空间例外与数据隔离 | testSceneSeparatesProjectedAssistsFromSpatialLines、testTrainingGuidesSurviveClippingAndKeepSpatialMarkers；空间线保留圆柱和XYZ弧长，ghost/contact保留球心高度。投影以值类型坐标生成新顶点，未改Physics/预测数据 |
| 真实台呢裁剪 | 凹面三角剖分、分离孔洞、正反绕序填充、裁空恢复、UV原始距离测试；六袋探针为空。仅显示几何，不声称物理支撑校准 |
| 三设备低角度/密集/近袋 | depth-policy-r1标准全桌/近袋，depth-dense-se-r2与depth-dense-ipad-r2各一项两图；六图已打开。字形四方位/模式恢复已验 |
| 遮挡与重合 | DR-143固定语义层级，读取实体深度不写深度。overlap-r1隔离问题，depth-policy-r1验证生产；库边/球遮挡保留。不同虚线周期空隙露出下层属有序叠加 |
| 实际使用 | depth-ui-r1一项完整分离角与走位UI，0失败，入口/低近袋/重打三图已审；此前开球与三规划入口见projected-r2、consumers-ui-r2。规划整流程归W13 |
| 构建/门禁 | depth-policy-r1 18项0失败、depth-ui-r1一项0失败，均TEST SUCCEEDED；verify-gate-depth-policy FAIL=0/142写盘文件；verify-doc-size-depth-policy-final与git diff --check通过 |

所有日志/xcresult在output/3d-v63/W03。depth-policy-se-r1/ipad-r1因不存在的密集选择器各只执行1项，不能算密集覆盖；正确补测r2已单独确认。保留失败覆盖和原始证据。

CPU更新样本p50=2.23ms、p95=2.42ms，只代表Debug模拟器100次采样，不证明真机帧率/功耗。W16仍须验性能/可访问性/最低系统。颜色沿用原规则；图谱整页多路线语义继续由W14验收。源码检查点depth-policy-source-hashes.json。
