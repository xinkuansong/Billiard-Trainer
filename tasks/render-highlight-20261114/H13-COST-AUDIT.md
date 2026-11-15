# H13前置核对：其他材质与活动期CPU

后续已执行：见[H13三轮结果](H13-DELIVERY.md)。下文保留计时前的核对与假设，不作为当前未完成状态。

2026-11-14，H11/H12之后重新核对生产消费路径。此页是下一批的成本边界与入口，**不是已量化的新收益，也不是实施完成**。

## 材质

- `AngleTrainingScene.configureReferenceTableRendering`明确将共享liveReference设为`.reflection`；`applyBall`将此选择交给probe安装。球的64次环境积分参考源码仍在文件里，但正常R路径已由`filteredBallShader`替换为预滤环境/响应查询，失败时才回参考。不能因为搜到64循环就重复优化已经替换的路径。
- 木台边`Wood/BlackWood`实际为constant＋`woodCoatShader`，每灯2×2高光样本；皮革/球杆为constant＋`satinShader`，每灯4×2样本。固定漫反射仍经解析矩形积分。当前2灯对应8/16次，但这只是结构次数，不能直接换成CPU/GPU/能耗百分比。
- `MG_Gold`桌腿实际被改成constant＋哑光木色/解析漫反射。台呢依旧PBR＋C1/H9，不能将此前对台呢PBR的约2.8%诊断数套给其他材质。
- 地板/墙面constant且依赖离线照明，H12已实际排除本机当前矩阵下“大幅降过滤即可显著提速”的方向。

后续计时必须先装入这些**现行生产材质**和实体球。H11/H12复用的台呢夹具虽是实际USDZ，其他桌体材质未完整调用现行`apply(to:)`；已查看的东方俯视图中桌腿仍呈导入模型的明亮金属。因此它足以支撑同基线的台呢/地毯局部对照，不能直接拿来给生产木台边、桌腿、球分账。旧H9捕获台呢Shader Cost 88.36%也只属那个无实体球夹具，不是App份额。

下一步应在当前完整材质消费者上按木台边、皮革、球、房间分组做有限诊断，先验证绑定/强色消费，再记录GPU/CPU编码和真实draw；仅定位成本的删项必须明确画面不等价。若没有显著可移除成本，不能为了列百分比强行改材质或合并几何。

## CPU

- `AngleSceneView.renderUpdate`仍每帧调用viewport、临时俯视维护、帧调度和标注。B2已有相同值写入/布局缓存；实际窗口convert保留，用于祖先移动而自身bounds不变，不能只按尺寸缓存。
- `TwoViewCamera.update`在普通模式无运动时早退；simpleShot分支最终进入`updateSurfaceInput`，无输入样本也早退。不是每帧都在重新求整条相机曲面。
- `CameraRig.applyTwoViewPose`已有transform/FOV同值保护，但仍begin/commit事务并写`usesOrthographicProjection=false`。这是可以局部量测的剩余维护，尚无显著成本证据，不能先承诺优化比例。安全候选应比较**实际节点**状态后早退，不能仅缓存上次目标而漏掉2D切换、外部改写或camera替换。
- `FrameDelegate.didRenderScene`仍扫描动作，但遇到首个动作即停止；必须在渲染队列保留动作/退场语义，不能按UI的contentIsAnimating直接删掉。B2曾因缺独立成本证据保留此项。
- `closeupRenderUpdates.requestUpdate`已有无订阅/已排队guard；HUD输入也已有同值guard，不新增第二套轮询缓存。

本轮没有修改这些生产路径、没有执行新的CPU计时或宣称整页/手机降温。优先取得现行材质成本，其次只对明确剩余CPU块做一次候选与净成本比较；不回到H10/H11/H12的旧排名。
