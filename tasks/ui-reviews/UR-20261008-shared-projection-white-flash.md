# 每日清台 / 分离角与走位：真机切换闪白

2026-10-08。已在用户的 iPhone 16 Pro / iOS 27.0.1 捕捉到异常帧，用户确认“是，就是这种闪白”。共享源码已修复，独立诊断版真机前后对照通过；原主App未覆盖，未提交/发布。

## 确认的问题与原因

两页共用 `FreePlayView → ShotPlayCamera.setMode → AngleTrainingScene.setCameraMode → AngleSceneView`。旧修复保住了SCNView实例，但 `DailyCarpetBackground` 仍受 `if !is3D` 控制。切换时，SwiftUI先移除地毯底图，SceneKit的渲染区域尚未铺满窗口，于是桌外区域露出浅色宿主底色，白色标题和时间等文字融进白底，看起来消失。

真机浅色基线两页各6次2D→3D，共捕捉到11个单帧白底（P01 5、每日6，录制帧约13–32毫秒）。球桌和部分HUD仍在；page/window/root/scene/renderer身份稳定，没有整页销毁的证据。P01深色基线没有近白帧，与宿主底色露出的解释一致。

用户起初描述3D→2D；日志与逐帧对齐后，这批确认的异常实际发生在2D→3D。两方向均纳入修复后回归，不把方向口述当作时序证据。

## 最小修复

生产仅修改 `QiuJi/Features/PositionPlay/Views/FreePlayView.swift`：让同一张地毯底图在2D/3D之间持续存在，3D稳定画面由原SceneKit视图覆盖；没有改黑底遮挡、没有替换渲染器，也没有重做两页界面。Swift编译器对原超长View表达式超时，拆为同顺序的HUD/场景/覆层表达式，并抽出地毯背景函数；布局和修饰器顺序保持。

诊断录屏、自动切换及独立App标识只在 `build/whiteflash-device-20261008/AppSnapshot`，没有进入生产源码。其他会话同期修改的标题字号保留，未覆盖。诊断快照基于C56-r03，正式源码另完成构建。

## 功能与真机视频验证

用户允许局域网连接；未使用iPhone镜像。独立诊断App `com.xinkuan.qiuji.whiteflash` 在真机调用设置菜单原有action，每轮12次交替切换，即每方向6次。ReplayKit提供手机本地视频帧，App内AVAssetWriter保存，局域网取回。

| 修复后轮次 | 切换次数 | 录制帧 | 白底帧 | 写入丢帧 |
|---|---:|---:|---:|---:|
| 分离角与走位·浅色 | 12 | 1130 | 0 | 0 |
| 每日清台·浅色 | 12 | 1147 | 0 | 0 |
| 每日清台·深色 | 12 | 1030 | 0 | 0 |
| 分离角与走位·深色 | 12 | 460 | 0 | 0 |
| 合计 | 48 | 3767 | 0 | 0 |

逐帧近白像素扫描后目视白底候选、切换中间帧和两模式稳定帧。异常基线约26%–28%画面为近白中性色，修复后峰值约1%–1.6%，来自正常白球/文字。视频为可变帧率；写入丢帧0不等于证明每个物理显示刷新均被ReplayKit采集，不承诺所有设备/任意瞬间绝无闪帧。

正式工程 `make -f scripts/Makefile build`、`verify-gate`、`verify-doc-size`、本次文件diff检查通过。诊断版真机构建、安装、四轮录制均成功。XCTest通道先前失败，因此本轮动作是调用真实按钮action，不是实体手指/自动化触摸事件；未重跑iPad/其他手机、长时间GPU/温升。

## 视觉审查

打开并检查前后原图及四轮切换联系表：原单帧白底消失，地毯持续覆盖桌外区域；球库、标题、左右控件、深色设置卡、时间/电量/FPS在切换时保留。两模式最终布局沿用基线。取证不将切换过程中的旧构图帧当作本次白屏，也不宣称已优化所有构图转场。

证据根：`output/table-page-adaptation/P01/whiteflash-device-20261008/`。

- `before-flash-01/02/03.png`：P01浅色第2次2D→3D的连续三帧，中间为用户确认的异常。
- `after-flash-01/02/03.png`、`before-after-transition.jpg`：修复后相同动作时间附近的对照。
- `fixed-four-runs-contact.jpg`：两页双外观的切换与稳定画面，已目视。
- `*-lan-r3.mov`：有效基线；`*-fixed-r1.mov`：四轮修复后录像。
- 同名 `*.mov.csv`、`*-events.json`、`analysis-*/white-metrics.json`、`verification-summary.json`：帧时刻、生命周期、逐帧扫描及统计。
- `production-build.log`、`verify-gate.log`、`verify-doc-size.log`：生产工程检查。

## 历史与失败证据边界

旧会话「[UI] 移除每日清台按钮下方解说文字」（thread `01a10ac2-634a-7493-86b9-4fd5e55bd31f`），commit `b29febfb` 的修复是单一SCNView身份和layout后同步viewport/相机，针对2D→3D约70ms黑场、HUD保留。该修复仍在，不能等同于这次底图条件移除导致的白帧。

先前模拟器六次反向切换未捕获白帧，不是真机通过证据。早期USB视频被首次联网权限弹窗遮挡，标为无效；独立XCTest两次DTX/code74失败，均在首条测试之前。USB源消失后用户允许改局域网；ReplayKit曾返回拒绝录制，用户随后明确允许重试，又因系统导出接口权限错误改用App内写帧。这些失败均保留，详见证据根 `STATUS.md`、`investigation-before-final.md`，不算App白屏回归失败，也不纳入有效样本数。
