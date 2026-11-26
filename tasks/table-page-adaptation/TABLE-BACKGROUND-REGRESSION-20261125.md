# 球桌进场黑屏与临时俯视黑边

2026-11-25（北京时间）。用户反馈手机进入球桌先黑屏、两球走位临时 2D 外围出现黑色矩形，确认分析后授权修复。

## 原因与范围

`a2d6037ac4ce6015599961e3d840863c9665d384`（2026-11-23）新增五处手机竖屏 2D 顶层黑罩，覆盖已有 ScreenAnchoredCarpet；同提交将 AngleSceneView 两条临时俯视路径由 clear/非 opaque 改为 black/opaque。注释试图用整层底色遮住半透明辅助的底层透出，但违反透明抠桌合同。不是地毯资源丢失，也不需要回退整个相机提交。

恢复范围：BTTeachingTablePage、FreePlayView、SceneAimingView、AimPointSceneTrainingView、BatchAuthoringView 的进场遮罩；AngleSceneView 的实时 SCNView 叠层及 UIImageView 快照叠层。保留窗口底层防闪白、实际完成帧驱动转屏、3D 主场景、取景、桌体、轨迹及交互权限。

## 局部条款复核

|条款|判定|本轮要求|
|---|---|---|
|TP03|继承|手机 2D 竖屏入场后转横，iPad 按窗口方向|
|TP16/17|继承|临时俯视为透明抠桌叠层，退出回原 3D；不改变题目或相机语义|
|TP29|继承|保留实际桌房资源与渲染树，只恢复合成背景|
|TP30|继承|先可见地毯、竖桌与控件，再在固定地毯上转横；不能加顶层黑罩遮挡|
|TP35|继承|对照原生录屏与截图，构建/交互/视觉/真机分列|

局部回退不重跑全部 TP01–TP36；原页面业务差异及未验边界保留。

## 验证与交接

源码修复完成。使用独立模拟器包 `com.youbilliards.cuephys.entryreview`，通过 fleet/lifecycle 持有租约，不覆盖既有正式包。

本轮原始证据：`output/local-test-runs/7b27b32bf30e4dcf9221a1d8bb26324d/evidence/`。对照包含两球走位共享宿主、每日清台自由宿主的进场和临时俯视，以及角度瞄准的半透明辅助管道。真机与用户视觉认可未验，未提交、未发布。

### 执行记录

- `before`：冻结源码的初次构建因快照漏带 `.gitattributes` 被资源检查拦截，0 项测试；补齐仓库构建输入后另开 `before2`，不跳过门禁。
- `before2`：iPhone 17 Pro / iOS 26.3.1 两项原生流程通过；截图复现桌角外黑色矩形。录屏按 20 Hz 抽样，黑像素定义为 RGB 最大值 < 12、整屏黑帧定义为黑像素 > 95%；两球走位进场 77 样本中 28 帧、每日清台 141 样本中 29 帧达到整屏黑帧阈值。该数据用于前后对照，不作为精确黑屏时长。
- `after`：同机修复版三项流程通过，临时俯视截图已核透明外围及管道；但测试包保留了上轮 3D 偏好，本轮不作为 2D 进场证据。
- `after2`：仅重置本任务独立包，补实际 2D 前置断言，三项流程通过（75.380 秒，0 失败）；录屏已目视检查先地毯、再球桌、再转横。两球走位 76 样本、每日清台 139 样本均无整屏黑帧。截图确认临时俯视圆角外围透明、退出回原 3D，管道未见明显底层重影。测试完成后的可选 simctl 诊断收集耗时较长，只终止该作业诊断子进程；xcodebuild 自行以 0 退出并完成结果导出。
- `after17`：iPhone SE 3 / iOS 17.0 三项流程通过（75.186 秒，0 失败），原生截图和进场序列已目视复核，透明桌角与管道正常。该机录屏时间戳与附件有偏移，定量黑帧对比仅采用同机 `before2/after2`，不把 iOS 17 抽样当精确全程统计。
- Swift 语法解析、`make -f scripts/Makefile verify-gate`、文档体积检查及 `git diff --check` 通过。

### 验证边界

原生操作覆盖共享教学宿主与每日清台宿主；其余三处入口为同类黑罩撤销和源码审查，未逐页重跑。两条叠层路径均修复，原生 UI 主要覆盖当前实时 SCNView 路径，历史快照备用分支未单独强制触发。未进行全量 App 回归、真机或用户体验验收。

### 便捷证据

证据目录记为 `../../output/local-test-runs/7b27b32bf30e4dcf9221a1d8bb26324d/evidence/`（下列链接相对本任务卡）：

- [改前进场录屏](../../output/local-test-runs/7b27b32bf30e4dcf9221a1d8bb26324d/evidence/before2-twoBall-entry.mp4) / [修复后进场录屏](../../output/local-test-runs/7b27b32bf30e4dcf9221a1d8bb26324d/evidence/after2-twoBall-entry.mp4)。
- [改前临时俯视原图](../../output/local-test-runs/7b27b32bf30e4dcf9221a1d8bb26324d/evidence/before2-twoBall-temporary-2D.png) / [修复后临时俯视原图](../../output/local-test-runs/7b27b32bf30e4dcf9221a1d8bb26324d/evidence/after2-twoBall-temporary-2D.png)。
- `before2/after2/after17.xcresult`、日志、原生附件、完整录屏、临时 UI 用例、驱动脚本及六个生产源文件 SHA-256 均保留。修后正式验证共 6 项通过；额外 `after` 3 项只用于叠层检查，不重复计入。

资源收尾：两台模拟器均已关机、fleet 租约已释放；正式包和用户数据未动。独立测试包卸载被生命周期工具的全局忙碌守卫拦截（另一个真机 xcodebuild 在跑），暂保留在关机设备上，不绕过守卫；清理脚本与状态已存证。本地测试工作目录通过生命周期工具回收，原始证据保留。
