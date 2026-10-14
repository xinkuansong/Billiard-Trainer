# 教学插图线条对比度 · 2026-10-13

状态：代码、构建及门禁通过；加塞吃库图谱同机前后截图、瞄准修正和旋转与加塞浅深实页已核对。未安装真机、提交或发布。

## 事实与根因
用户截图中的瞄准修正图使用BTTableFigure真实台呢底图。DeltaAimFigure、ThrowCollisionFigure、SquirtSwerveFigure、SolverCompareFigure直接把浅色界面深绿btPrimary用于实际轨迹，标签却用亮绿FigureLine.contact；摩擦和B档使用暗橙btWarning。绿色底图与浅色页面外观并不共享亮度，因此页面文字色不能直接用于台呢图形。

用户原图按内嵌ICC转为sRGB，选无标记台呢区域的众数为(24,111,17)。按该底色计算：原深绿1.03:1、暗橙1.67:1；候选实际亮绿含95%透明度3.89:1，浅橙4.13:1、浅蓝4.22:1、浅金4.84:1。非选中路径85%不透明度后最低3.11:1。这是色值合成估算，不是最终原生抗锯齿像素或所有台呢色的可访问性认证。数据见output/line-contrast-20261013/contrast-check.json。

## 修改
- TrajectoryStyle.TeachingFigure / FigureLine增加actual、effect、follow、guide；亮绿沿用接触标记色，另外三色通过Asset Catalog定义浅深同值，仅用于台呢覆盖层。
- 瞄准修正五幅图：实际轨迹亮绿，摩擦/低杆/B档浅橙，高杆浅蓝；参考线取消额外变淡，非选中路径28%→85%，仍以原线宽/标签区分选中状态。线、标签同色；假想球标签改随白圈。
- 旋转与加塞：分离路径及吃库图使用上述色板，入射线/库边参考线恢复可读亮度。TheoryT03复用SeparationPathsFigure，因此同样受益。
- 球位、路径、物理参数、夸大倍率、线宽、交互与页面按钮配色未更改。

## 其他页面分析
源码排查13个BTTableFigure来源文件，结果见output/line-contrast-20261013/source-audit.json。
- 瞄准方法、瞄准原理：金色教学细线有次级对比度风险，本轮只读记录，需原生图确认后处理。
- 瞄准点对照表的深绿曲线画在btBG上；理论T04–T10大部分流程线也在普通卡片上，不属于截图中深绿叠台呢的同一缺陷。
- 理论T01/T02主要使用已有白/亮绿/球色；TheoryT03共享分离图本轮一起更新。
- SceneKit按球号绘制的目标轨迹（含绿色球、黑8）属于另一语义系统，未用本轮教学色全局替换。其他台呢配色尚未逐页视觉审查。

## 验证与阻塞
- 四个修改Swift文件的swiftc -frontend -parse退出0；仅证明语法解析，不等于完整编译。
- verify-gate通过（FAIL 0 / WARN 0、路由签名/写盘面通过）；git diff --check通过。
- 原生基线build-for-testing退出65，SwiftCompile非零，日志没有更具体的错误原因，不能证明由磁盘直接导致。同期磁盘可用降至约162MiB，之后约142MiB，不能安全继续构建/启动截图。
- 已移除仅本会话创建的build/LineContrast失败产物和198229AD-10C8-48B6-9723-BB9DF7AD4D4C专用模拟器。旧缓存、现有模拟器、其他会话进程未动；失败日志保留。前后采集配置是未执行计划，不能算截图证据。
- 后续空间短暂恢复至约2.2GiB后，复用空闲build/DerivedData增量构建成功（after-build.log，BUILD SUCCEEDED）。最终四文件及三资产哈希见final-source-hashes.json。
- 原生重试使用A05C3B61-7BA6-4A04-AE76-B65FF9B4EC77独立模拟器，最终App配既有黑盒UI runner进入瞄准修正；仅首屏PNG成功保存，AX写盘报NSCocoaErrorDomain 640 / NSPOSIXErrorDomain 28 / No space left on device。1项UI测试失败，其他三项未执行。首图已打开核对，只显示介绍/参数，不含待验线条，不能用于证明修复。
- 已停止队列、关闭并删除本次设备，删除本次两份products克隆，保留原日志/首图/失败result。设备清理shutdown=0，terminate=3（应用已退出），不冒称terminate成功；构建主目录保留。没有删除其他会话缓存。
- 当时待办：补两页浅深原生截图；现已完成，见下方补验结果。TheoryT03仍只确认源码共享关系，未单独采图。

## 追加：加塞吃库图谱
- 用户补充要求吃库前保持与吃库后相同颜色。CushionEnglishAtlasViewModel.redrawEnabledTrajectories原先仅对preCushion调用color.withAlphaComponent(0.55)；现改为直接color。原八色身份、虚线/线宽、球位和物理计算保留。
- 同类SeparationAngleAtlasViewModel直接使用trackColor，无此淡化；AngleDynamicAssistOverlay的20%是管道面积填充，不是轨迹，边界仍使用原色，未改动。
- cushion-build.log确认BUILD SUCCEEDED；cushion-verify-gate.log为FAIL 0 / WARN 0；swiftc语法解析与diff检查通过。cushion-source-hashes.json记录本次源码；之前七项教学色文件哈希未变化。
- 独立iPhone 17 Pro / iOS 26.3同一初始球形（30°、杆速1.50）前后原生图已打开逐一核对：原55%入射虚线变为原色，出射段保持原色。用户截图杆速1.74，因此不是与用户图完全同状态比较。基线配置初始方向字符串未命中runner的landscape分支，但页面自动横屏，实际窗口874×402，截图有效；后测配置已使用landscape。
- 前图：output/line-contrast-20261013/cushion-before/phone/p08b-light/TABLE-P08b-default.png；后图：output/line-contrast-20261013/recovery/phone/p08b-light/TABLE-P08b-default.png。已验证模拟器可见差异，未安装真机，未代表用户最终观感验收。

## 原生补验进展
- 磁盘恢复后复用独立设备重采，两页浅色完整滚动采集通过。已实际打开瞄准修正scroll03/04/06/10/14，覆盖五幅教学图；旋转与加塞scroll01/10覆盖分离与吃库图。原来融入台呢的绿线、暗橙与非选中线已可见，标签与路径匹配。逐图记录：output/line-contrast-20261013/native-visual-review.json。
- 上述历史ENOSPC失败仍保留，不能把历史失败首图当修复证据；新证据统一位于recovery。TheoryT03共享组件仅源码确认，尚未单独打开该页；其他台呢颜色/字号/机型及交互极值未扩大验收。
- 最终补验：recovery五项采集全部通过（78张滚动/菜单原图），加上cushion-before一项共6项；关键15张前后/浅深图已实际打开审查，逐图见native-visual-review.json，其余滚动图不冒称全部目视验收。瞄准修正深色scroll03/06/10/14和旋转与加塞深色scroll01/10通过线条可见性核对。
- 独立设备41E9CB8E-4715-497F-BD05-3B2B44D66736已关闭并删除（delete退出0），移除本次products克隆；完整截图、AX、测试结果、日志及源码/二进制哈希保留。未改他人模拟器或缓存。
