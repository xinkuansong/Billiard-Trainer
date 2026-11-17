# 当前 App 凹面与六条候选的同步对比

用户要求在上一轮案例一、二中加入当前 App 凹面，先看视频，暂不修改 App。

## 状态

✅ 两段四宫格视频已完成。新增 242 个凹面机位帧全部渲染，Blender 退出 0；两份 MP4 均为 1920×1424、30 fps、12 秒、360 帧，完整解码通过。六张试渲染、四宫格起终点和编码后的 0／3／5 秒图册已审。242 个机位的坐标、光轴、上方向与桌面九点投影已验证，五份相关 App 源文件 SHA 与读取时一致。待用户观感反馈。

[案例一：绕台四宫格](../output/camera-cases-surface-20261117/01-orbit-with-app-surface.mp4) · [案例二：抬高四宫格](../output/camera-cases-surface-20261117/02-lift-with-app-surface.mp4)

## 对照安排

沿用 [上一轮场景与六条候选](CAMERA-CASES-PREVIEW-20261117.md)，每格 960×600。候选直接复用上一轮帧；仅补渲染两条当前凹面路线。最终为两段 1920×1424、30 fps、12 秒四宫格视频。

|视频|左上|右上|左下|右下|
|---|---|---|---|---|
|案例一：长边绕向短边|当前 App 凹面|固定距离|按方向自动远近|远近变化减半|
|案例二：抬高视线|当前 App 凹面|原地抬高|抬高并后退 45 cm|抬高并后退 90 cm|

动作节奏保持 1 秒起点停留、4 秒正向、2 秒终点停留、4 秒返回、1 秒起点停留。正向统一五次 smootherstep，返回复用同一组机位帧。各格标签显示水平距桌心、绕转角／抬高量、垂直视角与动作阶段。

## 当前方案的复现方式

读取当前工作区 `QiuJi/Core/Scene/CameraSurface.swift` 的完整代码；在独立 macOS Swift harness 中直接编译该结构，配合从当前 `TwoViewCamera.swift` 提取的 `Pose` 与 `angleDelta`，输出机位与 FOV。仅将 UIKit 导入替换为 Foundation，并提供与当前常量一致的球半径 0.028575 m、库边高度 0.037 m；未改 App 源码。

调用路径核对为 `AngleSceneView.applySurfacePan` → `CameraRig.handleSurfacePan` → `TwoViewCamera.surfacePan` → `CameraSurface`，由 `CameraRig.applyTwoViewPose` 应用 transform 与 fieldOfView。当前每日清台使用这条凹面分支。

Blender 场景保持原材质、灯光、模型、球形与标线。白球中心为 `(0.65,-0.25,-0.013425)`，台呢 Z=-0.042。采用米制映射：Blender `(x,y,z)` → SceneKit 台呢相对 `(x,z+0.042,-y)`，因此凹面白球锚点为 `(0.65,0.25)`。

原生 `SCNCamera` 默认投影方向为 vertical，harness 已断言。Blender 保持 36 mm 传感器宽度与 16:10 画幅，逐帧按原生垂直 FOV 换算焦距。所有机位的九个桌面标志点在 Swift 与 Blender 的归一化投影最大误差约 5.82e-7；光轴与上方向误差小于 1e-5。

## 对齐与保留的差异

旧候选 48 mm 的起始眼点不在当前凹面上，因此不能同时强行匹配位置、FOV 并保留当前公式。本轮匹配起始绝对眼高 Z=1.05 m 和绕台方位，保留当前凹面的距离、俯角、关注点与视角。它是完整方案的观感对比，不能单独用来证明凹面形状导致僵硬。

- 绕台：保持相同绝对眼高；通过求解凹面 bearing 匹配各帧绕桌心方位 −90°→0°。凹面 travel 固定，路线始终位于同一高度环上，按统一节奏重参数化。当前凹面距离约 2.115–2.892 m，垂直视角约 42.7–43.9°；候选固定 48 mm，对应垂直视角约 26.4°。
- 抬高：起始方位约 −36.87°，随后固定当前凹面 bearing，保留生产垂直移动的路径耦合；按相同抬高进度求 travel。凹面距桌心约 2.821→3.559 m，伴随约 1.05° 的绕桌心方位偏移，垂直视角约 42.7°。候选原地／直线后退保持绕桌心方位固定。
- 当前凹面的最高眼高为台呢上方 1.8 m，即此场景 Z=1.758 m。相同起点抬高 75 cm 会超过上限 4.2 cm，因此当前方案实际升高 70.8 cm；达到上限后停留，标签明确标注。这段饱和也会在返回时保留。
- 本轮直接采样凹面机位，并未模拟等量手指拖动、输入灵敏度、轴锁、显示延时或原生帧节奏。统一画幅用于比较，不代表某一型号手机的实际视窗。
- 画面外观来自 Blender 看样场景，未声称与当前手机材质及界面逐像素一致；未运行 App 或改其实现。

## 证据与复跑入口

工作目录 `output/camera-cases-surface-20261117/`。

- `CameraSurface.snapshot.swift`、`TwoViewCamera.snapshot.swift`、`source-identity.json` 保存读取源码及 SHA。
- `surface-harness.swift`、`export_surface.swift` 与 `surface-plan.json` 保存原生公式导出与逐帧参数。
- `scene-inspection.json` 记录模型尺寸、球位置及台呢高度。
- `render_surface.py`、`pilot-validation.json`、`manifest.json` 记录投影验证、渲染完成与源模型／非相机变换不变。
- `validate_motion.py`、`motion-validation.json` 检查时间进度、起始高度／方位、绕台同步、抬高 bearing 固定及高度上限，记录当前源文件是否仍与快照一致。
- `compose.py`、`make_headers.swift`、`edit-plan.json` 保存四宫格布局、标签与帧编排。
- `video-verification.json` 保存 MP4 实读帧数、格式、时长、完整解码与 SHA；`pilot-review.png`、`encoded-review.png` 为视觉检查图册。

## 用户反馈

待观看成片后反馈。后续若需定位原因，可再做统一视角／统一关注点的单变量对照；当前未实施或修改 App。
