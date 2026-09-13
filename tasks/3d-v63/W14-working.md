# W14 图谱页面接入

2026-09-13，真源问题集合_v63.md：多路线与打点一一对应，透视标签不误指、线条不混淆，保留2D比较及开关，每页至少一组固定多轨迹样例。前置页面批次W13本地验收已归档。

源码基线：两图谱使用AngleSceneView固定tapsOnly/autoFit，VM已有cameraMode但页面没有切换；轨迹使用.table绘制。首次接入复用相机保存/恢复和全桌观察、BTSceneObservationMenu、ShotPerspectiveLayout。3D保留既有轨迹开关/力度和吃库高低杆参数，球库编辑/台面选球选袋在2D。多轨迹无单一当前杆，不提供可用的回到瞄准（共享菜单项禁用）。未改求解、输入模型、轨迹数组或评分。

两页构建atlas-build-r1/session19962终态0且BUILD SUCCEEDED。iPad初次UI atlas-ui-r1正在验证模式往返及第0轨迹开关选择保持；尚未验证实际参数修改、全部八路对应、紧凑设备或标签遮挡。

atlas-ui-r1/session81271终态65：两项均失败，点击第0轨迹后仍已选（吃库27.374s/分离26.407s）。3613A2E7原图已查看，多轨迹实际绘出；不代表选择通过。工具栏单ToolbarItem直接并列两个View只显示切换按钮，已改既有HStack布局恢复更多入口。r2只跑吃库，保留UI断言并输出真实AX frame/层级用于查点击未生效，未改轨迹选择模型。gate-r1/session56415终态0，针对HStack修改前版本。

atlas-ui-r2/session4187终态65，吃库25.461s同一断言失败，工具栏HStack已编译。AX证据：第0按钮frame=(17.4,765.6,19.3,19.3)pt，八项均已选，顶部仍8/8，未误切其他轨迹。父legend frame=(17.1,765.6,19.8,170.8)，按钮约19pt，移动端命中偏小但不能直接归因为点击失败；选择模型自身仅在最后一档时拒绝关闭，当前8档不应被拒绝。保留r2完整层级，下一步排查真实触摸命中与2D对照，不能放宽断言。无活跃句柄。

后续实证：atlas-hit-baseline-r1的2D开关对照通过，进入3D才失败。将3D图例八项各设44pt矩形contentShape并分配8×44+7×3总高度后，atlas-hit-r2终态TEST SUCCEEDED，2项/59.377s/0失败，2D对照、3D第0项关闭及往返保持全部通过。已查看237F9F03分离八路和16AB5B05吃库七路原图，更多入口可见、关闭的红档变暗。证据位于output/3d-v63/W14/atlas-hit-r2-attachments；这证明组合布局修复有效，不单独证明SwiftUI内部命中失败机制。

新增全部八项逐项开关、至少保留一档及44pt触摸区断言，清除临时全AX日志；SE验证atlas-compact-all-r1/session35941终态0，2项/71.148s/0失败。已查看2E0D0AC2吃库、022E1388分离单路截图：仅紫色第7档亮起，对应紫色轨迹保留；375pt宽下八项完整可点，母球可见，部分左库边被图例覆盖。吃库顶部横向信息带右端需滚动查看。参数变化、其余观察模式及角度图谱范围仍待核验，W14保持进行中。git diff --check及verify-doc-size通过。无活跃测试句柄。

参数验证：atlas-parameters-r1/session34289终态65，分离50.432s通过，吃库在打点卡片定位失败。保留失败原始层级8412402E：卡片实际存在，Other frame=(19.5,442.5,336,170.5)，页面cushionEnglishAtlas.spinPad覆盖共享spinPad.card，关闭背景为同ID Button。测试改查Other而非改变生产交互；atlas-parameters-r2/session54123终态0，吃库53.425s通过。两页实际拖力度、母球/目标球/目标袋/全桌观察、回瞄准禁用及往返力度保持均通过；吃库另验高1%真实读数、左右键隐藏、回中与关闭。0FAD654B原图已查看，力度4.3、高1%且母球露出；截图仍在计算中，不作为新高杆轨迹计算完成证据。

范围补核：AngleHomeView的angleDynamic路由标题为“角度与瞄准”，对应方案W14“角度”范围。AngleDynamicView仍tapsOnly/autoFitsRotatedTable=true且无切换按钮；需接入现有cameraMode、观察菜单、2D编辑提示。不能把两张多轨迹图谱通过视为W14完成。

角度与瞄准接入：dynamic-baseline-r1实页通过并查看9F05997D原图，默认29°/半球/dR0.96/横移27.5mm。AngleDynamicView现增加44pt切换、现有四焦点观察菜单、3D收起球库及拖球提示，2D保持编辑。ViewModel计算未修改；metrics作为组合可访问元素提供整组读数。dynamic-ui-r1/session62540正在验证SE四焦点与回切读数保持，尚无通过声明。

角度实页结果：dynamic-ui-r1/session62540终态0，1项34.252s通过；四观察焦点、2D/3D往返组合几何读数保持，球库3D隐藏/2D恢复通过。07D59C3E与D616E567原图已查看，球形和29°等读数一致。视觉未收尾：3D白色“瞄准线”文字随方向倒置，黑色进球线文字亦斜转，可读性欠佳，须追踪共享标签朝向后复验。dynamic-gate-r1/session41237终态0。W14未验收；无活跃测试句柄。

DR-265标签修复：根因是inline标签沿用固定俯视翻转规则，3D无视相机。保留线旁锚点，复用角度数字billboard，2D恢复flatYaw；重建时清理旧引用。labels-r1实际UI1项33.241s通过，单测类名错误导致0项（不计入通过）。labels-unit-r2正确选择TableAssistSurfaceV63Tests后，实际1项1.182s通过，四方位文字基线/上方向与相机点积>0.99，线标签锚点不变，2D旋转恢复。CA840E23/AD13F31C实页原图已查，文字正向且2D布局恢复。待补辅助显示开关实页验收，W14仍进行中。

grid-r1/session6300终态0，三页网格开关及模式往返实际1项96.571s通过；490FA01E/688C4427/C124C1BF三原图已核。W14本地验收见W14-acceptance.md；其余批次及平台限制不变，无活跃句柄。
