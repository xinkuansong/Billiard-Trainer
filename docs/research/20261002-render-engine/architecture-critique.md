# 渲染架构理论反方审查

2026-10-02。本轮仅依据当前源码、公式、SDK声明与官方同步说明审查架构；未改生产、构建、安装或运行设备。采用项目 `idea-evaluation`、iOS架构与debate规则。多个同模型角色同意不构成性能证据。

**结论：值得现在实施一个受限床面切片，但共同首版应收敛为“同帧快照＋单队列持久逐样本场＋遮挡版本改变时完整生成有界承接域”。** 不同时引入稀疏页迁移、三份大场和角压缩。该切片能删除重复球—射线求解，有清楚的代码依据；它尚不能证明动态开球更快或最低能耗。第一次实施仍保留64方向BRDF，后续若要大幅减少这部分，应独立采用角响应或无遮挡响应＋局部修正。

## 1. 当前代码已经解决的问题

当前 owning source 是 `QiuJi/Core/Scene/MobileReferenceLighting.swift`（下称MRL）、`MobileTableRendering.swift`（MTR）、`AngleSceneView.swift` 与 `QiuJi/Core/Media/SequenceVideoExporter.swift`。基线为当前每日R；共享A另列。球面R已存在，不计为新架构收益。

MRL:375–459与869–906表明，当前片元在每个面光样本计算球遮挡，再用同一透射分别加权漫反射与GGX镜面。球遮挡只依赖接收位置、灯样本与上传的球float4，确实不依赖相机、球自身旋转、台呢颜色或roughness。因此把这个函数移出屏幕域是有依据的依赖拆分，不需要先跑手机才提出。

MTR:238–264上传的是presentation球位、编码高度与有效权重。shader使用固定球半径0.028575米；落袋淡出/高度clamp也属于现有视觉模型。不能将物理球心、节点缩放推导的半径或重新解释后的高度混入“同公式”对照。快照可以同时保存真实几何状态和原遮挡编码，两个字段的消费者必须清楚。

当前遮挡support已经过滤候选球；旧成本不是全屏64×16。`shadowPossible`决定near64与far8，两个分层的灯样本位置不同。首版保留这一次support扫描和原分层，不能把原far8称新无影优化，也不能在near区发现T=1就随意改成far8。

## 2. 联合透射场成立，平均透射捷径已被代数否决

令w_j是当前非负样本光权重，k_j为BRDF，T_j为所有球因子的乘积。原代码是：

```text
U = Σ w_j
D = Σ w_j T_j
E = I_analytic × D / max(U, ε)    // 按RGB通道计算
S = Σ w_j T_j k_j
T_j = Π_i (1 − a_i b_ij)
```

缓存每个T_j，仍在当前p/n/v/roughness上计算w_j、k_j及原解析I，可以保留这组关系。缓存texel上的计算可复用原模型；从texel插值到实际片元、降低储存精度则另有近似，不是exact。

三个不能继续作为架构前提的主张：

- 一个平均T同时供E/S：w=[1,1]、T=[1,0]、k=[9,1]，原S=9，平均T×无遮挡S=5。
- 每球平均透射相乘：两球都透过同一半边灯，正确联合平均为0.5，均值乘积为0.25。
- 无条件一阶漫反射方向矩：仅在所有当前微法线n与所有l_j满足n·l_j≥0时，clamped cosine才能移到点积外。当前法线资产域没有这个保证；可以建立法线锥条件，不能直接假定成立。

第一式中的ε是逐RGB通道保护，不能因灯色固定就无声删除。解析I与离散U也不是同一个积分。S的方向相关性不可通过提高平均阴影图分辨率修复；旧S/RS或旧L方案的均值模型不因此变成精确方案。

## 3. 256×128容量与影边：可算的反例和误差模型

当前床域2.54×1.27米，256×128格距为9.921875毫米，cell对角14.031650毫米。以当前rig、p=(0,0.8,0)、正常球心=(0,0.828575,0)静态代入64个灯点，`lightCellRadius=sqrt(5.08×1.27/32/π)=0.253328348`米，原filterRadius为 **1.445881–3.206899毫米**。

该数值只是一个具体位置，不是全域最小过滤宽度；原函数还允许1微米clamp。它足以推翻“9.92毫米网格无条件保留毫米影边”。也不能因球体可能盖住某些影边，就证明所有薄影过渡不可见。

可以现在实现保守certificate，无需用模糊“近机位”代替判据。设b=1−H(u)，H是smoothstep，d为射线距离，f为filterRadius。在过渡带且分支稳定时：

```text
u = 1/2 + (d − R)/(2f)
|∇b| ≤ 3/(4f) × (|∇d| + |∇f|)
|∇T_j| ≤ Σ_i a_i |∇b_ij|           // 各因子在[0,1]
```

固定f=2毫米、忽略f变化且|∇d|=1的示例，b的最大斜率为375/米，格距跨越足以令保守误差界达到整个[0,1]。有限差分四角很小也不是证明：窄遮挡可落在四角之间。

更容易审计的首版是对完整cell（含接收高度容差）做原式区间传播；对t、r²、d、f、smoothstep、球support和分支建立联合T的包络。分支无法证明时放宽为[0,1]或invalid。四角值属于同一快照，双线性重建是凸组合；若真实T和所有角值都在同一区间，区间宽度加数值误差就是保守绝对误差界。否则走当前原公式。证书按blocker/receiver/rig/layout版本生成，可跨相机帧复用；不要在每片元重新做全部导数求解，把原成本搬回来。

若每样本透射误差≤ε_V，由非负权重得：

```text
|δD| ≤ ε_V U
|δE| ≤ ε_V |I_analytic|            // 原max(U, ε)仍保留
|δS| ≤ ε_V Σ w_j k_j
```

这是绝对界，阴影极暗处不能据此保证相对误差。S界随当前BRDF变大；不能把ε_V直接叫线性RGB误差。最后albedo/nap/AO/曝光/色调处理另算。若缓存方向矩而非T，则还引入w_j(p)、l_j(p)的空间重建误差，不能复用上面仅针对T的证书。

暂不宣布任何新数字为获准画质容差。算法报告提出V p95≤.01/max≤.03、RGB p95≤.005/max≤.02，只是新的工程预算建议，既不替代原严格等价线，也不证明视觉可接受。误差证书过松导致fallback覆盖大，是实施后适用性未知，不是现在无法设计。

## 4. 接收域不能由TaiNi材质名称代替

X/Z为床面，Y向上，米制，正常床面0.8米；实际可见几何仍是接收真源。TaiNi包含非床面、库面与袋口过渡，几何modifier之后的接收位置也可能不同。第一场只承接经确认的canonical平面床域，袋口缺面和语义边界保留；不跨高度/边界做双线性过滤。不属于域、球高导致support退化、台下接收、未准备资源均走原公式。

原rail AO的床面高度条件与接触AO另保留。接触AO有无限尾部，不等于direct-shadow有限support；首版继续原公式最容易闭合。若后续加入完整单通道AO场，其依赖、插值误差与更新规则单列；有限截断必须显式分配尾误差。

球心编码、淡出权重、hidden/脱父节点和落袋/回球都进入blockerRevision。仅球自转或相机改变不失效场；相机放大可能请求更细表示，这改变layout/资源而不是几何函数输入。不能把“内容不依赖相机”误写成“任何相机都能用相同精度”。

## 5. 首版full generation优于同时引入稀疏状态管理

完整生成一个容量固定、明确承接域的场；blockerRevision或receiver/rig/layout/algorithm key改变时重算，未改变时复用。不要用每个frameID无条件失效。这个设计已拿到相机运动/球自转时计算复用，又不引入dirty积累、页迁移、复制与过期版本证明。

后续局部更新取旧support∪新support，包含重建halo；每个脏区域从当前完整候选集合重算乘积，不能除掉旧球因子（旧T可为零）。移出/隐藏球必须清旧域。AO不能搭这套有限support免费更新。

算法报告的“稀疏active tiles完整生成、FP16、三内容版本”是一个可研究备选，和runtime/主控“有界域单持久R32场”并不是同一个v1。交叉后算法报告§11已接受共同首版，旧§4布局明确留作后续/备选；实现卡应只冻结前者收口后的共同契约，防止将旧页表与单场正确性证明拼接。三份大场不是传统CPU buffer三缓冲必然导出的要求。

## 6. 单持久场可以成立；值快照不冻结SceneKit

SDK明确 `SCNRenderer.update(atTime:)`与不带time的`render(withViewport:commandBuffer:passDescriptor:)`最低iOS11；后者不更新动画、物理或粒子。一次update后只能调用后者，不能再调用会update的atTime绘制造成双推进。

首版同帧契约是：唯一scene owner消费输入→一次update→动画与约束最终阶段后capture→核对session/generation→固定本次immutable binding selection→compute→SceneKit render→present/commit。整个capture/bind/encode区间不await/reenter、不允许另一owner改scene/material。当前球没有查到constraints赋值，仅有label billboard；仍保留最终阶段采样，避免未来引入约束后静默错帧。旧didApplyAnimations阶段上传不能自动证明新的最终采样点已实现。

`FrameSnapshot`仅冻结值，不冻结SCNNode、SCNMaterial或它们的资源绑定。不能让同一scene同时由SCNView和受控SCNRenderer推进。取消/换局需要generation与content校验，旧完成回调不能改变新资源选择。UI拾取、投影、音频/媒体时钟与当前动作政策必须由受控宿主适配；不要求同时重写物理与全部出口。

一份场可以有多个在途draw：传统MTLCommandQueue上、tracked且直接绑定的GPU资源会自动同步访问冲突，使compute(k)→draw(k)→compute(k+1)→draw(k+1)保持依赖。场仅在GPU写；CPU输入buffer仍使用有限在途slot。这是已查清的API能力，不是“三份atlas才能正确”的未知。官方条件见[Apple Resource synchronization](https://developer.apple.com/documentation/metal/resource-synchronization)，全文已存研究目录 `primary-sources/metal-resource-synchronization.md`。

queue commit次序本身不是完整证明。heap默认untracked、间接绑定、跨queue、Metal4队列不得照搬上述保证。SCN内部若无法确认真实消费访问满足条件，就要在实际consumer访问前设置可覆盖该访问的同步/公开绑定适配，或用受控床面SCNProgram/局部draw；仅在compute端signal event不够。无法建立可靠关系时停用field，保持当前公式。传统single-queue正确性也不证明SceneKit实际已采取指定绑定路径。

CPU slots全部在途时不能覆写或CPU wait。保留当前原公式fallback slot处理常见field失败；连保留slot也忙时跳过该次提交、后续按当前时钟采样，明确可能影响呈现，不能报告这次已绘制。原公式仍需当前buffer，不是无限积压的资源救生口。

## 7. 硬预算与旧新资源峰值

256×128×64的逻辑容量：R32一场8MiB，三场24MiB；R16一场4MiB。512×256×64 R16一场16MiB、两场32MiB、三场48MiB。将64层排成8×8 tiles，每层两边各2texel collar，R32容量为2080×1056×4=8.378906MiB。有效payload不是allocatedSize；guard、certificate、index、输入buffer、旧场与准备中的新场另计。

首版R32、不加mip/时间jitter/FP16，能把近似来源先限定为空间重建。未来FP16在[0,1]内round-to-nearest的最大绝对量化误差为2^-12≈.00024414，不为零，应进入证书；不能用“可忽略”代替误差账。

**预算异议已在交叉后解决：** runtime§9及主控已撤销24MiB field＋1MiB额外inputs草案；算法§11也明确24MiB不是共同首版。首片所有新增GPU资源总峰值沿用≤16MiB admission，input亦计入；单8MiB常驻场留余量，替换旧新同时占用超额时先异步退役，completion后释放再准备新场，等待期间用当前公式；不阻塞UI。不要求同时保留两个满尺寸场。旧算法§4的三版本24MiB连gutter都未包含，只能作为未批准备选，不能覆盖原线。

若决定采用新预算，须显式标注“架构候选，尚未获准替代既有验收”，并对probe、输出attachments、scratch、pipeline/LUT、独立export session和所有retired资源统一计峰值。每session各有上限仍可能同时越过全App上限；需全局admission。export首版保持旧路径，避免新增第二个可变场成为隐含翻倍。

## 8. 64读取与BRDF可能吞掉收益；更强替代并非换引擎

首片保留64方向灯几何、BRDF、E解析校准、support扫描和AO，只删重复blocker检测，增加场读写与同步。64标量可以打包成16次RGBA sample；不能笼统称64次硬件调用。R32每近影片元涉及256 bytes逻辑值，双线性又涉及邻域访问；这是逻辑引用量，不是DRAM流量，纹理缓存/quad复用会改变实际带宽。

完整收益条件至少是：

```text
P_near ×64×b×C_ray
  > N_generated×64×(b_grid×C_ray + C_geometry + C_write)
    + P_near×64×C_read + C_management
```

共有的BRDF等项不能记作节省。相机单独运动N_generated=0；动态开球首版N_generated为整个承接域，不能套静止成本。候选球很少、near可见域小、证书大量invalid/原公式fallback、全域动态、带宽压力，都是可以推翻默认启用的反例。物理triangle估数也不等actual draw，资产优化和shader工作不能混记。

更强替代有两项值得与首片分阶段推进：

- **无遮挡响应S0＋非1样本修正**：代数恒等式S=S0+Σw_j(T_j−1)k_j。保存受影响样本mask，仅对J个样本修正；J最坏64。S0若用LTC/拟合则单列近似误差，不能说修正精确保整个精确。这个路线可能比全64读更有利，但不能假定所有影区J很小。
- **投影完整角传输，再与材质核组合**：先对每样本联合透射投影，片元按n/v/roughness重建。它保留方向关系，比平均visibility强；SH9/16/25只是候选rank，近影/窄高光可能需要高阶。离线核域、旋转、horizon、误差与fallback都必须明确，rank近64时应撤销该压缩。

合法法线锥域的一阶漫反射矩也值得实施，但不能替代所有S。若这些计算域能由SceneKit公开承载表达，结束全量迁移动机；SCNProgram先接一个床面是可行中间路线。只有载体实际限制资源/顺序/着色接口时扩大Metal draw范围，不由“可控”直接推导全引擎迁移。

## 9. 决策分类与交叉回应

**现在值得实施：** 有界bed chart、blocker独立revision、同帧owner/取消代次、single tracked持久R32场、变化时完整生成、cell误差路由、当前公式fallback；第一受限消费端就能形成完整切片，不以新设备实验或全出口重写起手。参数冷准备/probe隔离另按实际输入键推进，收益独立记账。

**已被代码或代数排除：** 每灯均值通用E/S、逐球均值乘积保持重叠、无条件平面接收、无条件一阶矩、near64与far8互换、AO直接按有限support截断、分辨率即exact、三重atlas必需、值快照自动冻结scene、仅commit顺序保证hazard。

**实施后未知并有明确处理：** 证书有效覆盖与允许画质预算；grid/patch实际所需精度；真实SceneKit绑定路径；读带宽与射线节省交叉点；角rank/无遮挡拟合域；GPU毫秒、全页能量、热态持续呈现。失败处理分别是细化/收缩field适用域、受控绑定或停用、选择correction/取消角压缩，不能以模糊“以后测试”代替现在的结构选择。

交叉一轮已收口：算法§10–11采纳cell区间certificate、AO独立与64残余，并将稀疏FP16三场列为后续/备选，接受共同单R32场首版；资产报告明确非平面例外、当前有效捕获输入/最终变换、规范probe与空间误差；runtime§6/§9采纳最终阶段采样、单owner不可重入、per-encode绑定、single tracked场、slot饱和跳过、真实消费访问同步边界及≤16MiB总新增峰值。主控当前方案亦已包含这组选择。剩余未知是实施后的质量覆盖与真实绑定/性能，不存在以同模型共识替代证据的放行。

这是一份附条件的架构实施建议，不是性能赢家认证；不同角色的一致只表示设计反例已被讨论，不能作为能耗证据。
