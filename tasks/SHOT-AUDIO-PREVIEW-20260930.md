# 本地 App 音效试听 — 2026-09-30

## 本轮裁定

用户采用「明显换色」并同意各力度以音量实现；碰库保留已认可的极柔音色。每类一个底样，运行时不变调，不新增四份仅音量不同的文件。

| 事件 | 采用底样 | App 文件 |
|---|---|---|
| 杆击 | C03 明显换色 | sfx_cue_strike.caf |
| 球球 | B04 明显换色 | sfx_ball_hit.caf |
| 碰库 | U02 中（已认可极柔原版） | sfx_cushion.caf |
| 落袋 | P03 明显换色 | sfx_pocket.caf |

资产在 `output/shot-audio-preview-20260930/ShotAudioPreview/`；同级 prepare.py 可重建，manifest.json 保存来源、时间点、输入/输出 SHA-256、规格、峰值。48kHz/24bit原样本留在 Downloads。输出44.1kHz、mono、signed16bit CAF；本次只重采样，保留已认可的电平、包络和换色处理。极柔碰库的慢起音为有意设计，不按原实录规范强行削成硬瞬态；各类不统一拉到 -3dBFS。

## 初版播放规则（由下方 R2 替代）

- 参考速度4.5m/s，归一力度 `i=clamp(speed/4.5,0,1)`。
- 音量 `sqrt(i)`；库边再乘0.6，落袋乘0.85。零、负、无效力度静音。
- 球球取相对速度在连心线的投影；碰库取速度在引擎真实接触法线的投影；落袋优先取捕获前快照速度。
- recorder事件同刻通常已经解算，取严格早于事件的速度；球球位置取事件后首帧。密集同刻碰撞仍是录制帧近似，不是精确冲量；低速进袋可能偏轻，待实听调整。
- 12 player重叠播放，节点轮换不代表样本轮换。取消后通过代次标记挡住旧排程。保留系统静音、混音和设置开关。
- 保留现有全App接入路径，未调整运动解算或击球结果。

## 安装与试用

Debug启动参数 `-shotAudioPreview` 才从 App Documents/ShotAudioPreview 读取。试听资产不放入发行Bundle。Release没有该读取分支；保留视频来源，不登记成自录/CC0。T-P14-07授权录音与T-P14-08真机验收仍待完成。

模拟器：构建并安装后，用 `xcrun simctl get_app_container <UDID> <bundle-id> data` 找到沙盒，把四个CAF复制到Documents/ShotAudioPreview，再带 `-shotAudioPreview -soundEffectsEnabled YES -forcePremium -deeplink.dailyClearance` 启动。音效默认偏好不变；命令行YES只用于本次试听进程。

真机计划：使用同一Debug构建；通过Xcode设备容器导入同名Documents目录，Scheme加试听参数，App设置打开击球音效。先用扬声器，再耳机验证。

## 听感验收顺序

1. 每日清台：轻推、中力、重击各3杆，注意小力度是否丢声、大力度是否刺耳。
2. 同速度厚碰/薄碰，垂直撞库/擦库：后者应更轻，碰库音色始终柔和。
3. 慢进袋/快进袋，确认响度与落袋画面自然同步。
4. 开球、多球连续碰撞、连打10杆：检查叠音和重复感。
5. 回放中复位/离开页面、关闭音效、静音键、耳机听音乐：检查残留触发与混音。

自动检查不能代替真实听感。当前只做本地试听，不发布。

## 验证记录

- 最终 Debug 测试构建成功，5项 ShotAudioTests + 1项实际每日清台 UI 测试通过（0失败）。日志 `build/shot-audio-final-tests.log`。
- 初次页面测试发现启动参数 YES 为字符串，旧偏好 `as? Bool` 读取失败；改为 `bool(forKey:)` 后复跑，新增默认关闭/字符串开启回归。初次无声音效日志不计作接入成功。
- 最终运行日志确认四类各加载1个已转换PCM buffer。真实页面击球触发 cueStrike 和两次 cushion（gain 0.363→0.245）；本轮真实页面未覆盖球球和落袋触发，二者只确认加载。
- 最终截图 `output/shot-audio-preview-20260930/app-after-shot.png` 已打开核验；初次系统账户提示曾遮挡，最终截图无该弹窗。
- `make verify-gate`、`make verify-doc-size`、`git diff --check` 通过。未改物理解算，ShotEvent只增加可选呈现法线，两处事件转录保留原法线。
- 待办：真机四类触发和听感验收、开球叠音、静音/蓝牙、连续10杆；没有主观试听结论，没有提交/发布。

## 真机安装 — 2026-09-30 15:33

用户授权后，`make build-device-profile` 成功，优化Debug安装到已连接的 iPhone 16 Pro。四个CAF经 devicectl 导入 Documents/ShotAudioPreview；安装后再次列目录确认保留。启动 `-shotAudioPreview -soundEffectsEnabled YES -deeplink.dailyClearance`，控制台确认四类各加载1个样本。未重置手机用户数据，未发布。构建/控制台日志：`build/shot-audio-device-build.log`、`build/shot-audio-device-console.log`；安装记录：`output/shot-audio-preview-20260930/device-install.json`。用户现在可试打；实际听感等待反馈。试听参数限本次启动，手动彻底退出再打开需要重新带参数启动。

## R2：接触驱动与开球 — 2026-09-30

用户反馈开球无声、力度不细、所有进球响袋后，授权实施。

### 当前规则

- 普通击球与 `BreakFlowRunner` 开球共用调度器，在实际出杆运动起点启动。杆击保留输入杆速；球球取接触前双方相对速度的法向分量，库边取接触前朝向表面的法向速度。数值是速度，不冒充实测声压或冲量。
- 默认 `planarReference` 引擎在实际解算点写入纯值 `ContactSoundEvent`，不再以旧录制帧估算密集碰撞。直库、袋角、内衬分别标注；分离/纯切向接触不产生正强度。
- 规则捕获事件本身静音。`PocketNetPresentation` 在原有下落轨迹的内衬接触、支架落地、末端停止处记录时间和速度。已有球占位时末端声改为较轻球球声。重复 attach 替换记录，不重复累加；支架队列的管理性移位不额外造声。
- 八种事件各有连续平滑速度曲线，轻擦更轻；杆击/球球延伸到 10 m/s，不在 4.5 m/s 后全部同响。具体标定点在 `ShotSound.swift`，属于本地试听参数。
- 保留12声部；空闲优先，满载时较强接触可替换最弱声部，弱接触不截断强接触。按各样本峰值预留混音余量。
- 取消排程同时停止正在播放的节点；关闭音效、App非活跃时取消。正常杆末仍遵守原有可见支架收尾。

### 素材和边界

| 接触 | 当前底样 |
|---|---|
| 杆击 / 台面球球 / 直库 | 原 C03 / B04 / U02 |
| 袋角 | `sfx_jaw.caf`，暂时复用 U02，独立曲线 |
| 内衬接触 | P03，沿用 `sfx_pocket.caf` |
| 支架承接 / 挡头 | `sfx_rail.caf`，暂时复用 U02，独立曲线 |
| 袋下已有球 | B04，较低增益 |

六个CAF的来源及哈希已登记 manifest；prepare.py 同步可重建。新增别名不是新录音。P03仍是原视频处理样本，未证实为完全独立的单次内衬撞击；其尾音及重复触发听感需试听。已有袋内动画是承接近似，尚未实现自由的袋内多球堆积物理。实验性 `localPockets` 路径保留旧事件估算，不声称已经接入精确接触元数据；本次真机默认仍为 `planarReference`。滚动摩擦连续底噪、跳球落台、故障击球音色和视频导出音轨未在本轮新增。

### 验证

- `shot-audio-r2-regression.log`：59项，58通过、1项原有可选GPU测试跳过、0失败。包括12项音效测试、22项袋内呈现回归和25项开球流程测试（其中1跳过）。
- 固定15球开球测得70次有效接触，其中47次球球；六袋慢入口、落地速度、已有球、重复构建与仅规则捕获静音均有断言。
- 最后界面回归、真机构建/安装结果见后续记录。自动检查证明流程和事件契约，不代表主观听感已验收。

### R2 页面及首次真机复核

- `shot-audio-r2-ui.log`：12音效单测和2页面UI测试通过。已核验开球后截图；同次模拟器日志出现 cueStrike、ballHit、cushion、jaw、pocket（内衬）、rail、railStop，未出现 pocketBall，后者仅有单测证据。
- 首次真机R2安装/六CAF导入成功，八种事件各加载一个样本；但随后出现 `Session activation failed`，因此这次只计资源加载成功，不能计音频引擎启动成功。补充前台检查和回前台激活重试，资源节点仍只创建一次；启动失败不永久锁死播放。UI开球用例加入先退到桌面再回App流程。
- 写盘门禁首次提示新增试听UI测试未登记；已补测试输出路径、覆盖/数据污染说明，门禁复跑通过。

### R2 最终交付 — 16:07

- `shot-audio-r2-final.log` 最终12音效单测+2页面UI测试全部通过，包含退到桌面后返回再开球；物理/袋内扩展回归仍为58通过、1跳过。构建 `shot-audio-r2-device-final-build.log` 成功。
- 最终优化Debug已重新安装到 iPhone 16 Pro，安装记录 `device-install-r2-final.json`；保留用户数据，六CAF的哈希与来源manifest一致。最后启动参数为 `-shotAudioPreview -soundEffectsEnabled YES -deeplink.dailyClearance`。
- `shot-audio-r2-device-final-console.log` 确认八类加载成功，尚未出现 engine ready；已请求用户解锁并让App处于前台。真机实际发声与听感仍待用户验证，不能用资源加载替代。最后版本不会在非活跃状态尝试激活；回前台及下次击球会重试。
- `verify-gate`、`verify-doc-size`、`git diff --check` 通过。未提交、未发布；试听参数只对本次启动有效。

## R3：桌面重启后无声修复

用户反馈手机完全无声。现场读取本机偏好，soundEffectsEnabled=true；旧带参数进程日志已终止（signal 9，只能证明终止，不能据此推断人为退出或崩溃原因）。源码确认沙盒音源仅凭一次性 -shotAudioPreview 参数启用，而发行Bundle没有这批试听文件。因此桌面重新启动会失去试听资源入口。

修复：Debug显式试听启动将 shotAudioPreviewEnabled 持久保存，同时开启音效；后续无参数启动读取该已授权本机偏好，用户之后在设置中关闭音效仍有效。Release继续不读取沙盒试听资源。新增单测验证默认不启用、显式启用、无参数重启和后续静音；页面开球测试在带参数启动后终止App，移除试听/音效启动参数再启动开球。引擎就绪日志增加真实输出路由及媒体音量，用于区分程序播放与设备输出状态。

R3最终验证：13项音效单测+1项移除参数后重启开球UI测试通过，0失败（build/shot-audio-r3-tests.log）；真机Debug构建、verify-gate、verify-doc-size、diff检查通过。iPhone16Pro已安装（device-install-r3.json），回读偏好确认 soundEffectsEnabled 与 shotAudioPreviewEnabled 均为 true。16:14 真机日志确认 engine ready、Speaker、outputVolume=0.25；普通杆触发杆击/球球/直库/内衬/支架/挡头，随后用户实际开球出现密集球球播放记录（build/shot-audio-r3-enable-console.log）。未为验证重启打断用户这次试打；无参数重启由模拟器验证，手机持久偏好已回读。程序输出证据成立，主观是否听到仍以用户反馈为准。此前“仅本次启动有效”的限制由本节覆盖。

## R4：减少进袋重复声，降低碰库音量

用户反馈进袋重复撞袋声、碰库偏响。真机R3日志在16:17:17.722/17.822/17.855连续触发三次 pocket，单次P03长约0.558秒，导致同段素材重叠。

播放层对同一已捕获球的内衬接触，保留法向速度最大的一次，仍在该次实际接触时刻发声；不删除记录器的物理事实。不合并不同球，也不删除真实袋角、支架或袋下球球接触。此规则针对当前完整P03素材；以后采用独立微碰撞录音时应重新评估。直库和橡胶袋角增益统一乘0.7（约-3.1dB），保留现有速度曲线形状和素材。

新增回归涵盖同球多次内衬、台面/下落两来源、同袋不同球、袋角及支架事件保留。14项音效测试通过（build/shot-audio-r4-tests.log），Debug真机构建、verify-gate、verify-doc-size、diff检查通过。已安装到iPhone16Pro（device-install-r4.json），仅带页面深链启动，使用R3持久试听偏好；真实听感待用户确认。

## R5：降低袋内球球碰撞音量

延续R4试听反馈：袋中已有球时，新进球撞到已收集球的声音仍偏响。现有呈现层已把占用球位末端接触标为 `pocketBall`，播放层独立分类可直接校准，无需修改碰撞或库存。仅将 `ShotSoundKind.pocketBall.outputGainScale` 设为0.5，相对R4播放增益降低约6.02dB，保留原速度曲线、素材和触发时刻；台面球球、撞袋、支架以及R4碰库设置不变。

验证：14项音效测试全部通过（build/shot-audio-r5-tests.log），覆盖六袋已有球的接触分类与增益曲线；优化Debug真机构建成功（build/shot-audio-r5-device-build.log），verify-gate、verify-doc-size及git diff --check通过。当前devicectl显示iPhone16Pro unavailable，新包尚未安装到手机，真实听感待用户试听。

## R6：支架承接与挡头静音（2026-10-01）

按用户要求，将rail与railStop播放增益设为0，并在排程层排除零增益类别。袋内轨迹和接触事实继续保留；皮革、袋角、袋内已有球碰撞按原有设置播放。调整现有回归，验证六袋空袋不排程支架/挡头、不同速度直接播放增益均为0、占用袋位仍保留pocketBall，记录器接触事实不被删除。14项音效单测通过（build/shot-audio-r6-tests.log）；优化Debug真机构建成功（build/shot-audio-r6-device-build.log），verify-gate通过。手机仍unavailable，未安装本轮，真实听感待验。

当前四种不同底样：C03杆击母球、B04球球、U02碰库、P03皮革/落袋；jaw复用U02、pocketBall复用B04。单底样以平滑分段速度曲线调增益，无运行时变调。皮革素材P03尚未验证为孤立微接触，素材内尾声不因rail静音自动消除。

## R7：降低碰库与球球整体音量（2026-10-01）

用户反馈碰库、球球仍明显偏大。相对R6各自播放增益再乘0.5（约-6.02dB）：cushion/jaw 0.7→0.35，ballHit 1→0.5，pocketBall 0.5→0.25。速度曲线和底样保持原有配置，支架/挡头继续静音。14项音效回归通过（build/shot-audio-r7-tests.log），优化Debug真机构建、verify-gate、verify-doc-size及diff检查通过。已安装到iPhone16Pro并正常无额外参数启动（device-install-r7.json/device-launch-r7.json）；实际听感待用户试听。

## R8：压低低速碰库与皮革声（2026-10-01）

用户试听R7反馈碰库仍大，低球速也有明显响袋声。核对底样manifest：P03峰值-5.70dBFS，U02峰值-19.00dBFS，相差13.30dB；峰值不是感知响度测量。R7未调低pocket整体增益，原低速段上升偏快。袋内法向接近速度包含重力引起的运动；本轮不以入袋水平速率替代真实接触速率，不改物理和接触来源。

试听标定：cushion/jaw整体系数0.35→0.175，再降低其低速曲线点；pocket整体系数1→0.25，并压低低速曲线。有效gain对照R7→R8：在0.2/0.6/1.5m/s时，直库0.01225/0.0455/0.105→0.00175/0.01225/0.042，皮革0.035/0.12/0.3→0.0005/0.005/0.03。高速度仍较响、平滑单调、有上限。袋内球球沿用R7，支架/挡头静音。既有测试补低速橡胶/皮革音量边界；14项音效回归通过（build/shot-audio-r8-tests.log），优化Debug真机构建、verify-gate、verify-doc-size及diff检查通过。已安装到iPhone16Pro并无额外参数启动（device-install-r8.json/device-launch-r8.json）。实际听感须用户试听确认。
