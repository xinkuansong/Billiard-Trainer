# DR-348 S8 距离增速与取景触发（2026-10-05）

## 最终行为
- 自动转镜基础速率由S7翻倍为3.6m/s、180°/s、FOV80°/s。本次完整相机路径L米决定统一增益1+0.25L；起停缓冲0.16秒，长距离巡航更快，仍沿原CameraSurface。0.25/m是本轮试用系数。距离指镜头转场路程，非母球到目标球距离。手势半灵敏度、等高圈、主轴隔离、33ms缓存均保留。
- 有效点球立即按当前几何瞄准进入默认第三人称，覆盖重复点击、显式自由、无可行袋口的自由回退；不等待预测可行。非法目标拒绝不转镜，力度等普通重算不抢镜。临时俯视内记录点击意图，退出后取最新方向；普通2D点球不切3D。
- 开球初始、重摆、点击第三人称、2D回3D：沿开球瞄准方向进入travel=1最远端，随后仍可手动观察。一般看全桌按钮保持当前环绕方向后退。
- 同时修复旧2D显示回调覆盖新3D模式：TwoView渲染写入前要求Coordinator缓存mode与scene.currentCameraMode一致，防止投影停在2D、转镜永不完成而卡住击球按钮。
- 临时俯视各镜像节点用SceneKit原生SCNGeometry.copy()持有独立geometry对象，保留导入格式；源geometry身份变化时才更新，静态网格驻留。materials保持共享以同步袋口反馈。普通节点手工创建SCNNode，绝不clone来源子类。

## 数值结果
| 操作（中心母球、默认圈） | S7 | S8 |
|---|---:|---:|
| 转15° | 0.400秒 | 0.2667秒 |
| 转90° | 1.600秒 | 0.6000秒 |
| 同方向退到最远 | 1.375秒 | 0.5583秒 |

直线3.6m与7.2m增益分别1.9、2.8；60/120Hz、中心/近角、近/中/外圈按独立2048段测长核验位移与转速界。零行程、起停、改目标、手动接管均保留。

## 最终验证
证据目录：`build/camera-surface-s8-20261005/`。
- final.log/xcresult：25 CameraSurface＋11 PocketSelectionUX，共36核心通过；普通2D拖动、开球初始/重摆/2D往返、重复点球、真实击球自动取景4 UI通过。临时俯视UI当轮出现SIGABRT，见下方返工记录，未计为通过。
- copy-mesh.log/xcresult：2 Daily3DClothPerformance＋5 PocketMarkerHighlight，共7核心通过；含真实USDZ、副本/源球底、材质反馈、物理位置与节点驻留。独立geometry对照原导入geometry，640×320同相机同光照串行像素MAE=0（门槛0.005）。
- 同一copy-mesh轮2 UI通过：临时俯视选球选袋退出，以及连续六轮开关俯视/交替换球/六袋口编辑。普通2D、真实击球等其他原生用例来自final轮；mesh-retest轮亦曾复跑真实击球通过。
- 合计**43核心/渲染＋6个唯一原生UI，49项分批通过**。最终临时俯视原图已导出查看，球桌/台呢/球/反馈显示正常；开球最远与重复点球后第三人称原图亦已审。
- delivery-gate.log：verify-gate通过，双端对齐FAIL0/WARN0、v47基线FAIL0。源码diff空白检查通过。

## 失败与修订轨迹（FL-118）
1. core首轮把Snapshot当前可见点当成目的地，在未推进渲染时断言travel=0.5，导致6条失败；另把含context变化的revision当自动取景次数导致1条失败。修正测试时点与观测对象，终点界未放宽。
2. checked/shot-diagnostic/shot-state的真实击球入口等待失败。现场computing=false、feasible=true、cameraBusy=true、moving=true、ortho=true、eye=(0,5.8,0)，证实旧2D回调写回后转镜被暂停。加mode一致性检查后原用例通过。
3. final临时俯视点袋口SIGABRT，malloc报pointer being freed was not allocated。栈落在__BuildRenderableSourceChannelsAndSemanticInfos→C3DMeshBuildRenderableData→SCNRenderer；旧代码双SCNView直接共享geometry。本轮隔离几何对象并复验，崩溃栈保留overlay-crash-stack.txt及diagnostics原报告。
4. 首轮手工重建顶点源的mesh-retest虽6核心/2UI、stress六轮交互通过，原图却出现三角形撕裂，该版否决。仅保留原生sources/elements重建geometry又漏台呢，新增像素用例真实失败MAE=0.0867955。最终native-copy保持完整导入元数据，原像素阈值不变而MAE=0。失败代码未装机，原图/日志保留。中间一次测试局部函数非throws导致编译失败，已显式guard+XCTFail修复，未吞错误。

## 交付
设备Debug-O构建及严格codesign验证通过。正常包com.xinkuan.qiuji，实验标记为空，executable SHA256为bbf908e9f99978cabc6ebf8466c6d79d0f757c4015f9ef916e9d82e483820d75；见device-build.log、identity.json。最终devicectl仍显示iPhone16Pro unavailable（devices-final.json），S8尚未安装，手机最后交付版本仍S7（当时PID22240）。未提交/发布；模拟器通过不代表真机手感、温升或所有时序问题已获用户验收。
