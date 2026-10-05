# DR-348 S7 路程定速与贴台缩放（2026-10-05）

## 用户修正与实现
用户明确自动转镜应按速度，不按固定时长；同时反馈选球放大后球心不抬高，球下半部嵌入台呢。S7覆盖S6的固定0.95秒转镜约定，其余S6修复保留。

坐标为SceneKit米制、XZ台面、Y向上；台面0.8m，球心台面＋BallPhysics.radius(0.028575m)。

### 自动转镜
TwoViewCamera.SurfaceMotion在现有CameraSurface路径上积分256段，累计各小段max(世界位移/1.8m/s、四元数角距/90°/s、FOV变化/40°/s)作为巡航时间坐标，再反查曲面参数。不是把曲面参数线性播放，也不是单纯把总距离除速度后再全程ease。
巡航统一速率，起止使用0.16秒半余弦速度坡；短程无巡航段，缩短起停时间并降低峰值。没有统一总时长上下限，零行程立即完成。生产曲面入口duration=nil选择速度时钟；duration=0初始化及减少动态效果0.1秒、非曲面旧相机保持原显式时长。旧surfaceTransitionDuration常量删除。
相机仍走原曲面，手势半灵敏度、等高圈、分轴和33ms输入缓存不变。中途改目标从当前可见点重算路径；触摸接管/快照/换杆清除旧时钟。

### 选球视觉放大
TableBallPulse保留导入缩放及pivot基值，反馈缩放s时视觉中心沿世界Y上移R(s-1)，通过pivot完成；节点物理position不变，瞄准/碰撞数据不抬高。球自转时用当前world线性变换的逆将世界竖直抬升转回节点坐标；放大、拖动1.15倍提示、还原与打断共用该补偿，结束恢复原scale/pivot。
SceneKit presentation.transform已含pivot效果（本轮原生日志：modelY=0.828575，presentationY=0.8485775）；临时俯视复制presentation变换后将副本pivot置单位阵，防止重复抬升。

## 证据与验证
目录：`build/camera-surface-s7-20261005/`。
- before-pulse：原真实USDZ顶点球底约0.78017m，对照原始0.80010m，嵌入约19.93mm，两个自转方向及拖动提示共4条断言失败；旧代码/图片保留before/。
- core首轮：速度模型数值用例通过；Rig测试首帧没有提交初始化姿态、以及球底oracle重复应用presentation的pivot导致失败。诊断证据保留core与pivot-diagnostic日志/xcresult；修订测试初始化顺序和真实变换契约，保留原速度及0.3mm球底误差界。
- 首轮额外scale恢复用例类名指定错误，实际0条，未计通过；最终明确指定SimpleCueCameraTests，执行1条通过。
- final核心：**38项0失败**（21 CameraSurface、5 PocketMarkerHighlight、11 PocketSelectionUX、1导入缩放打断恢复）。真实USDZ两个姿态下球底、主/副场景单次抬升、物理球心、基值恢复均通过。
- Rig定速实测：默认中心15°=0.400秒，90°=1.600秒，同方向退全局=1.375秒；60/120Hz曲线路径位移/角速度在1.8m/s及90°/s上限的2%数值误差界内。长程匀速段、短程、零行程、纯旋转/FOV、中断/重选测试通过。
- final原生UI **4项0失败**：普通2D拖动/回3D、等高圈/近远端/全局/俯视恢复、俯视选球选袋保持与最新杆恢复、真实击球后自动选杆。原生附件已导出，选球后临时俯视及球放大/还原原图已查看。
- 收尾补零路程状态：VM以实际isTransitioning设置busy，重复点击当前视角立即完成，避免击球等待无完成回调。zero-motion 22核心通过（含新增零路程VM用例）；击球原生复验通过。合计**39核心/渲染/选择＋4原生UI，43项唯一用例分批通过**。
- verify-gate本轮通过（含v47基线，FAIL=0），S6记录的共享写盘漂移本轮已不存在。Debug-O设备构建及严格codesign检查通过；未声称手机手感或全局性能通过。

## 交付
07:56:54已覆盖安装并启动iPhone16Pro普通球迹com.xinkuan.qiuji，PID22240，进程复查存在。证据device-build.log、identity.json、install.json、launch.json、processes.json；未卸载/清数据，未提交或发布。本轮未构建Release，设备手感待用户试用。
