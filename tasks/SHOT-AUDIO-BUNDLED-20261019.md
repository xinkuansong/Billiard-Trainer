# 已选击球音效随包接入 · 2026-10-19

用户要求：把之前选好的击球音效正式接入 App，随安装包一起打包，恢复声音并验证。

## 原因与改动

- 原先仅通过 Debug 的 `Documents/ShotAudioPreview` 导入六个样本，`QiuJi/Resources/Audio` 没有物理击球音效。普通安装无法加载；残留试听标记且导入文件缺失也会直接返回 nil。
- 将既有试听包的 `sfx_cue_strike / sfx_ball_hit / sfx_cushion / sfx_pocket / sfx_jaw / sfx_rail.caf` 原样纳入 Audio folder reference，共 144372 字节。六个 SHA-256 与旧 manifest 一致；来源与逐文件哈希在 `QiuJi/Resources/Audio/CREDITS.md`。
- 试听文件存在时仍优先；缺失时回退到安装包。Release 沿用包内路径，既有 project.yml 和 pbxproj 的 Audio 资源声明不需要重新生成。
- 保留开关选择与新安装默认关闭、ambient 静音策略、已选音色、力度增益曲线；rail/railStop 继续按既有政策静音。
- 音频引擎允许注入实例，测试使用真实 AVAudioEngine/mixer tap 检查生产加载与播放输出，不用 mock 代替音频。

## 验证

- 六个源文件及 Debug / Release 包内文件与试听 manifest 的 SHA-256 逐一一致；配置真源与工程均有 Audio 资源引用。证据：`output/shot-audio-bundled-20261019/resource-verification.json`。
- 定向 XCTest：18/18 通过（8.326 秒），含包内解码、缺失覆盖回退、有效覆盖优先、实际 mixer 输出、静音与既有时序/增益回归。日志：`output/shot-audio-bundled-20261019/unit-r2.log`。
- Release 模拟器双架构构建：`** BUILD SUCCEEDED **`，日志 `output/shot-audio-bundled-20261019/release-build.log`；并非签名 Archive 或发布。
- 页面原生回归：ui-r5 的 1 项测试 / 2 个场景全部通过（48.182 秒）；selection 场景真实瞄准后普通击球、manual 场景开球，均先退后台再恢复且不启用试听模式。日志 `output/shot-audio-bundled-20261019/ui-r5.log`，两张截图已从 xcresult 导出到 `ui-final-attachments/`。
- 首次 sim-test 被受管池容量限制拒绝，没有运行测试；随后显式借用原 iPhone 17 Pro 开发设备 `AE86244C-EE61-4585-882F-E39B892214DB`，未删除或擦除任何模拟器。

尚未安装真机、真机听感验收、提交或发布。资源接入不改变原来源和许可记录。


### 已测音频输出

生产 ShotSoundBank 实例接真实 AVAudioEngine，在 mainMixerNode tap 测得峰值：cueStrike 0.1615191、ballHit 0.19148056、cushion 0.0107995365、pocket 0.0909124、jaw 0.012763756、pocketBall 0.050652158；关闭音效后有音频渲染回调但峰值为 0。该证据证明引擎输出，不替代真机扬声器听感验收。

### 页面测试迭代保留

- ui / ui-r2：沿用旧 progress 夹具，击球按钮不可用；r2 完成瞄准手势后仍不可用，未改产品可击球判定，旧失败保留。
- ui-r3：换用当前 selection 夹具后，真实瞄准→退后台→恢复→普通击球通过；随后开球查询误用了旧 break.strike 标识。核当前 FreePlayView：每日页使用 dailyClearance.strike，自由击球的手动开球页才使用 break.strike。仅修测试定位，最终 ui-r5 完整复验通过；旧失败保留。

- ui-r4：Release 构建仍在运行，生命周期管理器保守拒绝借用，未启动测试。Release 完成后串行执行 ui-r5，不绕过设备租约。

## 最终状态

代码和资源接入完成；18 项音频测试、1 项原生 UI 测试（普通杆/开球两个场景）、Debug 测试构建及 Release 模拟器构建通过。用户原 iPhone 17 Pro 开发模拟器已安装本轮 Debug App；受管借用已归还，设备按原开发机策略保留。未安装真机，未提交或发布；用户听感待实际体验。
