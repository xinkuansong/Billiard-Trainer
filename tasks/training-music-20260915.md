# 练习背景音乐 — 2026-09-15

## 用户裁定与实现

采用已确认的原创《静台》无打击乐循环母版；背景音乐默认关，击球音效保留已有选择（无存储值时仍默认关），两个开关分别保存。最新补充明确排除正式训练计分页 `ActiveTrainingView`。

13 个页面根视图接入共享 `trainingBackgroundMusic()`：AngleDynamic、GeometricAngleQuiz、SceneAiming、AimPointTraining、AimPointSceneTraining、ShotSimulation、FreePlay（含每日清台）、PositionPlayComposer（含试打）、SiluTrainer、PlanThree、SnookerTactics、BankShot、DiamondSystem。首页、列表、说明、历史、正式训练计分没有接入。

`TrainingMusicPlayer` 共用一个 AVAudioPlayer，60 秒无限循环，音量 0.55；页面可见令牌防重叠播放，最后一个页面离开暂停，返回从当前位置续播。后台/失活暂停，音频中断尊重 shouldResume；耳机拔出暂停，媒体服务重启后按当前条件重建。休息计时占用音频期间暂停背景音乐，结束后重新判断可见性与开关。`.ambient` 遵循硬件静音，不声明后台音乐能力；暂停音乐不主动停用击球音效共享音频会话。

## 音频来源与核验

`QiuJi/Resources/Audio/Music/quiet_table.caf`：ALAC，44.1 kHz / 16 bit / stereo，60 秒，2,184,900 bytes。来自已确认的 `quiet-table-no-percussion-loop.wav`，并非带淡出的试听 MP3；无外部录音/样本/API。重现脚本 `scripts/audio/compose_quiet_table.py`，依赖 NumPy，默认产物写入 build/training-music/source。

Apple `afconvert` 解码为 PCM 后与母版完全一致：2,646,000 帧，SHA256 `a7793ee6d73d38ab7f7b3aa77fd94cc3e0f73655d1de8e628528839bf40f11b1`。FFmpeg 的 CAF 解码尾部少 16 帧，已用 Apple 解码确认实际资源完整，未因第三方解码器差异改动母版。

## 验证

- Debug build：通过，日志 `build/training-music/build.log`。环境无 xcpretty，Makefile 原有 fallback 完成构建。
- TrainingMusicTests：8 项通过，覆盖独立默认/保存/升级、共享播放器与可见性、后台与休息、音频中断、重建和资源解码。最终 8/8 通过（unit-final.log），其中真实 AVAudioPlayer 启动后时间推进、暂停后位置保持通过。
- 设置 UI：验证独立切换、终止重启后持久化、恢复音乐开/音效关，浅深色截图。首轮辅助截图断言误把 ScrollView 当 Other，断言移除后重跑；非产品开关失败。已验证切换与保存通过；发现 Debug 深链固定深色使首批浅色标签截图实际为深色，改用 forceLight 夹具重跑。最终 UI 1/1 通过（ui-verified.log），含浅色渲染断言；settings-after-light.png / settings-after-dark.png 为最终截图，声音两行布局、文字和开关无截断。
- verify-gate、verify-doc-size、git diff --check：通过；未运行全仓测试矩阵。
- 真机听感、蓝牙/电话/硬件静音实测、小屏/iPad完整UI矩阵未验；未提交或发布。

## 后续默认值调整

用户要求背景音乐默认关闭，已将未存储值的 fallback 改为 false，已保存的 true/false 均保留。同步更新默认值与持久化断言，TrainingMusicTests 8/8 通过（build/training-music/default-off.log），git diff --check 通过。
