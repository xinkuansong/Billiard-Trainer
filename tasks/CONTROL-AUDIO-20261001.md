# 瞄准条与力度条刻度声（2026-10-01，DR-336 r4）

当前为r6第一版：用户提供direction.mp3瞄准/power.mp3力度，已处理、安装并启动到iPhone；15音频单元通过，UI回归在拖动前等待击球按钮超时，真机听感待用户反馈。第二版已准备未切换。r4/r5为历史，最新结果见末尾r6节。

## 需求与根因

用户报告两尺滑动没有声音。BTAimWheel、BTShotInstrumentColumn原来只调用UIImpactFeedbackGenerator；现有ShotSoundBank只播放物理事件资源。接入共享组件，覆盖其所有消费页；不改参数连续性、自适应增益、视觉刻度或松手不击球契约。

## 实现

- 原创12ms机械点击PCM，44.1kHz立体声，无外部录音与运行时文件读取；复用AVAudioEngine/ambient会话。
- 独立AVAudioPlayerNode，不占用球碰撞的12声部池。
- 有效刻度与力度到边界时发声；沿用精度切换重设起点、边界滞回和100ms限频，声音不由震动标志控制。持续顶住边界、停手、松手和缩放刻度不发声。
- 沿用设置中的「击球音效」和手机静音模式；默认关闭和用户保存选择保持。后台、关闭音效或非法强度不播放，已有取消路径同时停止操作声。

## 功能验证

设备：独立QiuJi-AdaptiveR2-20260928 / iOS26.3，UDID F9FEA63A-BD84-47DE-BDF5-D60B20081A0B；最终构建独立DerivedData，避免与另一个会话共享构建数据库。

- `unit.log`：首次28单元，0失败。
- `final-isolated.log`：最终生产代码构建，28单元0失败；既有2D/3D快慢调节原生UI回归1项通过。
- 新UI用例首轮在瞄准触发异步预测后立即检查击球按钮，断言时预测未完成；保留原失败。按现有交互契约等待预测完成，未改生产代码或放宽断言。
- `ui-r2.log`：新UI用例1项通过，完整覆盖启用/静音×2D/3D的力度/瞄准原生滑动。
- `playback-isolated.log`及`log-check.json`：启用进程19800，力度7次/瞄准16次，最短间隔110ms；引擎route=Speaker、音量0.60。静音进程19837同样拖动，播放次数0。
- `gate-r2.log`：verify-gate通过，FAIL0；新增测试写盘面已登记，仅build目录试听/截图证据，不写产品资源。`doc-size-r2.log`通过；三条旧当前状态完整移至既有归档，未删除内容。git diff --check通过。
- 首轮共享构建数据库被另一个会话锁定，`final.log`保留；改独立目录后无此故障。

合计最终28单元+2原生UI通过。播放调度与扬声器路由不等于主观听感验收；手机静音开关实测、音色/响度和震动同步仍待用户试听。

## 视觉审查

已打开最终启用2D/3D原图，左右刻度条、力度读数、相机控件和击球按钮完整可见，无本轮布局改动；静音与启用四图保存在`build/control-audio-20261001/ui/`。此次未改视觉，不宣称全项目视觉矩阵或真机画质验收。非目标页/辅助字号/iPad未重验。

## 用户追加：金属齿轮滚动质感

用户希望有质感的金属齿轮滚动声。先制作两段本地合成方向试听，不调用收费服务，不替换当前App点击样本：

- `build/control-audio-20261001/metal-precision-preview.wav`：精密金属滚轮方向，4.4秒。
- `build/control-audio-20261001/metal-ratchet-preview.wav`：较厚重棘轮方向，4.4秒。

试听用加速/减速点击展示金属共鸣与滚动感，最密60ms（约16.7Hz）；目前App仍100ms（10Hz）上限。若用户认可滚动方向，下一轮须将音频节奏与现有100ms触感限频分开调校并按有效位移驱动，停手不继续滚动；不能直接循环整段试听或把音调随滑速改变。两段合成声音均未进行人耳质量验收、未作为真实金属录音。

## r5 — 用户授权金属音色替换（2026-10-01，历史版本）

用户“替换下吧”已授权前述搭配：瞄准用A精密金属滚轮，力度用B厚重棘轮。已将原试听的首个单次齿声提取至Audio/ui_aim_metal.wav（1411帧，约32ms）与ui_power_metal.wav（1764帧，40ms）。去除试听0.68增益后重施增益，与原首个齿声误差≤1个16位PCM量化单位。正式资源SHA-256与App Bundle中的文件一致；不受Debug物理音效导入覆盖。

音频与原震动分开限频：声音最短60ms，触感仍100ms；同一有效位移可触发声音而不必触发额外震动。声音仍依赖有效刻度跨越，停手/缩放刻度/持续顶住边界不连响；不循环4.4秒试听、不随滑速变调。原开关、硬件静音模式与连续参数写回契约保持。

验证目录：`build/control-metal-20261001/`。

- `final.log` / `final.xcresult`：最终生产构建，29单元+2原生UI，全部0失败，TEST SUCCEEDED。
- 单元验证两种真实Bundle资源可解码、非静音、不同波形、有短淡出、在下一个允许齿声前结束；音频60ms/触感100ms、停手不排队与缩放无误触的行为测试通过。
- 两项原生UI覆盖启用/关闭×2D/3D两尺调节，以及既有快慢精度、松手不击球、数值连续性。
- `playback-full.log` / `log-check.json`：启用进程21298，瞄准12次/力度13次，分别使用ui_aim_metal/ui_power_metal；静音进程21316，同样拖动播放0次。日志核对每次映射正确、间隔≥60ms。
- `assets.json`：来源/正式资源哈希；正式Bundle两文件哈希一致，现有Audio folder reference已打包，无project.yml或Xcode项目变更。
- `gate.log`、`doc-size.log`与git diff --check均通过。
- 已打开此次最终2D/3D启用截图，左右尺、数值及击球按钮完整；四状态截图复制至此轮ui目录。未改视觉或确认真机画质。

替换及本地回归已完成，真机听感/硬件静音开关/触感同步仍待验。尚未安装手机、提交或发布；前一轮试听音频、原失败日志和xcresult保留。

## r6 — 用户原声逐版试用（2026-10-01，当前第一版）

用户提供direction.mp3/power.mp3和direction-v2.mp3/power-v2.mp3，要求一个版本一个版本试。第一组现已替换App包内两种操作声，并安装/启动到已连接iPhone；第二组仅预处理，未激活。

处理交付在`output/control-sounds-user-20261001/`：sources保存四个原始MP3；previous-metal-r5保存原App两WAV；v1/v2分别保存单齿资源和3秒滑动试听。manifest.json登记源/输出哈希、切点、增益；process.py可复现处理，activate-version.py校验哈希后切换两文件，active-version.txt当前为1。

第一版保留direction的0.369–0.413秒和power的0.202–0.246秒，均约44ms完整单齿；去DC、0.5ms淡入/3ms淡出、峰值0.25，44.1kHz/16bit/stereo。没有变调、EQ或压缩，保持现有60ms声/100ms震动及位移触发机制，本轮不改Swift生产代码或测试。第二版约56ms/51ms也已处理，但用户反馈前不替换。

验证目录`build/control-user-v1-20261001/`：

- test.log/test.xcresult：15项ShotAudioTests全部通过；资源解码、峰值、首尾淡出和区分两音色通过。随后UI用例在第一次拖动前等待dailyClearance.strike.enabled超时，未执行拖动，不能计为声音开关/2D/3D回归通过。
- ui-optimized.log/ui-optimized.xcresult：以-O重跑同UI，仍在同一拖动前断言超时。保留失败，根因未证实；未通过放宽断言或修改不相关业务来掩盖。r5通过记录属于历史，不代替本轮UI证据。
- device-build.log：Makefile build-device-profile成功，Debug/-O；使用独立DeviceProfile构建目录，编译当前共享工作树，未回退其他会话修改。
- bundle-hashes.json：本轮模拟器和真机App Bundle两资源与v1清单SHA-256一致。
- install.json/launch.json：iPhone原位安装成功、App激活成功，进程2624；启动参数仅-soundEffectsEnabled YES，为本次启动临时启用音效；未使用清空训练/重置/夹具/强制会员参数。尚未由用户实听验收，硬件静音仍遵循既有ambient设置。
- gate.log：内容/发布图/双端/术语门禁通过；整体verify-gate被测试写盘面登记漂移阻塞：extra=QiuJiTests/PocketMarkerHighlightTests.swift，该文件属于并行修改，未在本轮改动或替其登记。

本轮verify-doc-size及git diff --check通过。

下一步：用户试第一版后反馈，再使用已处理的第二组切换、构建与安装；这轮保持第一版。未提交或发布。
