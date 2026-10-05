# S2 独立曲面相机响应试用版

日期：2026-10-05。用户反馈S1横向反转及不同位置涩手/过快，授权第二版。仅更新「球迹·曲面实验」，不切换普通App默认。当前：最终9项核心/场景测试与3项原生UI均通过（12/0），设备包已重建并校验签名；04:10已更新安装并启动于iPhone16Pro（PID20873），手感待用户反馈。

## 改动

- 横向输入反转。独立相机局部投影验证：右滑时前方目标向屏幕左侧移动。
- 曲面手势取消额外8pt/1.3分轴门槛与整次轴锁定；支持斜拖，正常结束提交最终触点。系统UIPan自身识别门槛仍存在，识别后补齐touch-down以来的位移，不宣称触点零延迟。
- 保留S1曲面、默认1.65m/台上0.65m和所有快捷机位。近远在实际距离空间积分，再反解travel，避免默认位置两段参数化导致速度跳变。
- 使用15个固定台面地标的软权重投影运动量调节局部增益，目标代表性屏幕运动0.65pt/手指pt；不随活球或推荐目标切换。速度设上限，无强制最低空间速度；每次输入按最多4pt中点子步处理，降低快慢拖动/事件合并差异。此指标不是全画面所有像素严格等速。
- 松手无新增惯性。原选球/选袋/摆球优先级、方向尺瞄准、临时俯视及下一杆参考更新继续保留。

## 数值验证

最终核心类 `CameraSurfaceTests` 8项通过：原S1独立Python姿态对拍、近区距离/外沿独立性、房间边界、端点反向与保持、Rig所有权，新增横向符号/默认带速度连续性、80pt整段与80次1pt/往返、192组投影响应检查。

192组为2个母球位置 × 8方位 × 6近远位置 × 2轴，视口874×402pt。独立NumPy探针对比同一地标指标：S1范围0.15244～4.44511pt/pt；S2为0.60945～0.65006。Swift最终实际输出0.6094583～0.6502533，与独立探针相符。只代表此采样集和指标，不等于全连续空间/真实手感已验收。

证据：`build/camera-surface-experiment/response-analysis/s2-comparison.json`、`s2-probe.py`、`s2-probe.log`；`s2-final-validation.log`。

首轮 `s2-validation.log` 保留失败：8项核心中投影速度上限1项失败，最大1.625711pt/pt；3项原生UI均通过。独立探针定位到母球(1.2,0.5)、方位90°、travel0.75的竖向最低空间速度限制，强行抵消了补偿。取消速度下限后复验，原上限断言未放宽。

## 原生页面与交付

专用iPhone17Pro/iOS26.3模拟器：原近远/绕桌/俯视往返、真实击球至下一杆、新增45°斜拖与16pt短反向。原生记录确认35pt斜拖收到DX=35.000004、DY=35.000004；16pt反向后累计DY=19.000004，输入没有被额外门槛吞掉。最终`s2-guard-validation.log`为TEST SUCCEEDED：8项相机核心+1项SceneKit动作测试+3项原生UI全部通过。最终xcresult为`Simulator/Logs/Test/Test-QiuJi-2026.10.05_03-17-26-+0800.xcresult`（均位于build/camera-surface-experiment）。10张原生截图在`s2-final-screenshots/`，已目视默认、近端、外沿、斜拖、短反向、下一杆及俯视7张：所测画面球桌/母球/HUD正常，近端杆身遮母球下部仍属S1既有边界，不宣称全球形无挡。

冻结可安装包：`build/camera-surface-experiment/S2/球迹.app`（复制后签名校验通过）。设备包沿用独立bundle `com.xinkuan.qiuji.camerasurface`，现有手机S1可直接更新且保留其独立数据；不重置存档。04:10用户连接后更新安装，原bundle数据未重置；应用清单实查原球迹与独立实验包并存。证据s2-install.json/s2-launch.json/s2-apps-after.json/s2-processes-after.json，安装前二进制SHA256与冻结S2记录一致。

## 试用重点与边界

建议依次试：小幅左右与反向、默认位置上下经过、靠近/外沿绕桌、斜向连续拖动。固定总灵敏度0.65仍为试用值，用户可能希望更快或更慢。

没有把数值响应归一化等同于帧率、延迟或温升改善；本轮未做真机性能采样。小屏/iPad、全域遮挡/HUD与侧旋杆轴等原有边界仍开放。FL-109的手机手感待反馈，FL-094不因此关闭。

## FL-112：复验发现的启动崩溃

`s2-final-validation.log` 的击球用例在进页阶段失败，录屏回到桌面；`s2-launch-crash.ips` 确认SIGSEGV发生在原有Coordinator.updateFramePacing遍历子节点的SCNNode.hasActions读取，不是正常等待超时。未改代码单独重跑 `s2-shot-retry.log` 通过，但不能据此忽略崩溃。

修复假设为动画状态与渲染线程交错读取：按SDK提供的SCNTransaction全局锁保护完整图遍历/复合动作读取，根节点已有动画则跳过多余子树遍历；没有改idle条件或强制持续渲染。补既有testEventDrivenIdleCandidateWakesForSceneAction，实际动作唤醒、动作完成后停止、layout唤醒、无几何节点动作、旧轮询对比均通过（15.894秒）。该保护随最终设备包构建；有限复验不宣称所有SceneKit并发问题已经根治。

最终设备构建：`s2-device-final-build.log` BUILD SUCCEEDED，codesign --verify --deep --strict通过；`s2-identity.json`记录bundle、实验标记、二进制及本轮源码SHA256。源树还有其它此前未提交工作，本轮未提交/推送。
