# S267 → App 迁移（进行中）

用户在 S269 后选择保留 2×0.5m 宽双灯、适当环境补光；明确接受推荐 S267（环境侧向项 1.2、原灯功率、无地面）为固定目标。2026-09-12 要求做到 App 与 Blender 相近；不是再次调 Blender 的授权目标。

## 当前实现

- 新增 `QiuJi/Core/Scene/MobileReferenceLighting.swift`，Debug 参数 `-v62.s267Lighting` 开启，默认未启用；`AngleTrainingScene` 的 mobile setup / enhanceBallMaterials 有两个接入点。
- 球体：矩形光源 Lambert 积分、Fresnel 反射、有限球桌反射；环境与台面反弹以数值积分拟合曲线近似。未改球号纹理、网格、球位或物理。不是完整 Cycles/GGX 路径追踪等价。
- 台呢：保留原纹理/原绿色，自算矩形直接光/遮挡软影及镜面项；环境 GGX 近似固定 roughness 0.8 曲线。材质乘色先作用于底色，再叠中性反射，最后将 multiply 归一，避免重复染色。
- 运行时借用现有 MobileContactOcclusion 的动态球组坐标；不是烘焙固定球影。远离投影用每灯 2×2 点，投影附近每灯8×4点。
- 木头等仍原生面积光，15000强度为当前迁移诊断值；不能视为 Blender 能量单位直接换算。尚需完整材质匹配及性能验证。
- 环境 RGBE 512×256 在内存生成；S288 UIImage 与原型 URL 读入的入口截图逐像素一致。

## 已验证证据

- S275 建立独立球两端对照，初轮脚本断开环境后查节点 StopIteration、初始 Blender 相机上下倒置已修；失败日志保留。Lambert 改 PBR 后用于原生对照，不能用初始图作结论。
- S279 自算积分灰球与 Blender 直接光四处 RGB 相差约1–2级；S280 真实球模型直接光对拍相近。只证明这个分量，不能据此声称整体相同。
- S277–278 引入台面反弹并以16384方向采样拟合环境曲线；粗采样条带移除。S284修正反射接近平行方向时 fwidth 放大引发的亮边。
- S281恒定材质导致台呢材质通道缺失，S282改PBR通道取样、自算结果送emission；metalness=1+黑底色仅用于消除内建BRDF重复贡献，不代表把台呢改成金属。
- S285环境镜面贡献；S286正确处理multiply顺序，对照点RGB从28,121,20到40,123,34，目标41,120,35。不是全图逐像素等价。
- S287降采样相对S286全图RGB均值差0.2003，P99=1，最大5。不是性能证明。
- S288封装后入口截图与S287逐像素一致，入口/近景/转角3图测试通过、原图已看。近景球面仍有反射边界/阴影近似差异，尚未完成多视角Blender对照。
- 所有本段通过指 XCTest 执行及相关断言通过；视觉与性能有独立边界。

## 当前设备与下一步

S289真机测试未运行成功：`Unable to find a destination`；设备由 connected 变为 unavailable。已通过异步问题请用户重新连接并解锁，不能继续沿用此前connected声明。S290 iOS17三视角测试进行中。

待完成：多视角 Blender 对照、其他球色与动态摆球/透明度/恢复、真实训练页、iOS17和真机、GPU/CPU/实际呈现帧与20分钟热稳态、内存。未达到全任务完成或60fps验收，不开启默认候选。保留所有output/日志和原USDZ。

## S291–S298 真机与实际页面（2026-09-12）

- S291：iPhone 16 Pro 的 SCNRenderer 三视角截图已取回，与 S288 模拟器入口平均通道误差约0.016，细节/转角约0.009；这是设备离屏截图，不是训练页性能验收。
- S292：1206×2622、4×MSAA、移动相机、两球 MTKView 25秒，去掉前180帧后1263有效呈现帧；59.9899fps，间隔P99约16.6695ms，无>25ms间隔。CPU P95 2.467ms，GPU P95 15.348ms / P99 15.543ms，thermal nominal→nominal。GPU未满足12ms预算，短测不替代20分钟热稳态或完整训练UI。
- S293：16球版本设备测试执行通过，但取数据时连接失效，尚无可读取指标，不能声称16球60fps通过。JSON仍待从设备App容器tmp/render-quality-v62/presented-frames.json取回；以后报告已增加XCTest保留附件。
- S294：实际页设备测试因destination unavailable未启动。用户两次反馈恢复后复查，CoreDevice仍unavailable、xctrace仍Offline；不是用户操作结论，只是工具当前状态。
- S295：模拟器编译失败来自设备专用addPresentedHandler在模拟器SDK不可用；S297增加编译平台隔离后实际页测试1项0失败，覆盖辅助、旋转缩放、答题/下一题。页面与手势图已审，新光照生效，木沿反射/辅助线仍待整体验收。
- S290近景对照发现只迁移相机矩阵，漏迁移缩放后的FOV，因此旧近景/转角对比图无效；S298已重新输出矩阵+FOV+投影轴，测试1项0失败，按垂直40度修正Blender对照正在渲染。
- S296-review/index.html展示S267、S274、S291设备渲染三列及原像素球裁切。默认Debug候选仍关闭，原资源未替换，目标未完成。

### S293 数据取回与限制

03:05 CoreDevice重新connected，成功取回16球报告（S293-presented-frames.json，统计S293-summary.json）。有效3270帧约54.5秒，平均59.9899fps，间隔P99 16.6697ms、>25ms为0；GPU P95 15.5256ms / P99 15.6386ms / max20.0966ms，thermal 0→1（nominal→fair）。CPU计时覆盖render调用及可能的提交等待，P95 16.58ms，不能当作纯CPU运算耗时。测试原意25次1秒sleep，但实际呈现区间更长，以帧时间戳为准；未达到12ms GPU预算或20分钟验收。S299真实页面设备测试开始。

### S298–S301 后续

S298两张Blender 512采样图完成，相同FOV/矩阵的近景和转角、原像素白球已审：主体明暗接近，顶部反射细线缺失、阴影扩散和木沿仍不一致。S299/S300设备UI均运行器在建立连接前exit74，测试未进入页面；保留xcresult，不改产品导航或放宽断言。S301正在验证以现有nearShadow保守范围跳过无关遮挡计算的优化，尚未确认性能收益。

S301三视角执行1项0失败；对S298近景/转角仅4/11个通道相差1级，入口均值差0.00716、最大48，>2级的差异定位于画面最下方右侧边条（x738–1175,y1945–1999），不在球/台面，不能称全图像素相同。原像素差异区域已审。S302在连接恢复后重测16球性能，待数据。

S302设备短测在进入test后超过2分钟未结束，03:10主动中断（exit130）；测试期间设备保持connected，不能归因为掉线，也不能据此归因于优化。提前复制的JSON SHA与S293完全相同，已改名S302-stale-S293-copy.json防误用。nearShadow遮挡跳过优化已撤回，未宣称收益。S303按用户最新重试请求，在已connected设备上再次启动实际UI测试。

S303最终仍是UI运行器建立连接前exit74；同时CoreDevice connected，不能说手机离线或页面断言失败。03:12通过devicectl process launch --terminate-existing com.xinkuan.qiuji -- -v62.s267Lighting成功直接启动真机App，供用户进入3D角度训练查看（未启用身份/会员/摆球fixture）。仅本次进程显式候选，正常重启默认仍旧路径。实际UI截图/长时性能/整体视觉验收仍未完成。

## S304 分离角与走位试打接入

用户明确要求将同一候选应用到可击球的「分离角与走位」。PositionPlayViewModel.setupScene新增默认false的mobileRendering参数，仅ShotSimulationView传MobileReferenceLighting.requested；其他共享消费者沿用原默认。沿用实时contactOcclusion更新、球号与物理，未改击球/回放逻辑。Debug本次启动参数仍为-v62.s267Lighting。

模拟器testReferenceShotSimulationPlayback通过（1项0失败）：进入3D、击球、等待结束、回放、重打；before-shot/after-shot/reset-shot三张1206×2622截图已审，球位/阴影更新和复位可见。真机Debug构建/安装进行中；不将模拟器流程或安装视为该页60fps验收。

S304真机Debug BUILD SUCCEEDED，03:18 devicectl安装成功并以-v62.s267Lighting启动成功。用户进入「打→分离角与走位」，点2D切为3D即可试打；仍仅本次进程候选，未默认发布。

## S305–S307 用户灰雾/球壳/2D反馈修正（进行中）

S305分项隔离测试1项0失败，近景原像素已审：关闭环境/台面镜面反射后球面椭圆壳分界消失；关闭台呢镜面后色彩更实但过哑。不是把所有反射关闭后直接交付。

候选修正：drawsArea=false隐藏灯本体；球面使用64个GGX半向量样本、roughness0.12，包含Fresnel/Smith权重，替代单方向环境/台面反射；灯板也走同一反射积分。台呢镜面输出缩放0.35为本轮视觉候选，原绿色底色不改；不是与固定S267逐像素匹配结论。原照度积分/环境强度保持。S306三视角1项0失败、近景原像素对照显示椭圆边界明显柔化，仍待彩球及真机完整验收。新增采样成本未验证，不能延用S293性能结论。

仅在ReferenceLighting开关下跳过旧MobileTableRendering木材flatten/纹理替换，保留源模型木纹响应。S307实际分离角页补拍初始2D以及3D击球/回放/重打测试进行中；设备目前unavailable，已请求连接安装。原USDZ不改。

S307 2D/3D实际页面及击球/回放/重打1项0失败，图片确认灯板消失、源木纹恢复（仍有明显亮纹）。S308花球iOS17测试通过，但roughness0.12仍有上下分层；S309粗糙度0.24花球iOS17测试1项0失败，原像素对照边界进一步柔和，同时高光更软，保留为当前候选，未宣称完美或60fps。S310当前0.24版本实际页击球/回放/重打1项0失败，3D图已审。评审页S310-response-review/index.html；手机仍unavailable，尚未安装。新GGX采样64次只作用球面但成本未测。

03:40用户反馈手机在线后，CoreDevice connected已确认；S310 Debug修正版本安装成功，以-v62.s267Lighting直接启动成功。可进入分离角与走位试打，本次启动候选有效；本次仅安装启动，不代表新增GGX采样真机性能验收。

## S311 原木纹粗糙度对照

用户同意轻/中两档试验。测试从TableModelLoader独立材质副本取原Wood/BlackWood，保留底色/纹理/法线；仅surface粗糙度加0.08/0.16并clamp。原版/轻档/中档入口和斜视共6图，testReferenceWoodRoughness 1项0失败；全图与原像素桌沿裁切已审。结果：亮区变宽，木边灰感增加，中档明显；不采用，不改生产材质、不安装手机。评审页S311-wood-roughness/index.html。整体v62及真机性能未完成。

## S312–S314 木材镜面强度试验

用户同意只减反光强度。S312修改_surface.specular.rgb为65%/35%，入口与斜视各档逐像素相同，确认此路径未生效，不以测试通过冒充效果。S313在fragment从_output.color中减去(1-strength)*_lightingContribution.specular并下限0，实际图像有响应；原木纹/底色/粗糙度/法线均保留。三档两视角6图测试1项0失败，全图及原像素桌沿已审：35%候选较好，反光明显收敛，未像粗糙度试验拓宽灰亮区域。仅测试文件，未接生产/未安装手机。评审S313-wood-contribution/index.html；S314相同路径iOS17复验进行中。不能认为全部浅色木纹均为反光，也未证明真机性能。

S314 iOS17测试1项0失败；建议35%档入口/斜视两图与iOS26逐像素相同。其他档入口均值差0.00715/max48（此前底缘差异同量级，未据此声称全档等价），斜视最大1。候选保留，手机不变。

## S315 自由击球试打接入

按用户要求，FreePlayView标准入口传mobileRendering: !isDailyClearance && MobileReferenceLighting.requested；同页每日清台入口不变。使用当前S310灯光/球面/台呢候选，S313木材反光35%仍仅实验未随本次接入。物理、规则、击球/回放逻辑不改。实际自由击球UI流程验证进行中，随后真机构建安装。

S315实际自由击球UI测试1项0失败，3D截图已审；真机Debug构建成功，04:04安装成功，04:05以-v62.s267Lighting启动成功。本次启动候选有效，用户可进自由击球切3D试打；不是新路径真机60fps验收。


## 真机桌面启动预览（2026-09-12）

用户要求将当前灯光应用到真机。MobileReferenceLighting.requested在真机Debug默认开启，可用-v62.legacyRendering回到旧路径；模拟器仍需显式参数，Release仍关闭。保留S310球面/台呢/灯光组合，不混入未采用的S313木框35%实验。消除从桌面重启丢失启动参数而回到旧灯光的问题。

make -f output/device-lighting-preview/Makefile device-preview：BUILD SUCCEEDED；产物build/DeviceLightingPreview/Build/Products/Debug-iphoneos/球迹.app。安装尝试报CoreDeviceError 1011，iPhone16Pro仍unavailable，USB枚举未见iPhone。用户反馈连接后已再次验证；待连接恢复安装并无参数启动，不声称本次已安装或真机视觉/性能已验。证据output/device-lighting-preview/。


### 真机连接恢复，安装完成

2026-09-12 13:03，CoreDevice显示iPhone16Pro connected。上轮已构建的默认灯光Debug包安装成功，随后不带灯光启动参数启动成功。证据output/device-lighting-preview/install-connected.json与launch-default.json。用户可从桌面重开并进入自由击球3D体验；此证据只证明安装和启动，不替代真机视觉/性能验收。


## S316–S319 木边与球面分项收敛（2026-09-12）

用户确认台呢与球影满意，本轮锁定。S316四项球面分量对照测试通过：移除环境镜面、F0 0.04→0.02效果有限，粗糙度0.24→0.12反而强化分界。S317球面间接漫反射×2、直接漫反射×0.75对照通过：下半球变亮但过平，不采用。这些是定位实验，不能宣称球膜感解决。

将S313/S314已检查的木材镜面贡献35%接入MobileTableRendering的reference分支；保留源Wood/BlackWood纹理、法线、粗糙度，避免提高粗糙度扩散灰光。属于预览材质贡献调整，不是物理IOR标定。MobileReferenceLighting.swift与S316 baseline逐字节一致；MobileContactOcclusion类逐字节一致，证据S319-material-review/preservation.txt。

S318 iOS17球面诊断测试通过；该测试显式调用reference照明但未设置requested开关，因此不能单独作为木材集成证据。木材接入由S319实际自由击球UI带-v62.s267Lighting验证。球面保持现状，仍需继续校准间接照明与反射之间的关系；新路径真机60fps仍未验收。

S319实际自由击球击球/回放/重打1项0失败，1206×2622截图及原像素木边前后裁切已审：大片发白减轻，残留灰色反射未消失。真机构建BUILD SUCCEEDED、安装成功、无参数启动成功，可从桌面进入体验。球面未采用S316/S317实验；不声称两项视觉问题或真机60fps完成。git diff --check、verify-doc-size通过。


## S320–S321 哑光木边（2026-09-12）

用户批准哑光木材试验。S320复用原木材副本对照，将镜面贡献从35%降到0；iOS17测试通过，入口/转角原像素裁切已审。入口大片灰白消失，源贴图浅色纹理保留；转角本来反射少，变化小。仅将此fragment扣除镜面贡献方案接入reference预览；没有替换USDZ、木纹、法线或粗糙度。MobileReferenceLighting文件SHA256未变、MobileContactOcclusion类逐字节未变，台呢/球面/球影锁定。S321实际自由击球回归与真机安装进行中。此版为哑光诊断预览，真实木漆响应和60fps未验收。

S321实际自由击球击球/回放/重打1项0失败，原像素近侧木边前后裁切及全图已审。近侧灰白覆盖消失，但远侧低角度仍偏浅；扣除_lightingContribution.specular不能据此宣称所有反射路径全关闭，剩余环境贡献/底色待分离。真机构建通过、安装成功。未重新验收真机60fps。


## S322 球面全哑光/半哑光分项对照

用户批准三组试验。新增testBallMatteComparison，仅将球shader最终spec输出乘1/0.35/0，保留原漫反射及其Fresnel能量项，不将其称作完整物理材质重建。白球/花球共6张1176×2000截图，iOS17测试1项0失败、原像素裁切已审；全哑光消除花球灯条高光，但底部发闷与白球顶部亮仍在。半哑光改善有限，两者均不接生产。

MobileReferenceLighting与MobileTableRendering SHA256未变；台呢ROI和球下方阴影ROI三组像素最大差0，见S322-matte-balls/pixel-checks.txt。手机保留S321哑光木边，球面不改、未重装。球膜感仍未解决，后续检查漫反射上下分布与间接光近似，保持台呢/球影锁定。没有真机性能新结论。
