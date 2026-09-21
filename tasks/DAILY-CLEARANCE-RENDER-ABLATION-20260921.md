# 每日清台 GPU 定位与交互 2D 阴影优化

> **当前状态**：本文为分阶段历史记录。8×2降采样和新增30FPS限制已撤回；简单紧凑循环无收益，未采用。最终使用原采样的保守球候选掩码，并完成CPU取消、预览复用和刷新治理，详见[等画质收尾报告](DAILY-CLEARANCE-EQUIVALENT-OPTIMIZATION-20260921.md)。最后一轮只用模拟器，最终包未安装手机。

日期2026-09-21。已定位固定 2D 场景的台呢直接球影 GPU 热点，并将交互 2D 每光源近影采样从 8×4 调整为 8×2。A18Pro 短时对照 GPU 命令跨度中位 47.93→23.88ms，呈现约 37.94→59.61fps。最终 1 单测与 2 实页 UI 回归通过，设备构建通过；持续温升改善和完整页面 GPU 复采仍待验证。以下按阶段保留失败、跳过及否决方案的证据。

## 固定测试

新增显式门控 `RenderQualityV62Tests.testDailyRenderAblations`。seed52、8m/s真实开球后固定球形；生产AngleTrainingScene、2D竖向俯视；MTKView强制连续60fps，4x MSAA、屏幕原生像素，独立SCNRenderer复用生产contactOcclusion委托。每项预热2秒、测量4秒。基准首尾重复。各变体依次：仅跳过台呢直接球影循环（保持采样数）、台呢原生材质、球体原生材质、2x MSAA、75%线性分辨率、房间隐藏。

独立渲染宿主不是完整每日清台页面，也没有物理求解/动态击球。关闭shader的图像仅用于成本隔离，不是交付画质。记录Metal命令完成回调gpuEndTime−gpuStartTime；是对应设备命令buffer执行跨度，不是能耗或直接等同Instruments片元通道区间。

## 模拟器结果

Mac M5 Pro / iPhone17Pro iOS26.3模拟器；优化Debug -O。1个测试通过，49.694秒，0失败。各有效变体239–241帧；2x MSAA设备不支持，明确跳过该变体并记录原因，不计为已验证。

| 变体 | GPU命令中位ms | P95 ms |
|---|---:|---:|
| 基准 | 0.289 | 0.431 |
| 基准尾部重复 | 0.334 | 0.394 |
| 关闭直接球影 | 0.305 | 0.422 |
| 台呢原生材质 | 0.322 | 0.406 |
| 球体原生材质 | 0.239 | 0.358 |
| 75%分辨率 | 0.313 | 0.414 |
| 隐藏房间 | 0.304 | 0.436 |

模拟器时间很短且基准重复漂移存在，没有得到足以定位手机瓶颈的证据；不能套用手机优化收益。固定盘面基准PNG已目视，全部变体PNG存档；这些不是实页UI验收。

## 初始真机采集计划（历史）

已为真机准备同一测试，Caches/run-daily-render-diagnostics一次性门控（结果目录由App创建为Caches/daily-render-results），开始消耗标志；要求系统Nominal后开始，每组检查热状态，渲染回调遇Serious/Critical暂停并停止后续组。真机测试包构建已通过（TEST BUILD SUCCEEDED，Debug -O），等待用户冷却确认，尚未启动设备负载。测试不卸载/清空用户数据，不修改持久画质偏好。确认温度后自动执行，无需手动持续击球。若无法保持正常热状态，保留部分数据，不宣称完整对照通过。

后续候选是将每颗球的阴影可达性判断移出光源采样内循环，仍须独立数值/像素对照和真机收益验证，尚未实施。保留既有同帧contact uniform更新，避免引入FL-076延迟。

证据：build/daily-render-ablation-20260921/ 内simulator.log、simulator-summary.json及ab-*.json/png；源码生产设置保持原状。git diff --check通过。


## 初始真机执行记录（历史）

用户确认温度可接受后开始。首次0.181秒失败：devicectl复制整个诊断目录后目录UID为0，App无权移除门控文件，尚未渲染。修正为只复制门控文件到App已有Caches根目录，结果目录由App创建；保留device-attempt1.log。

第二次执行1项、跳过1项、0失败，0.006秒：系统thermalState非Nominal，冷却守卫生效；不计性能通过。保留device-attempt2-thermal-skip.log。追加最长90秒只读热状态等待并保存preflight-thermal.json，第三次执行1项、跳过1项、0失败，90.098秒；18次每5秒读取均为thermalState=1（Fair），仍未达到Nominal。未开始任何GPU变体，不能把TEST SUCCEEDED当作性能测试通过。preflight-thermal.json及device-attempt3-thermal-skip.log已归档。未调低热状态门槛、未去掉失败断言。

该阶段停止真机测试，无在跑采集；门控在等待前已消耗，常规测试不会自动再次加压。最终测试包编译与git diff --check通过，真机GPU单变量结果仍缺失，生产渲染参数未修改。下一步待系统Nominal后执行同一对照，无需用户手动击球。


## 第四次：真机GPU变体已采到（02:15）

用户再次确认冷却后，preflight实测Nominal。iPhone16Pro/A18Pro，生产场景在全屏MTKView绘制（视口不同于完整每日清台工具层）。基准/无直接球影/台呢原生三组结束均Nominal。以下均为GPU命令跨度中位/P95，不是纯片元耗时、瓦数或正式页面FPS。

| 变体 | GPU中位/P95 ms | 呈现回调平均FPS | 组末热状态 |
|---|---:|---:|---|
| 基准 | 43.04 / 45.21 | 42.07 | Nominal |
| 仅关闭直接球影 | 12.57 / 12.99 | 59.99 | Nominal |
| 台呢原生材质 | 8.29 / 11.77 | 59.99 | Nominal |
| 球体原生材质 | 43.72 / 46.08 | 41.42 | Fair |
| 2x MSAA | 47.12 / 49.42 | 38.44 | Fair |
| 75%线性分辨率 | 28.54 / 31.71 | 57.38 | Serious（部分窗口） |

降低台呢直接球影工作是本次最明确差异，首三组热状态相同，命令跨度中位下降约70.8%。但这只是关闭阴影的成本隔离，不能把它当最终优化收益。CPU编码时长基准24.32ms、关闭影子2.29ms，可能包括GPU背压等待，不等于CPU物理求解成本。球体材质/2x组在Fair运行，不能精确量化其独立收益。

Serious时自动停止，room-off和尾部基准未执行，最后分辨率组也不能计作完整稳态。XCTest 1项失败（44.851秒，明确热停止断言），不是完整测试通过。已停止手机负载。有效局部数据保留在device-run4/及device-run4.log，不把未跑组/上轮文件混入。基准PNG已目视。

后续实施候选：用每球原有保守范围布尔值跳过内层不相关球检查，保留2个面光源各32采样、软过滤和接触参数同步。数值床面随机20万样本，1300个潜在遮挡、漏筛0；仍需像素回归和真机收益验证。


## 保留画质的每球筛选候选：未采纳

候选在模拟器4姿态原算法→候选→原算法PNG完全一致、运动阴影/幂等及2实页UI通过。扩展低表面数值抽样发现旧床面范围不能用于低于0.8m的接收面，补回退后20万样本漏筛0。但性能否决优先：独立Fair短时成对真机诊断，两组前后均Fair，候选GPU命令中位50.36ms/呈现36.27fps，原算法46.64ms/38.83fps，候选没有收益。已完整撤回该生产改动，并移除专属候选测试入口；失败方案diff保留rejected-candidate.patch，日志和图像不删除。不得把其视觉测试结果说成最终采样方案的验收。

完整冷机A/B两次均等待90秒后因Fair跳过；未放宽原冷机测试守卫。为了定位算法成本另增显式warm诊断入口，允许Nominal/Fair、仍在Serious/Critical停止；只作短时比较，不是冷机/长时热验收。

## 真机阴影采样对照：选择8×2

2026-09-21 02:33，三组开始/结束均Fair；每组2秒测量、2秒预热，XCTest 1项通过17.186秒。固定盘面、相机、MSAA4与原生像素。顺序8×2→4×2→原8×4，无反向重复，保留顺序/热状态粒度限制。

| 每个面光源阴影附近采样 | GPU命令中位/P95 ms | 呈现平均FPS |
|---|---:|---:|
| 原8×4 | 47.93 / 50.24 | 37.94 |
| 8×2 | 23.88 / 30.73 | 59.61 |
| 4×2 | 14.73 / 15.05 | 59.99 |

8×2相对原GPU命令中位下降约50.2%；不是功率下降50.2%。此命令跨度可能包含排队/交错执行，不等同片元实占时间。588×1000固定截图逐RGB比较：8×2最大差1/255、平均绝对通道差0.002506/255；4×2最大差6/255。原图及两候选均已目视，选更保守的8×2，不能把单张缩小截图的差异界当作所有视角/分辨率保证。

生产接线（最终回归通过）：MobileReferenceLighting提供交互2D阴影8×2源码特化；AngleSceneView在2D/3D模式或桌节点更换时更新，避免逐帧改shader；3D及视图销毁恢复8×4，独立场景/离线渲染默认8×4。两光源、光照/材质/阴影过滤公式、场景分辨率、4x抗锯齿及物理不变。影响共享AngleSceneView交互2D消费者，不只每日清台；正式页面回归聚焦每日清台。8×2诊断入口已改为调用生产helper，4×2仅保留测试变体。

证据device-sampling/、device-sampling-full.log、pixel-differences.json；原失败候选证据device-warm-pair/及对应日志。长时间降温、真实完整页面GPU新trace及3D负载仍未闭合。


## 最终构建验收

最终源码：`testInteractiveShadowSamplingRestoresFullQuality` 1 项通过（0.664 秒），验证默认完整采样、2D 降采样、重复调用稳定、切回 3D 及 dismantle 恢复完整源码。`testNormal2DShotPerformancePhases`（40.296 秒）和 `testRealAutomaticBreakFirstShotAndRelaunchIn3D`（30.176 秒）2 项 UI 通过，0 失败；不是跳过或 0 测试。日志 `shipping-regression-full.log`。

已目视最终 `shipping-ui/normal-2d-after-shot.png` 与 `v63-daily-first-shot-3d.png`：球影、球体、台呢与操作控件可见，未见新增材质缺失。截图对应不同球形，不作实页像素相等声明。`make -f scripts/Makefile build-device-profile` 成功（Debug -O），日志 `shipping-build.log`。本轮不再追加连续手机热负载。

最终范围仍为共享 AngleSceneView 交互 2D；3D 保持完整采样，其主动负载优化尚未完成。单张固定截图的最大差 1/255 不代表所有动态/放大视角。最低 iOS17 与其他 2D 消费页本轮未复验。此前全仓 gate 的 6 个无关视频测试写盘登记漂移仍存在，不能声称全仓 gate 通过。未提交、推送或发布。

最终优化构建已成功覆盖安装并启动到每日清台（保留用户数据），安装/启动证据 `shipping-install.json`、`shipping-launch.json`，可执行文件及源码 diff SHA256 见 `shipping-build-identity.json`。模拟器诊断门控已移除。最终 `git diff --check` 与文档体积门禁通过。

## 等画质方向：紧凑阴影循环（历史候选，已否决）

用户明确画质和流畅度优先后，撤回新增降帧/减采样的生产改动。保留先前过期预测取消。新增测试内候选，将每个光源样本展开的逐球检查变为禁止展开的定长循环，球顺序、原 8×4 采样、过滤公式、原生像素及 MSAA4 均不变；生产材质未接入候选。

模拟器 `testDailyShadowLoopEquivalence` 实际执行 1 项、0 失败、2.876 秒；2D/3D 各原算法→候选→原算法，共六张 1176×2000 PNG 的同视角 SHA256 完全一致，候选原图已目视。证据 `build/daily-frame-pacing-20260921/loop-equivalence-full.log`、`loop-pixel-equivalence.json` 和 `loop-*.png`。这只证明固定盘面的图像等价，动态、多球重叠、近景及真机收益尚需验证。

被用户纠正方向前启动的帧率策略测试（3 单测、1 UI）已自然结束，日志归档 `regression-full.log`；其策略随后撤回，不作为当前候选验收。
