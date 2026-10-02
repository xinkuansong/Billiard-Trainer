# 台呢球影与局部照明：计算域重构

日期：2026-10-02。独立首轮；未读同伴本轮 architecture 报告。仅写此报告，未改生产、未构建、未运行设备。按 `idea-evaluation` 与 debate protocol 区分事实、数学推导、设计选择和实施后未知。

**建议：保留 SceneKit 场景，先实施“台面稀疏逐光样本遮挡场”，把候选球的射线/滤波检测从每屏幕片元搬到受影响的世界空间 tile。第二阶段再把完整可见光分布投影到角响应基底，使灯样本积分也离开片元。** 第一切片保留 S 的逐样本 visibility×BRDF 耦合，不采用每灯一张平均阴影图。它有明确减少工作的机制，但仍保留每片元64次 BRDF；若要求一次同时去掉这64次，应采用后文“角基底”或“未遮挡响应＋局部修正”，承认其新的近似预算。

这里选择的是新架构，不是宣布已有帧率或能耗结果，也不冒称属于10-01严格等价代码方案。该方案固定资源、采样与架构边界；当前议题允许提出超出其边界的设计，接入另行处理。

## 1. 当前源与公式证据

本轮直接读取当前 owning source。以下文件与上一轮 baseline-source 字节一致；关键 SHA256：

| 当前文件 | SHA256 |
|---|---|
| `QiuJi/Core/Scene/MobileReferenceLighting.swift` | `3df2a2e4d0b9403bc0482b6b956747ea7a144497de80f8a40d195b0f6450eea8` |
| `QiuJi/Core/Scene/MobileTableRendering.swift` | `1f443d5f2ad7be96cea3bf08da7a2b5fe0cd9780a0760c90b77180b639834c07` |
| `QiuJi/Core/Scene/AngleTrainingScene.swift` | `e94b1ee894f843b17d550f815e49da1094f3132800f38da1d08038137f09da8c` |
| `QiuJi/Core/Scene/AngleSceneView.swift` | `20b9ca2f4491d770a1820dbe1d345fef210b7d99ae5280b2972d918714be8257` |
| `QiuJi/Core/Media/SequenceVideoExporter.swift` | `15a71754af6260e640f8539859d04aa83d667166641f5111317acd663df02647` |

`ClothAppearance.swift`、`CameraRig.swift`、`RoomReflectionProbe.swift`、`PrefilteredReflection.swift` 亦与快照一致。行号均指当前源码；后文简称 MRL=`MobileReferenceLighting.swift`、MTR=`MobileTableRendering.swift`，均在 `QiuJi/Core/Scene/`。

**事实 F1**：每日清台是 `.reflection` R（`AngleTrainingScene.swift:27–38`），R仅替换球面反射，台呢仍是64/8灯样本原路径；共享默认 A（MRL:166–179）。因此新台呢算法以当前每日 R 为参照，不再把去掉球面A64反射算成新收益。`mergesDailyClothSupport` / `factorsDailyClothBRDF` 默认关闭，DEBUG opt-in；前者合并support扫描，后者提取Smith公共项（MRL:421–450），属于算术重排，不是下面的计算域改变。

**事实 F2**：两个静态水平矩形面光，Y=3米，世界X/Z对齐（MRL:29–48）。台呢片元在世界 p 上做球影：总64点，若所有球都不在 conservative support则总8点（MRL:375–459,869–900）。灯点的世界位置、面积与 `lightCellRadius` 跟 near/far strata有关，8点并不是64点的子集。

**事实 F3**：每样本透射率来自所有候选球的**乘积**。中心使用 `(ball.x,0.8+ball.z,ball.y)`；球半径0.028575；软过滤使用 `filterRadius=max(1e-6,lightCellRadius*t/sqrt(r2))` 与 smoothstep（MRL:383–396）。它本来就是固定离散积分和样本足迹过滤模型；本报告的“等价”针对当前模型，不把它称连续面积光的物理真值。

**事实 F4**：`MobileContactOcclusion` 定义在 **MTR:152**，不存在独立同名源码文件。节点动画应用后读取 presentation，float4是 `(x,z,max(R,h),weight)`，隐球/脱父节点weight0，`weight=.85*opacity*clamp(h/R)`（MTR:238–264）。MRL:320–324又在接触AO里解码 `.85`。保留这套视觉状态，不另读物理位置，不把台下球强行恢复为几何中心，不把球节点 scale 解释为当前遮挡半径。

**事实 F5**：台呢 normal/roughness纹理保留、2×repeat（MTR:96–106），粗糙度还驱动纤维对比（MTR:205–211）；E 与 S使用**扰动微法线** n，nap使用 geometryNormal，不能混为平面法线（MRL:869–902）。TaiNi同时覆盖床面与其他台呢表面（MTR:214–225、MRL:314–329）；已有rail AO仅在离床面高度<0.5mm时采样（MTR:193–202）。新场先限定真实床面语义，不用材质名字把库边/袋口变成同一平面。

**事实 F6**：离屏导出独立 `SCNRenderer`、contact delegate、按clock snapshot并推进固定dt（`SequenceVideoExporter.swift:1077–1094`）；交互view在didApplyAnimations转发contact（`AngleSceneView.swift:1149–1150`）。同帧动画快照与跨消费端覆盖是承载条件，不是可省略的接口细节。

## 2. 哪些部分真的能搬走

令 s枚举当前near的64灯点；far另用8点。把公共光色 `c=(1,.985,.96)` 拆出，定义：

- `q_s(p)`：radiance/π、cellArea、panelGain、emitter余弦/r²的标量乘积；与相机、n、roughness无关。
- `a_s(p,n)=max(0,n·l_s)`。
- `V_s(p,B)=∏_j[1-opacity_j*blocked_j(p,l_s,cellRadius_s)]`：B是当前球影float4快照；不依赖相机、球旋转或roughness。
- `k_s(p,n,v,α)=D_s G_s F_s/(4 nv nl_s)`，保留代码的nv/nl正值clamp。
- `U=Σ q_s a_s`，`D=Σ q_s a_s V_s`，`T=Σ q_s a_s V_s k_s`。

当前代码精确对应：

`unoccludedE=c U; sampledE=c D; E=I(p,n) * ((c D)/max(c U,ε)); S=c T`，其中 `I=v62PanelDiffuse`、ε=1e-6，运算逐通道。MRL:609–637 的 I 是horizon-clipped矩形投影固体角积分；它**不是** U那套64点权重。最后叠加albedo、fiber、geometry-normal nap、接触AO、grazing polynomial、0.35S（MRL:900–906）。

因此不存在无条件成立的“只存一张平均visibility，再乘原灯光”的替换：

1. `D/U`随扰动n改变；固定平面n的visibility比值不能适用于所有微法线。
2. S的权重还有BRDF。两样本V=[1,0]、漫反射权重[1,1]、BRDF=[9,1]，原T=9，平均V×未遮挡T=5；误差不是空间分辨率能补救。
3. 各球平均遮挡相乘也不等于联合遮挡的平均：两个同样V=[0,1]，联合平均.5，均值乘积.25。必须先在每s上做多球乘积，再积分或投影。

上述三条是**本轮已解决的A类否定**；不是留到设备实验才知道的事项。

### 2.1 精确可分量与条件性漫反射moment

V_s可单独缓存，是精确的函数依赖拆分；在**完全相同p、球快照、strata、数值精度**上重新代入原积分，积分模型不变。世界纹理texel之外的重建、量化和半精度储存则是新近似，不能继续称exact。

若能证明当前接收n对所有l_s都满足 `n·l_s≥0`，则 `U=n·M0`、`D=n·M`，其中 `M0=Σq_s l_s`、`M=Σq_s V_s l_s`，每点只存两个三维vector便能精确表达该离散漫反射。当前代码保留 `max(0,n·l)`，且微法线取自资产；**代码没有给出足够的法线锥上界**，不能把这个前提无条件当真。越过horizon时，有限的一阶moment无法表达clamped cosine，须使用原逐样本或带误差界的高阶角基底。I的解析horizon积分与ε逐通道仍要保留。

### 2.2 接触AO可以搬，但尾部不是球影support

接触AO是 `∏(1-op_j R² h_j/(d_j²+h_j²)^(3/2))`，与相机/n/roughness无关（MTR:179–190、MRL:320–324）。它可成为床面单通道场，减掉每片元的全球遍历。不过它有无限空间尾部，不能拿direct-shadow support外一律AO=1。

若另接受误差预算ε_AO，可给每球截断误差δ=ε_AO/B，选择 `d_cut²≥(op R² h/δ)^(2/3)-h²`；各因子在[0,1]时，截断乘积误差≤Σδ。否则直接用低分辨率**完整床面**AO场，边界/台下/库边回原公式。此处插值仍是近似，AO不可同direct shadow叠成一个平均标量。

## 3. 路线比较与真正的大幅重构

| 路线 | 移出片元的工作 | 精确性/决定性边界 | 判断 |
|---|---|---|---|
| 只换引擎、照搬MRL | 没有移出64×球循环 | 同公式仍执行；SceneKit尾部是另一维 | 不作为算法优化方案 |
| 每灯平均visibility场 | 64×球检测及BRDF耦合 | 上节反例已推翻无条件等价 | 淘汰作为默认 |
| **稀疏逐s visibility场** | 球遮挡测试：屏幕P→世界dirty N | nodal模型保留；重建/存储近似；仍P×64 BRDF | **第一切片** |
| 角响应系数场 | 遮挡及积分：P×64×B→dirty N×64×(B+L)，运行P×L | 有限L BRDF/normal/view近似；保留V×BRDF关系 | 大幅减少工作量的第二阶段 |
| 未遮挡响应＋局部sample修正 | 未遮挡64积分用响应拟合/LTC；仅真正遮挡J样本做修正 | 基线响应替换近似，修正仍逐s耦合；J最坏64 | 比单纯平均visibility强，优先研究的替代压缩 |
| 球锥局部解析并集/LTC裁剪 | 大量离散sample可被边界积分取代 | 曲线并集、过滤、n horizon、BRDF拟合都须处理 | 理论可行但首片复杂度较高 |
| 逐屏幕像素缓存visibility | 只避开不变化帧的重算 | 相机变动缓存失效；动态球仍P×64×B | 不解决用户核心动态场景 |

### 3.1 角响应基底：保留完整透射分布，才可以把K降为L

把含clamp的完整BRDF核写成 `g_θ(l)=max(0,n·l)*DGF/(4 nv nl)`，θ包含n、v、roughness。采用世界方向基底φ_m(l)，拟合 `g_θ(l)≈Σ_m η_m(θ)φ_m(l)`。动态compute在每世界接收点形成：

`C_m(p,B)=Σ_s q_s(p) V_s(p,B) φ_m(l_s(p))`

片元求 `S≈c Σ_m C_m η_m(n,v,roughness)`。**compute里每s先乘全部候选球**，保留方向遮挡信息，η可以随当前微法线、相机和roughness变化；不是给每个球平均visibility后混合。球动只更新C，镜头动只更新η/片元，不重新射线；球自转不更新C。

世界SH9/16/25或定制多项式是可实施候选L，不是声称SH9足够。对于旋转对称GGX，先在“n为Z、v位于XZ”的局部坐标拟合核，只需 `(nv,roughness)` 的系数LUT；再按当前n/v旋转基底或做moment tensor contraction。这样避免把n两维×v两维×roughness的一张5D材质纹理直接存满。法线切线框架、nv接近1时退化的view-tangent选取必须一致，不得造成方位缝。

数学误差可明确写出：`|ΔS|≤|c| Σ_s q_s V_s |g_θ(l_s)-g^L_θ(l_s)|`。离线拟合目标直接用当前离散公式、当前near/far各自sample grids、资产roughness/normal domain、覆盖全部允许view角，而不是套一个通用“低频光照”正确率。低roughness/擦边/部分灯遮挡可能需要更高L；若某材质域达不到选定误差，保留原64模式或逐sample局部修正，不强行全局升L让所有片元付费。

漫反射另投影clamped-cosine核，保留其对n的响应以及当前 I×D/U 校准。满足法线锥前提的tile可用一阶moment；不满足则保留与g_θ分开的diffuse basis/reference。把E也一律换成C0是不成立的。

[Ramamoorthi/Hanrahan原论文](https://graphics.stanford.edu/papers/envmap/envmap.pdf)研究远场照明漫反射低频表示；[Sloan/Kautz/Snyder原论文§4.1](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/01/prt.pdf)明确指出visibility会产生更高频，即便光源平滑也可能需要更高阶。它们支持“传输函数与BRDF分解”的方法，**没有证明本项目近球影或高光用9系数足够**。查询2026-10-02；本文公式与应用成本为本报告推导。

### 3.2 未遮挡响应＋局部修正：一个不丢耦合的LTC使用方式

代数恒等式：`S_ref=S0_ref+c Σ_s q_s (V_s-1) g_θ(l_s)`，`S0_ref=c Σ_s q_s g_θ(l_s)`。若某s无遮挡，其修正严格0；用两张32-bit样本mask标记真正非1的V，只为J个受遮挡样本计算修正。基线S0可以用静态响应拟合或LTC替代；其误差单独归为 `S0_approx-S0_ref`，不能因阴影修正精确就把整体称等价。

E同样用 `D=U+Σ q_s a_s(V_s-1)`，再代入当前逐通道I校准。条件性vector moments可表达U，否则有clamp的U也需要响应基底或原计算。近区未遮挡S0是64点，远区是8点；二者不相等，替换必须记录两种reference strata，不能把连续LTC默认当两者一致。

[Heitz等LTC原作者说明](https://eheitzresearch.wordpress.com/415-2/)给出拟合BRDF后多边形解析积分，明确拟合并不完美；[原作者实现](https://github.com/selfshadow/ltc_code)还提醒实现LUT参数化不同于论文。LTC能提供便宜的**未遮挡**面光响应；球遮挡在灯平面是曲线域、多球还需并集，不是现成矩形LTC调用顺手解决。查询2026-10-02。

J远小于64的区间有结构价值；接触中心可能J=64，虽然往往被球体本身挡住，但不能把“往往不可见”当证明。一律剪掉shadow中心不合法。样本mask/索引存储、atlas读取和两次LTC边界积分都纳入成本，不只数BRDF循环。

### 3.3 局部解析路线不能绕过遮挡并集与过滤

单球锥与灯面相交可以解析构造影域；多个球不是把各自面积积分结果相乘。要精确得到当前乘积过滤模型，需积分重叠中的透射率乘积；“遮挡形状几何并集”只等价于硬、全不透明V。当前smoothstep足迹与opacity fade是软透射，直接多边形并集还会变公式。

若接受新连续硬影/软影模型，可为球投影椭圆、求交与并集、把可见灯域分为多边形近似，再用LTC逐区域积分；复杂度随边界交点而增长，密集球组可能不再便宜。保留每样本的V场可避免这套复杂边界管理，因此适合作为先实施切片。

## 4. 第一切片的具体设计

**边界：仅床面接收域，光照与球状态沿用当前MRL快照；非平面、台下接收、其他材质继续当前R/A路径。** 球体反射本轮第一切片不动。

1. 引入receiver域（床面几何标识＋surfaceY＋XZ范围＋采样格距），材质语义与几何映射先分清。允许height epsilon只是匹配当前平面数值误差，不能将高37mm库顶误入。
2. 全局固定二维tile坐标；sphere support采用MRL:401–416原predicate，并在台面范围裁剪。近场8×4×2灯点常量固定；far走当前2×2×2，无shadow循环，也不新增far visibility存储。
3. 第一实现采用**快照变化时完整生成当前全部active tiles**，N_d=N_active；当前frame页表只引用当次完整生成的页，不沿用过期球贡献。相机移动或仅球自转不重新生成。随后才加入旧support∪新support dirty更新及不可变页copy-on-write。无论哪种，重叠tile从完整当前候选集合重算，不用“除掉旧球因子”（V可能0且会积累误差）。隐藏、落袋、跨tile由新页表删除旧贡献。
4. compute每texel以相同世界p计算64个V：相同sphere radius、顺序、sampleCellRadius、height clamp、opacity解码和候选predicate。shader读V_s后沿用原q、n、v、roughness、E校准、S和nap；保留 normal/roughness采样与颜色链。
5. 片元先沿用原shadowPossible predicate决定8/64 strata；因此首片保留一次每片元球support扫描，不把它算作已消除。世界cell的重建误差超过预算时回原积分，不能只按相机近景决定fallback。32×32有效texel的tile带邻域gutter。64标量可pack成16个RGBA16F层，使用同一atlas页和索引表；层/页绑定可由SCNProgram或自定义texture argument承载。不默认采用密集512×256×64。
6. **设计资源上限**：先采用8MiB/版本的有效payload预算，最多65536个receiver texel；gutter、页表、对齐额外列账，不可塞到“零开销”。允许最多3个GPU在途版本，payload上界24MiB；这只是此候选预算，尚未被产品批准，不声称符合10-01“不改资源”约束。实际tile数须从payload预算减去gutter；不强写64个32² tile同时又把gutter免费。
7. 超预算/受影响域过大/无法保证当前快照版本的tile直接用原积分；**同一状态同时提供reference与atlas模式**，不采样旧场、不降全页分辨率，不降低near灯样本数。选择只基于覆盖域与预算，不等用户跑设备后才允许实现。
8. 首片不顺手把接触AO截断或烘焙。AO场可紧随加入：512×256 R16F一状态256KiB，3状态768KiB；仍算资源和插值误差。其独立尺度/依赖允许共用tile状态所有权，不强行与64通道场同分辨率。

**为什么首片保留64通道，而不立即只存9个系数？** 它独立拆除了球遮挡工作、保留全部方向信息，可作为后续角压缩的直接参照和局部fallback。直接9系数一阶段会同时引入遮挡重建、BRDF低秩、normal/view旋转、E重校准四类误差，失败后难定位。第一切片不是最终“大幅压缩64积分”的终点；第二阶段compute仍逐sample取V但只写L系数，取消64通道驻留，用同一dirty结构和语义边界。

**不宣称第一切片必然净省电**：少球、桌面屏幕覆盖小、atlas层读取贵、dirty世界texel多的组合可能净增成本。首片同时实现reference回退是完整设计的一部分，不靠低频更新牺牲运动同帧质量。

## 5. 工作量、资源与交叉点

令 P_h为实际near台呢着色调用数（含可见像素、过绘及实际着色频率，不把MSAA4机械乘4）；P_f为far调用数；K=64；b为每点候选球平均数；N_d为这一帧dirty有效texel数；N_r为驻留有效texel数；B为全球数。定义 c_b为一个过滤球检测成本，c_g为一个灯几何+BRDF求值成本，c_t为每个V_s的有效texture读取成本（pack四通道时64标量可由16次RGBA sample取回，不等于64次独立硬件texture调用），c_w为一个V_s写入成本，c_f为compute新增灯方向几何及cell误差certificate的摊销成本，H为tile管理/compute切换/必要copy成本。

- 原与首片共有 `P B c_support` 近区判定成本，首片并未消除它；以下整式省略这一共有项。若改成lookup近区predicate，又引入分类重建误差，必须另计。
- 原台呢主要项：`P_h K(b c_b+c_g)+P_f 8c_g+P B c_AO+P c_I`。
- 逐s场：`N_d K(b_d c_b+c_f+c_w)+P_h K(c_g+c_t)+P_f 8c_g+P B c_AO+P c_I+H`。
- 第一切片优势条件：`P_h K b c_b > N_d K b_d c_b + N_d K(c_f+c_w) + P_h K c_t + H`。
- 若b≈b_d，转移的射线工作比例是N_d/P_h；这不是帧时间或能耗比。相机移动但球不动时N_d=0；动态开球首实现N_d=N_active，后续旧新support dirty并集也可能很大，不能代入静止成本。
- 角场：`N_d K(b_d c_b+c_f+L c_project)+P_h(L c_fetch+ c_kernel(L))+H`，与原式交叉条件用两整式比较。核系数旋转/插值不一定只是L次乘法，必须纳入c_kernel；不把投影的K×L藏掉。
- correction路线：`N_d K(b_d c_b+c_f+c_write)+P_h(c_S0+J(c_g+c_t))+H`。遮挡中心J=K、支持区边缘J小；S0的LTC/拟合成本以及sample-index管理是明确残余。

两套不同成本不能混为一谈：P_h/N_d主导“屏幕→世界”；K/L或K/J主导“积分→角响应”。第一切片只拿前者，第二阶段拿后者。多摄像机同时消费同一球快照可共享场、各自η，但不相同scene instance/灯几何的场不能共享。

资源公式：逐s标量存储 `K N_r h` bytes，h=2时 `128 N_r`；L系数场为 `L N_r h`，加diffuse核/校准数据另算。512×256×64 FP16一状态16MiB，两状态32MiB，三状态48MiB，尚无gutter/页表/AO；本候选不默认分配这张dense场。相同512×256、L=16 FP16是4MiB/状态，L=25是6.25MiB/状态；它们是**内存算术示例**，不是已证明够用的rank或分辨率。

32²有效tile的64-channel payload为128KiB；若每tile四边1-texel gutter，变成34²×128=147968 bytes；总tile数相应减少。FP32 nodal参照为该payload两倍。R8 UNorm是FP16一半，但单通道量化最大约1/510，且积累/校准后不是同样RGB误差；不默认以R8实现保画质。

格距δ与预算的交叉：`N_r≈coveredWorldArea/δ²`，`N_d≈dirtyWorldArea/δ²`。例如把δ减半，资源与更新工作约增4倍。full-bed512长轴在2.54m尺度上约5mm格距，不能单靠“512已经很高”保证近球影准确。纹理场真实误差包括V量化、双线性重建、tile边界、current近区predicate连续位置误差。sample光足迹smoothstep给V一定平滑性，但代码有极小f clamp，不能据此无条件断言粗网格足够。

frame版本copy也计成本：首实现球快照变化时完整生成全部active tiles，不含未dirty旧页复制；相机或仅rotation变动引用同一只读版本。后续三版稀疏场若只dirty更新，未dirty tile如何进入新版本必须明确。可用不可变tile页copy-on-write＋当前frame页表；只有changed tile分配新页，旧页GPU完成前保留。若简化为每frame整atlas复制，则H含 `128N_r`读写bytes/帧；不把GPU在途ring-buffer免费当缓存。同queue顺序保证compute写后draw读，完成后才复用页；无需CPU每帧waitUntilCompleted。

## 6. 失效依赖与同帧所有权

| 变化 | V场 | AO场 | 角C场 | 片元θ/基线响应 |
|---|---|---|---|---|
| 球XZ/height/opacity/active | 旧新support重算，含重叠球 | 重算有效影响域或整床 | 跟V重算 | 无需因遮挡额外改θ |
| 仅球自转 | 不变（当前球阻挡是球体） | 不变 | 不变 | 球面号码/反射正常实时 |
| 相机位移/旋转/FOV/2D3D | 不变 | 不变 | 不变 | v/nv/footprint/纹理LOD更新；不能烘成固定view高光 |
| cloth颜色/曝光 | 通常不变 | 不变 | 无光色的标量系数可不变 | 颜色链/曝光仍当前frame |
| roughness/normal内容或取样LOD | 不变 | 不变 | 如C为incident方向分布则不变 | η、E校准、fiber、nap更新；适用域改变需重新拟合/模式选择 |
| 灯位/尺寸/采样strata/footprint模型 | 全失效 | 灯无关AO不变 | 全失效 | 静态响应/LUT版本变 |
| receiver高度/桌变换/geometry | 域变失效 | 域变失效 | 全失效 | receiver语义/坐标变 |
| scene销毁/重建、不同导出实例 | 不沿用旧状态 | 不沿用旧状态 | 不沿用旧状态 | generation与资源完整分离 |

球位/相机属于同一个FrameSnapshot版本：先按指定时间完成SceneKit presentation更新，从同一animation epoch读当前float4；提交dirty compute；结束compute encoder；再draw当前frame。最晚决定模式时必须知道当前场是否ready，旧场不能与新球混用。已有不可变Data/变化检测/presentation读取是基础，不算本架构新收益。物理预测、碰撞、进袋规则不参与修改。

轨迹回放/导出可以把时间传入同一更新服务；不能仅在交互CADisplayLink更新而在snapshot输出陈旧场。现有导出先保reference；如果将来采用新field，要改成“update(t)→freeze(t)→compute→render(target)”接口，而不是在renderer.snapshot内部未知时序另开queue。

## 7. SceneKit承载：公开API够用，不必先全引擎迁移

2026-10-02已实际读取Apple页面的Markdown正文；以下官方API构成可实施承载，未执行集成：

- [SCNMaterialProperty.contents](https://developer.apple.com/documentation/scenekit/scnmaterialproperty/contents)：接受MTLTexture；当前代码已有railAO/room textures绑定。可将atlas作为自定义shader argument。颜色转换必须明确，visibility/coefficients作为线性data texture，不加sRGB。
- [SCNProgram](https://developer.apple.com/documentation/scenekit/scnprogram)：完整替换指定geometry/material的vertex/fragment，并能获取SceneKit frame/node transform以及custom variables。它不会自动替你实现normal mapping、粗糙度纹理、MRL输出校准；这些要明确移植。可以只替床面，不替全桌/球/线条。
- [handleBinding(ofBufferNamed:frequency:handler:)](https://developer.apple.com/documentation/scenekit/scnprogram/handlebinding(ofbuffernamed:frequency:handler:))：提供每frame等频度的自定义buffer内容；不是得到任意compute encoder的API。本机SDK `SCNShadable.h:290` 方法availability是 **iOS9**，不可拿SCNProgram类iOS8替代方法；iOS17满足。
- [SCNRenderer.render(atTime:viewport:commandBuffer:passDescriptor:)](https://developer.apple.com/documentation/scenekit/scnrenderer/render(attime:viewport:commandbuffer:passdescriptor:))：将SceneKit render编码进调用方commandBuffer，官方说明会先更新presentation再draw；本机SDK `SCNRenderer.h:57` iOS9。
- 更适合此切片的是 `update(atTime:)`后 `render(withViewport:commandBuffer:passDescriptor:)`：SDK `SCNRenderer.h:67–77`明确后者不更新animation/physics/particles，调用方先update；均iOS11。这样得到“更新一次→快照→compute→同buffer draw”的公开链，避免在render(atTime:)再次更新球快照。当前最低iOS17满足。
- [currentRenderCommandEncoder](https://developer.apple.com/documentation/scenekit/scnscenerenderer/currentrendercommandencoder)：只公开当前**render** encoder，delegate中可追加render commands，不能把它当compute encoder或随意结束SceneKit内部pass。另开queue再给SCNView读texture若无明确ordering，不能宣称同帧正确。

Apple Markdown availability元数据在这些不同方法上出现统一iOS8值，和真实SDK精确方法声明不一致；本报告以SDK精确声明确认版本，并用官方正文确认行为，不把页面摘要当精确availability。

可以保留SceneKit场景与交互框架，局部用SCNRenderer＋MTKView host取得提交顺序，再决定用modifier还是床面SCNProgram。SCNProgram去掉PBR尾部是另一可实施切片，不与field降低B项重复记账。若modifier在床面可完整绑定atlas且保normal/roughness，则无需强制同时上SCNProgram。只有所需resource layout/compute-composition无法用公开承载满足时才推进局部Metal draw；此算法本身不要求全自研引擎。

## 8. S/RS与旧L的处理

S/RS已存在（MRL:166–179,375–378,462–568），不是本报告发明。S每球锥截面Z解析、X八Gauss-Legendre条带；每灯得到单球阻挡积分，再乘各球平均visibility；S镜面用2×2无影quadrature再乘该平均visibility（MRL:547–561）。其积分精度、软过滤模型、多球重叠、微法线及BRDF耦合与当前R的64-point原式不同。由§2反例，**不能**作为同画质精确重构默认。

旧任务记录 `tasks/DAILY-CLEARANCE-SPECIALIZED-20260921.md:53–57` 已公开最大近接触边界误差和非精确多球并集；记录的视觉矩阵没有宣称S因“条纹”被正式视觉否决。本报告不捏造这个否决。S/RS不是每日现默认，亦无当前全页热目标证据；可保留为与新算法对照的另一近似，而非一键开启。

旧L也不是空白：`tasks/DAILY-CLEARANCE-CORRECTION-20260921.md:29–36`、`scripts/research/bake_local_sphere_shadow.py:8–25` 已做3个台面位置×2高度×2灯的局部平均遮蔽图，12张128² R16F；再quad画入512×256 RG16F。它只保留**每灯一个标量**、只做采样fixture，连续球位/高度、多球并集、动态入袋、扰动n未完成。第47–65行保留SceneKit单球负结果与后来边界纠正，不能外推当前每日设备，也不能说“一切局部场都已失败”。

本方案相对旧L的实质新增是：世界固定tile；当前float4状态；先每s多球乘积；保留64方向信息；同frame compute/draw依赖；dirty旧新域；有界驻留与fallback；第二阶段有针对g_θ的角投影。仅把旧L每灯标量换个引擎、说成世界场重构，并未解决§2反例，应淘汰。

## 9. A类判定与B类实施后关口

**A类，本轮已定论：**

- 动态sphere visibility与相机/rotation/roughness无关：MRL遮挡函数只读p、灯点和float4；域转换成立。
- 平均visibility不保S、多球均值乘积不保联合：反例已定论；不可作为默认前提。
- field对nodal计算复用相同模型可成立，但插值/FP16并非exact：数学和存储类型已定论。
- 支持区外far与near不同strata、AO无限尾部、库边非平面：均由代码已解决；设计已提供例外。
- SceneKit能接受MTLTexture、SCNRenderer能由调用方提供commandBuffer、split update/render iOS17可用：官方正文＋SDK已核验。
- 旧S/RS、旧L、已有参数缓存与停绘不是新成果；第一slice不去掉P×64 BRDF，代码/成本式已明确。

**B类，转为实施后的具体关口，不阻止现在选定架构：**

| 未知 | 本候选建议门槛与方法 | 不通过的处理 |
|---|---|---|
| V空间重建/FP16误差 | 离线以原MRL同p fp32结果为参照；active shadow ROI而非整帧背景，起始预算absolute V p95≤.01、max≤.03；最终以E/S线性RGB误差另判 | 更细tile或局部reference，预算满则fallback；不放松误差宣布等价 |
| E/S累计图像误差 | 初始工程预算：active ROI线性RGB p95≤.005、max≤.02；带球遮挡/低视角/纤维/多球重叠/near-far边界单列，运动同姿态复画不额外拖影 | 定位空间重建与角压缩分别误差；回退该tile/材质域 |
| 角rank是否足够 | 以真实normal/roughness域＋允许view参数离线原公式响应矩阵，L=9/16/25递增；上表E/S预算不变，报告最坏参数而非均值 | 保64或采用S0＋逐s correction；不强行“SH9足够” |
| 页复用/dirty时序 | 快照/场/球transform版本必须相同，差1frame即失败；旧support清理、隐球、入袋、场景代次切换确定性一致 | reference当前快照，禁止旧场补帧 |
| 是否净减少工作 | 实现后从调度账本得到P_h、N_d、b、J、tilecopy及驻留量，代入整式；8MiB/版本预算含有效texel而总量另报gutter/页表，3在途payload≤24MiB | 增强角压缩或缩小适用域，不宣称所有开球动态帧更快 |

门槛是本报告提出的工程起点，不是当前用户已批准的画质容差，更不是原v62严格等价验收。本轮下一动作仍是实现结构切片及其离线正确性链，不把新手机测试写成启动条件。实际GPU毫秒、功耗与视觉接受度保持未知，报告不虚构倍数。

**最强反方与可推翻本推荐的条件**：若实际允许的影边误差迫使δ非常小，使正常每日开球的N_d≥P_h且fallback覆盖大部分可见near台呢，同时64次atlas读取显著增加工作，逐s场第一slice不值得成为默认，即使公式完整也要撤销该部署。若cloth响应的L始终接近64且kernel旋转/采样成本抵消循环减少，角基底也应撤销。届时优先保SceneKit、实施未遮挡S0拟合＋稀疏逐sample correction或仅同公式公共项，而不是据“可控性”转完整Metal。

这并不把决策推给未来：**现在选择稀疏逐sample场作为最小结构切片，明确完整角响应场为第二阶段主路线；现在淘汰平均visibility与无条件SH9；实现后按照上述反例和预算决定哪些域启用。**


## 10. 首轮评审提问回应：重建判据与第一切片上限

评审指出：256×128在2.54m×1.27m床面上约9.92mm，近接触样本足迹可能只有毫米尺度；仅以相机近景fallback不足。这个异议成立，§4已改为世界cell误差决定模式，不按相机名称作保证。

可实施的**保守判据**是给每cell、每s计算V_s的区间包络：以cell XZ范围（若有容许height误差也纳入Y区间）对原t、r²、perpendicular²、filterRadius、smoothstep与分支作区间计算；每球因子在[0,1]时，联合V区间是各因子区间的乘积。任何分支无法证明时放宽为[0,1]，不能错误当作无遮挡。若该cell的所有s区间宽度加FP16量化界不超过ε_s，且重建用的四角都是同snapshot完整结果，则双线性值是四角值的凸组合，真实V和重建V均在包络内，可给绝对误差上界。否则cell invalid，片元对该cell采用原积分。gutter不是免除判据的证书；邻域不完整、版本不一致均invalid。

这是可直接实现的保守certificate，不是说区间界一定紧。原式有很小filterRadius clamp与t分支，保守界可能大量invalid，明确归为候选适用覆盖率未知。也可以用导数上界细化包络，但仅对几个角点测有限差分后称严格误差界是不成立的。原64点和高梯度区域保留reference，所以无需为了让field命中而放松预算。E/S上界仍按原权重累加：`|δD|≤Σq_s a_s ε_s`、`|δT|≤Σq_s a_s k_s ε_s`，E再乘I并除当前逐通道denominator；不可把V误差直接称RGB误差。

评审建议首实现full generation以减少状态证明成本，已采纳为**当前全部active tiles**完整生成，而非full-bed dense64。每次球影快照变时N_d=N_active，旧新支持完全由当次页表决定；dirty局部COW留第二阶段。AO保持原式，后续独立完整单通道更新，不塞入球影有限support。

是否应在首片立即上moments/无影快分支？far本来已8点且无遮挡，首片不重复计作新收益；近区即使V全1，当前S仍使用64点，与far8不同，直接改8是新近似。合法的一阶moment锥条件可写成：存在床面轴n0、所有纹理n满足夹角≤β，全部sample方向与n0的最大夹角γ，且β+γ≤π/2；此时n·l_s≥0。共享光色c也由MRL常量给出，但ε逐通道不能删。当前文件没有β保证，normal map范围/LOD尚不由源代码限制，因此**不能**把条件性moment当首片无条件方案。

第一slice上限明确：去掉重复blocker检测、相机/自转时不重算世界遮挡，仍有每near片元64个V标量读取（RGBA pack可用16次sample）、64次灯几何/BRDF、一次support扫描、解析I与接触AO。若用户要求第一次就同时减少64次数，选§3.1的角场或§3.2的S0+局部修正，接受明确的核拟合误差；不要把第一slice的射线次数比包装成实际性能倍数。推荐第一slice的原因是方向信息完整、状态与耦合可单独闭合，并给第二阶段压缩提供基准，不是认定所有每日开球负载都会获益。

## 11. 交叉收口：接受主控有界单场首版，稀疏页留后续

已阅读 `ARCHITECTURE-PROPOSAL.md` 当前版。**接受共同v1缩为“明确床域、单份持久R32Float逐样本场、blocker快照改变时完整生成该承接域、同queue compute→draw、原公式fallback”**。本报告§4的稀疏tile、FP16和最多3份24MiB payload是独立的后续/备选提案，不能与共同v1混称，也不能当作已批准资源范围。首版及后续均沿用既有**新增峰值16MiB护栏**，计入guard、metadata、临时工作资源、资源替换时新旧并存；24MiB未批准，本文不推动绕过护栏。采用单份tracked、稳定直接绑定纹理，在已明确的GPU访问顺序内不必复制三份大场；CPU快照/uniform在途slot是另一种资源。

这个收窄牺牲首版“更新工作跟球影面积成比例”，获得较简单的内容与版本证明：球影快照变就完整生成有界承接域；相机与单纯球自转时复用。后续若再引入dirty tile或page COW，另列分配、迁移、回收账单，不把它们列成首版既得收益。256×128×64 R32Float逻辑payload为8MiB；collar/对齐等使真实资源更大，替换峰值不允许仅看新field这一份。

**保留的不赞同项/条件**：

- 不能因首版简单就给9.92mm世界格距默认质量放行。评审按当前中心正常球计算的filterRadius约1.44588–3.20690mm，足以否定无条件“该格距保证接触影细节”；本报告§10的world-cell区间包络/解析导数界与invalid-cell原公式路径仍须写进实现契约。四角finite difference不能称certificate，fallback也不能只按机位名称。
- 同一queue的commit顺序本身不足以证明安全。接受persistent单场的前提是传统Metal tracked资源、真正直接绑定、全部field读写都在受控同queue，稳定材质资源句柄及明确encoder结束；新实现要使这些条件真实成立。独立export/queue、间接或untracked访问、SceneKit包装导致无法证明实际资源依赖时，需显式同步或隔离资源，重新列峰值，不能偷读旧场。未完成接入前不宣称已经证明上述条件。
- 首版仍每near片元64个方向/BRDF响应；RGBA pack取回64标量可16次sample，逻辑bytes或sample次数不能直接当DRAM流量/能耗。原support扫描、AO、解析I也保留。大幅压缩方向维度仍属后续实质工作，S0＋非1样本correction值得与角基底并列优先，J最坏64、rank不足可撤销，不需要全引擎迁移。

误差还可更紧地表述：若所有s满足 `|δV_s|≤ε`、q/n及U沿用当前计算，则逐通道 `|δE_c|≤ε I_c·(c_c U/max(c_c U,1e-6))≤ε I_c`；S为 `|δS_c|≤ε c_c Σ_s q_s a_s k_s`。这里保留原ε denominator，未把V误差冒充最终输出误差；材质albedo/nap和0.35镜面权重之后还有输出映射。R32避免FP16储存量化，仍不消除空间重建误差。

另澄清§3.1的二维LUT：只按 `(nv,roughness)`存**局部BRDF角基底系数**，再用实际n/v旋转或contract世界方向场，不等于只按N·V读取最终面光结果；缺少方向基底与旋转的一张二维最终照明表，不能承载任意微法线/面光方向。这个区别与主控禁止的捷径一致。
