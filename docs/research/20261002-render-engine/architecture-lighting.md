# 静态照明、动态遮挡与接收面架构

2026-10-02。材质与资产角色，按用户纠正转向代码、数学与架构方案。独立阅读 ARCHITECTURE-BRIEF 和当前 owning source，未读本轮其他新报告；未改生产代码/资源、构建、渲染或运行设备。本提案使用 cursor-project-adapter 与 blender-ios-assets 的消费端契约；不进行 Blender 操作，故不加载编辑/导出技能。读取窗口约08:44–08:55 +08:00。所有下列行号指当前 `QiuJi/Core/Scene/`，不借旧报告代替核对。

**建议把床面的球体遮挡计算从屏幕片元搬到持久世界空间场，以球位/有效opacity版本更新；微法线、roughness、视角镜面仍在最终着色阶段求值。** 先保留每个面光样本的visibility，随后对有条件可精确化简的漫反射使用方向矩。房间和规范probe离线，库面/袋口等非平面走独立语义路径。这是结构性减少重复计算的方案，不需要先得到新设备测试才能提出；实际画质误差和毫秒留到实现关口。

最值得先实施的切片是 **BedReceiver + WorldVisibility64**：仅承接台呢床面，把原64样本逐球visibility搬至球位版本驱动的纹理场，片元保留原积分与材质输出；相机移动不再触发该场生成。该切片不承诺全台呢改为一张颜色图，也不先换完整引擎。

## 1. 当前代码揭示的可拆分边界

- `MobileReferenceLighting.swift:29–47,94`：固定两块水平矩形面光，几何、gain、radiance不由相机决定；`:371–459,869–900` 是现有逐接收点支持筛选、每灯8×4或2×2采样及逐球平滑射线遮挡。每日 `AngleTrainingScene.swift:28–30` 采用reflection，`MobileReferenceLighting.swift:168–169,378` 说明它没有启用analytic shadow替代，所以本提案针对现行64/8离散积分。
- `MobileReferenceLighting.swift:870–902`：world position与微法线来自 `_surface`；E是视角无关漫反射，S使用view、half vector、roughness、F/D/G；台呢nap还使用geometryNormal与view，不能永久烘进albedo。`:900` 又以解析矩形辐照度校正离散积分的遮挡比，不能把任意灰度影图直接相乘替代。
- `MobileTableRendering.swift:178–211,242–264`：球位/height/opacity生成接触AO；已有同帧presentation读取、批量uniform和变化检测。新架构优化的是后面的重复求值域，不能再次把这些已有上传优化算作成果。AO的当前艺术公式有远距尾项，不具严格有限支持。
- `MobileTableRendering.swift:194–201` 明确库顶比床高约37 mm，床面rail AO仅在0.5 mm高度带应用。`TrajectoryRenderer.swift:184–195` 明确TaiNi包含床、库面、袋坡，源床还有校准前的tent faces；最近库面≥+31 mm、袋坡≤−55 mm。`MobileClothAlignment.swift:24–29` 是geometry modifier视觉抬升。**TaiNi是材质名称，不是单平面身份；X-Z查询必须基于校准后的BedReceiver，而非材质名。**
- `TableSurfaceTextures.swift:43–62` 皮革cotangent frame依赖原UV/镜像与屏幕导数；其微normal/roughness与角色色仍应在最终片元计算。`MobileReferenceLighting.swift:696–715` 的皮革/球杆satin也是view相关GGX，不能照搬床面颜色场。`ClothAppearance.swift:71–79` 主题改变albedo/multiply；只缓存可见性时无需为主题重算。

本轮当前文件SHA-256：MobileReferenceLighting `3df2a2e4d0b9403bc0482b6b956747ea7a144497de80f8a40d195b0f6450eea8`；MobileTableRendering `1f443d5f2ad7be96cea3bf08da7a2b5fe0cd9780a0760c90b77180b639834c07`；RoomReflectionProbe `b35c13726ba2b123d2d0da13350c39ac40c5b1abd304944fbff3a061188d8372`；AngleTrainingScene `e94b1ee894f843b17d550f815e49da1094f3132800f38da1d08038137f09da8c`；BakedTrainingRoom `e775d40fd66d8d42e8f68b58c8fd49d0014333759fd80d7e7a2baa45ad9409fe`。不宣称这几份SHA组成已验收运行包。

## 2. 依赖表：重算应由什么触发

| 量 | 离线/初始化 | 球位、height、有效opacity变化 | 球旋转/号码/桌主题 | 仅相机变化 |
|---|---|---|---|---|
| 房间静态预照明 | 现有三风格已烘焙；新布局/rig/织物资产版本才重建 | 不重烘；当前模型本来不表达球对房间的动态投影 | 房间albedo策略改变另立版本 | 只采样、投影，不重烘 |
| 规范环境probe/SH/GGX/LUT | 固定房间、桌参考材质、光、捕获协议产生 | 明确排除动态球和其uniform阴影；不重建 | 默认规范桌面不随主题变化；若产品要求真实主题反射才扩依赖 | 不重建；球的采样方向/LOD继续实时 |
| 床面点位、语义mask、静态灯样本 | 桌校准、receiver chart、rig确定后持久化 | 不变 | albedo不变几何；normal资产改变仅影响材质/合法法线锥 | 不变 |
| 每样本Visibility64 | 不含相机、normal或roughness；初始球阵求一次 | 重建受影响区域，删除/淡出也包括旧支持区 | 不透明球旋转/球号不影响球体遮挡；改变透明材质遮挡规则则需要 | **不dispatch**；只读取 |
| 方向矩/未遮挡矩 | 未遮挡矩初始化；遮挡矩按球阵更新 | 与Visibility64同版本 | 微normal实时点乘；albedo实时乘色 | 场不变；法线mip随视角改变时仍可响应 |
| 接触AO场 | 静态rail AO已有 | 动球AO更新；首版全床更新保留远距尾项 | 不透明球旋转不变 | 不更新场 |
| 台呢GGX/nap、球面灯板、皮革/木材coat | 固定常量/纹理可初始化 | 位置/visibility更新 | 球号、normal、roughness、角色色继续参与 | **实时重算view相关项**；相机运动不是整帧无工作 |

表中“球不透明”是当前解析球模型的条件，不是对未来透明树脂/镂空球的普遍结论。球杆当前不参与这段解析球影；首版不偷偷增加或取消杆影。若要增加杆遮挡，加入独立blocker类型与版本，不把它假装已存在。

## 3. 数学上哪些能精确搬移，哪些是近似

令p为校准后的床面接收点，B为有序球状态，q(p,B)为当前8或64样本网格选择，j遍历两灯的样本。定义 `a_j(p)=radiance/π × gain × cellArea × max(Nlight·−l_j,0)/r_j²`，当前两灯共用色向量C=(1,0.985,0.96)。V_j保留当前滤波射线公式及**逐球乘积**：

`V_j(p,B)=Π_i [1−opacity_i × blocked_ij(p,B)]`。

原表达式可写作：

`Eraw=C Σ_j a_j V_j max(n·l_j,0)`，`Uraw=C Σ_j a_j max(n·l_j,0)`；

`E = Erect(p,n) × Eraw/max(Uraw,epsilon)`；

`S=C Σ_j a_j V_j max(n·l_j,0) × BRDF_j(n,v,roughness)`。

这里保持代码的clamp、支持筛选、sample-cell半径及球顺序；Erect由现有horizon-clipped解析矩形函数给出（`:609–636`）。E的view无关只是在给定n条件下成立；**实际normal/roughness纹理的导数选mip随相机变化**，所以把最终E或S按固定微法线烘成低分辨率颜色，不是当前shader精确搬移。

有两个可用层级：

1. **完整每样本V场**：V_j没有n、roughness、v依赖，在相同p、B、q和float运算下可独立compute一次，随后E与S仍使用各自权重。不需要证明normal全部朝上，也不把镜面遮挡替成漫反射比。搬移的是同一个离散遮挡函数。
2. **方向矩加速漫反射**：若能证明该床点合法微法线范围内，所有灯样本均满足n·l_j≥0，则 `M=Σ a_j V_j l_j`、`U=Σ a_j l_j`，有 `Eraw=C(n·M)`、`Uraw=C(n·U)`。这使微法线仍以每片元的当前mip参与，而球阵生成M不依赖微法线。若灯color不共线，改用RGB各一个方向矩，不能继续只用单向量。

第二层**不是平均visibility**，也不是无条件精确：微normal跨灯光horizon时max不能移出和式；库侧/袋坡尤其容易违反。应由床域位置与normal资产解码范围计算合法锥，无法证明的片元退回每样本V/原shader。S仍需每样本V或另一个显式近似模型；一个M向量不能编码所有GGX方向相关性。当前analytic shadow路径的逐球平均遮挡相乘也不能当原逐样本遮挡乘积等价替换：通常 `平均(Π V_i)≠Π 平均(V_i)`。

**精确重排与质量变化分列**：固定p上独立算V、正常半球内方向矩是数学重排（浮点累加/FMA次序仍可能不同，非bit-identical承诺）；把p采样到纹理、bilinear重建、half/UNorm量化、normal锥近似、粗分辨率和局部支持截尾都是近似。首版用float运算、R16Float存V不等于没有量化；绝不将“相机不重算”宣传成无误差灯光图。

RNM和低阶SH可作为后续多方向静态漫反射近似：Valve的原始RNM把方向lightmap与逐像素normal组合，PRT原论文明确低频光照和漫反射向量/光泽矩阵区别。这支持“保留微法线、缓存光照基”的分解方向，**不证明三基/SH9能精确保存近球高频遮挡或GGX高光**。[Valve GDC 2004原讲义](https://cdn.steamstatic.com/apps/valve/2004/GDC2004_Half-Life2_Shading.pdf)、[Sloan等SIGGRAPH 2002原论文](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/01/prt.pdf)（核对2026-10-02）。

## 4. 接收面语义与图集：按表面定义，而不是统一TaiNi UV

初始化建立不可变ReceiverManifest，语义至少为Bed、CushionTop、CushionSide/Jaw、PocketRamp、Leather(六袋ID)、Wood、Net/Return、Room。不要直接复制物理碰撞patch作为视觉全表面：几何modifier后的高度、法线、双面/透明和visual silhouette有自己的契约。

- **Bed**：从现有床域拓扑与校准规则生成完整可见footprint，X-Z/world metre参数化；有效coverage包含床边不规则轮廓，孔洞为无效。不使用原TaiNi UV作为世界场坐标；原UV继续采样纤维normal/roughness。一个world(p.xz)查询与一个原materialUV查询并存。床面残余高度/法线若不能按实际校准后几何证明为规范平面，manifest需保留height场或将该patch列为例外；仅用y=0.8重建不是对任意TaiNi几何精确。
- **CushionTop/Side、Jaw、Ramp**：语义分面、保留真实Y和normal，每个chart记录world position及tangent；若以后缓存，使用不重叠的UV1/geometry-ID chart，不能把相同X-Z不同高度叠进床图。首切片继续原shader，更稳妥且无需同时改所有消费者。
- **库边/袋口**：床coverage与库侧交接禁止filter跨表面；holes和chart seam需guard band。床面rail AO只应用原床条件。接近袋口的球、抬球、低于床的receiver、回球架和半透明袋网没有平面投影保证，保留真实3D路径。
- **微表面**：最终片元保留同一normal/roughness map、原mip/anisotropy、mirror tangent与clothFiber、nap；六袋角色色仍是linear albedo输入。图集中不得永久混入桌主题、角色色或微normal后的照明。

ReceiverManifest记录asset SHA、校准变换、床/库/坡的来源element/face与语义ID、chart→世界映射、coverage、合法normal锥、边界guard；图集只属于视觉路径，物理和教学坐标不改。

## 5. 一个具体布局与内存模型

以下是首版可实现的预算模型，不是实际驻留数字或固定画质标准。床域沿当前2.54×1.27 m（AngleSceneCalculator:10–11）使用256×128，texel约9.92 mm。近球/低机位不靠这个粗场兜底，走下述精确例外。所有数据linear、无sRGB，V场默认无mip，避免把不同遮挡函数/边界用普通颜色mip混合。

| 资源 | 格式/布局 | 逻辑大小 |
|---|---|---|
| Visibility64 | `texture2d_array`，R16Float，64 layers = panel×32近影样本，shaderWrite+shaderRead；compute用float | 4 MiB/slot；三slot12 MiB |
| MomentAO | RGBA32Float，RGB为M64，A为当前接触AO；可选优化，不取代镜面V场 | 0.5 MiB/slot；三slot1.5 MiB |
| UnoccludedMoment64 | RGBA32Float，RGB为U64，A预留；固定rig/bed后初始化 | 0.5 MiB |
| BedCoverage | R8Uint，语义mask/有效性；规则位置从X-Z隐式重建，首版不保存整张position atlas | 0.03125 MiB |
| TileMetadata | 16×16 texel tile，共16×8=128，版本、有效性、支持球bitmask；格式显式uint | 例如32 bytes/tile，共4 KiB |
| 球状态 | 对齐struct(position,height,radius,effectiveOpacity,semantic flags)+ordered stable ID；3份不可变buffer | 16球按32 bytes/球仅1.5 KiB，加头部/对齐另计 |

总核心纹理约14.03 MiB，另计guard、高分辨率补片/metadata/driver alignment/原资源和峰值。首次不做mip，不预留无限精细patch，完整atlas如升到512×256则Visibility64变16 MiB/slot、三slot48 MiB，**不能称低成本小图**。上述array是Metal布局提案，不假定SceneKit modifier已经支持自定义array自动绑定；若公开材质路径只能稳定承载2D，则将64层按8×8块打包成2048×1024的R16Float atlas，每层手动局部clamp并加guard texel，不跨层filter。每层2-texel collar后为2080×1056，约4.19 MiB/slot，三slot约12.57 MiB，加其余资源需重新列预算；或者以SCNProgram显式布局承载，不能把未核实array绑定当现成功能。如果三slot生命周期不允许这个预算，选择两slot并严格等待可复用，或者减少缓存区域；不能边写正在显示的texture。

S在q64处每片元仍读64个V值与原GGX运算；q8且无球支持处可保持原8样本、V=1，不需要8层场。固定64层避免ball-count层数爆炸，层含所有球乘积，层序必须与原近影grid一致。若首版直接在S循环中同步累加E，MomentAO的RGB可暂不分配；使用方向矩的代码与无矩代码必须清楚分版本。首版不靠R8或有损压缩“悄悄节能”。

Metal资源读写是显式依赖，不是材质设置自动同步；Apple官方说明缺同步时draw可能在上次写完前读取。[Resource synchronization](https://developer.apple.com/documentation/metal/resource-synchronization)、[shaderRead](https://developer.apple.com/documentation/metal/mtltextureusage/shaderread)、[shaderWrite](https://developer.apple.com/documentation/metal/mtltextureusage/shaderwrite)（核对2026-10-02）。设计使用iOS17可用的既有texture/compute/command-buffer体系，不依赖Metal4、新稀疏驻留API或升最低系统；实施时按目标GPU格式表落定read/write/filter组合。

## 6. 更新边界与相机不重算的具体机制

持久遮挡版本 `VisibilityKey=(ReceiverRevision,RigRevision,VisibilityAlgorithmRevision,OrderedBlockerStateRevision)`，不含CameraRevision、球orientation、号码或桌albedo。块内球数据取一次最终presentation快照；opacity、hidden、reparent、height和radius及既有低于床衰减规则都进入B，不能仅比较物理position。相机只有 `ShadingViewRevision`，不改VisibilityKey。微normal/roughness版本单独决定材质采样与方向矩合法性；默认不改变V。

帧k的顺序是：完成逻辑/SceneKit动画采样 → 冻结B_k及其stable ID顺序 → 按B_k更新V/M/AO → 同一版本的球geometry与材质绘制 → present。原 `didApplyAnimationsAtTime`（MobileTableRendering:238–250）已是读取最终presentation的入口，不能在另一个CADisplayLink提前读取旧球位再异步烘下一帧。离屏视频也是指定采样时间的B_k；共享规范静态资源，但不共享可写scene atlas。

首切片可通过局部Metal compute生成场、SceneKit材质/SCNProgram消费；**同帧保证需要受控command buffer时，采用SCNRenderer宿主，把compute放在其render之前**，而不是整引擎重写。保留SCNView时，若不能明确建立跨queue写完成→本帧读的依赖，场未就绪必须用B_k原实时shader；不能把B_(k−1)场贴在B_k球下，也不靠每帧CPU wait掩盖调度设计。准备完成的纹理、key和B快照必须原子发布，slot在GPU读完前禁止复用。

仅相机运动：所有Bed texel场已完整生成，同一个V_k可无限读；相机只改变投影、view、normal/roughness采样mip、S和nap。未缓存区域/高精细例外可以按需实时算，但不因此重建整个V场。球原地旋转也不更新解析球visibility，只有号码/球面材质变化。球阵静止阶段因此能根本避开**已缓存床域**逐球阴影重算；不能声称整个产品所有receiver都零shadow工作。

局部更新第二阶段才加入：以变化球旧支持区∪新支持区，扩展采样/滤波guard，再按当前B_k重算区域内**所有仍相关球**的乘积。禁止以新球贡献除旧贡献恢复V（旧V可能为0，重叠球也不能线性相加）。删除/opacity淡出同样要清旧区。AO有无限尾项，首版全床AO更新，不以有限tile支持静默截断。抬球导致支持扩到全桌、低于床/超过光高的异常状态走原路径或全域，不强行沿用桌面接触球的小支持。

三slot局部更新还需保证未改tile也属于当前版本：从最新完整场复制/迁移有效tile，或维护每slot的tile版本并补齐；不能round-robin写dirty tiles后把两帧前未更新部分交给draw。首版采用全床generation以减少这项复杂性；球静止时整个generation不发生。

## 7. 空间近似与近景例外

V场保留角度样本，但空间有限。半影软化随sample-cell投影半径变化，球接触附近半径可能很小；9.92 mm texel不足以保证接触影边。使用以下明确分流：

- 对bed coverage边、库鼻/袋口guard、局部球影高梯度、球与接收点接近导致filterRadius小于若干texel的区域，原公式实时算V；保留完整微normal与S，不拿模糊图补轮廓。
- 仅相机近距离放大时，允许将已有高精度patch留在world cache，不因同一相机位置每帧重新生成；patch版本由B/rig/receiver决定，camera只决定选择/是否准备。若准备未完成，原公式覆盖同帧。
- coarse/fine交界的线性过渡也是近似，会形成两路成本，必须显式计费。q8/q64网格切换保留原支持predicate；不能任意bilinear平均两个不同sample-grid的函数。
- 方向矩horizon条件失败可使用每样本V恢复max(n·l,0)，无需整场重烘；若p不是床上同一个位置，必须走原3D路径。

量化误差、插值误差和有限空间带宽不能当场保证不可见。架构先给正确例外与可调整参数；后续实施的质量关口再决定允许覆盖率，不将全部低机位强塞粗图，也不以新测试作为今天提出方案的前提。

## 8. 规范probe：独立捕获scene，拆开辐射与输出

当前 `RoomReflectionProbe.swift:314–365` 保留table/room/root light，隐藏其他顶层节点；probecamera禁HDR/曝光自适应，额外无桌下拍floor。`:385–406` 将8-bit sRGB截图解码回linear，因此是经过LDR输出链的环境样本。`MobileReferenceLighting.swift:365,575–589` 已在保留桌材料内嵌由主camera exposure生成的fragment高光压缩；换probecamera不移除它。`AngleTrainingScene.swift:244–256` 的首次捕获又早于桌主题/台呢色应用；后续style miss可能带当时材质/接触uniform。新规范应消除访问顺序依赖，而非哈希所有动态状态。

建立离线/初始化的CanonicalProbeScene：只含当前正式房间、固定规范桌面、固定rig/environment及明确背景；排除球/球杆/叠层并**显式零接触uniform**，不是仅隐藏node。保留既有LDR协议的CompatibilityProbe作为首版；之后若要线性HDR捕获和最终输出分离，另立RadianceProbe版本及质量策略，不能冒称与原像素等价。

ProbeKey包括房间geometry/lightmaps/yarn/macro/poster内容、规范桌几何与有效材质、rig/light/environment、centre/facebasis/FOV/clip/time/AA、颜色解码/SH/GGX/LUT及材质fragment映射版本。**不含最终主camera眼位、投影、view tonemap或用户桌主题**；但CompatibilityProbe材料里实际存在的曝光派生fragment常量属于捕获输入。若产品要求桌主题反映在环境图内，扩为ThemeProbe并明列组合成本，不默认全部主题/曝光都使规范probe失效。

三风格8×6已正式试用集成，房间尺寸和烘焙版本由owning资源决定；本提案不重开尺寸。中心单probe仍为原有空间近似，不用缓存规范化宣称已解决近墙/回球局部反射。球位改变只更新当前球的reflection采样与cloth bounce等表达，不重烘房间。

## 9. 结构收益模型、实施切片与最强反例

设P是当前床面着色片元数（不等于drawable全部像素），A是场texel数，Q=64近影样本，N是相关球数，u是实际重新生成场的帧占比，d是每次更新覆盖率，e是使用原shader的例外片元比例。只看遮挡遍历的工作模型：

`旧 ≈ P Q N`；`新 ≈ u d A Q N + e P Q N + (1−e) P Q textureFetch + copy/sync`。

GGX在严格保留原积分的首版仍有约P Q工作；它不因方向矩消失。静止球阵只动camera时u=0；如果可缓存床域e低，逐球遮挡遍历大部消失，但有64次纹理读。全台动态且d≈1、例外面积大，收益会缩小；从同样球数可得必要而非充分交叉点 `u d A < (1−e)P`，还需计64读带宽、compute/store和slot复制。256×128的A=32768；如果P也是很小的远景面积，盲目全域dispatch可能比原fragment还多，不该每帧生成固定大图。理论数量比不是fps/能耗倍数。

具体结构切片：

1. 先新增BedReceiverManifest与不可变OrderedBlockerSnapshot，明确床域和最终presentation所有权；不改物理，不同时拆全桌材质。
2. 让原V函数成为片元/compute共用的同一MSL实现，64样本层号与球序统一；按VisibilityKey构建持久场与同帧资源依赖。保留原微材质、GGX与例外shader。完成这个切片后，静止球阵/仅相机运动的compute-dispatch数由设计就是0，而不是希望GPU自行缓存。
3. 再加入M/U的漫反射缩减、合法法线锥和高精度patch；规范probe作为独立静态准备切片。最后才研究GGX近似/LTC/RNM或全Metal重写，不把新采样近似掺进第一步。

实现后的正确性/画质关口检查同帧、过渡、微normal/roughness、孔洞/抬球和输出；性能/能耗决定参数与晋级。**不需要先启动一轮新真机测试才能执行上述结构设计。** 这些步骤超出10-01固定资产/shader接口范围，应作为新的架构任务，不冒称原方案已完成或生产接入已获批。

**最强反例**：当前成本可能主要是64样本GGX、解析矩形horizon clipping和SceneKit材质尾部，而不是逐球V；64-layer纹理把ALU换为高带宽，而且低机位近球需要广泛fallback，u/d/e使结构收益消失。单矩/平均visibility如果一并替掉镜面权重才变快，收益实际来自近似而非本切片。应对是保留上述分解与成本账单：先完成可解释切片，后续必要时单独选择改变镜面算法或更细world patches；不无声牺牲微表面、袋口和重叠影。

当局部场及SceneKit承载已达到整体画质与能耗目标，停止为节能重写完整Metal。若公开宿主无法保证资源依赖，最窄升级是受控SCNRenderer；只有还存在具体不可消除的内部工作或功能边界，才扩大迁移。该选择来自工作域与生命周期，不是“换引擎就会更快”的断言。

## 10. 最终交叉回应：统一首版契约，保留数学与画质边界

已读主控 [ARCHITECTURE-PROPOSAL.md](ARCHITECTURE-PROPOSAL.md) 和 [architecture-critique.md](architecture-critique.md) 的最终资源/同步/函数界选择。本节只追加本报告，不更改主控、不新增资料查询或执行构建/设备操作。**以下首版契约优先于本报告§5的R16/三场容量候选；后者保留为被收窄的设计分支，不进入首版。**

**接受单份持久R32场、blockerRevision变化时有界全生成。** 传统CPU输入slot在途不能推导大texture也必须三份。首版只接一个interactive session，导出沿原公式；变化时重建所承接床域，相机/号码旋转独立revision不触发场生成。R32保留float存储，使初版近似账主要集中在空间重建；不同时加入dirty tile、旧tile迁移、half压缩或时域jitter。MomentAO/U等额外场不作为默认首版必需资源；原AO及64方向BRDF保留，先删重复blocker检测。此前“只能两/三slot场否则等待”的范围过宽，按实际GPU访问依赖可复用一份场。

**接受同步条件必须落实到真实consumer。** 同一传统queue、tracked资源及direct binding能支持GPU读写依赖，但SCNMaterialProperty不证明SceneKit内部实际满足这些条件；队列commit次序也不是完整hazard证明。实现需保证实际读访问被覆盖，或者在app-owned commandBuffer用公开GPU event明确compute完成→render开始、render完成→下次改写。仅在compute端signal不足以保证consumer已wait。未能建立该关系时沿当前公式，不CPU wait、不贴上一版本场、不覆写在途输入slot。输入slot饱和时沿宿主背压跳过本次提交、下一次采样当前时钟，不能据此宣称该次已呈现或已经流畅达标。

**接受总新增GPU峰值≤16 MiB，而非只算field payload。** 256×128×64 R32单场8 MiB；2D打包含两侧2-texel collar约8.38 MiB，certificate/input/临时准备/retired资源等均入总账。旧+新超额时先原公式，异步退役旧场、释放完成后再分配新场，不同时保留双满场，也不阻塞UI。正式资源替换与新session由全局admission控制；一个session各自低于预算不保证全App同时峰值合法。扩分辨率/patch/更多session必须另列预算，不能从§5被撤回的三场候选自动取得空间。

**接受以函数区间界和cell invalid处理质量，而非靠“近景”标签。** 反方代入现行rig得到床中心64样本filterRadius约1.446–3.207 mm，而256×128网格间距约9.922 mm，已在理论上否决“粗场全域够用”，无需测试才承认。首版应由完整cell上的原射线距离、filterRadius、smoothstep、opacity及分支条件建立保守V区间；分支边界、接触极小filterRadius或界过宽时cell无效，片元回原式。误差需继续传播到有权重的E比值、S及输出映射，不能把ε_V直接称为最终RGB误差；当前GGX/view使S误差权重可随相机变化，camera只影响有效性/路由，不要求重烘整个V场。invalid-cell可能降低缓存有效覆盖，这是明确结构代价，不能放宽界来保住覆盖率。若未来缓存M/U，需新增几何权重/方向空间重建的误差项，不能复用只针对V的证书。

**保留最重要异议：方向矩不足以取代64样本镜面。** M/U仅在合法法线正半球条件下恢复漫反射的加权结果；两个不同V_j分布可具有相同M，却因GGX半向量权重不同产生不同S。原S必须读各方向V_j并保留BRDF积分，或采用另立且给误差界的角基底/镜面模型。把M的漫反射遮挡比直接乘未遮挡S，仍是近似，不因单场、R32或certificate就变为等价。本报告保持微normal/roughness实时、TaiNi非平面分流及规范probe曝光fragment例外的结论。

最终推荐仍是实施这个最窄结构切片，而非先开展新测试或完整Metal重写。保留的实际风险是64方向读带宽、有界全生成成本、SceneKit真实绑定边界及certificate有效覆盖；这些不否定现在可做的依赖拆分，但也不允许提前声称大幅帧率/能耗收益。后续若结构收益不足，先分别处理镜面响应或适用域，不能将平均visibility偷换进同公式方案。
