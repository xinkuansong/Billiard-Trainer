# v63 2D/3D 入口补审（2026-09-15）

用户询问是否漏页；本记录来自当前生产源码/实际路由审计，不把源码接入视为全平台验收。

| 页面 | 当前接入 | 证据 |
|---|---|---|
| 翻袋解球器、反射解球器 | **已接入，真机/SE定向验收通过**，共享容器页内切换 | `SolverStageChrome` 使用 VM cameraMode binding，3D 相机手势/观察菜单/透视布局；两页复用同一实现（DR-307） |
| 角度训练 2D/3D、瞄准点训练 2D/3D | 两套 route 均存在，但页内固定机位，不能当前题无损切换 | `App/MainTabView.swift` 四分支；`SceneAimingView` / `AimPointSceneTrainingView` 使用 let cameraMode 与 constant binding。路由注释明确成绩分记，合并切换前必须保留成绩归属契约 |
| 自由击球、每日清台 | 有页内切换，共用 FreePlayView | ShotPlayCamera.setMode；本轮真机已验自由击球，每日清台本轮未跑 |
| 分离角与走位 | 有页内切换 | ShotSimulationView + ShotPlayCamera；本轮真机已验 |
| 自由走位/编排、动作库试打 | 有页内切换，共用 PositionPlayComposerView | cameraMode binding / cameraIdentifierPrefix；本轮真机已验试打，完整编辑本轮未跑 |
| 思路训练、打一走二想三、防守 | 有页内切换 | SiluTrainerView / PlanThreeView / SnookerTacticsView 修改 vm.cameraMode；本轮手机 UI 未逐页验证 |
| 角度与瞄准、分离角图谱、加塞吃库图谱 | 有页内切换 | AngleDynamicView / SeparationAngleAtlasView / CushionEnglishAtlasView 的 cameraMode 按钮；本轮手机 UI 未逐页验证 |
| 动作详情、训练记录球台 | 有共享切换 | DrillDetailView / DrillRecordView → DrillSceneView 的 2D/3D 按钮；本轮真机已验详情 |

初始审计：两页确实未接 3D，本轮已开始补齐；另两种训练页是独立入口固定模式，不等于缺少对应 3D 页面。原 W00 页面族表未包含翻袋/反射两页，应补入验收范围。纯理论图解/二维拖圈答题不直接认定为漏接球台页。

用户继续授权后补齐翻袋/反射，已完成真机改前/改后截图、模型与页面定向验证。页内训练模式切换涉及原成绩分记规则，不能通过重建题目或重开会话伪装无损切换。


## DR-307 验证轨迹

- 真机 iPhone 16 Pro / iOS 26.6.2，Debug -O、coverage NO。
- 改前：mode-before.log / Test-QiuJi-2026.09.15_00-37-21-+0800.xcresult，1 UI 用例通过，2 张原图已目视（mode-before-attachments）。
- r1：mode-after-r1.log / Test-QiuJi-2026.09.15_00-41-09-+0800.xcresult，两模型不变量通过（2.710s / 0.857s）。两 UI 因通用 helper 查找 spinPad.card 失败；失败控件树证明此页卡片为 Other solver.spinPad（336×170.3pt），与关闭背景 Button 同名。只修测试定位，保留所有尺寸断言。改前、全桌、旋转与瞄准截图已采集，代表原图已审。
- r2：两 UI 通过（70.326s / 66.357s），Test-QiuJi-2026.09.15_00-44-16-+0800.xcresult；包含求解击打/上一杆与自由击球/上一杆。16 张原图导出至 mode-r2-attachments。目视发现 3D 空杆文案仍提示拖动台面，已改为用刻度轮；不改变 2D 文案，追加模式文案断言。最终 r3 已通过：两模型 2.620s/0.861s，两 UI 65.570s/66.775s（共4项、0失败），Test-QiuJi-2026.09.15_00-48-34-+0800.xcresult，mode-final-r3.log；16张最终截图导出 mode-final-attachments，已目视全桌/打点/停稳修正文案/返回2D代表原图；小屏首轮在编译期因该修正主动中止，不能记通过。
- 本轮产物统一位于 output/3d-v63/device-20260914/，xcresult 位于 build/DerivedData-v63-device/Logs/Test/。

- 小屏 SE/iOS26.3/large/dark：r2 两 UI 通过（68.503s/64.673s），Test-QiuJi-2026.09.15_00-51-42-+0800.xcresult。16 张图原图复核发现翻袋解说明尾部省略（U-02），改为仅两页允许两行说明，其他消费者单行默认不变；重跑小屏 r3 和真机最终版。系统产生4条 _UIReparentingView 诊断附档，未出现流程失败；不据此宣称系统无警告。

- U-02 r3：lineLimit(2) 单独设置仍被原生导航栏压成单行，保留 r3-bank-truncated.png 后主动中止；r4 增加仅多行状态的 fixedSize(vertical:true)，不更改默认单行消费者。

- U-02 小屏 r4：两 UI 通过（66.458s / 65.267s），Test-QiuJi-2026.09.15_00-58-23-+0800.xcresult；16张最终750×1334截图位于 mode-compact-20260915/final-attachments。已目视2D/3D全桌与打点展开原图，完整解序号可见，操作行与母球未被导航说明挤压。真机同布局最终 r4 复验中。


## 本次交付（2026-09-15 01:04）

- 真机最终 UI r4：2项通过（72.592s / 67.311s），mode-final-r4.log，Test-QiuJi-2026.09.15_01-01-25-+0800.xcresult。16张最终截图位于 device-20260914/mode-final-r4-attachments；已目视全桌、完整导航说明、打点展开、空杆文案与返回2D代表图。01:04:36 已无测试参数正常启动手机 App。
- 小屏最终 UI r4：2项通过（66.458s / 65.267s），mode-compact-20260915/final-r4.log。16张最终截图已导出并目视，750×1334；真机为1206×2622。各自16个唯一PNG，不用旧轮图片补数。
- 模型最后一次验证为真机 r3 两项通过；此后只改导航说明布局，VM/相机业务逻辑未变。合计2模型+4最终UI定向回归通过，功能与视觉分开验收。
- verify-gate（mode-final-gate-r4.log）FAIL0，verify-doc-size、git diff --check通过。最终源码指纹见 mode-final-r4-source-sha256.json。
- 本次两页补齐完成；W16/v63整体仍未结项。后续继续完整平台、最大字号/VoiceOver、持续性能验收；角度/瞄准点训练仍独立模式入口、成绩分记；扎杆/跳球延期。未提交/推送。


## 2026-09-15 续验：iPad / iOS 17 最大字号

本轮只执行既有 DR-307 用例，没有修改生产代码或测试断言。两个平台均通过 `scripts/Makefile test` 串行执行，`TEST_CODE_COVERAGE=NO`、`SWIFT_OPTIMIZATION_LEVEL=-O`；实际命中 `S2_ShotPagesLayoutUITests/testV63BankCameraModes` 与 `testV63ReflectionCameraModes`，每组 2 项、0 失败，命令退出码 0。

| 平台 | 配置 | 翻袋 / 反射耗时 | xcresult |
|---|---|---|---|
| iPad Pro 13 M5 / iOS 26.3.1 | 5EA7F427-A49B-41E3-80CF-02FD9D5A93C6；large | 69.645 / 67.360 s | `build/DerivedData-v63-w17c/Logs/Test/Test-QiuJi-2026.09.15_01-16-40-+0800.xcresult` |
| iPhone SE / iOS 17.0 | 51383D5F-38C6-4D36-9FBF-B9B622AE45C7；accessibility-extra-extra-extra-large | 51.345 / 49.380 s | `build/DerivedData-v63-w17c/Logs/Test/Test-QiuJi-2026.09.15_01-19-39-+0800.xcresult` |

证据根：`output/3d-v63/mode-platform-20260915/`。每组 `test.log`、`runner.log`、`attachments/manifest.json`、`image-check.json`、`contact-sheet.jpg` 独立保存。iPad 16 张 2064×2752、SE 16 张 750×1334，均可解码、每组 16 个不同 SHA-256；两组联系表逐状态审查，并打开各组全桌与打点面板代表原图，未见本轮新增控件截断、模式按钮遮挡或空白场景。iPad 的 4 个 `_UIReparentingView` 诊断附件保留，不能将诊断附件计作截图。

系统 appearance=light、字号均设置后回读；实际场景页由 `SolverStageChrome.preferredColorScheme(.dark)` 固定深色，因此此记录不是页面浅色主题通过证明。模型各自 setup 固定球形；外观沿用设备偏好（iPad 轨迹全、SE 轨迹双），不将两设备图片作为同外观像素对拍。源码指纹覆盖 App/两测试目标 Swift、project.yml 与 Makefile，运行后无漂移。

已覆盖：下一解后 2D/3D 往返保留状态、拖动旋转和缩放、四个观察目标、翻袋独有目标袋菜单、打点面板、求解/自由击球、播放中切换和上一杆恢复。系统最大字号可操作不等于真正 VoiceOver 手势通过；其增减动作交付、持续性能/内存/热验收以及 v63 其他未闭合项继续保留。手机仍连接，本轮没有重新安装手机（生产代码未变）。
