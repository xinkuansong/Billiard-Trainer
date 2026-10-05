# 每日清台横屏入口修复（2026-10-05）

状态：本地实现、构建、原生定向回归及转场审查完成；未安装真机、未提交或发布。

## 现象与根因

从竖屏训练首页进入每日清台，先出现挤在竖屏中的每日工具，再旋转为横屏。修前原生录屏 `output/daily-entry-20261005/before/home-entry.mp4` 与抽帧 `before/home-contact.jpg` 已确认这个过程。

原 `FreePlayView` 会立即构造 VM、显示每日横屏布局，并在 `onAppear` 同步执行 `setupScene` / 对局恢复；其背景 `DailyTableOrientation.Controller` 到 `viewDidAppear` 才请求方向。因此场景初始化、导航动画、方向变化挤在同一进入过程，横屏布局还会先拿到竖屏尺寸。

## 本次变更

- 首页路由和 DEBUG 直达入口统一使用轻量 `DailyClearanceEntryView`。方向准备期间仅有深色背景、准备提示与返回按钮，不创建 `FreePlayView` 或场景。
- 入口在 `viewIsAppearing` 请求横屏；导航已出现、系统旋转完成、window 和承载 view 均为横屏后，异步一次性交付准备完成，再创建球台。没有用固定延时猜测转屏结束。
- 方向控制器由入口持有，贯穿每日页整个生命周期。离页撤销尚未交付的回调，恢复竖屏；scene owner 防止旧控制器清理覆盖新入口的方向。
- 几何请求失败时有明确返回路径。角度训练沿用不带 readiness callback 的既有生命周期；普通自由击球没有引入横屏门控。

生命周期参考：[Apple viewIsAppearing](https://developer.apple.com/documentation/uikit/uiviewcontroller/viewisappearing(_:))。

## 验证记录

- 独立 iPhone 17 Pro / iOS 26.3 模拟器：`C2B99E8C-26C5-4ECD-8044-5164DCBED48C`。
- 项目 Makefile、现有 DerivedData、Debug `-O`、禁用测试并行。
- 修前基线首次查询仍使用历史 `dailyClearance.hud`，失败后核对当前源码：每日横屏使用 `dailyClearance.landscape`。基线失败不作为产品回归证据；录屏已实际到达目标页面，证明竖屏闪现。
- 新增原生用例：竖屏首页连续两次进入/切 3D/返回并检查草稿状态、竖屏 DEBUG 直达入口。
- 最终 `build/daily-entry-20261005/after-r2.log`：`Executed 2 tests, with 0 failures`、`** TEST SUCCEEDED **`。结果包：`build/daily-spin-setting-20261005/DerivedData/Logs/Test/Test-QiuJi-2026.10.05_16-32-14-+0800.xcresult`。
- 首轮 after 的首页重复进入用例通过；直达入口在“元素已存在但尚未可命中”时立即断言失败。保留失败日志 `after.log`，将测试改为有界等待真实 `isHittable`，产品代码未因此增加延时或放宽条件，最终两项通过。
- `app.screenshot()` 在设备物理方向竖屏、App 强制横屏时生成裁切图片；改为 `XCUIScreen.main.screenshot()`，8 张最终全屏图保存至 `output/daily-entry-20261005/after/final/`。逐张检查：两次进入均为完整横屏，2D/3D控件可达；两次返回首页均恢复竖屏且显示“继续清台”。
- 修后录屏 `after/home-entry.mp4` 与转场抽帧 `after/transition-detail.jpg`：先展示轻量准备页，转屏期间没有每日工具或球台；随后首次每日布局即为横屏。进入后的短暂场景首帧准备仍存在，本次没有宣称资源加载耗时归零。修前/后录屏属于实际模拟器屏幕取证，不使用成片合成。
- 角色切换：SwiftUI Developer → Test Engineer → UI Reviewer，由同一执行者完成。视觉审查仅覆盖本次入口、完整横屏和返回首页；相机构图及2D/3D内部切换专项属于其他任务。
- `make verify-doc-size` 最终通过（PROGRESS 99 KB / 当前状态7条）；新增进度使原文超100 KB时，已将最旧的中八开球研究条目原文移到状态归档，未提高门槛。本次文件 `git diff --check` 通过。

共享工作区还有其他每日HUD/渲染等变更。本任务代码范围仅为 `DailyClearanceEntryView`、两个路由接入、方向控制器生命周期，以及入口测试；不认领同文件其余差异。

边界：模拟器入口与截图证据不等于真机流畅度、冷缓存加载耗时或持续性能验收。


## r3：完整场景预加载（2026-10-05）

用户要求先做成预加载。此前只有模型原型/袋口数值缓存，仍在点击后同步搭建场景；本轮把每日场景本体、房间、材质、袋口标记与渲染资源准备移到启动后的 utility 后台任务。

- `DailyClearancePreloader` 最多保留一份未使用场景，入口消费同一份节点树，不 clone 后再重建。退出页面后准备下一份；进入后台/内存警告丢弃待用缓存，任务代次防止迟到回填。
- 不创建隐藏 SwiftUI/SCNView，不启动对局、计时、默认球形求解或播放循环；一次性 `SCNRenderer.prepare` 用于资源准备，`isPlaying=false`。使用中的场景由页面独占，释放缓存不影响它。
- 按房间/球桌/台呢/瞄准点/球面/球杆偏好快照识别过期缓存，后台构造完成后才交给主线程 VM；正常页面仍使用原初始化入口。共享法线贴图缓存和中性反射探针增加锁保护。
- 每日渲染诊断参数集中到 `configureDailyClearanceRendering`，预加载与旧直接构造采用同一配置；`setupScene(roomStyle:)` 接收此次准备的房间快照。
- r2 横屏显示门控保留，改为同时等待方向与预加载，首次冷启动立即进入仍可出现准备页。

API 依据：[Apple SCNSceneRenderer.prepare](https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare(_:shouldabortblock:))。资源 prepare 成功不等于最终页面首帧耗时归零。

### r3 验证

同一独立 iPhone 17 Pro / iOS 26.3 模拟器，Makefile Debug `-O`，未安装手机。

- 初验直达入口 1 UI 通过：`build/daily-preload-20261005/first.log`。
- 最终基础验收 `build/daily-preload-20261005/validation.log`：3 核心 + 2 原生 UI、0 失败，`** TEST SUCCEEDED **`。结果包 `build/daily-spin-setting-20261005/DerivedData/Logs/Test/Test-QiuJi-2026.10.05_16-56-20-+0800.xcresult`。
- 核心覆盖：预加载完成后消费、空闲场景没有球形/求解/开球/SCNView、不改变每日草稿、后续场景独立；取消与后台释放后的恢复、释放不破坏当前页面；准备后改变房间偏好重新构建。
- 原生入口覆盖：冷启动直达，首页保持“未开始”，两次进入、切3D、返回竖屏及恢复“进行中”。最终8张截图在 `output/daily-preload-20261005/final/`，已检查首次2D、再次3D及直达2D代表图，与r2截图对照没有新增布局退化。
- 原生录屏 `output/daily-preload-20261005/home-entry.mp4`，抽帧 `contact.jpg` / `entry-detail.jpg`：旋转期间显示轻量准备页，没有竖屏每日HUD；不能据此宣称每帧无空白或手机零卡顿。
- 本轮测试宿主的冷准备实测约7214ms（含资源加载/编译），同进程后续准备约296–528ms，缓存已就绪时移交约0.015ms。这是模拟器单次日志，移交耗时不是点击到首帧耗时，也不是手机测量；没有内存MB/持续耗电结论。
- `git diff --check` 和 `make verify-doc-size` 通过（PROGRESS 99KB/7条，hub 49KB/10条）。真实开球专项 `testLandscapeFirstManualBreakBecomesShootable` 通过（27.192s），`build/daily-preload-20261005/manual-break.log` 为 `Executed 1 test, with 0 failures` / `** TEST SUCCEEDED **`：手动开球、停稳直接交付、可再次出杆、切3D保留1杆状态。结果包 `Test-QiuJi-2026.10.05_16-58-45-+0800.xcresult`。本轮合计3核心+3不同原生UI通过。

本轮新增代码范围：预加载服务、App生命周期接入、入口VM注入与默认初始化分离、渲染配置归位/房间快照、两处共享缓存锁、3项核心测试及首页未开始断言。共享工作区其他HUD/相机差异不属于本轮。
