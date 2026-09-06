# SC28 音效与回放只读诊断

2026-09-06；基线snapshot-002。没有运行声音、UI、构建或测试，没有调用音频引擎/会话，没有写入素材。

## 已确认：当前缺全部四类音效资产

对冻结整个`QiuJi`目录枚举生产loader支持的caf/wav/m4a/mp3/aiff文件，**0个**，不存在包根备用样本。`QiuJi/Resources/Audio`只有：

| 文件 | 字节 |
|---|---:|
| CREDITS.md | 2752 |
| RECORDING-PLAN.md | 13952 |
| RECORDING-PLAN_副本.md | 13952 |

Audio目录存在不等于存在音效。CREDITS“已采用文件登记”仍是待填；冻结project.yml将Audio整个folder作为resource打包，这三份Markdown亦属于拟进包资源。当前不能执行真实音效文件解码，因为没有候选文件；不存在“解码测试通过”结果。

四类所需前缀为：杆击母球`sfx_cue_strike`、球碰球`sfx_ball_hit`、吃库`sfx_cushion`、落袋`sfx_pocket`。每类支持无序号以及_1…_6；扩展名优先caf/wav/m4a/mp3/aiff，先Audio子目录再包根。是7个候选名/类，不是任意同前缀文件都会加载。

**结论：冻结资产尚不能交付击球音效。** 这是内容准备缺口，不能由“动画运行/击球测试通过”“静音优雅降级”抵消。来源文档已注明待补录音，故不能把它误报为未知播放引擎故障。未用其他项目音频替代，也不新增素材。

## 实际执行链与回退

源码：Core/Audio/ShotSound.swift、ShotSoundBank.swift、ShotAudioScheduler.swift；App/QiuJiApp.swift；Data/Services/UserPreferences.swift；Features/Profile/Views/SettingsView.swift。

- UserPreferences.soundEffectsEnabled默认true，写UserDefaults.standard；Settings“击球音效”绑定同字段。此单例private init且无defaults注入，不能用伪隔离测试改shared然后声称不碰宿主偏好。
- App启动task延迟约0.5秒，仅开关true时调用ShotSoundBank.prepare。prepare先置isPrepared=true、加载样本、创建12个player node，再设置ambient+mixWithOthers并启动engine。**即使样本全缺，仍会进行音频会话/引擎初始化**，空资源并非所有音频代码完全不执行。
- ShotAudioScheduler.play先取消上一杆pending、检查开关/recorder，再prepare；cueStrike在0时刻，碰撞/吃库/落袋按prediction.events.time调度。强度由recorder速度近似归一，落袋固定0.7。
- bank.play再次检查开关/isPrepared/样本池；缺池直接return。未来排程在开关关闭后触发，也会被第二层guard阻止；但没有停止已在播放的buffer。
- loader对找不到文件、AVAudioFile失败、0帧、read/转换失败多数直接nil；没有逐文件错误记录。prepare catch仅记录prepare failed，且isPrepared提前锁定，不能靠再次prepare重载失败资源。
- canonical转换目标44.1kHz双声道float32。转换结果只排除.error，没有额外检查输出frameLength>0。当前无文件可验证该分支是否实发空buffer，不判已复现。
- bank重启路径仅在!engine.isRunning时try? engine.start，没有重设AVAudioSession.category/active；见下面生命周期风险。
- 注释称“同档轮换”但selectSample实为`Int(intensity * pool.count)`选固定索引；nextPlayer只轮换播放通道，不改变样本。同强度会选同一文件。这与多样本自然变化目标有实现差异，当前资产为空尚无听感复现。

## 静音/生命周期边界

| 情境 | 已查源码行为 | 未验证风险/限制 |
|---|---|---|
| 关闭设置开关 | scheduler与bank都在调度/入播放时guard | 不会主动stop正在发声player；需要真实短音效中途关闭的听感验证 |
| 一杆结束、重播/重置 | 多个VM在收尾或复位调ShotAudioScheduler.cancel | cancel只取消尚未执行DispatchWorkItem，不停已响buffer；听感尾音是否合适未验 |
| 硬件静音键 | prepare设置ambient | 当前无样本/无真机听测，不能宣称实际尊重静音键已验 |
| 组间休息后台保活 | RestTimerLiveActivityManager.activateBackgroundAudio设playback+mixWithOthers、启动临时静音caf；deactivate只setActive(false) | Audio Session是共享对象；未恢复ambient类别。bank.prepare已只运行一次，后续play也不恢复类别。**补样本后可能出现休息前后静音/恢复差异**，目前仅源码风险 |
| 训练缩小后进入工具 | AppRouter允许minimizedTrainingChrome存在时导航其他Tab；休息可仍活跃 | 音效注释“时段不重叠”不能当不变量。需真实路径核对休息状态与球桌音效共存 |
| 系统来电/路由变化/媒体服务重置 | 全QiuJi检索未找到相应notification监听；bank仅尝试engine.start | 来电后会话active/节点重建与耳机切换未验证，不据缺监听自动宣称必坏 |
| FreePlay离开/后台 | onDisappear主要停止dailyController，scenePhase分支仅每日清台flush/resume；Composer没有显式onDisappear音效cancel | 不能推定所有退出都会取消排程；全局scheduler可能保留未到时事件。需要实际中途离页/后台恢复测试 |

RestTimer调用来自ActiveTrainingViewModel组间休息路径（844–845激活；869–870/897–898结束停用），不是只有未使用类。没有实际调用该路径，本子任务没有生成rest_silence.caf。

## 现有精确白名单

**没有找到直接测试ShotSoundBank/ShotAudioScheduler/音效开关的现有方法。** 不用无关绿色单测充当音效验收。可补充与原速回放有关的两项只读纯计算：

- `QiuJiTests/TrajectoryPlaybackSettleTests/testPlaybackRunsToNaturalSettleNoTailTruncation`：手造recorder、stateAt及action.duration，无音频调用；验证自然停止时长而非耳听同步。此前正式B3若已同指纹通过，不必为了本审计重复跑。
- `QiuJiTests/TrajectoryPlaybackSpinTests/test_replayAfterReset_reproducesIdenticalPose`：内存SCNNode旋转积分两次一致，无渲染/音频/磁盘输出；不证明声音排程。

本次亲读这两方法及帮助代码，不白名单整目标/整制作套件，也不把RestTimer相关VM测试当安全无声音测试（可能激活音频会话）。V53ProfilePreferencesTests只见显示/法律/订阅/提醒等方法，没有soundEffects专用测试。

## 新增安全草稿（2方法，未运行）

`AudioResourceDiagnosticTests.swift`只读Bundle资源，AVAudioFile/PCMBuffer解码，不调用ShotSoundBank、ShotAudioScheduler、AVAudioEngine、AVAudioPlayer或AVAudioSession，不改UserDefaults。

1. `QiuJiTests/AudioResourceDiagnosticTests/testFourEventPoolsHaveAtLeastOnePackagedSample`：逐类要求至少一个当前loader可发现文件；缺资源明确失败，不将优雅静音当成功。当前冻结资产预期报告四类缺失，**这只是首跑预期，不是测试结果**。
2. `QiuJiTests/AudioResourceDiagnosticTests/testPackagedAudioSamplesDecodeToNonemptyPCM`：至少一文件，否则失败；逐样本AVAudioFile解码至PCM，4096帧分块读全文件，核对正帧数、format及完整解码。无空集合pass。只验系统解码，不复制生产canonical转换器或宣称声音听感通过。

测试必须在正确App宿主中执行，Bundle.main应是球迹.app；误注册到无宿主目标会测错Bundle。App宿主自身会按启动偏好执行prepare；测试代码没有音频输出调用，但**不能把测试方法无播放等同于整个宿主未初始化音频**。冻结0样本使其无真实音效可响。未来补素材后若要求连引擎都不启动，应专门配置宿主启动前soundEffectsEnabled=false，不在测试setUp之后才改shared来假装从未初始化。

## 后续应补的证据

先由主控把资产缺口登记，不自行制作。素材真实接入后，按四类确认文件解码/转换、预测事件时刻与声音同相、低/高强度、开关中途关闭、硬件静音、普通工具与休息保活切换、后台/来电/耳机恢复；需要设备与听感记录。当前视觉回放通过最多覆盖动作节拍与姿态，SC28不能标完成。
