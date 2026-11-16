# 球桌正式入口耗时实测（2026-11-15）

用户要求：实测“点进球桌”的完整耗时，定位慢点，先不改正式代码；本轮先完成模拟器。

## 结论与范围

首次进桌确实有明显等待。当前已确认的主要成本是进入时同步组装场景、首次环境反射生成，以及瞄准面板为台呢底图额外创建完整场景。缓存命中后重进显著变快，但每次仍重新应用球桌、球和灯光配置。11 月 12 日历史版本也存在这些主要成本；不能把整个首次等待归因于近期渲染优化。

仅为本机 iPad Pro 13 M4 / iOS 26.3.1 模拟器、竖屏 1032×1376 逻辑视口的定向诊断。没有修改正式 App 源码，没有安装或测试用户 iPhone，没有发布或提交。手机模拟器原评审现场保留。未覆盖全 App、全设备、无障碍或真机性能。

## 测量方法

- 使用真实首页入口：角度训练→走位→分离角与走位；训练→每日清台。没有用深链跳过导航。
- 每个轮次重启 App，第一次为“进程内资源冷启动”；随后返回原首页重进。没有清系统/Metal 驱动缓存，不能称为驱动冷启动。
- 起点为实际入口 action，另捕获 UIKit 的触摸按下/抬起时间。最终汇总同时给出“抬手点击→首帧回调”。XCTest 的 tap 返回、idle 等待不当作 App 时间。
- 首个完整内容帧指：主场景 onAppear 设置完成之后开始的首个 renderer 帧，其 didRender 回调完成。它是完整渲染提交回调，**不等于 GPU 完成或屏幕实际呈现**。之后还记录 DisplayLink 和控件业务就绪。
- 控件就绪条件：已收到上述内容帧，SCNView 在窗口中，shotControlsBusy/cameraTransitionBusy/isPlaying 均为 false。历史版本没有 shotControlsBusy，用 isComputing；本轮不调参/不拖动，比较的是初始静止入口。
- 每次进入后验证球桌舞台与返回按钮；每轮首次还实际打开菜单、验证展开后内容，再关闭返回。未击球，因此“击球守卫满足”与“已实际完成击球”分开。
- 录制完整模拟器画面，首轮截图已人工式视觉检查。画面复现：导航推入后先有控件和背景，稍后补出球桌。录像起点与 action 的 Unix 时间不是精确呈现同步，未用其冒充毫秒级 on-glass 计时。
- 所有诊断注入只发生在受管构建副本。Debug 使用项目既有 `-O`，不临时降画质/关光照/修改物理。相机模式由诊断只读偏好固定，不写永久设置。

## 已定位的阶段（R2 当前版、首次分离角与走位）

以下以入口 action 为 0；各行连续区间可相加，括号内子项不要重复相加。

| 阶段 | 时间区间 ms | 耗时 ms | 证据/解释 |
|---|---:|---:|---|
| 导航与 SwiftUI 宿主形成，直到 onAppear | 0–306 | 306 | makeUIView 在 274–283；此段还不是球桌 setup |
| onAppear 至主 ViewModel 准备完成 | 306–1100 | 795 | 主 scene.setup 732；袋口标记首次约 60 |
| 初始球形及页面状态完成 | 1100–1122 | 22 | loadBoard 18.7；本例 selectBestPocket 本身接近零 |
| 页面更新、任务被调度 | 1122–1246 | 123 | 尚未开始主 renderer 的首个完整帧 |
| 瞄准面板台呢底图 | 1246–1447 | 202 | 主线程创建第二个 AngleTrainingScene，完整 setup 178；再截图 |
| 主 renderer 首帧开始前余下调度/布局/准备 | 1447–1769 | 321 | 本轮没有把这段细分到唯一函数，不全归咎于 shader 编译 |
| 首个主 renderer will→didRender | 1769–1793 | 24 | renderer 回调范围，不等于独立 GPU 时间 |
| 后续 DisplayLink/控件业务就绪 | 1793–1795 | 2 | 正常初始可行球形、非播放/非计算/非相机过渡 |

主场景 732 ms 内已计入：球桌 78、参考灯光/材质 71、房间安装 207、同步环境反射 288 ms，以及其他配置。反射为六个方向和地面快照；第一个方向约 220 ms。以上是**包含关系**，不可再与主场景耗时叠加。

调用栈独立采样确认 `FreePlayView.onAppear → PositionPlayViewModel.setupScene → AngleTrainingScene.setupScene → RoomReflectionProbe.probe/bake → SCNRenderer.snapshot` 在主线程。其下可见纹理上传、SceneKit 管线准备/编译。另一支为 `BTAimCloseupHUD.task → TableFigureRenderer.closeupFelt/backdrop → AngleTrainingScene.setupScene`。调用栈轮有额外采样开销，只用来定位，不混入正常时长。

**物理不是本例的主要等待**：首例求解 6.4 ms，1252 ms 已在后台结束，到1464 ms才回主线程（等待211 ms），期间主线程正生成底图。每日清台对应一次后台求解约2.3 ms，主线程回传也等了约239 ms。

**重进仍有成本**：tableCache.hit/reusedTable=true，但主场景仍约186–190 ms。setupTable 约68–71 ms，灯光/材质约53–54 ms；复用模型不等于复用已组装可显示的整个页面。底图与反射缓存命中后其首次成本消失。首页的warmForEntry主要预载模型/外观资源，并不提前组装完整场景、房间反射和HUD底图，所以已经在首页停留也不能消除首次进桌等待。

**每日清台**：反射 bake 在后台约258 ms，不是主线程同步阻塞；但主线程场景416 ms、袋口标记约59 ms、首次 loadBoard102 ms，以及底图191 ms仍在入口窗口。后台反射952 ms结束、1172 ms才安装；异步任务完成同样要等主线程。重进完整内容帧约405–420 ms，控件业务就绪约900 ms；相机状态追加探针结果见下。

## 对“近期优化导致变慢”的判断

历史基线为 `259a2116bb084534f9546dd44b5fae72c1b0696a`（2026-11-12 15:15:44 +08:00）。历史 App/项目/配置的已跟踪源码来自 git archive；3412 个 QiuJi 已跟踪文件逐一哈希吻合。忽略的模型/图片等资源复用当前工作区，因此这是“历史代码 + 同资源”的对照，并非重现用户旧安装包。额外的新 Swift 文件未在旧 PBX 项目中引用。

当前默认材质、当前 referenceCloth 分支与历史版本必须分开。当前 reference 只是同包材质开关，不等于历史 App。模拟器实际 `staticField=false`、`ltc=unsupported-source`，没有覆盖真机上 C1/H9/H18 的完整优化路径，不能据此排除真机回退。

R2 首次分离角：当前默认1793 ms、当前 reference1686 ms、历史1737 ms。每种只有一个首次样本且顺序运行，不据这几十/百毫秒差异宣布稳定百分比回退。历史的同步反射264 ms、底图189 ms仍然存在；这些文件的相关主体没有近期变化。当前球形加载比历史多几毫秒到十几毫秒、材质准备也多若干毫秒，可以继续作为小成本检查，但解释不了整个1.7秒首次等待。

R3 回到当前版本的复测与完整数字汇总追加如下。

## 证据目录和测试有效性

- R1（探针预飞）：`output/local-test-runs/167c75df6d064be6a7cfaf614ac726bd/evidence`。6次UI进出通过，但首次探针被底图第二场景覆盖，首次完整帧缺失，**该首次不计入完整时长**。测试后Xcode附加诊断采集等待，保留记录后仅停止该作业自己的simctl diagnose；测试退出0。后续轮关闭附加诊断采集。
- R2（当前/同包reference/每日/2D/调用栈）：`output/local-test-runs/fabcfc0229b24a7ca757e80812754f12/evidence`。5个方法执行、12次进出；最后1次为归因采样，不作正常性能样本。
- 历史对照：`output/local-test-runs/7cef790985694c019fd8fecab79d858d/evidence`。2个方法执行、6次进出。
- R3为副本恢复遗漏导致的探针注入失败，未构建/未执行测试：`output/local-test-runs/65bdab43adc54682b9f5cd07bbab3a34/evidence`。失败保留，修订后另立R3b。
- R3b（当前回测+相机状态）：`output/local-test-runs/a9203831eec8494a8900855a22eaaf24/evidence`。
- 每轮含 test.log、原始 xcresult、安装包/构建包 SHA、原始事件 JSON、screen.mp4；汇总见 entry-summary.json。样本按该轮真实 action.wallUnix 落在 identity 起止区间过滤，避免累积Documents造成重复计数。
- R2 起每轮执行前冻结 research-source；R1脚本在原进程加载后曾演进，不能把当前脚本当成R1原版。R1 原始日志、源码哈希和当时UI探针保留。
- R2视觉附件由 xcresult 副本导出，原件未直接交给修改型读取。`visuals-r0/preview.png`与`entry-strip-15s.png`已检查，原始附件和视频保留。每日清台3D、分离角2D的全屏附件也已检查，实际姿态与设置相符。
- R2 结束逐文件核验正式 QiuJi 共6573个文件，和测前快照完全相同。宿主还有其他系统进程负载、驱动缓存未清，故小样本不代表精确回退比例。

## 后续修复优先级（仅建议，本轮未实施）

1. 把瞄准面板底图的完整场景创建移出首次可见路径，评估共享既有渲染结果或独立预生成；保持颜色、材质与生命周期合同。
2. 分离角入口的反射与房间准备从主线程关键路径拆开，并测首帧材质完整性，避免先灰后亮或新的纹理尖峰。
3. 缓存命中后减少重复球桌/灯光配置；不能只看USDZ缓存命中。
4. 相机仍过渡时明确区分“画面已经出现”和“击球可操作”，审查是否必须阻止所有相关控件；不直接删动画绕过交互合同。
5. 剩余首帧前321 ms需更细的逐阶段trace；真机优化路径需另行实测，不能从本轮模拟器推断。

## 源码定位

- [FreePlayView.swift:567](../../QiuJi/Features/PositionPlay/Views/FreePlayView.swift#L567)：onAppear配置及同步setup。
- [AngleTrainingScene.swift:510](../../QiuJi/Core/Scene/AngleTrainingScene.swift#L510)：命中球桌缓存后仍恢复外观、球与球杆。
- [RoomReflectionProbe.swift:327](../../QiuJi/Core/Scene/RoomReflectionProbe.swift#L327)：同步probe缓存未命中后bake；每日走异步路径。
- [TableFigureRenderer.swift:69](../../QiuJi/Core/Scene/TableFigureRenderer.swift#L69)：closeupFelt→backdrop缓存未命中时创建完整场景。
- [BTAimCloseupHUD.swift](../../QiuJi/Core/Components/BTAimCloseupHUD.swift)：task请求台呢底图。
- [PositionPlayViewModel.swift:246](../../QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift#L246)：自动选球/镜头请求与cameraTransitionBusy。

TP01/15/16/17/29/30继承当前页面入口、状态与返回合同；TP35本轮分列真实UI、阶段计时、视觉、真机未验。未改变页面布局/菜单/偏好/生命周期，不宣称全TP或跨设备验收。

## 完整数字汇总

以下均为毫秒；点击起点用UIKit抬手事件，后两列已包含触摸到action的4.9–17.8ms。首入为每轮独立App进程第一次进入；重入为同轮第二/第三次。R2 stacks仅归因，不进入正常汇总。

| 版本/分支 | 页面/模式 | 次序 | action→完整帧 | 点击→完整帧 | 点击→控件就绪 |
|---|---|---|---:|---:|---:|
| R2/default | 分离角/3D | 首入 | 1792.9 | 1802.8 | 1804.5 |
| R2/default | 分离角/3D | 重入1 | 484.7 | 501.5 | 502.9 |
| R2/default | 分离角/3D | 重入2 | 413.4 | 429.8 | 465.8 |
| R2/reference | 分离角/3D | 首入 | 1685.7 | 1701.1 | 1716.1 |
| R2/reference | 分离角/3D | 重入1 | 390.8 | 406.8 | 448.7 |
| R2/reference | 分离角/3D | 重入2 | 379.9 | 394.0 | 395.3 |
| R2/default | 每日/3D | 首入 | 1583.6 | 1594.7 | 1793.8 |
| R2/default | 每日/3D | 重入1 | 404.9 | 409.8 | 904.5 |
| R2/default | 每日/3D | 重入2 | 420.2 | 427.3 | 906.6 |
| R2/default | 分离角/2D | 首入 | 1660.5 | 1676.0 | 1678.0 |
| R2/default | 分离角/2D | 重入1 | 391.1 | 408.1 | 430.7 |
| 历史/default | 分离角/3D | 首入 | 1737.1 | 1745.6 | 1747.0 |
| 历史/default | 分离角/3D | 重入1 | 411.4 | 418.2 | 472.9 |
| 历史/default | 分离角/3D | 重入2 | 398.9 | 416.7 | 467.2 |
| 历史/default | 每日/3D | 首入 | 1558.0 | 1574.4 | 1782.5 |
| 历史/default | 每日/3D | 重入1 | 400.1 | 413.8 | 879.8 |
| 历史/default | 每日/3D | 重入2 | 365.5 | 380.0 | 863.8 |
| R3b/default | 分离角/3D | 首入 | 1833.5 | 1842.6 | 1844.3 |
| R3b/default | 分离角/3D | 重入1 | 381.2 | 398.6 | 400.1 |
| R3b/default | 分离角/3D | 重入2 | 405.7 | 422.8 | 466.5 |
| R3b/default | 每日/3D | 首入 | 1593.0 | 1604.7 | 1811.2 |
| R3b/default | 每日/3D | 重入1 | 417.0 | 426.0 | 908.5 |
| R3b/default | 每日/3D | 重入2 | 416.0 | 423.8 | 907.3 |

当前默认（R2+R3b）分离角点击→完整帧首入 **1803/1843ms**，同进程重入 **399–502ms**；每日首入 **1595/1605ms**，重入 **410–427ms**。每日点击→控件就绪首入 **1794/1811ms**，重入 **904–909ms**。当前2D首入1676ms、重入408ms，同样承担完整SceneKit准备成本。

历史分离角点击→完整帧1746ms、重入417/418ms；每日1574ms、重入414/380ms。当前冷首入相较此历史样本多约57–97ms（分离角）/21–30ms（每日），但冷样本少、状态非完全受控，不能当稳定回退比例或归因到某一个提交。明显的1.6–1.8秒大头和每日相机门控在历史基线中已经存在。

### 每日相机等待的直接证据（R3b）

两次重入的camera.request在250ms左右，主求解在342/344ms回传；完整帧416/417ms。首次后续控制状态记录449ms为shotBusy=false、playing=false、cameraBusy=true、rigTransitioning=true。camera.transitionEnded在883ms，899ms下一DisplayLink读到cameraBusy=false、rigTransitioning=false并记录controlsReady。因此后半段额外等待已直接定位到自动相机过渡，不是物理解算还没完成。首次同样1595ms只有cameraBusy为真，1783ms过渡结束、1799ms业务就绪。

相机使用SurfaceMotion的速度时钟，不能把观测的约0.48秒尾段误称为固定500ms延时；这段已经与前面的场景/首帧准备重叠，不能把整段相机时长再加到总耗时。

R2/R3b/历史共9次方法执行中的正常时长取23次进出（R2还有1次独立归因采样）；再加R1预飞，整轮共10次该UI方法执行、30次进出，无UI失败/skip。R3注入阶段失败没有运行测试，单独保留。各次都实际开关菜单、返回到入口。没有性能门槛断言，测试绿灯只表示流程和证据采集通过，不表示耗时达标。

## 收尾

10次实际方法执行均从test.log核实Executed 1 test、0 failures及TEST EXECUTE SUCCEEDED；未生成JUnit XML，不列为证据。全量事件汇总见[measurements.json](measurements.json)，作业/测试/设备收尾见[verification.json](verification.json)。R3b再次核验正式QiuJi 6573个文件与冻结前完全一致。受管模拟器已关机释放；R1暂留构建和R3失败工作目录均经生命周期complete回收，原测试结果/失败退出码仍保留。

测量完成并已定位主要阻塞，尚未修复：首帧前剩余调度/布局准备未细分到单函数，真机完整优化路径未测。后续若实施，先处理主线程反射与辅助底图场景，再验证首帧完整性和内存生命周期；本轮不据此直接合入改动。
