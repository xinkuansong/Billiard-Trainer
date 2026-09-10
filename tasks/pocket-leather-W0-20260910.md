# v60 W0：六袋口皮革映射与真实渲染验收

日期：2026-09-10。状态：W0完成；W1–W4未实施。需求真源：`问题集合_v60.md` v60.2。

本批确认原皮革可拆成六个独立视觉子集，单袋采用暖金/琥珀色；打三保持①绿②青，同袋以皮革双色分区表达。所有预览来自真实USDZ和SceneKit，未用生成图。主工作区App代码、USDZ、物理和内容数据未修改。

## 1. 运行与输入

- 独立目录：`/Users/song/projects/.codex-worktrees/qiuji-pocket-leather-20260910`，detached HEAD `b91f0452`，叠加当时主工作区139个dirty/untracked输入。它是当时快照，不能整文件覆盖当前主工作区。
- 独立模拟器：`QiuJi-PocketLeather-17Pro`，`E1EA7F13-032E-4D39-AF6D-0FE4D942553B`，iOS26.2，Dark，默认large字号。未中断其他任务设备、构建或测试。
- USDZ：98,247,794 bytes；SHA256 `617bcf941e3a153965de63fff27150b1c02504a433da12a8a587c902636c851b`。本批前后相同。
- 当时30个源码/模型指纹：`output/pocket-leather-integration-20260910/W0/prototype/source-fingerprints.json`；详细原始dirty基线、输入、调用检索、命令日志与失败输出同目录保存。

## 2. 六袋映射

必须按App pocketIndex绑定，不能用Blender网格枚举顺序。下列网格中心是面积未加权的面中心均值，仅用于映射核验；保持原变换，不把网格移到CAD袋心。

| index | 模型子集 | 面数 | 世界X/Z中心（米） | 竖向顶视 | 横向顶视 |
|---|---|---:|---|---|---|
| 0 | Plane_001 / Leather / -X,-Z | 2342 | -1.326373 / -0.695237 | 左下 | 左上 |
| 1 | Plane_001 / Leather / +X,-Z | 2342 | +1.326374 / -0.695237 | 左上 | 右上 |
| 2 | Plane_001 / Leather / -X,+Z | 2342 | -1.326374 / +0.695237 | 右下 | 左下 |
| 3 | Plane_001 / Leather / +X,+Z | 2342 | +1.326373 / +0.695238 | 右上 | 右下 |
| 4 | Plane_001 / Leather / 0,-Z | 1468 | 约0 / -0.723952 | 左中 | 上中 |
| 5 | Plane_001 / Leather / 0,+Z | 1468 | 约0 / +0.723952 | 右中 | 下中 |

竖向对应 `CameraRig.applyTopDown2DRotated`（+X向上）；横向对应`applyTopDown2D`（+X向右、-Z向上），不代表所有设备旋转状态已做UI回归。

SceneKit源具有3条独立索引通道：位置177346向量，法线/UV各683330；`geometrySourceChannels=[0,1,2]`。Leather为12304个polygon、UInt32、三通道交错索引，数据639520 bytes。保留polygon、所有位置/法线/UV引用，不焊点、不三角化、不改源模型。测试同时核对总面数、完整面记录集合和通道数据。

## 3. 视觉决策

- 单目标：复用深色`btAccent`（sRGB约`#F0AD30`），将其转换到线性sRGB后与原albedo混合65%；保留原diffuse纹理URL、UV、法线、粗糙度、光照响应。画面实际呈现随原纹理和灯光变化，不把Token值当最终每个像素颜色。
- 未选中：恢复原材质；不可行袋也保持原皮革，仍沿用当前目标身份语义。
- ①/②不同袋：沿用`PlanThreeViewModel.color1/color2`（绿/青），与球角色对应。
- ①/②同袋：按局部网格面分为绿/青两区，保留全部面、袋洞和网袋。邻近“①②”标签备选在当前相机下不够清楚，未采用。
- 6袋全亮图仅用于核对完整性，正式单目标不是六袋同时高亮。普通和enhanced透视中选中部分正常被模型遮挡；不再使用高renderingOrder或关闭depth的覆盖圆盘。
- 顶视、普通透视、enhanced单角袋、双色不同袋/同袋的原图均已目视。原型直接替换对应面，没有原皮革与选中色双层叠面。运行期快速切换、iOS17线程安全、多实例隔离仍归W1，不能用静态图证明。

预览和基线：

- [原皮革](../output/pocket-leather-integration-20260910/W0/prototype/render/original.png)
- [六袋暖金核对图](../output/pocket-leather-integration-20260910/W0/prototype/render/six-gold.png)
- [enhanced单袋](../output/pocket-leather-integration-20260910/W0/prototype/render/enhanced-single-gold.png)
- [双色不同袋](../output/pocket-leather-integration-20260910/W0/prototype/render/roles-different-pockets.png)
- [双色同袋](../output/pocket-leather-integration-20260910/W0/prototype/render/roles-same-pocket-split.png)
- 改前真实App：`W0/baseline-ui/daily.png`、`aim3d.png`、`planthree.png`及对应AX文本。2D/3D截图固定模拟器、外观、字号；daily和planthree使用已有fixture，3D由实际练习卡进入。页面身份断言通过，不以App在前台代替进页成功。

## 4. 技术选择与成本

选择首次加载时按原USDZ生成六个索引子集并缓存；后续实例复用只读顶点/纹理/索引数据，节点与可变材质独立复制。保留现有缓存锁；先完整验证再安装子集，失败保留完整原皮革并提供诊断。选中/原色材质预先准备，运行期切显隐，规避历史iOS17渲染中修改材质风险。

不另外打包一份USDZ，不重烘焙贴图。W0基准是在未接renderer的模型副本上安装已缓存子集；生产缓存与线程安全尚待W1实现。

iPhone17Pro模拟器、Debug、同一进程实测（不是物理手机/冷磁盘/发布性能）：

| 测量 | 结果 |
|---|---:|
| 单独重新解析原USDZ，受系统文件缓存影响 | 454.22 ms |
| 首次生成六袋子集 | 72.33 ms |
| 另一渲染用例提取 | 75.67 ms |
| 5次原表缓存克隆 | 0.94–1.13 ms |
| 5次缓存子集安装原型 | 0.376–0.461 ms |
| 新六袋索引总数据 | 639520 bytes |
| 新正式资源文件 | 0 bytes |

此表不包含最终多态材质GPU内存、持续帧耗时和真机功耗；W1/W4继续实测。生产实现需验证节点路径/模型结构后应用缓存，不能照抄原型的唯一节点名查找；也需补越界读取保护、材质诊断、幂等、共袋API和命中父节点解析。

## 5. 测试结果与首轮失败

- 最终`make -f scripts/Makefile test ONLY_TESTING=QiuJiTests/PocketLeatherMeshTests TEST_DESTINATION='platform=iOS Simulator,id=E1EA7F13-032E-4D39-AF6D-0FE4D942553B'`：退出0，4 tests / 0 failures，32.64s，`prototype-r4-raw.log`。
- 改前`QiuJiUITests/PocketLeatherUITests`：退出0，3 tests / 0 failures，70.3s，`baseline-r2-raw.log`。
- test命令成功构建并加载App及测试目标；此前主工作区`before-build.log`只作旧基线，不冒充本原型构建证据。
- 原图重复snapshot差异0；重组恢复后最终最大通道差1/255、平均差0.000000794（byte尺度）。完整面/UV/法线记录保持精确相同。
- 首轮要求逐像素完全相同失败：独立draw call导致少数MSAA/光照8-bit舍入差，原日志保留；离线复算最大4/255，平均0.000996。现断言为最大≤8/255且全图均值<0.01 byte，同时保留严格面/法线/UV不变量；并非删除几何断言换绿。
- 第一版直接将diffuse替换UIColor造成平涂；第二次强转原diffuse为UIColor崩溃，发现其实际为NSURL贴图。已改为保留贴图的surface modifier，r3/r4全部通过。失败日志和r1/r2原图保留，不能把旧图作最终方案。
- 初始helper复杂map编译超时改为显式循环；测试首次前台宽松断言已改成各真实页面独有控件断言。

最终xcresult仍在独立目录`build/DerivedData/Logs/Test/Test-QiuJi-2026.09.10_11-13-38-+0800.xcresult`；基线在`Test-QiuJi-2026.09.10_10-58-14-+0800.xcresult`。原型源副本在`W0/prototype-source/`，只用于继续开发，不在主App编译目录。

## 6. 范围与后续

S01–S22全部做了静态入口/调用复核，详`W0/prototype/coverage.csv`；11处创建markers，8个单目标控制器，PlanThree独立袋环。S19/S20没有目标袋高亮，S21/S22没有此红盘选择调用，须保持中性；正式JSON、缩略图、视频未写入。

W0的3页改前UI和4项原型测试不证明22类页面已接入。W1开始时重新读取当前主工作区指纹与v59/瞄准辅助最新API，只合本任务差量；W1共享渲染/命中/缓存、W2单目标生命周期、W3打三、W4全入口及iOS17/紧凑机/iPad仍待实施。已定位的清桌/开球索引复位未刷新风险需先复现，不凭静态推断登记为已修复。

本批未提交、未推送、未发布；真机、iPad、紧凑机、iOS17、VoiceOver及持续GPU性能未验证。W1依赖已就绪。
