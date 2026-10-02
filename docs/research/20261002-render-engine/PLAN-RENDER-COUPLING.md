# 两视角相机语言与渲染表示的实施候选

2026-10-02；方案专项输入，未实施。只读当前源码、`ARCHITECTURE-PROPOSAL.md`、`CAMERA-RENDER-CONTRACT.md`及本轮已有官方证据；未新增联网研究、构建、设备或实验。新语言目前为第三人称轨道 `(s,θ)`、第一人称眼位/头yaw域、2D全盘；眼位范围、横滑语义、最近/最远端、观察中心与自动转镜政策未全部冻结，以下不以旧FOV/俯角约束新产品。

**执行顺序：实际相机/球帧契约 → 单有界V64世界场 → 合法法线锥内的漫反射方向矩 → S0＋J局部修正与完整角基底竞争 → 扩展接收chart/资源与媒体消费。** 第一切片保留64次BRDF，是搬移重复球几何的起点；更大的工作量减少来自后续减少方向求和，不来自限制镜头。

## 1. 代码给出的计算边界

- `QiuJi/Core/Scene/MobileReferenceLighting.swift:375–459,869–906`：near两灯各8×4、far各2×2；每sample球透射乘积，E再用解析矩形照度乘采样遮挡比，S直接逐sample加权BRDF。相机只参与材质响应，不参与sphere blocker计算。
- 同文件`:29–48,609–637`：固定水平矩形rig与horizon-clipped解析照度；`:166–197`及`AngleTrainingScene.swift:27–38`：每日默认R，仅球反射预积分，台呢64/8原式仍在。
- `MobileTableRendering.swift:152–277`：contact类在本文件；presentation float4为 `(x,z,max(R,h),.85*opacity*clamp(h/R))`，状态变化才批量提交。`:179–202`AO有无限距离尾部，床面railAO已做高度判断；`:99–106,205–225`保normal/roughness与fiber，TaiNi不等于单一床面。
- `AngleSceneView.swift:539–607`仍由显示回调更新相机/锚定；新宿主必须迁移最终矩阵的投影/拾取消费，不能让旧SCNView继续读另一个实际相机。`SequenceVideoExporter.swift:1077–1094`为独立renderer、contact delegate、固定clock snapshot；首片不改导出。

## 2. 相机域与误差契约

| 域 | 必须冻结的表达 | 对表示的影响 |
|---|---|---|
| 第三人称 | `eye=γ(s,θ;context)`、朝向/构图规则、投影/lens、viewport/HUD、安全边界；context说明桌中心或动态观察目标 | 参数控制可二维，但实际接收视线仍随p变化；目标若变化，不能只按s/θ复用最终照明表；θ周期接缝与s端点响应须连续 |
| 第一人称 | 当前站位/眼位域、杆轴返回政策、头yaw域；是否有pitch/dolly/换站位明确另列 | 转头不改V内容，低掠射、小n·v、near clipping、库/袋可见域仍需覆盖 |
| 模式转场 | 两端及整条实际eye/orientation/lens路径、手势接管、owner epoch、取消与事件时钟 | 中间姿态属于拟合域；不可只检查两端，资源未ready时当前frame用原公式 |
| 2D全盘 | 实际正交矩阵、fit/pan/zoom域、读盘能力与主体 | 可独立路由表示，不能把3D观看能力减少算成渲染算法节能 |

表示契约还需 receiver chart/XZ-Y范围、微法线锥、roughness/纹理LOD域、实际视线集合与最小n·v、像素世界footprint、E/S线性RGB误差和峰值资源预算。render不得反向收窄镜头、抬眼位或取消近景来让拟合通过。

低机位直接改变n·v，不直接改变n·l的light horizon；normal mip/LOD变化可能改变实际n。球阵不变而相机推进s/θ或头yaw时，**V内容版本有效**；dolly靠近造成的footprint和镜面核变化可能使**该表示精度不合格**。两者独立判断，不共用sceneDirty。

## 3. 阶段一：搬走候选球检测，保留完整方向信息

仅一个interactive session、明确床面chart接入。缓存 `V_j(p,B)=∏_i(1-a_i b_ij(p))`，64方向/顺序、球半径、height/opacity解码、lightCellRadius、near predicate沿当前公式。相机视锥外球仍可遮灯，不从blocker列表删掉。

首版为**单份持久R32Float场**；blocker revision变时完整生成有界承接域，相机或球仅自转时复用。无dirty tile、page迁移或轮转大场。far8、AO、非bed接收、球R及现有曝光/材质链保持；同材质库顶/袋口/台下走原式。片元继续原n/v/roughness、解析E校准及64 BRDF；不是一灯平均visibility场。

256×128×64 R32逻辑payload8MiB，带2-texel层collar的2D打包约8.38MiB，仅容量示例。新增GPU**总峰值≤16MiB**，包括field、collar、certificate、metadata、输入在途slots、工作资源和retired资源。旧新替换超峰值时当前帧用原公式，旧资源异步退役后再分配；不CPU等待、不偷读旧场。高层纹理property不证明真实direct binding。

约9.92mm床面格距不能保证中心正常球约1.45–3.21mm的sample过滤足迹。采用world-cell区间包络或解析梯度上界，包含p位置误差、64个V及分支；无法给出误差界的cell invalid→原公式。四角finite difference不是证书；仅按相机“近景”分类也不足。R32去掉FP16存储量化，却仍有空间重建误差。

若 `|δV_j|≤ε`且权重/材质原计算不变，则逐通道 `|δE_c|≤ε I_c·c_cU/max(c_cU,1e-6)≤ε I_c`，`|δS_c|≤ε c_cΣ_j q_j a_j BRDF_j`；最后还需传播albedo/nap、0.35S及输出映射。cameraFrame提供当前响应与footprint，世界certificate可复用，响应传播界逐帧或用整个允许相机域保守界。

成本：令P为near片元求值数、K=64、b为候选球数、N为承接域texel数、u为本帧blocker变化标记。原检测约 `PKb c_block`；首片增量约 `uNK(b c_block+c_geometry+c_write+c_certificate)+PK c_fetch+H`。原BRDF、support扫描、AO与far8另列共有项。RGBA布局可用16次sample取64标量，但逻辑bytes/sample数不是DRAM流量或瓦数。

反例：开球频繁u=1，且N接近P、certificate大面积invalid或少球b小，field可能净增工作。此时缩小承接域或当前frame退原式；不以“相机只有两参数”宣称大幅节能。

## 4. 阶段二：条件性漫反射方向矩

当前共享光色c成立。若资产法线锥β与全部灯方向锥γ满足 `β+γ≤π/2`，则所有n·l≥0，离散漫反射可以用 `M=Σq_j V_j l_j`、`M0=Σq_j l_j` 表达，`D=n·M`、`U=n·M0`；保留当前 `I(p,n)*(cD/max(cU,1e-6))`。I不是U，不能删解析校准或epsilon。

资产normal/LOD无该保证的cell/材质域不接入一阶矩；低机位本身不破坏light hemisphere，但normal变化会。法线锥由真实资产/允许LOD范围与rig导出，不脑定一个角。球动更新M，相机/roughness动只重建响应；输出仍须用实际cameraFrame。

这一步降低漫反射方向求和，但镜面S仍64，且原E/S共享light geometry：不能把减少E循环重复计作整64成本被删除。三分量moment布局、M0静态或解析重建、normal predicate/certificate均入16MiB预算；不能在V64旁无限增加派生场。优先与镜面压缩组合后减少存储。

## 5. 阶段三：优先S0＋J修正，完整角基底竞争

**候选A：无遮挡响应＋受遮挡sample修正。** 恒等式 `S_ref=S0_ref+cΣ_j q_j(V_j−1)g_ξ(l_j)`，`g_ξ=max(0,n·l)BRDF`。把固定rig的S0用两灯LTC或针对原64/8积分的响应拟合表达，仅对J个受影响方向算修正；ξ包含n、v、roughness，不能只按s/θ查最终颜色。

near64与far8的S0不同；LTC连续积分不能冒称与二者精确相同。S0拟合误差与V重建误差分别列账。cell的非1样本mask必须来自保守包络：四角V=1不证明内部无遮挡；删掉近1修正须计入误差预算。J最坏64，接触/重叠球组可能无收益；保持高频原路径。成本约 `uNK c_generate+P[c_S0+J(c_BRDF+c_fetch)]+H`，不能漏mask与基线响应成本。

**候选B：完整可见光角系数场。** compute先逐j做所有球乘积，再形成 `C_m(p)=Σ_j q_jV_jφ_m(l_j)`；片元 `S≈cΣ_m C_mη_m(n,v,roughness)`。二维轨道限定拟合视线集合但不令全BRDF二维。旋转对称GGX可用 `(n·v,roughness)`存局部角核系数，再按实际n/v旋转或contract世界基底；省略此方向处理的一张二维结果LUT不成立。

L=9/16/25只是候选，不默认9系数足够；核误差界 `|δS|≤|c|Σ_jq_jV_j|g_ξ−g^L_ξ|`，纳入两模式及转场全域。低掠射、窄高光、horizon和高频遮挡可能提高rank。成本 `uNK(b c_block+L c_project)+P[L c_fetch+c_kernel(L)]+H`，projection/rotation不免费。L接近64或kernel成本抵消时撤销该域压缩，不要求全Metal迁移。

按核误差与实际调度工作账本选A/B的适用域，不先指定赢家。S0＋J在遮挡只影响少数方向时更有机会；完整角场在受遮挡方向较多但粗糙核可低rank时更有机会。二者都保visibility×BRDF关系，不采用平均visibility或各球平均遮挡相乘。

## 6. 误差预算与阶段出口

| 项目 | 方案起始预算/出口 | 失败的具体动作 |
|---|---|---|
| v1 world重建 | 建立cell级ε_V→E/S传播；建议初始active ROI线性RGB p95≤.005、max≤.02，最坏cell/材质另列 | invalid cell原式；细化需重新算峰值；不能放宽容差宣布等价 |
| direction moments | hemisphere前提可证明、epsilon/解析I保留；数值重排误差独立列 | 该域继续逐sample，不改变相机语言 |
| S0/角核 | 与当前R台呢离散reference比较，沿用同一E/S预算，覆盖允许n/roughness/view及转场 | 增加有限高频修正或reference；预算/rank不足撤销 |
| sameframe/资源 | camera/blocker/field session一致；内容版本完全匹配；新增总峰值≤16MiB | 当前快照原式；不漏影、不读旧状态、不覆写在途输入 |

上述质量容差是待最终方案裁定的工程起点，不是用户已批准外观改变。数学前提、分区与资源/API契约现在可以形成并实施；画质接受度和GPU毫秒是实施后关口，不把“先做设备测试”作为启动条件，也不承诺能耗倍数。

## 7. 同帧/API与版本所有权

`CameraFrame`至少包含**实际**view/inverseView、projection/inverseProjection、投影类型、viewport/裁剪、实际eye/orientation/lens、曝光/显示参数、time sample、camera revision、session/generation。不能只存目标γ(s,θ)；实际阻尼/转场/约束结果才供draw、project/unproject、hitTest、锚定和标签共用。

另存request revision、owner epoch、presentation revision、blocker revision、receiver/rig/layout/algorithm版本、材质/静态资源版本。球自转只变presentation；相机只变camera/精度需求；过期自动取景不能抢手动owner。frame owner具有唯一提交权限，不同时让SCNView与受控renderer推进同场景。

公开承载沿本轮已核验[SCNRenderer API](https://developer.apple.com/documentation/scenekit/scnrenderer)与本机SDK精确声明：`SCNRenderer.update(atTime:)`推进一次，在动画及相关约束最终状态就绪后freeze；compute结束后用**不再update**的 `render(withViewport:commandBuffer:passDescriptor:)`draw。两方法iOS11，最低17可用；不要再调用会update的render(atTime:)造成双推进。SCNProgram buffer binding iOS9，MTLTexture可作material contents；这些是能力条件，不是已集成证明。

persistent场须tracked＋真实direct绑定＋同传统queue GPU compute→draw→下次改写顺序；高层SCNMaterialProperty不证明内部资源访问。若无法证明，则在app-owned commandBuffer使用公开GPU event边界覆盖写完→SceneKit读与draw读完→下次写；载体仍不成立就当前公式。heap/untracked、间接绑定或跨queue另列同步/资源；输入slots满时不覆写、不CPU等待。

显示唤醒、仿真、回放、相机转场时间有明确映射；事件按有效时钟区间/稳定ID/杆次消费，跳过draw不漏事件，seek政策单列。GPU completion只回收资源，不触发观看政策。转场每一中间姿态的表示都必须合格或有原式退路。

## 8. 静态资源与export渐进边界

canonical静态资源键至少含asset/room、rig、table/receiver、捕获原点/姿态/曝光、shader与预过滤算法、明确材质政策；相机s/θ或头yaw不进入固定room probe内容键。当前`RoomReflectionProbe.swift:290–297`仅按RoomStyle缓存，`:305–374`捕获安装场景；未来规范capture不得由首次用户相机/偶然材质状态决定，也不把新增canonical机制冒充已有。

首片继续现有probe/球R，不顺手重烘焙、改曝光或重复计入已存在的R收益。若规范probe政策更改，独立资源版本与外观对照；normal/roughness纹理细节继续实时，球面反射方向随cameraFrame更新。镜头变化可能暴露既有反射近似边界，但不自动要求重capture静态房间。

首个interactive session接入后，其他训练页与导出保原路径；共享契约逐出口适配。未来export通过 `update(t)→freeze(t)→field→render(target)`明确指定clock，不在snapshot内部异步补field。不同session/queue的动态场不共享；canonical只读静态资源可按完整key共享。2D/3D、六袋、回球、球/杆与媒体出口不能因为床面chart而消失。

最终应交付的是这条分阶段算法与所有权链：相机语言定义可覆盖的响应域，V缓存消除屏幕重复球检测，方向矩/修正/角系数进一步减少方向求和；低掠射和近景例外有同帧原公式出口。观看能力与物理保持各自产品/算法所有权，不用缩小镜头掩盖压缩不足。
