# P01 · C56 核心模板、来源返工与复用核验

> 续接状态（2026-10-08）：P01原生首版与缓存/配置修复已接入主工作区，44项单测、8次UI验证通过；见[P01活动交接](P01-SHOT-SIMULATION.md)及[续接报告](../../output/table-page-adaptation/P01/c56-native-r01/REPORT.md)。以下为本轮实施前的模板/设计审计历史，其“未迁移/待修复”状态已由续接记录更新。

2026-10-08。审计时范围：更新每日核心模板、验证复用边界、采集实际页面并制作P01继承稿。生产P01和其他页面尚未迁移；本轮不把设计稿当原生after。

## 交付

- [每日核心模板及全状态适用性](CORE-TEMPLATE-C56.md)：D01–D29逐项分类，补D30时间/电量/FPS；每个组件有有效来源、旧材料风险和P01接法。
- [效果与原生参考](../../output/table-page-adaptation/P01/c56-r01/index.html)：当前每日22种原生状态、P01真实before与15张Figma继承稿。
- Figma新22页：`2078:197251`「P01核心模板继承｜C56」；新23页：`2078:197182`「每日核心模板C56｜当前App实图」。旧简化稿留在98页，已标撤回勿实施。离线提示持续存在，本地修改已确认，云同步未确认。
- P01保留母球、最多2目标球、无开球、教学读数；长标题两行及读数位置是本轮提案，尚非确认标准。候选球径32/30只说明两张静态容量样本，生产必须使用模板容量求解，不能新增固定设备断点。窄屏16槽与状态块冲突，r5按现行statusFits规则隐藏辅助状态，不反向缩桌或缩球。

## 用户反馈与来源问题

用户指出“很多相关的页面没有用最新的，比如设置”，并明确“每日清台是核心的模版”。首稿只把显示提前，另外重画了256pt宽/35pt行的简化面板；漏继承磨砂、行分隔、滚动和完整子菜单。此稿不能作为实现输入，已撤回。

进一步核对发现：C56是状态增量，并未更新全部旧Figma整屏；D2子菜单旧图仍有底部返回，当前App已是顶部返回/关闭。透明度的202pt却不是过时：组件上限252，调用方Panels在与大盘同带冲突时收为202，本轮原生确认为202×108。已纠正只读组件默认值产生的误判。

当前一级菜单原生实测：panel=(560,46,252,328)，可滚动内容可视高312；视图分段行56，其他动作行44（截图AX像素取整有43.7）；上下滚动位移56.7，使最后一项完整可达。新版Figma据此恢复容器、分隔、状态和滚动上下两态；子菜单恢复顶部导航。Figma材质是近似表达，实际SwiftUI regularMaterial、字号和触摸仍以原生实图/实现为准，不能宣称像素一致。

10个原设计来源节点结构/填充/文字/效果签名未变，见figma-current/report.json；没有覆盖每日或用户粗调稿。P01场景图由真实SceneKit两球夹具产生，未计算态不绘制假轨迹，不能称原生P01整页。

## 当前实际执行

|检查|结果|证明范围|
|---|---|---|
|最终测试构建|通过，build-r6.log|当前测试与App可编译；非全量测试|
|复用单测|6项0失败，reuse-tests-r2.log|下列实验与断言；历史37项未重新全跑|
|P01真实before UI|1项通过，before-ui.log；10张图|正常入口、2D/3D、菜单/打点、进袋/自由、返回；请求横屏仍竖屏作为before记录|
|每日当前核心状态 UI|1项通过，core-native-r2.log；23张原始图（22状态+入口）|2D/3D更多上下滚动、瞄准/轨迹子菜单、透明度0/50/100、关闭设置保留大盘、四视角选中|

当前核心状态的相机静帧显示相应选择，不代替连续机位手感验证；透明度端点操作已执行并留图，本用例不额外宣称所有Runtime的数值端点验收。菜单返回/关闭可见且可点击；AX报告的是小图形范围，本轮未用其证明44pt热区。首轮错误地对AX字形套44pt断言而失败，日志保留，最终移除该错误推断，保留真实操作和可达性检查。

### 6项复用检查

- `RoomReflectionProbeTests/testP01ProbeFirstConsumerOrderAudit`：三room style，默认→每日和每日→默认；缓存对象身份、同源重复烘焙对照、外观变化实验。
- `RenderQualityV62Tests/testP01TemporaryOverlayReleasesAndKeepsMainScene`：6次临时俯视往返，主scene身份/球位保持；派生SCNView/scene弱引用归零；同步比较同一次presentation样本。
- `RenderQualityV62Tests/testP01HostTeardownAndReentryOwnSeparateScenes`：4次宿主拆除/重进，默认/每日交替；清scene/pointOfView、停止isPlaying，scene/coordinator弱引用归零。
- `RenderQualityV62Tests/testP01C56ProposalSceneAssets`：真实两球2D/3D渲染素材输出；只证明素材，不是新P01页面实现。
- `CameraSurfaceTests/testC54SurfaceFirstPersonPeekAndOverviewRoundTrip`：第一人称/俯视/全局往返合同。
- `CameraSurfaceTests/testDailyProductionDefaultAndOtherHostIsolation`：每日默认相机配置与其他宿主隔离。

初次overlay测试失败的原因是测试在刷新presentation前后取了两个不同时刻的样本；修正采样顺序后通过，生产代码未改。前失败日志保留。

## 复用结论与尚未关闭的风险

**反射缓存**：缓存键仍只有RoomStyle。walnut/eastern的两种首入顺序与同源重烘焙均无差；tournament首入/后续差异MAE=0.0001353、max=0.284912，与同一来源的首次/再次烘焙差异完全一致，不能将其归因于跨页污染。切象牙桌框/酒红台呢后，新烘焙资源变化MAE=0.0916184、max=0.490982，但缓存仍复用旧资源。数据是线性半精度RGBA纹理差异，不是屏幕可见亮度或实际用户已见串色。

下一步需要选择完整外观缓存键或规范烘焙输入契约，并用同机位实图确认；当前没有全局清缓存，也不能称风险已解决。见probe-order.json。

**宿主生命周期**：有限循环支持当前拆除/重进与临时副本释放；不等于GPU内存无泄漏或长时性能验收。同一UIView host仍要求稳定scene，不支持随意换scene后沿用旧Coordinator。共享可变scene不可推广。

**相机/渲染职责**：`configureDailyClearanceRendering()`仍同时设置渲染profile与每日相机标志。模板接入应显式映射这两个策略，不能让外观复用顺带引入每日规则Controller。既有共享资源和组件优先使用，P01之后再验证普通自由击球第二消费者。

**覆盖边界**：本轮专用iPhone17Pro/iOS26.3模拟器，UDID 1D02D993-A84E-4376-9AE8-3465A6DD9967；正常字号large。未重新执行iPad/SE原生全矩阵、最低Runtime、真机手感/温升/读屏。C56此前四设备证据保留为历史，不能称P01已通过。P01旧before与横屏提案窗口不同，不做像素回归。

唯一下一步：按核心模板合同接P01的完整能力，先解决共享渲染/相机的显式配置和缓存输入风险，再做同窗口原生对拍；不采用被撤回的简化图，不从旧lab02直接全仓推广。按既有授权继续已明确的共同项；新业务位置提案单独保留评审状态。

## 收口检查

本轮361个生产Swift文件与起始指纹无变化；新增内容为测试、设计与文档。`verify-gate` FAIL 0、`verify-doc-size`、`git diff --check`通过。证据见产物目录verification.json、gate.log。设计图不等于生产迁移完成。
