# 台呢保守遮挡界：页面接入核对

2026-11-13，局部 DEBUG 研究入口，承接[每日现行入口](../daily-adaptive/CURRENT.md)和[球桌统一规范](../../docs/design/table-pages/球桌页面统一规范.md)。不是整页改版；不重做未受影响的标题、布局、计分和权限条款。本地定向验证完成，最低Runtime/实体移动设备及完整Release未验，不能当通过。

## 范围与接线

`-daily3D.safeClothSupport` 对应 plain safe-r3-signbit，新增 `-daily3D.guardClothSupport` 对应带有限域守卫的 cone+safe-hoisted；只由每日场景配置读取。两flag同时出现回退原配方并报告冲突。正式默认与 Release 保留原生成器。场景持有安装结果，台呢 refresh/容量扩张重新判定；桌缓存及房间反射缓存纳入实验身份。仅 R、原 reference 采样、16 槽和已审查源码可生效，其余返回原请求配方并记录原因。

该场景的正式 2D、3D、临时俯视共享材质，不能把名称里的 3D 当作只影响透视画面的证据。不会持久化实验标志，不增加产品设置项。诊断记录 requested/effective/version/reason/capacity/profile/sampling；只读取安装时缓存，不逐帧生成程序或计算 SHA。

| 条款 | 判定与对应合同 | 验证及状态 |
|---|---|---|
| TP16 正式模式/临时俯视 | 继承；同场景、同球局、同材质，临时层按原策略复制 | r6三风格×三配方的2D→3D→临时→恢复通过，状态与原图已核 |
| TP17 相机恢复 | 继承；不修改镜头或手势，核临时退出及后台恢复 | r6原控件切换、模式值、renderer/球位及恢复图通过；非精确手势增益验收 |
| TP27 偏好隔离 | 按研究范围调整；进程启动标志，不是用户显示偏好 | r6三风格/三配方及冲突回退通过；r7补验guard缓存通过 |
| TP29 场景与资源 | 继承；可变场景不共享，缓存包括配方，球位/姿态/物理不变 | 源码黄金、实例隔离、扩容、桌复用、反射与临时副层通过；FL-262定向闭合 |
| TP30 进入/后台/释放 | 继承；异步反射旧结果拒收，休眠和唤醒不变 | 真实首页进入/返回、后台恢复、两候选真实击球后休眠通过；非长期资源压力结论 |
| TP35 验证 | 继承；原程序与候选同构建同条件，明确功能、画质、性能层级 | r6/r7本地38目标方法已有通过记录，45页图已审；完整场景图像全等。最低iOS17、实体移动设备与用户认可待验 |
| TP36 回写 | 继承；局部实验记录留本工作包，未改变共用产品规则 | [逐轮记录](ITERATIONS.md)、[通用评价](EVALUATION.md)、进度同步 |

TP01–15、18–26、28、31–34：本次没有改变对应业务/布局合同，不把“没有修改”写成重新验收通过。真实击球测试仅检查渲染实验没有阻断已有回放/计次/休眠，不替代物理准确性专项。

## 图像与设备范围

- R23新增原生完整动作验证：两个真实开球共1,194帧R/guard/重复/恢复像素及同刻节点/uniform一致，含进袋轨道和旋转停稳；精确selector 1/1、独立分析通过。18实际球态的162轮GPU对照均更快，仅证明该场景直接渲染成本，不升级为整页FPS、用户手感或长期资源验收。[动态证据](../../output/render-lowdim-20261113/native-dynamic-r16-analysis/REPORT.md)。
- 技术 before：同构建关闭实验时的原生产 shader；现有冻结生产场景红控、重复、恢复和逐像素比较保留。页面原版/候选均从相同确定球形启动，截图必须实际打开审查。
- 页面矩阵：标准手机、最低支持 Runtime；必要时用可用 iPad 角色补宿主生命周期。此处没有布局改变，不机械重复全尺寸/全字号矩阵。
- 原生 GPU 成本：Mac M5 Pro / Mac mini 原生 Metal 同包配对，独立于 Simulator 功能验证；[R22 原生完整固定场景](../../output/render-lowdim-20261113/native-production-r10-rack-analysis/summary.json)使用同一 R 反射 probe，不代表整页或手机性能。
- 真实页面：[R21 逐 drawable 证据](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/REPORT.md)已有描述性结果，但实际活动覆盖不足，不作性能排名。
- 手机预览：r7 Debug -O 已安装到 iPhone16Pro 并以 guard 参数启动，交付用户试用，见[安装证据](../../output/render-lowdim-20261113/phone-preview-r7/SUMMARY.md)（run `c45e6ee61c5d4f298cdbb0fa4f546b89`）。这不等于手机性能、温升或完整手感验收，也不代表提交或发布。

## 选择器

- `DailyClothSupportExperimentTests`：生成器 gate/默认源码、缓存和容量（具体方法以最终源码为准）。
- `Daily3DRenderDiagnosticsTests`：已安装配方、回退与重复配置去重、disabled 静默。
- `ClothSupportPageResearchUITests`：三风格原版/候选、投影、后台恢复及 balanced 回退。
- `ClothSupportPageResearchUITests/testSafeRecipeDirectionInputAndRealShotReturnToIdle`：真实方向尺/击球流程。

最终实际命令、快照、执行数、原图路径及缺测原因将在下面补充，不能拿旧快照验证新增接入。

## r5 冻结与执行中

- 快照 `b1affea5a5a11bf1638df48508a56dfa84deb2ea79240af3c32512df0d72a3d3`，4451个构建输入，所有输入写入者交接后冻结。研究输出不纳入构建快照。
- 远端作业 `cloth-support-page-ios26-r1-20261113`，iPhone17Pro/iOS26.2；[实际提交参数](../../output/render-lowdim-20261113/page-ios26-r1-submit.json)。完整构建通过，实际30项27通过/3失败/0跳过；原失败保留，新快照复验准备中。
- 静态独审发现旧V52脚本沿用隐藏的toolbar视图入口，未进入运行就修正新测试为当前“更多→视图→关闭菜单”。没有扩改旧V52；新增方向尺/击球测试用当前selection夹具，不等待已废弃的自动开球确认。
- 临时层截图等待`temporaryTopDownActive`及实际`diagramSurface=temporaryTopDown`；返回验证真实每日页面退出，不能以菜单按钮消失代证。方向尺当前断言无误击、手势后休眠；没有前后杆向数值，不声称精确增益/方向响应验收。
- CPU源码对照通过：[默认生成器、完整surface及40配方合同](../../output/render-lowdim-20261113/support-live-implementation/cpu-contract.json)。DEBUG/Release解析通过；r5完整工程通过，实验10项单测通过。新增guard须另验，不能沿用plain结果。
- `verify-gate`、`git diff --check`、`verify-doc-size`已通过；这三个检查不替代页面或图像验证。

## r5 失败与修正范围

- [完整结果](../../output/render-lowdim-20261113/page-ios26-r1-failed/test-summary.json)：30项27过/3失败。balanced回退、plain真实击球、4配置完整场景、实验10项逻辑已通过；三风格矩阵只走首个reference，不算整体通过。
- [FL-261](../FAILURE-LOG.md#fl-261--根页深链不能验返回上级2026-11-13)：根页深链没有导航祖先，矩阵改真实首页进入，退出断言保持并补首页可点。原生产导航未改。
- 旧默认delegate已实现frame receipt，测试修为真实回调后receipt送达且disabled诊断仍无事件；没有删除生产回调。桌复用截图改XCTAttachment，原像素阈值不变。
- 已目视原3D、临时2D和plain击球后图：桌/球/球房完整，临时层和回放状态可见。具体附件映射在原件`attachments/manifest.json`；不是guard或全风格画质结论。
- 已校验回传原件，clone导出不动原件；本作业精确临时设备BF1B6808已退役、build/source与旧snapshot已按queue协议回收。
- r6计划：三种recipe×三风格真实进入/退出、双候选各一次方向尺和真实击球、balanced与冲突回退；新增guard完整场景图像及单测。最低iOS17待新快照通过编译后运行。

## r6：三臂接入复验中

- 不可变快照`b7e367d1b4462f48997647a553f7faa2aa40546821cebfb4563d2ed8503d85a8`，4455输入。所有构建输入写入者交接停止后冻结。
- 作业`cloth-support-page-ios26-r2-20261113`，iPhone17Pro/iOS26.2；[实际参数](../../output/render-lowdim-20261113/page-ios26-r2-submit.json)，预期38方法（15实验、10诊断、6共享生命周期/缓存、2完整场景、5UI）。以最终xcresult实际数量/无跳过为准。
- 独立审查[guard真实Swift输出](../../output/render-lowdim-20261113/support-guard-live-independent-r1/result.json)及[测试修复审查](../../output/render-lowdim-20261113/support-legacy-comparison-r1/live-guard-and-test-fix-review.json)通过；guard完整source精确命中跨硬件包黄金，尚不替代本轮App执行。
- guard字符串构造中位约5.064ms、相对原R配对增量约4.973ms，864次源输出核对通过；发生在安装/扩容边界，完整源码增加6258 UTF-8字节，不是每帧或GPU内存。详[CPU报告](../../output/render-lowdim-20261113/support-guard-live-cpu-r2/REPORT.md)。

### r6远端连接中断

提交已确认queued/worker启动，随后SSH hostname与IPv4均timeout/host-down；不能推断作业没跑，也不重复提交。只读连接证据在`output/render-lowdim-20261113/remote-connectivity-r6/checks.json`。继续用本地空闲large-pad及同一r6不可变源运行完整38项；受管入口不修改其他已启动/保留设备。最低iOS17待远端恢复，尚未执行。远端native两轮文件此前已完整回传，约1GiB临时专属副本的清理预览完成，但因失联尚未执行删除。

用户随后确认“暂时不方便，继续本地验证”。因此本轮停止远端连接尝试，原作业状态、最低iOS17及远端临时资源收尾留待主机可用时恢复；没有要求用户开启手机或修改网络。

### r6本地受管复验

同一快照通过扩展后的受管入口执行：本地large-pad（iPad Pro13 M4，iOS26.3.1）。运行ID `12ff42b4bcb4407bba1f485eed441b92`，[运行记录](../../output/local-test-runs/12ff42b4bcb4407bba1f485eed441b92/run.json)。完整构建通过，实际38项37过/1失败/0跳过，[结果](../../output/render-lowdim-20261113/page-local-r6-analysis/test-summary.json)。5项UI均过，失败仅下述FL-262。

### r7定向修订与最终本地结果

r6发现guard缓存测试泛词命中黄金注释，见[FL-262](../FAILURE-LOG.md#fl-262--shader注释命中不能证明安装了另一配方2026-11-13)。生产程序不改；测试改为确切函数定义和完整surface SHA。独立CPU复现原三次误报，新五序列谓词全部通过，随后执行下述真实缓存复验。

新快照`ade5961f45f2e436c6a6aa5df3da862e740a699f58b231d1139d39c7cc02b834`仍为4455输入；[与r6的差异](../../output/render-lowdim-20261113/local-cache-retest-r7/snapshot-diff.json)仅测试文件、测试规则和本地launcher，所有App/资产/配置/项目输入未变。定向补跑一个方法，保留r6原失败和其余已通过用例，不能将r6汇总改为全绿。

r7完整构建通过，`testGuardCacheSeparatesOtherRequestsAndReusesGuard`实际1/1通过、0跳过（8.908秒）；[结果](../../output/local-test-runs/247fbbe3fb1f4a2797b9c2acee7c5511/evidence/test-summary.json)、[完整运行](../../output/local-test-runs/247fbbe3fb1f4a2797b9c2acee7c5511/run.json)。因此38个目标方法均已有与当前生产输入一致的通过证据；不是宣称同一次全量38/38绿。

45张页面图与45份状态已实际核对：[tournament/walnut 24图审查](../../output/render-lowdim-20261113/page-local-r6-tournament-walnut-review-r1/REVIEW.md)、[eastern/击球/回退21图审查](../../output/render-lowdim-20261113/page-local-r6-analysis/root-visual-review/review.json)。未见候选独有空白、洋红、缺球或错层。guard完整场景4配置、20PNG、12组严格对拍全部RGBA相同，红控有效，见[独立复核](../../output/render-lowdim-20261113/page-local-r6-guard-review-r1/review.json)。

`verify-gate-r7.log`通过；完整Release App只完成预飞并发现生产配置缺项，未执行，详RESULT。没有iOS17/手机实测、长期帧率/温升或用户手感验收，也未提交、安装到手机或发布。

本地r6失败诊断关闭后执行受管complete，r7成功后自动回收，两轮`work/`均已删除，原始证据与可复现快照保留。远端r6作业及约1GiB专属实验副本因用户暂不方便保持待续，未声称完成远端收尾。


2026-11-13 R24/R25增补（TP16/17/27/29/30/35/36相关资源与进入路径）：原生真实每日清台同一构建R/guard各20次正常进退、0杆与现有偏好保持，缓存候选额外footprint页面1.516MiB/首页1.422MiB/延后1.859MiB，本轮32MiB AND10%预算过；不等于长期泄漏排除。16材质/回退/并发合同过，R19整17仍有1首帧失败。R24后续独立72次成本采集通过，其零差画质状态仍未解决，4组各1次1像素/1色阶差均保留；不能替代完整页面首可交互、持续多视图或发布验收。详见RESULT和ITERATIONS。

2026-11-13 R26增补：缓存版guard真实原生每日清台现有rack/0杆，已核打点面板开关、独立SCNView临时俯视开关、隐藏/透视恢复及返回首页，7张原图/AX保存；各桌面状态仍0杆、杆速10，主场景静置标签恢复。隐藏事实另由只读AppKit确认，未用标签推导整个App或overlay GPU零成本。持续相机性能首臂因缺19输入/首orbit无效，余7臂未跑；独立校准首输入前被界面变化中断，未进入测量。功能观察不替代持续多视图/后台成本证明，未扩设备矩阵。详见[状态证据](../../output/render-lowdim-20261113/native-page-state-r1/summary.json)。

2026-11-13 R32增补（TP17/29/30/35）：同构建8个原生进程、现有16球rack/0杆，固定相机操作加自然idle，实际配置与2660×1996 layer一致；App及日志进程全部退出。第一周期因实际输入缺1无效，第二BAAB均值GPU约−5.18%但呈现间隔基本不变、尾分位未一致改善，不认定稳定整页净收益。CPU实际包围时间不同，持续多视图/后台GPU/移动设备尚未覆盖，不能将其标为不适用。原功能与画质证据沿用，本轮无页面合同或生产改动。[完整记录](ITERATIONS.md#r32真实页面八组固定操作对照一个有效baab尚无稳定整页净收益)。
