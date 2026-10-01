# 3D全局C档与相机按钮图标

2026-09-28；DR-337。用户选定r4/C，追加全局俯看眼睛、观察站立人形。

## 变更

CameraRig全桌拟合距离×1.18；桌心旋转沿用现有轨道。独立常量不改变2D或第一/第三人称预设。共享ShotPlayerCameraButtons全局用28pt矢量斜眼+短视线箭头，观察figure.stand，第一人称保留原架杆人物；44pt命中、选中态、标签及动作保持。每日清台和角度训练共用三键，其他双键消费者观察本来就是figure.stand。

## 功能验证

- `build/global-camera-c-20260928/test.log`：8测0失败。包括已选C真实场景黄金距离、24次水平旋转中桌心/距离/高度/FOV恒定、重复全桌无累乘、2D往返，以及既有相机输出/多视口入镜回归。
- `build/camera-icons-20260928/before.log` 与 `after.log`：分别1项UI用例0失败。每日selection夹具，Dark/Light×全局/站立/瞄准各6张。测试真实按钮切换及选中态。
- `build/global-camera-c-20260928/gate.log`：verify-gate通过，写盘清单已登记GlobalCameraPreviewTests。出图opt-in，不触及真实用户存档。

## 视觉审查

基线与修改后均在QiuJi-Camera-20260925 / iPhone17Pro、iOS26.3.1模拟器实际页面截图。对照原图与局部：全局斜眼和向下视线可辨认；站立与俯身轮廓不同；图标未出44pt圆形按钮边界，按钮列及力度条位置保持；选中背景仍按模式变化。HUD在Light/Dark均沿用场景深色表面。

证据：`output/global-camera-c-20260928/page.png`、`icons-before-after.png`、`states.png`。原始截图保留`build/camera-icons-20260928/before/`与`after/`。

## 边界

r4已选预览冻结未改。全局C固定距离在部分旋转方向仍会裁桌角，这是预览中已展示的取舍。数值测试不替代真实手势手感。未真机、iPad、所有消费页面逐页截图、完整VoiceOver或持续性能验收；未提交/发布。


## 图标r2：用户反馈后调整

全局改普通eye（btHeadline），观察人形17→24pt semibold，移除OverviewEyeIcon自定义斜眼箭头。44pt外框、相机参数和动作保持。修改前为本报告首轮after截图；修改后build/camera-icons-20260928/r2/，UI测试1项0失败（r2.log），浅深色三状态6图及整页已目视：眼睛方向水平，人形较首版清晰且未出圆形边界。最终展示output/global-camera-c-20260928/icons-r2/page.png、icons.png、states.png。未真机验收。
