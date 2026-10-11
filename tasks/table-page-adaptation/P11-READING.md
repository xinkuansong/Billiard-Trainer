# P11 · 教学阅读与嵌入球桌

用户连续授权的下一批。范围：ContactPointTable、AimingPrinciple/Methods/Correction、SpinAndEnglish、BallFeel、TheoryT01–03，以及共用BTTableFigure。保留文档滚动、章节、公式/教学物理、交互滑块、前后景说明与练习导航；不套全屏HUD。DC几何/真实素材/统一线语言适用，15槽/球杆速度/相机按钮/开球等操作页能力不适用。

源码检查：BTTableFigure的backdrop仅onAppear采集比例，旋转后Image aspectFill与overlay分别按新宽高拉伸，可能失配。计划先采集9页手机/平板原生横竖图，再修复尺寸生命周期和共用均匀投影；宽屏阅读容器按已有阅读规范限定宽度，保留BallFeel明确全宽演示范围。验证几何等长/直角/中心对齐与同图旋转、返回、滑动。

source-before在output/table-page-adaptation/P11/r01。P11_ReadingTableUITests已加入P07 r3编译，但阅读生产尚未改；等待P07矩阵后用该构建采集before。禁止把源码猜测当作已复现视觉事实。

## 当前交接
P07 r4的9页iPad改前竖屏采集通过（reading-before，300.858秒）；此前旋转断言失败证实普通阅读页被锁方向。before均真实原布局，共用投影未改。生产现已补均匀aspectFill投影与尺寸生命周期、720pt正文上限、iPad横竖及原理四个引线标注；等待P07在途矩阵完全结束，再启动build和run-matrix.py。共用投影几何测试和9页真实旋转/滚动/滑块；同构建附P12及后续内部入口before审计。

首构建成功、10项图形单测通过；iPad首阅读页仍未旋转（final/ipad原日志保留）。下一候选补方向组件在窗口布局后按有效mask重核，使用windowScene的设备trait而非过早的子controller trait，并加真实方向诊断；尚未构建，不宣称根因已闭环。手机/SE旧构建巡游在途，P12独立iPad旧布局采集并行，无下一构建覆盖。

方向诊断更新：重读FL-139发现同类模拟器方向失灵历史；同时复核P02–P07所有iPad PNG仍为竖屏，旧测试漏断言横屏，相关横竖通过声明已撤回，保留状态流/竖屏验证。撤回本次QiuJiApp方向候选（保存withdrawn-orientation-candidate.swift），先重启仅本任务隔离iPad，用同一构建复验P11，禁止再次把环境问题提前归因到生产逻辑。

方向证据进一步校正：P02原测试确含实际横屏断言，01-standard-2d重新目视是横屏，原结论有效；XCUIScreen PNG存储宽高不能替代显示方向。P07原AX直接证实window仍820×1180，P03–P07补强横屏断言后统一重验。P11同构建重启隔离iPad后9页横竖实际通过，无生产方向修改。

## 定向收口
同一构建经模拟器重启：10单测、手机9页/SE9页/iPad9页横竖巡游全部通过；主要原图已审，REPORT/index在output/table-page-adaptation/P11/r01。生产App方向文件无改动。P12–P15构建与最终矩阵已启动（P12/r01/build.log、run-matrix.py），包括P03–P07真实横屏补验；P11大字号深色三页随该构建检查。未真机/提交。

深色最大普通字号代表三页补验通过：P12/r01/final-r4/reading-large-dark，原图已审。保留普通字号9页/三设备完整定向证据。
