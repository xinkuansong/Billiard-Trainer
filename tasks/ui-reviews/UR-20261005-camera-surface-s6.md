# DR-348 S6 转镜与选择反馈（2026-10-05）

## 范围与根因
用户授权处理四项：自动/按钮转镜生硬；普通3D和临时俯视缺少手动选球/袋口反馈；临时俯视点球偶发整桌闪；普通2D拖动时变黑底3D、松手恢复。用户已明确普通2D**没有**点球偶发闪烁，不纳入该缺陷。

- VM请求0.95秒转镜，simple camera入口却上限0.3秒，全局入口也固定0.3秒。曲面入口统一使用0.95秒，沿曲面参数采用五次smootherstep，保留触摸接管与减少动态效果0.1秒。
- 桌面点球没有触发已有的TableBallPulse，只有上方球列触发。将成功手动选球的反馈放入VM统一入口；球列删除重复触发，母球仍保留原识别提示。球1.7倍、0.18秒放大＋0.24秒还原，物理基准缩放不变。
- 手动袋口原来延迟1秒，现接受点击即变色0.6秒；自动推荐保留原有延迟1秒的反馈。快速重选取消旧袋口反馈。
- 临时俯视只在重建时克隆袋口状态，后续只同步球节点；选球、选袋口、预测回写都可能触发整场景重建。现在保持场景、相机和球桌节点，逐帧同步源场景的presentation变换/透明度/隐藏状态，局部增删轨迹等节点，源场景统一驱动反馈时钟。复制基类SCNNode，避免PocketLeatherMarker动态clone构造失败；源节点作为映射键保留到下一次同步，防止地址复用误匹配。
- 普通2D瞄准手势调用updateCuePose，原applyTwoViewPose无视普通2D，写入3D姿态并关闭正交投影；显示循环再写回2D，形成争用。CameraRig显式记录2D展示所有权，2D下禁止TwoView姿态写入及3D更新，显式回3D时解除。

## 验证
证据目录：`build/camera-surface-s6-20261005/`。
- 修复前两项核心回归确实失败（2D投影与0.3秒上限），before-tests.log/xcresult保留；临时俯视原生截图保留于before-attachments，未将静态截图当作闪烁复现。
- 首版18项CameraSurface核心通过（after-core.log/xcresult）。
- 首版4项PocketMarkerHighlight＋11项PocketSelectionUX通过，含真实SceneKit像素前/峰/后比较；3D与临时俯视峰值截图已查看，球放大、袋口黄色提示可见并恢复。反馈渲染图在feedback/。
- 普通2D原生按住拖动测试已通过，逐次瞄准回调检查正交投影，回3D仍有效。首轮其余2UI也通过；源映射修订已复验。扩大模式恢复检查发现旧页面显式focus回归1项失败（2条断言），现将update阻断限定为TwoView控制器，保留旧页面准备聚焦的行为，原断言保留并已在final-retest通过。

## 交付
07:35:51已覆盖安装并启动iPhone16Pro上的普通球迹com.xinkuan.qiuji，PID22121，进程复查存在；本次没有卸载或清数据，S5分轴也随包交付。证据install.json/launch.json/processes.json及identity.json。自动测试不代表手机转镜手感已获用户认可。

仓库总门禁本轮失败：verify_v47_ui_baseline报未登记写盘测试extra=[QiuJiTests/BreakRackPhysicsTests.swift]，该文件本轮开始后由共享工作区其他工作增加375行，本次未修改；此前四步门禁通过。记录gate.log，不以相机定向测试替代总门禁。

### 最终定向回归
- final-tests：47核心中旧显式focus用例失败1项/2断言，其余通过；4项原生UI全部通过（普通2D拖动与回3D、俯视3种摆球权限/抓取偏移、选球袋场景不重建与恢复、真实击球后换杆）。失败保留。
- 将update阻断限定到TwoView后，final-retest：**47项核心/渲染/选择/模式恢复全部通过，0失败**，原focus断言原样通过。
- S5分轴UI在feedback-ui通过；本轮共**52项唯一用例分批通过（47核心＋5原生UI）**。不会以该结果认定手机手感/帧率/温升通过。
- 原生前后附件见before-attachments、after-attachments、final-attachments；实看普通2D拖后、临时选球、临时选袋截图，未見布局异常。临时选袋原生截图可见下中袋黄色反馈；像素时间序列另验证球和袋口恢复。
- Debug-O设备构建成功（device-build.log），严格codesign检查通过，普通包身份/二进制SHA-256见identity.json；本轮未构建Release、未发布。
