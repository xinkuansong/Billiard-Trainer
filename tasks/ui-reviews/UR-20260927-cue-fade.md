# 首杆球杆淡出卡顿：诊断与修复

## 问题与原因

用户确认：重新进入球桌页面后，第一杆球已运动，在球杆消失的一刻卡顿。

同一生产场景的模拟器离屏探针复现：节点 opacity 从 1 首次降到 0.99 时，snapshot 墙钟耗时 307.4 ms，第二轮 5.7 ms；直接隐藏约 2.5 ms。新场景对照再次出现 123.6 ms。snapshot 含提交、GPU 和读回，并非屏幕实际呈现间隔；没有采样栈，不把全部耗时精确归为 Metal 编译。

Apple 文档说明 SceneKit 会根据材质决定透明绘制，资源默认延迟准备。实验支持首度改变节点透明度引起渲染状态准备是本问题的触发路径。

- [SCNShadable](https://developer.apple.com/documentation/scenekit/scnshadable)：透明分类、shader modifier。
- [prepare](https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare(_:completionhandler:))：后台资源准备。

## 方案

- 球杆完成场景材质配置后，提前声明透明绘制，加入 `cueFadeOpacity` 参数。
- 瞄准及动画期间保持节点 opacity=1，淡出改变材质参数；RGB 与 alpha 一起缩放，保持预乘颜色关系。
- 普通跟杆结束和避让回撤均使用同一入口，保留既有时长、运动与末尾隐藏。
- 切球杆样式时绑定新的材质；下一杆 show 恢复参数；未配置此路径的独立 CueStick 沿用节点透明度兼容行为。
- 不改变球运动、球桌材质、相机和帧率。

只调用 prepare 的实验仍有 121.4 ms 首次突增；只加 `#pragma transparent` 同样未消除节点 opacity 变化的成本。因此没有把这两种未奏效的方案交付为修复。采用参数淡出的诊断首轮约 3.1 ms，第二轮约 3.1 ms。缓存状态会影响后续参考耗时，不能把某一轮比例当作稳定收益。

## 证据

根目录：`build/cue-fade-20260927/`。

- `baseline/` 保存本轮修改前文件及 Git 状态；其他工作区修改保留。
- `probe-first-timings.json`、`probe2-timings.json`、`probe3-timings.json`、`probe4-timings.json`、`probe-source.swift` 保存迭代诊断；`probe*-build.log` 保存真实执行记录。
- `final-26.3.1/comparison.json`：三款球杆（原款、墨龙、小头/大头代表）、2D/3D、五档透明状态，共 60 张前后原图。最终参数路径首度淡出约 4.0–5.8 ms；这些是模拟器离屏样本，不是帧率承诺。
- `final-render2-build.log`：15 项测试通过（12 避让/运杆、2 新增淡出/图像、1 样式尺寸姿态恢复）。
- `page-before.log`：原版每日清台实际 3D 开球、击球、回到静止，1 项 UI 通过；截图在 `page-before/`。

## 图像审查与失败记录

已查看标准系统的三款 3D 前后联系表及原款 3D 原图、2D 原图、原版实际页面整页截图。

原先将 3D 完全显示状态也要求逐像素相同，`final-render-build.log` 中该断言失败 3 次；保留 `first-visual-failure/`。定位为球杆自身轮廓/抗锯齿混合差异，74–94 个像素，最大 2–4/255；背景没有变化。修订检查前提：背景逐像素一致；实际球杆掩模内 RGB 平均误差小于一个 8-bit 灰阶；完全隐藏严格一致。用缺失整杆的负对照确认该规则会拒绝缺失球杆。未放宽时序、隐藏/恢复、几何及背景断言。

最终标准系统球杆区域最高平均误差约 0.272/255；淡出中少数轮廓像素有较大单点差异，不能称为全程逐像素等价。目视未发现杆身颜色、消失节奏或桌面背景回归。

## 页面及跨系统回归

- `ios17-render.log`：iPhone SE 3 / iOS 17.0，2 项淡出/图像和 1 项样式尺寸姿态测试，3 项通过；三款球杆、两种机位联系表已查看。
- `page-after.log`：iPhone 17 Pro / iOS 26.3.1，实际 3D 每日清台击球、恢复瞄准及持续静止通过，整页前后截图已查看。
- 同批新增 2D UI 首轮在击球前等待静止超时。原因是 `AngleSceneView.updatePocketAccessibility()` 仅在 3D 输出 FPS 文字；默认 2D 的无障碍值没有“静止”。测试改用已有 `-renderProfileProbe` 暴露调度状态，生产渲染配置不变，保留静止、击球结果与持续静止断言。失败日志、附件保存在 `page-after.log` / `ui-failure/`。

- `page-2d-fixed.log`：修正测试观测接口后，同一标准手机模拟器实际 2D 击球、杆数/重打快照、恢复瞄准、持续静止全部通过，1 项 0 失败；整页截图已查看。最终定向测试：iOS 26 单测 15 项 + 页面 2 项，iOS 17 单测 3 项。

## 门禁与边界

- `git diff --check` 通过。
- `verify-gate` 未通过：既有未登记写盘测试 `QiuJiTests/CueSpinPreviewCaptureTests.swift` 触发清单漂移（`gate.log`）。该文件已出现在本轮修改前 Git 状态，未修改此无关视频工作；不声明全仓门禁通过。
- 手机实际呈现与用户体验未验证。本轮按用户要求使用模拟器，不安装手机，不作真机性能通过声明。
