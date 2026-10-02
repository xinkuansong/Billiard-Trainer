# 材质与资产独立研究

日期：2026-10-02。角色：材质与资产研究员。首轮未阅读其他角色报告。本轮只读源码、USDZ/图片和官方资料；没有修改生产代码/资源，没有构建、渲染、运行手机负载，也没有新增性能实测。

## 结论

**建议当前保留 SceneKit 的消费端，先验证引擎无关的资产准备与缓存优化；将定制 Metal 保留为第二阶段挑战者。** 球迹已经将静态房间照明离线化、将每日清台球面反射预积分。换引擎时，如果保留相同高密度桌体、纹理、阴影算法和片元覆盖，这些成本不会自动消失。资产质量也不能由“USDZ 成功加载”证明：最终画面包含大量 Swift/MSL 覆盖，并不是源模型的通用 PBR。

最有根据的待验证路线是：①版本化离线反射资源，减少首次进入成本；②为移动管线准备只含实际消费材质的衍生资源，避免原型持有过时贴图；③按实体用途验证桌体网格的分区与 LOD；④仅在纹理/带宽计数器支持时测试 GPU 格式与采样策略。它们均可在 SceneKit 中先获益，没有证据要求先迁移引擎。

**最强反对意见**：当前 SceneKit 导入的多索引展开、隐藏节点提交、材质实例和内部 pass 可能使桌体资源优化仍难以控制；定制 Metal 可以精确决定格式、不可变 buffer、批次与渲染区域。但本轮没有实际 draw/tiler/纹理驻留证据，不能把这种控制能力等同已实现节能。若相同输入、画质及分辨率的最小 Metal 原型稳定胜过已优化基线，推荐应改变。

## 证据基线与读取时点

- 源码：`baseline-source/`，共同快照时间 `2026-10-02T08:10:51.577770+08:00`，HEAD `b69aa749b12a4e322da1bbca1a78536349531c47` 加 dirty 状态。下述源码行号均相对于这个快照，而非继续变化的工作区。
- 资源：工作区实际读取窗口 `08:17:03–08:17:06 +08:00`，137 个直接文件，逐文件读取前后 SHA-256 均一致。之前的探索读取在 `08:12–08:15`。目录存在并行房间工作，不能把资源与 HEAD 视为一套已验收版本。
- **状态更正（交叉讨论时核对）**：用户已选定 8×6 m、层高 3.6 m，三风格重烘并完成正式试用集成；真源为当前 `tasks/PROGRESS.md:15`、`tasks/ROOM-SIZE-STUDY-20261002.md:3,32–48` 和 `QiuJi/Core/Scene/BakedTrainingRoom.swift:10–11`。首轮“尚未定案”表述错误，现撤回。已试用集成不等于最终画质/空间舒适度接受、提交发布或持续性能验收；本报告仍保留原资源读取窗口与 SHA，未来性能对照须重新冻结完整包与相机/灯光。
- 可重跑原始脚本：[assets-measure.py](assets-measure.py)。原始结构化输出、每个文件完整哈希、PNG IHDR、USD Mesh/GeomSubset 统计：[assets-evidence.json](assets-evidence.json)。工具：Python 3.14.7、`/usr/bin/usdcat`，Apple USD Tools `0.25.2`。脚本不生成新模型、不保存完整 USDA、不触碰输入。
- 几何口径是 `sum(faceVertexCounts - 2)` 的**面扇等价复杂度**，不是实测 SceneKit GPU 三角化数量；19 Mesh 定义也不是 19 draw calls。纹理估算假定 RGBA8，没有证据证明所有图片按该格式驻留。

## 当下资产量级

| 资源 | 文件/结构事实 | 仅作容量模型的估算 |
|---|---|---|
| `TaiQiuZhuo.usdz` | 104,244,229 bytes（99.415 MiB）；42 包内文件，31,994,656 bytes USDC + 41 PNG；SHA `0e011ae72889d56a97255d8d69f2a7c0615ad779340ab64b938c2947817b48d1` | 所有 PNG 独立展开到 RGBA8 基层约 402 MiB，加完整 mip 约 536 MiB；这不是峰值/实际驻留上界，CPU 副本与 driver 分配可能另计，运行时也可能少用/共享/压缩 |
| USDZ 源纹理 | 24 张 2048²（18 RGB、6 RGBA）、15 张 649×325 球号、1025² 白球、710² 纹理各一张 | 不能用 PNG 压缩后大小推 GPU 内存或每帧带宽 |
| 桌体 `Plane_001` | 422,048 源 points；240,435 polygons；348,164 面扇等价三角形 | face-varying 法线/UV 在其他引擎转换后可能展开；源 points 不是最终统一索引顶点数 |
| 桌体 `Plane_007` | 64,180 points；125,984 已三角面 | 消费端明确有共面腿面/leg shell 排序契约，不应直接删除所谓重复壳体 |
| 球和球杆 | 16 球各 720 三角面，合 11,520；球杆 13,630 面扇等价三角形；全模型 499,298 | 桌体两 mesh 合 474,148，约95%；提示几何研究机会，不证明热路径受 tiler 限制 |
| 单个房间 | perimeter：赛事25,800、木质22,040、东方29,936三角面；floor各2；两张照明图为2048²+1024² | RGBA8+mip约26.67 MiB，另有模式 atlas 1402×1122约8 MiB、共享1024² yarn约5.33 MiB；仅三类图合约40 MiB/已选房间，不含海报/几何 |
| `TableMaterials` | 3张1024² RGB（两皮革微表面、一木材 coat），包体3,376,716 bytes | 若每张RGBA8+mip，则共16 MiB；实际粗糙度可使用单通道，当前MTK loader输出需实测 |
| `BallStickers` | 90张1024×512 RGB（6套×15球），6张预览；总PNG包体3,269,468 bytes | 一套15球若RGBA8则30 MiB基层、约40 MiB含mip；全目录PNG展开约185.58 MiB基层，但不会默认整目录一起加载 |
| 房间探针 | 当前512×256 RGBA16Float，含mip；R新增同尺寸filtered纹理，128² RG16Float response LUT | 每探针source约1.333 MiB，filtered再约1.333 MiB，LUT 64 KiB且共享；三个样式并存约8 MiB加共享LUT，neutral另计。不含snapshot/CPU转换临时内存 |

USDZ 压缩方法字段本次全部为0；包内PNG本身仍是压缩图片。USDZ要求零ZIP压缩及64-byte成员对齐，不能以普通ZIP替换资源来优化加载。[OpenUSD格式规范](https://openusd.org/release/spec_usdz.html)（查询2026-10-02，规范版本1.3；不据此推定iOS17支持规范最新新增图片格式）。

`Plane_001` 的材质分区面扇等价数量：TaiNi 19,682、Gold 10,392、White 132,706、Leather 24,584、BlackWood 18,744、WeiBian 5,240、Wood 5,816、MG_Gold 126,280、Black 4,720。`Plane_007` 没有 GeomSubset 数组；其材质及壳体用途以消费端 `TableAppearance.swift:99–114` 为证，而不凭名称把全部点视作廉价可删。White同时包含置球点、库边瞄准点和袋网（`:51–57`），材质分区不能当实体分区。仅上述几个材质的总量不支持“全部减面”建议。

## 最终材质由谁决定

| 对象 | 已读源码事实 | 迁移影响 |
|---|---|---|
| 台呢 | `MobileTableRendering.swift:96–106`以常量替换均匀2048²底色，原法线/粗糙度保留并2×重复；`MobileContactOcclusion`在同文件`:167–225`追加活动球接触、rail AO和纤维调色；`MobileReferenceLighting.swift:311–340`继续追加自定义直接照明/阴影 | 不是一个原始USD Preview Surface可表达的最终效果；烘焙球影会随球位失效，不能静态化 |
| 木材 | `MobileReferenceLighting.swift:353–359`设constant并绑定1024²WoodCoat；`TableSurfaceTextures.swift:10–16`约束全部mobile木材用同一roughness图；主题底色由`TableAppearance.swift:86–95,152+`覆盖 | 原PBR材质导入不是参考画面；不能误把标准roughness=0.24当当前最终全部木材规律 |
| 皮革 | `MobileReferenceLighting.swift:661–667` + `TableSurfaceTextures.swift:33–62`替换源normal/roughness为微表面；通过导数构造切线，保留镜像UV，区分角/中袋物理纹理尺度 | 微表面可离线，随视角高光须实时。不同引擎需保持切线手性和采样原点；原Leather底色仍参与细微色变，不是完全废图 |
| 六袋高亮 | `PocketLeatherAppearance.swift:6–26,50–56`先在线性albedo阶段改变角色色再照明；`PocketLeatherMesh.swift:25–112`按材料+世界空间拆六袋，`:195–246`缓存几何签名及场景独立材料 | 默认PBR tint/最终输出乘色不保证等价。6袋身份、两个角色、主题恢复必须保留 |
| 球 | `MobileReferenceLighting.swift:256–273`使用constant+MSL自定义球面，选择台呢bounce与probe；`BallStickerAppearance.swift:27–55,105–148`生成对面球冠UV、处理接缝/极点并覆盖底色 | 不能直接导入USDZ球号即宣称迁移完成；完整旋转、相反面、落袋/回球区需比对 |
| 房间 | `BakedTrainingRoom.swift:39–103`使用geometry-only USDZ和constant已照明RGB；地毯分离yarn与macro atlas后除原烘焙albedo保留照明（`:106–134`）；海报额外几何/材质（`:139+`） | 通用引擎应保留unlit路线。重新加入动态PBR灯会重复照明；source与最终输出色彩校准要独立核对 |

**事实**：每日清台为R/reflection（`AngleTrainingScene.swift:28–38`）；其他场景不能假定已采用同profile。**推断**：删除已经被覆盖的源贴图引用，可降低某些准备成本和资源保留风险。**未证实**：SCNScene原型中的UIImage/URL引用是否已全部解码、上传或被SceneKit回收。原引用存在仅证明潜在保留，不能据此宣称“GPU多占536MiB”。

## 冷加载、跨场景复用和缓存

1. `TableModelLoader.swift:33–79`序列化首次SCNScene解析并永久持有原型。`:105–107,309–320`每实例clone并浅拷贝geometry/material；代码设计共享不可变顶点/贴图contents、隔离材质参数。**不等于渲染器必然跨SCNRenderer共享相同GPU buffer/texture**，需要GPU捕获或分配表证明。
2. `BakedTrainingRoom.swift:13–35`仅缓存一个选中样式的原型，retain图片contents并隔离材质；切样式时旧场景仍活着，其资源仍可被保留。`TableAppearance.swift:86–95`初始化字典创建四个主题UIImage，**UIImage创建不是四张纹理已全部解码上传**。Ball sticker的NSCache costLimit为36MiB（`:9–24`），属于缓存策略；活跃SCNMaterial持有图片，不能把36MiB当进程硬上限。
3. `RoomReflectionProbe.swift:286–298`以样式缓存，首次用当前场景生成六张128²face，另下拍一次floor，进行sRGB→linear、SH9投影和GPU上传（`:305–381`）；没有磁盘复用。cache解锁后才bake，不能由锁的存在推定同样式并发首次生成完全去重。
4. `PrefilteredReflection.swift:29–49,54–81`首次生成compute library/pipeline、256样本LUT与逐mip环境卷积，且`waitUntilCompleted`；不是每帧发生。离线化主要针对首次进入/切换峰值，不可当持续每帧节能。R已有每帧预积分资源，不能把旧64样本消融收益再算一遍。
5. 缓存键当前只有RoomStyle，未编码实际安装场景的完整依赖。首轮建议把主题/曝光统统加入键过宽，现修正为下文“实际探针输入”依赖图：最终主视图输出变换通常不使探针失效，但当前材料中已写入的曝光相关 fragment mapping 是例外。中心probe是有界近似：能保持既有效果，但不能自动正确表达近墙、低机位或回球区的局部反射；除非新需求/对照证明需要，不扩张为逐球每帧probe。

## 保画质的离线与实时分工

| 工作 | 推荐分工 | 应验证的收益 | 停止条件 |
|---|---|---|---|
| 房间照明 | 保留现有离线diffuse lightmap；选中样式加载；照明与地毯albedo分别管理 | 避免增加房间每帧灯与阴影；改善cache命中/切换 | 出现重复照明、墙面色阶/织物细节改变，或对照未冻结已选8×6房间的完整资源/运行配置，停止晋级 |
| SH9、GGX环境、BRDF LUT | 候选离线预生成，可版本校验后加载，保留失败诊断与基准路径 | 首次进入CPU/GPU峰值、首帧延迟、短时内存；steady-state不假定更快 | 球灯板、台呢bounce、桌下floor颜色不同；资源键失配；冷加载收益落在噪声内 |
| 过时/常量源贴图 | 创建移动管线专用衍生USDZ/纹理清单，先找实际引用，保留legacy/export所需母版 | 包体与解析/解码保留；纹理捕获确认后才报驻留收益 | 任何offline或2D消费受影响、必须源纹理丢失、身份/UV变化，停止 |
| 粗糙度/法线格式 | 数据图保持linear；测试R8/RG等可用格式或ASTC，正确mip；不要把正常图转换sRGB | GPU texture allocation/texture read limiter/带宽；可独立于引擎 | 皮革高光颗粒、木材条纹或低角度纤维闪烁超过冻结参考；压缩误差不能只看静态全图 |
| 桌体几何 | 先分实体+材料+相机可见度，局部LOD；保留全精度数值物理资产。保留六袋近景与网篮、回球呈现 | tiler/buffer/提交与初次准备；先测后简化 | 袋嘴/库鼻轮廓、捕获口沿、纹理UV/法线、加载器包围盒缩放改变；不得用放大洞或移动物理补偿 |
| 动球阴影/反射 | 反射环境可预积分；球位、半径、opacity、球影支持与球杆遮挡实时更新 | 由GPU算法角色验证同质量成本 | 使用离线固定球影、漏球、落袋残影或恢复不一致；停止 |

Apple建议先看实际ALU/Texture/Bandwidth limiter再优化格式、mip或anisotropy；过高anisotropy也可能提高采样成本。ASTC是资产候选而非PNG包体压缩。[WWDC20 GPU counters](https://developer.apple.com/videos/play/wwdc2020/10603/)（查询2026-10-02）。不可直接把ASTC塞入现有USDZ并假定iOS17加载器支持，应通过独立GPU纹理加载路线核验。在本机SDK，`MTLResource.allocatedSize`标注iOS11、`optimizeContentsForGPUAccess`和`allowGPUOptimizedContents`标注iOS12，均不要求升至iOS18/26；更晚的lossy选项本报告不推荐。

## 跨引擎必须继承的资产契约

- **单位/坐标**：本次USD元数据Z-up、metersPerUnit=1；App世界X长边、Y向上、Z短边，台面Y=0.8m。`TableModelLoader.swift:94–102`根变换非identity时直接保留，仅identity分支补-90°；room使用其USD-authored根变换（`BakedTrainingRoom.swift:54`），不能统一再旋转一次。`:121–162`按外包围盒计算uniformScale及surfaceY；`AngleTrainingScene.swift:274–278`再对齐物理高度。迁移应使用已校准世界坐标快照，而不是再次猜尺寸。
- **视觉与物理**：`MobileClothAlignment.swift:9–31`存在仅视觉顶点抬升；真实捕获口沿/网袋物理来源有独立数值缓存与版本。缩减可见模型不能默默替换物理几何。新模型包围盒改变还可能改变全桌尺度，先对拍几何真源。
- **命名/身份**：QiuGan、BaiQiu/_0、_1…_15、TaiNi、Leather、Wood、BlackWood、White及Plane_007都被消费。不要批量改名、合并材质或省略背面。迁移资产应提供显式semantic ID表，逐项证明代替原有名称查找。
- **索引/UV**：USD face-varying多索引、mirror岛和极点/接缝不能丢。SceneKit compact保留各属性角点字节（`PocketLeatherMesh.swift:250–286`）；若新引擎使用统一索引，按(position,normal,UV,material)角点组合展开，而非只按位置焊接。皮革normal使用bottomLeft，球号显式V翻转（`BallStickerAppearance.swift:119–121`），通道原点不能再重复翻。
- **颜色/输出**：颜色贴图按sRGB输入，normal/roughness按linear数据；房间预照明RGB不能当新动态光照albedo。相同色值不代表SceneKit/新引擎曝光、tonemap和预乘alpha相同。

从资产侧看：SceneKit继续优化迁移成本最低；Metal可完整控制buffer、纹理和现有MSL，但必须自建USD/资产预处理及输出校准；RealityKit需重建材质覆写与切线/几何契约，不能只凭USDZ原生导入判断等价；Filament可用unlit保留房间，custom shading需要重新编译材质并适配自己的光照/UV规则。官方Filament文档明确unlit适合预照明对象、customSurfaceShading只适用于lit、默认flipUV为true，[Materials](https://google.github.io/filament/main/materials.html)（查询2026-10-02，main未锁tag；实施前须锁版本，不把文档当前能力等同iOS17验证）。这三条外部事实只是可实现性依据，均不是球迹画质或功耗实测。

## 画质参考与验收入口

**建议冻结参考**：以真实已接受App截图为主，保留资产母版和原始albedo；三房间的用户认可范围不同，不能把赛事材质接受扩为木质/东方也已接受。现有线索：`TrainingRoom/README.md` r6记载赛事r5已接受、其余未扩大认可；参考在`output/carpet-styles-20260928/accepted-reference/r5-tournament/`。这些是定位线索，应由主控核实具体用户认可记录并冻结哈希，不能用README一句话代替全场景验收。

场景至少包括：2D顶视含六袋、全台16球3D、母球近景体积与两灯板、皮革角袋/中袋低机位、球号完整滚动与相反面、落袋/袋内/回球支架、房间织物斜视与旋转、模式/主题恢复、缩略图与离屏视频。相机、像素尺寸、曝光、输入时间与shader profile固定后进行局部像素检查和运动连续性检查。保存既有不满意参考，避免只挑好看的图。

本轮没有打开这些历史像素，也没有生成新对照，所以**未作画质通过声明**。不设通用“50k面/15MB/1024px”预算；后续GPU捕获必须记录实际draw、triangulation、MTL格式/mip/allocatedSize、buffer分配，内存按启动→首次进入→热进入→三样式切换→退出峰值分别采样。计算器容量模型不替代分配表；分配表不替代带宽；带宽也不替代焦耳/瓦数。

## 待证实假设与否决条件

1. **假设H1**：移动专用资源可减少首次解析与原型资源保留。否决：真实加载仅按需解码，清单清理对冷峰值与驻留无明显收益，或其他消费者需要被删资源。
2. **假设H2**：桌体分区/LOD有可观收益。否决：完整页面由片元ALU限速，几何消融效果在噪声内；或近景轮廓/物理契约无法保持。
3. **假设H3**：GPU纹理格式优化有效。否决：texture limiter/带宽不显著，格式变更只有包体收益、没有实际GPU改善，或运动画质下降。
4. **假设H4**：离线probe可稳定减少首次进入峰值。否决：首次峰值不来自probe、版本复杂度高于收益，或离线无法复制实际输出/场景组合。
5. 若候选依靠降低分辨率/目标帧率、隐藏房间/球影、取消材质主题/视频消费者才领先，不能作为“同画质最省电”结论。保留独立“同预算提高画质”评分。

当前可交付的是资源事实、可证伪的优化方向和迁移约束。最低能耗和最佳全场景画质仍需公平真机对照，不能由资产大小或引擎名推定。


## 交叉讨论、状态更正与可执行停止线

本节已读 [pipeline.md §8](pipeline.md)、[engines.md §9](engines.md) 和 [review.md](review.md)，仅追加/纠正本报告；没有执行生产修改、构建或设备测量。当前 owning source 的复核在 2026-10-02 08:27–08:33 +08:00；资源统计仍为08:17窗口，不改写为此次重新量测。报告引用的实际类型名为 `BakedTrainingRoom`，没有据“RuntimeBakedTrainingRoom”措辞虚构另一个已集成类。

### 1. 房间状态与证据归属

当前 `tasks/ROOM-SIZE-STUDY-20261002.md:34–37` 记录六USDZ、六光照PNG已替换为三风格8×6的新烘焙；每灯83.618076 W、世界强度2.2、壁灯12 W、192 samples、2048²/1024²，运行时rig不改。`:42–46` 的回导、核心/UI回归、设备安装及包装核对是**房间任务报告的证据**，本研究没有复跑。`:48` 明确舒适度待用户反馈、持续帧率/温升与全页面/HUD未验收，FL-094仍开放。初轮候选旧烘焙错位（`:28`）不能继续描述正式集成（`:34–35`）。正式对照应将新包的USDZ及解码后PNG哈希、相机、shader、rig与输出设置共同冻结；“房间已选定”不免除该步骤。

### 2. 499,298 与 536 MiB 能证明什么，什么值得改

**两者不能证明GPU瓶颈。** 前者是源拓扑面扇等价复杂度，后者是把所有包内PNG假设独立RGBA8全mip展开的模型。它们适合筛查和预算预警，不能证明实际提交/驻留/带宽，不能换算瓦数。536 MiB也不是整个进程上界。现有解析原型、浅拷贝、单选房间、球号NSCache、皮革签名、style探针及预积分LUT已经做了复用，不能再把“新增缓存”作为笼统收益；只应量实际 miss、重复副本和失效条件。

| 分支 | 先取哪一份账单 | 足以推进的证据 | 反例/停止 |
|---|---|---|---|
| 几何/分区/LOD | GPU capture的实际index/vertex数量与格式、draw/material批次、各pass；tiler/vertex执行与限制；顶点buffer allocation；CPU解析/展开/编码时间；逐相机可见度 | 同shader、同输出分辨率下，合法局部几何候选实际降低受限工作并改善完整页尾部；轮廓/UV/法线与六袋、袋内/回球仍符合参考 | 高密度mesh可能遮蔽/剔除，或主要是fragment ALU；减面没有稳定动态净收益，则不因95%复杂度继续删。Plane_001需实体分解，Plane_007壳体需排序验证 |
| 纹理/母版清理/格式 | 各资源实际MTLPixelFormat、宽高、mip、usage、allocatedSize及引用/跨renderer共享；CPU解码/临时峰值；texture read、cache/带宽限制与sampler；冷/暖进入和退出 | 仅删不用资源能改善解析/CPU峰值即记冷收益；压缩/通道格式要确实减少GPU allocation或受限采样/带宽，且运动细节通过 | PNG文件更小但GPU格式相同，只有包体收益；retained UIImage未上传；带宽不受限。此时不声称持续节能 |
| 房间照明烘焙 | room相关draw/pass、片元覆盖、纹理格式/采样/带宽；离线lightmap画质参照及rig校准；样式切换峰值 | 已有constant路线避免动态重照明；若新贴图/采样候选真实减少受限项且无墙面/织物误差，推进 | 烘焙已经完成，不能再计“一次免除全部实时房间照明”；新重烘本身并非渲染成本优化 |
| probe/SH/GGX/LUT离线 | 首次neutral及房间cache miss时间线：七次snapshot、CPU颜色转换/SH、上传、PSO/LUT/卷积、同步等待；热命中次数；CPU/GPU峰值与可交互P95 | 相同生成协议的离线产物消除已归属准备成本，键可靠、失败恢复及资源预算通过 | 已热命中、动态期未生成，不能记每帧收益；首次峰值实为USDZ解析；离线新增分配抵消收益 |

这些指标应在当前每日R和共享A分别记录；不能从旧A反射消融估出R增益。重型capture只定位工作，低扰动长期能耗另测，完整页真实present身份和重复配对原则沿review §4–6。不同Apple GPU的counter名称/可用性须按实际设备工具记录；缺counter时可做控制实验，但不伪造精确归因。

### 3. 反射缓存键：实际输入与最终输出分开

当前所谓probe radiance是**SceneKit LDR截图经逆sRGB解码的值**，不是直接读取线性HDR光场：`RoomReflectionProbe.swift:330–355` 使用替代camera、HDR/自适应关闭；`:385–406` 经8-bit sRGB CGContext后查表。因此离线兼容资源首先应复制这套协议；升级为HDR/新tonemap是另一个画质候选，不能叫缓存等价化。

| 依赖 | 当前代码事实与实际作用 | 未来键/规范应怎样处理 |
|---|---|---|
| 保留几何、变换、可见性及有效材料 | `RoomReflectionProbe.swift:314–324` 保留table、reference_room和root直属light，隐藏其他root子节点，强制room可见；六face保留桌，下拍floor临时隐藏桌（`:359–365`） | hash实际桌/房间衍生资源及有效材料/纹理/UV状态、捕获可见性协议。房间lightmap、地毯yarn/macro、挂画确为输入；不因style名字相同就认定内容相同 |
| 照明与着色实现 | bake使用原scene（`:344–347`），保留的桌材质仍可读取lightingEnvironment、root灯、MSL内嵌rig和有效uniform；scene.background也未清空，若有可见背景则影响face | 键包含有效light/environment/可见背景和实际作用的shader/rig/参数；不需要未被捕获的功能开关。hash源文件可作为保守版本手段，但不等于每行更改都物理依赖 |
| 捕获及投影协议 | 中心 `surfaceY+ballRadius`；6basis、90°vertical、near0.01/far50、face128、atTime0、无AA；转512×256、SH投影/floor均值（`:314,330–374`） | 将这些常量和颜色解码、SH、GGX/mip与LUT算法作为版本化生成协议；若按设备保存纹理二进制，还需格式/兼容目标，不把设备名称当光场输入 |
| 用户桌主题/台呢色 | 首次setup在材料处理后、主题/台呢色之前烘焙（`AngleTrainingScene.swift:244–256`）；之后 `applyTableStyle` 并不重烘。后续不同style的首次miss会使用当时安装scene | 不能把所有用户主题无条件塞键。先决定沿用“规范桌面环境”还是反映实际选中桌面：前者冻结规范材质，不随最终主题失效；后者只将捕获可见桌面的有效变化入键并接受组合成本。这是未来设计选择，非当前实现 |
| 球、球杆、叠层与接触shadow uniform | 球初始hidden（`AngleTrainingScene.swift:331`），接触权重初始化/更新由 `MobileTableRendering.swift:227,242–264` 决定；bake隐藏节点没有显式重置材质uniform，新SCNRenderer没有设置该delegate | 不把已隐藏的球号/杆款一概入键。但后续style miss时若有效uniform仍带球位/权重，其影子可能留在保留的桌材质中；这是待验证的代码风险，不是已拍到的错误。规范捕获应显式冻结零动态遮挡状态，不能靠扩大无限球位键来解决 |
| 曝光与tonemap | 主camera被新probecamera取代，主视图眼位/投影/最终曝光不直接传入。**例外**：`MobileReferenceLighting.swift:365,575–589` 在保留桌材料的fragment中内嵌由主camera exposure生成的highlight headroom；更换POV不会删除它 | 主视图后续最终输出变换通常不进键；现有实际fragment mapping/数值是捕获输入，应包含于规范材料/生成协议。不能宣称当前曝光完全无关，也不需要把主camera每次调曝光本身自动纳入；代码有“只追加一次”guard，不会随所有后续曝光更新 |

最小合理方案是建立**独立、规范化的捕获scene/材料快照**：固定桌主题和台呢色、零动态接触状态、固定rig与材料输出映射，明确房间内容及输出协议，随后hash这些实际输入。它减少首次访问顺序依赖，不必为每个最终显示主题制造重烘。若产品要求选中桌面颜色真的出现在环境反射，应单独选择该策略，并量其组合数/缓存成本；不能无声改变既有参考。当前 `RoomStyle` 唯一键未覆盖资源版本、捕获配置及可能的首次miss状态，尚不能证明所有消费者都获得同一规范探针；首轮“把全部主题/曝光塞键”也撤回。

**未覆盖依赖的验证入口**：两个全新进程反转房间访问顺序；默认/非默认桌面首次setup与动态击球后首次切风格分别保存probe像素/SH/floor及有效shader/uniform。同style比较差异可以验证风险；不靠“关闭球节点”或cache命中就判定radiance与球状态无关。本轮没有执行该实验。

### 4. 对同伴结论的最强质疑与停止Metal重写条件

对pipeline §8的最强质疑是其动态优先级仍可能受旧shader消融影响：当前R、正式8×6与新相机下若tiler、展开buffer/多材质提交或texture带宽主导，先改64近影积分可能错过低风险资产收益。反例是某条低机位实际可见台呢面积很小，但桌体/袋网/回球draw或CPU遍历仍大。必须先拿当前完整页账单；接受该报告已经给出的“受限项不同即改顺序”，不把旧room-off小收益当永久否决。

对engines §9的最强质疑是“保留既有MSL，所以专用Metal原型更窄”可能遗漏实际统一索引资产工具、皮革切线/镜像、透明袋网/回球、sRGB与材料fragment输出映射、离屏视频双管线的工作。反例是Filament的资产/设备工具能更便宜覆盖这些功能，或SceneKit只换SCNProgram便已达标。必须按完整资产与消费端的实际原型成本重排，不能把shader行数当迁移总量，也不能仅将旧536MiB理论格式搬到新引擎就声称驻留改善。

**应停止**：资产准备/格式/合法LOD加最窄SceneKit优化，在冻结画质与全部必要消费者、iOS17、资源/启动、实际present、长期帧时及同指标能耗上达到任务目标，则停止以当前能耗为理由的完整Metal重写，不为引擎排名继续扩张原型。验收沿review §5的既有每日与共享v62范围，不下调帧率/像素、不用冷进入改善代替动态长期达标、不把≤10%能耗增幅护栏当“最低能耗”。SceneKit生态风险可保留独立退出接口和兼容性工作；若真实出现无法修复的正确性/工具链问题，可另立维护迁移决策。

**真实未决项**：当前实际GPU三角化/vertex/draw与跨renderer共享，逐格式allocatedSize/驻留及texture带宽，首次probe访问顺序与接触uniform残留，规范捕获是否保持已接受像素，8×6全页面画质/舒适度、实际present与长期能耗；各新引擎完整消费者的实现/维护成本。报告之间同意某条路线不关闭这些缺口。
