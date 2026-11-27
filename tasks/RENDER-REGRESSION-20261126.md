# 手机已装版本渲染优化核查

2026-11-26，北京时间约11:38完成有效取证。角色：Test Engineer。用户反馈手机再次明显发热，要求检查已装版本的优化是否生效、后续代码是否回退。仅诊断，无生产代码修改、覆盖安装、偏好写入或账号操作。

## 手机已安装版本与实际接入

- iPhone 16 Pro，iOS 27.2.1。无线发现显示 unavailable；用户解锁并确认同局域网仍不可达，接数据线后恢复连接。本轮是安装身份/材质状态检查，连接充电条件不用于温升结论。
- CuePhys `com.youbilliards.cuephys`，1.0.0 (1)，开发安装。实读可执行文件85,187,328字节，SHA256 `0970932e50327c07c62d0b33ce0bb968c9b8b3cd3260957d4fc396433fdc952c`，Mach-O UUID `9BD0FE11-8578-3583-AAE0-7514CBB8003C`。未建立完整二进制到Git提交的一一对应，不能仅凭重复使用的1.0.0 (1)认定源码版本。
- 用户打开每日清台。有效快照实际为3D透视主球桌，窗口874×402 pt，界面树中1个SCNView。真实TaiNi材质包含固定灯预计算调用、球影优化及LTC调用；`temporalField0/1`、`h18Table0/1`四个绑定的contents均非nil。
- 手机包内LTC资源98,304字节、固定灯资源1,048,576字节，SHA分别为`5a94fd48682bdace13bd58911d843444c4ec1e03771ea959431b1e826eb0b463`和`bc7509c3ebe99b0f823fd9722264f67503e006f976abc32ac54fdf050ad0b096`，与历史交付及当前仓库完全一致。
- 从手机实际surface中精确移除当前`MobileRailAppearance`的declaration、attenuation、finish三段（各出现一次），结果与H18-R7交付`production.surface`逐字一致，SHA `ead5e317bffd1279c93a31771dba5cd18b8b47ba9312a5e1dcf975ce6b64afa9`。这比只查开关/资源存在更直接，支持该材质没有丢失原优化或意外走全量旧着色器。
- 当前相机实读世界Y=1.45000005，高出台面约0.65m，向下分量0.25994042（约15.07°）。LTC要求高度0.25–0.50m、俯角30–65°，这两个必要条件都不满足，因此**已接入LTC程序，但当前机位所有片元均不会选择LTC分支**；固定灯/球影优化仍在。没有擅自放宽阈值。
- r5/r6/r7停手快照均为`isPlaying=false`、`rendersContinuously=false`；目标FPS=30是空闲调度值，不是实测持续30帧。原始帧率偏好键为0，当前源码按未设置值采用60；未实测活动期请求/呈现帧率。启动参数仅App路径，没有关闭优化的研究参数。

## 后续修改与回退核查

- 审计HEAD `a08ff66cfc2a4b26a36ce136bda477d7adaabb5f`，与包含最终优化的`8f8ae54e`对照，并用H18-R7源审计/实际surface黄金件核验。
- `ClothSpecularLTC.swift`、`StaticClothIrradiance.swift`、`DailyClothSupportExperiment.swift`、`PrefilteredReflection.swift`字节未变；参考灯组、采样/配置、灯几何、台呢模板及主要程序生成片段未变。资源哈希未变。
- 后续材质新增库侧细化、床面靠库阴影、提亮B档及白球光泽调整。手机实际surface差异仅上述库边新增片段；fragment实读为原高光映射加B档0.35提亮。库边新增着色工作是额外成本，尚无同条件GPU对照，不能称其导致本次发热或无性能影响。
- 帧调度保留空闲暂停、事件唤醒、关闭强制连续渲染；新增P01相机/手势订阅在停止循环时清理。有效实机停手状态没有发现持续播放，但不覆盖活动期、后台、长时运行、其他页面或所有切镜路径。
- 新相机默认高度0.65m；历史TwoView默认距1.65m的公式也包含0.65m高度，因此不能把本次未命中LTC直接归因于新相机回退。新旧机位在真实训练中命中优化范围的时长尚未对照。

## 诊断失败与收尾

最初两轮LLDB附加尚处于connected时就执行表达式，未取得有效数据，退出后目标进程退出；已正常重启原包。一次交互式附加在状态打印/运行时展开与模块加载锁间阻塞，用户反馈卡住；保存LLDB宿主采样，终止本轮所属LLDB并恢复App。此为诊断工具干扰，不能计作自然App崩溃或渲染卡顿。

后续沿用已验证的禁用language-runtime-unwindplans、parallel-module-load及精简frame/thread格式，并在收到实际`Process stopped`事件后执行表达式，成功读取。哈希表达式最初extern C声明位置错误、扩展材质表达式id类型推断错误均保留；改为Objective-C函数声明及显式材质属性类型后读回成功。r5/r6/r7均确认detach，最终LLDB退出，PID4042继续正常存在。没有重装App、清数据或修改偏好；仍保留所有失败原件。

## 证据与结论边界

- [汇总JSON](../output/render-regression-20261126/result.json)、[源码审计](../output/render-regression-20261126/source-audit.json)、[手机材质与相机读回](../output/render-regression-20261126/r7/material-detail.txt)、[安装包哈希](../output/render-regression-20261126/r6/bundle-hashes.txt)、[手机对R7差分](../output/render-regression-20261126/phone-vs-r7.surface.diff)。原设备发现/进程、附加失败、调试器栈和解除回执同目录保存。
- 可以确认：所测手机每日清台的核心优化实际接入、资源正确，当前停手状态休眠，当前机位不命中LTC近景加速；没有发现该材质的旧优化被覆盖。
- 尚未确认：所有后续修改是否造成CPU/GPU耗时回退、持续操作温升、实际GPU执行时间、当前安装包精确Git提交、其他页面和全状态。没有运行新的App构建、XCTest或长时性能测试，不宣称这些通过。
- 下一步：保持当前机位/画质/帧率，优先取得短时活动CPU/GPU证据，再对后加库边效果及相机/预览工作量做隔离对照；不能把LTC未命中直接当作热源已定位，也不能靠放宽适用域或降帧宣称修复。

## 无线连接续查（2026-11-26 12:16，北京时间）

- 用户要求先恢复无线连接。用户确认拔线并保持解锁；同一SSID与IPv4 /24网段，Mac至手机3次ping均成功，路由走en0。不能据此认定开发服务可用。
- 系统日志记录12:05:50取消配对，12:10:01新手动配对认证成功并添加该UDID记录；本轮诊断未执行取消配对。配对完成后CoreDevice、Instruments与原生remotepairingd发现均未列出目标手机。
- Mac配对服务曾在en0正常发布`_remotepairing-pairable-host._tcp`，手机完成认证的连接也经过en0。手机`_remotepairing._tcp`服务未被发现；TCP 62078/49152可建立连接，但基于指定IP读取lockdown值立即断开，未取得无线连接开关值，不能认定开关已关闭。
- 用户重开手机Wi-Fi后结果未变。独立工具pymobiledevice3 11.64.0的host doctor确认Bonjour查询可以发出、usbmux与remotepairingd可响应，但设备数为0；仅在uv工具缓存安装诊断工具，未更改App或全局Python环境。原始日志与检查结果保存在`output/render-regression-20261126/wireless/`。
- 待临时USB连接读取无线连接设置，再拔线验证；尚未开始新的CPU/GPU记录或温升测试。

### 12:17–12:22 无线直连恢复

用户临时接线后，实读`EnableWifiConnections=false`；开启并读回true。用户再次确认拔线后，通过手机IPv4地址和既有配对成功读取设置。继续读到独立的`EnableWifiDebugging=false`，已开启；两项true的读回保存在`wireless/wireless-settings-enabled.json`。两次发送设备服务重新广播通知成功，但CoreDevice自动发现仍为unavailable，不能宣布Xcode自动发现已修复。

改用同一手机IPv4地址，经已认证lockdown → CoreDeviceProxy → 进程内RSD隧道，实际成功读取正确UDID并连接Instruments DVT进程服务；本次CuePhys PID返回0，尚未启动负载采样。此通道完全经过Wi-Fi，用户已确认拔线；该进程内隧道不能供外部xctrace直接使用。后续DVT graphics若可采，为设备级计数器，不能伪装成App独占GPU执行时间。等待用户重新打开每日清台并确认正常温度、未无线充电，再做短采样预检。
