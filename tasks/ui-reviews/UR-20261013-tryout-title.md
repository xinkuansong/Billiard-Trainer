# 上手试打长标题 · 2026-10-13

用户授权按每日清台规则修复，并用模拟器查看。范围：动作库详情→上手试打（P03）；DR-383。构建与原图分别验收，用户观感待复验。

## 根因与实现

调用链为DrillDetailView→PositionPlayComposerView→PositionPlayEditorConfiguration→FreePlayView。标题来自完整nameZh；旧代码仅对“分离角与走位”特判换行，其余单行自然宽进入dailyFoundationReservation。长标题增大导航预留，使球库无法同排，额外行高缩小球桌。

修复：试打标题预算固定60pt，使用BTTablePageTitle既有短标题单行、多字两行、奇数中间字右侧居中规则。fitsLongText仅试打启用；按SwiftUI实际两行自然宽统一缩放完整字形，固定60×34pt占位，测量值不回流布局容量。保留返回触点、全文无障碍名称、业务球形及相机/物理。

生产修改仅FreePlayView试打分支及共享标题可选参数（默认false）；新增定向UI回归。无真机安装、提交或发布。

## 证据与回归

- [改前长标题原图](../../output/tryout-title-20261013/before/phone-long-title-landscape.png) / [每日对照](../../output/tryout-title-20261013/before/phone-daily-landscape.png)。方向副本来自保留原始PNG的旋转，非重绘。
- [修后常规屏中文长标题2D](../../output/tryout-title-20261013/phone-r3/title-drill_c029-2D.png) / [3D](../../output/tryout-title-20261013/phone-r3/title-drill_c029-3D.png)。已实际打开核字形和球桌，9字无省略，六袋完整（2D）。
- iPhone 17 Pro（Daily-Fix-Phone-20261009，iOS26.3）：UI 1项通过，含4种标题各2D/3D及返回详情。每日与所有试打stage均为(x128,y42,w618,h342)pt；标题AX包络≤60pt。这里是stage尺寸，不冒称桌框实际外径。
- iPhone SE3（Daily-Fix-SE-20261009）：se-r4 UI 1项通过，4种标题各2D/3D及返回详情。每日中八与所有试打stage均为(x65,y77.5,w537,h297)pt；已打开四类2D及长标题3D原图，标题无省略、2D六袋完整。
- 既有DailyLayoutMetricsTests 29项通过；最终生产源码已完成Debug构建。verify-gate通过（FAIL0），verify-doc-size与本轮文件git diff --check通过。
- 测试testTryoutLongTitlesPreserveDailyTableSize覆盖c003（4字/球形选择）、c029（9字）、c034（8字）、c065（中英混排）。断言同机每日中八15槽的stage宽高/位置、渲染面与stage一致、标题宽及全文AX名称、2D/3D切换和返回；另以真实PNG核对视觉，AX标签不能证明无省略。

## 保留的失败轮次

- r1：仅接入60pt共享标题后球桌恢复，但两行文字出现省略；已拒收。最终改为SwiftUI自然宽量测+整体等比缩放，保留r1原图。
- phone-r2：29布局单测通过，UI用例遗漏多球形选择弹层而失败；补真实弹层选择后phone-r3通过。工具300秒超时与实际xcresult失败分别留证。
- se-r3：旧设备保留九球偏好，每日9槽而试打15槽，stage大小相同但顶部位置相差16.5pt；这是对照状态不一致。测试显式重置每日状态并选择中八15槽，保留位置断言重跑，不通过放宽断言掩盖。

原始PNG、AX、日志在output/tryout-title-20261013；xcresult与隔离DerivedData在build/tryout-title-20261013。与实时评审设备03/07及其记录隔离。


## 最终结果
两台独立模拟器均完成4种标题×2种相机回归（共16个试打截图状态，另2张每日参照）；2项UI用例、29布局单测通过。未修改实时评审设备或其状态。

[SE长标题效果](../../output/tryout-title-20261013/se-r4/title-drill_c029-2D.png) / [SE每日参照](../../output/tryout-title-20261013/se-r4/title-daily-reference.png)。phone-r3.log、se-r4.log和对应xcresult为最终通过证据；失败轮次保留。
