# 球桌品牌 · H 桌外字标（中央名称已撤回）

**最新决定：2026-11-16 用户认为中央文字不好看，要求拿掉。已删除中央着色、字形资源、显示开关及偏好接线、反射缓存字段和专属测试，恢复干净台呢。桌边／域名／袋口 H 品牌保留。旧偏好值不再读取，不影响画面。TP08／19 的中央名称增补撤回；TP09／16／20 继承原合同。撤回按源码完整性、Swift 语法和工程资源引用核对，不把前轮通过当作撤回后新一轮模拟器测试。**

2026-11-16，北京时间。用户已认可 H 方案并授权应用到 App、同步不同桌款。共用运行时接入完成；五款原生渲染、换肤与 iPad 实际页面验证完成。真机视觉/性能尚未复验。

## 历史：台呢中央字标 B · App 接入（已撤回）

2026-11-16 用户确认接入，设置使用原生「显示名称」开关，默认开启，独立保存 `showsClothName.v1`，重启保持；仅控制台呢中央 CuePhys。桌边、域名及袋口文字沿 H 合同。

- `ClothAppearance` 在原 TaiNi 表面着色前采样已批准字形 alpha，将底色乘以 `1 − alpha × 0.23`；六色共用相同相对压暗，纹理、粗糙度、法线、真实光照保留。无新增浮层几何，不改碰撞。
- 世界坐标 +X 为开球端，文字右向 −Z；采用 UIKit 顶到底 V，对应宽 0.47625m、高 0.10718265m，中心为桌面原点。沿用批准 B 的方向和尺寸。
- 共享 `AngleSceneView` 与 `AppearanceCombinationPreview` 应用同一偏好；主 2D／3D、临时俯视共用 TaiNi 材质。新场景与复用场景在反射抓取前安装字标，反射缓存包含显示状态。
- 局部适配：TP08 按业务调整（中央台呢名称独立于桌外品牌）；TP09、TP20 继承（原生 Toggle、正常行距、可滚动可访问）；TP16 继承（模式切换同状态）；TP19 按业务调整（全局默认开且持久化）；TP35 继承（定向渲染与 UI 验证，不扩大为全页／全量验收）。其他球桌布局与玩法条款不在本次改动范围。
- 最终 R2：Mac mini／Xcode 26.2，iPhone 16 Pro／iOS 26.2，**3 passed／0 failed／0 skipped**。`testClothNamePreferenceDefaultsAndPersists`、`testClothNameRendersAcrossColorsAndCameraModes`、`testClothNameSettingPersistsAndReachesPreviewAndTraining` 全部实际执行。
- 覆盖：六色开／关共12张；主2D与临时俯视副场景材质开／关各2张；五桌款切换、反射缓存键、重复开关无节点增加；真实设置默认开→关→重启仍关→预览隐藏→自由击球及分离角与走位各2D/3D隐藏→重新开→预览显示。UI 5张附件已回传，设置开关与预览开关原图已看，开球端六色正向已逐张核对。
- [测试摘要](../output/cloth-name-app-20261116/r2/evidence/test-summary.json) · [原始 xcresult](../output/cloth-name-app-20261116/r2/evidence/tests.xcresult) · [开关设置](../output/cloth-name-app-20261116/r2/images/cloth-name-setting-default-on.png) · [预览开启](../output/cloth-name-app-20261116/r2/images/cloth-name-preview-on.png) · [六色原图目录](../output/cloth-name-app-20261116/r2/images) · [像素差](../output/cloth-name-app-20261116/r2/pixel-comparison.json)。六色有显著像素差的范围均为中央字形的203×25px边界，约1,987–2,003像素；其余场景没有超过2级的通道差，关闭无矩形底或悬浮几何。
- R1 编译通过但同型号设备占用上限在创建前拒绝，**0用例**，不记为测试通过。R2 改用空闲型号并纳入初次反射前安装与重复更新快路径；测试源码快照 `43566c007a77a83e0012210889b2e1d1de544681b37606aa5b59f019a0a05d32`。运行时代码与当前工作区一致，仅 `ClothAppearance` 类说明注释在快照后更新；生成脚本补齐原字形拷贝，mask SHA256 `85d406a70019e53fc51225c6cdc94cd62a6c9af88987a0cfb218fbfa03639e1d` 与批准原稿逐字节一致。
- 收尾：R1/R2 原始日志、xcresult、快照清单和截图已回传并核对哈希；R2 临时模拟器由生命周期回收，两轮远端 source/build/snapshot 已关闭回收。本地仅删除本任务私有复制工作区和两份可重建快照，清单及测试证据保留。导出附件曾更新本地 xcresult 的 SQLite 缓存，已从远端恢复原件并再次核验后完成收尾。
- 验证边界：本次没有安装用户真机，没有测真机功耗/帧率、iPad新开关布局、iOS17中央名称或完整App回归；临时俯视核对共享材质及离屏副场景，未新增真实UI进入临时俯视流程。仍保留前轮 H 品牌的既有验证，不冒称本轮重测。

**当前候选 B（用户连续修订）**：中央字标旋转 90°，从开球线所在的 +X 端朝 −X 看时正向可读，文字右向为源 +Y、字顶朝 −X；整字宽由 0.3175m 放大 50% 至 0.47625m，居中、原 23% 线性底色压暗与独立开关范围保持。方向依据当前 CameraRig 对开球端的注释及实际模型开球线；开球端相机的屏幕右向/上向与文字基向量点积断言通过，并目视检查正向可读。新一轮八张开关渲染完成，1,036 个字形采样全部落在台呢，原几何和正式资产哈希保持，进程退出 0。用户已授权接入 App；下述运行时实现与验证覆盖本版。

[B 开球端正视](../output/table-branding-center-20261116/rotated-large/breakline-on.png) · [B 整桌](../output/table-branding-center-20261116/rotated-large/overview-on.png) · [B 俯视](../output/table-branding-center-20261116/rotated-large/top-on.png) · [B 可编辑模型](../output/table-branding-center-20261116/rotated-large/Center-candidate.blend) · [B 参数](../output/table-branding-center-20261116/rotated-large/manifest.json)。下述 A 版长轴方向/小字宽仅作历史对照，以 B 为当前看样。

用户同意先看中央淡色 `CuePhys` 的效果对比，并补充要求设置中可关闭。本轮仅制作 Blender 候选与独立开关预览，尚未加入正式 App，也未改正式 USDZ。

- 台面中央、字长沿桌长，宽 0.3175m（有效短边 1.270m 的四分之一），沿用已批准的 CuePhys 字形；在线性台呢底色中按遮罩降低 23%，保留台呢原纹理、法线和粗糙度，不增加凸起文字。
- 三组相同机位的开启/关闭渲染：整桌斜视、俯视参考、近景。三颗原尺寸示意球与一条穿过字标的白线用于视觉干扰检查，不是物理仿真或 App 截图。
- 开关合同：设置名称「台呢中央字标」，关闭只移除中央字标，桌边/袋口标识保留；正式接入时保存偏好。默认值与实际 App 在 2D/3D 中的效果待候选确认后落实，本轮未声称已实现设置。
- Blender 4.5.6 / Cycles / Metal，32 samples；六张 1600×1000 渲染及拼板已目视检查。1,036 个字形采样落在原 TaiNi 面上；球底贴合实测床面；原桌体几何/变换摘要与默认 USDZ 哈希保持。输出 `CENTER_CANDIDATE_COMPLETE`，进程退出 0。仅证明候选制作，不替代 iOS/真机验证。

[开关对比](../output/table-branding-center-20261116/comparison.png) · [近景原图](../output/table-branding-center-20261116/detail-on.png) · [交互开关看样](../output/table-branding-center-20261116/preview.html) · [可编辑模型](../output/table-branding-center-20261116/Center-candidate.blend) · [参数](../output/table-branding-center-20261116/manifest.json) · [渲染脚本与日志](../output/table-branding-center-20261116/render.log)。

## 真机不可见反馈（用户确认已解决）

2026-11-16，用户回复“解决了”，本次反馈关闭，不再执行重装。具体解决方式与根因未提供，不推断为旧包或贴图压缩问题；本轮未安装、未改正式代码，此反馈不替代真机完整视觉/性能验收。

用户反馈刚通过 Xcode 安装后，训练画面和设置整桌预览均无字标，并要求重新安装。当前尚未定位原因，不能归因于训练视角遮挡或旧包。

- 本机 Xcode `Debug-iphoneos/球迹.app` 可执行文件更新于 11-16 11:22:55；构建日志 `1FAD7903-1F4F-4B14-919E-B88EB0462D8F.xcactivitylog` 包含 `TableBranding.swift` 与两份资源，目标为 iPhone 16 Pro。包内 JSON 与 PNG 均存在；[包记录](../output/table-branding-app-20261116/device-reinstall/package-inspection.json)。这些是本机构建证据，尚未证明手机运行的是同一份。
- 真机 PNG 经 Xcode CgBI 压缩，模拟器使用普通 PNG；两份均可在本机 ImageIO 解码。目前没有证据证明压缩差异就是根因，未因此修改材质。
- 排查时 `devicectl` 报告两台已配对实体 iPhone 均 unavailable，当时等待连接后重装；随后用户确认已解决，未执行安装及运行日志核验。

## App 接入（已实现并完成针对性验证）

五桌款共用 `TableBranding`：标准（charcoal）、经典原木（standard）、深胡桃木、象牙白蜡木、樱花粉木纹。位置与文本沿用已批准 H；深色皮革使用浅字，浅色皮革使用深字，装饰条统一深字。字标使用球桌同源漫反射照明，避免细字被镜面反光冲淡。设置页的真实场景预览和各训练入口共用此实现。

从正式默认 USDZ 三角面裁出贴合装饰条/皮革的字标表面，新增 200 个三角形、7 个节点、一个 1024×512 遮罩；两份打包资产共 187,577 字节。正式默认和备用 USDZ 未改；原球桌、碰撞几何、颗星和训练坐标未改。可复算源码见 [`scripts/table-branding/README.md`](../scripts/table-branding/README.md)，独立重建两份资产逐字节一致。

袋口字标命中映射回原六袋口索引，高亮/清除继续走原实现。2D 主场景隐藏字标，临时俯视副场景不复制字标。五风格共享布局，换肤只改变所需字色，不累积节点。

| 局部复核项 | 判定与验证范围 |
|---|---|
| TP02 几何与坐标 | 继承：原 USDZ 和物理常量保持，新增表面位于源模型局部坐标，由既有加载器转换。六袋口最近邻映射用实际世界坐标验证。 |
| TP08 共享样式 | 按用户批准 H 扩展：五桌款同布局、按皮革明暗配字色，已回填现行规范和来源表；原 HUD 样式与按压反馈保持。 |
| TP14 袋口与目标反馈 | 继承：字标命中复用原袋口索引，原高亮/清除材质保持；原生测试检查角色切换。 |
| TP16 视角与 2D | 继承：普通 2D 隐藏、临时俯视排除，返回 3D 恢复；共用场景测试覆盖。 |
| TP19 外观设置 | 按共用需求扩展：五桌款同步字标，设置页真实场景复用同一实现；保存与两处训练页沿用已通过 iPad UI 测试。 |
| TP35 验收 | 原生渲染与交互测试分别留证；真机可读性、GPU/功耗和完整页面矩阵未验，不扩大结论。 |

本次仅改共享 3D 表面装饰，不改变页面合同、布局或业务流程；其余 TP 项不重复整页验收。首轮 iPad 原生测试 2/2 通过，但截图发现 PBR 镜面冲淡袋口文字，已改哑光漫反射。iPad 13 / iOS 26.3.1 第二轮 2/2 通过（运行 `041d8c186a114edc9b961cca2787cf86`），17 张 SceneKit 渲染已导出；五款袋口近景、五款整桌/装饰条拼板及双色袋口已目视检查。字形完整、随桌面透视、无方块背景；高亮清除后的 PNG 与原樱花款袋口 PNG 的 SHA256 一致，恢复正确。此为 App 场景原生渲染，非完整 UI 页面截图。

[五桌款对照](../output/table-branding-app-20261116/r2/five-styles-review.png) · [标准款袋口](../output/table-branding-app-20261116/r2/branding-charcoal-pocket.png) · [双色袋口](../output/table-branding-app-20261116/r2/branding-pocket-both-roles.png) · [本机测试日志](../output/local-test-runs/041d8c186a114edc9b961cca2787cf86/evidence/test-results.log)。本机测试工作目录已由生命周期回收，证据保留。

iOS 17.0 / iPhone SE 3：Mac mini 任务 `table-branding-20261116-ios17-r1` 原生测试 **2/2 通过**，构建/安装/启动成功，五款渲染和设置页选择、重启保存部分完成。两个旧 UI 用例在旧相机入口/训练卡片定位处失败，不能把整组报为通过。已根据当前 FreePlay 共用宿主改为“更多 → 视图”、当前右侧相机按钮与正式页面调试路由；不修改产品行为。修订后的两个 UI 用例已在 iPad 13 / iOS 26.3.1 分别通过，详见下表；iOS 17 完整 UI 未重跑。

远端快照 `ceceab093d1c8812f16ec9c3380e585a088a4d561dece555576d39549ede6a35` 由共享目录前后校验一致的私有副本生成。结果、日志和附件已回传到 [`ios17-r1`](../output/table-branding-app-20261116/ios17-r1)。旧 UI 定位失败诊断结束后，仅回收本任务的失败临时模拟器 `18C94599-D30C-42B0-A94F-6E89C42F36E3`，队列已回收本任务 source/build/snapshot，证据保留；未动其他会话设备或任务。

中间 UI 校正运行：本地 `e81b86ac952746308365b3bcee565351` 在测试执行前主动停止，以一并替换尚存的旧观察菜单；生命周期已回收。远端 R2 上传在入队前撤回（自有 incoming 归档移除，未创建作业），不计为产品测试结果。UI R3 `ce253987f9ca49999d71eb69c49dfa63` 的换肤/保存/两训练入口通过；观察用例在查询 SCNView 内部不可单独访问的子叠层处失败。改为检查公开相机按钮状态并目视截图；R4 测试 runner 因模拟器 Busy 未启动，显式等待 bootstatus 后 R5 复用同一构建补测通过，未修改产品行为。


### 最终验证与证据

| 环境/范围 | 结果 |
|---|---|
| iPad 13 / iOS 26.3.1，`TableBrandingTests` | 2/2：五款与重复切换、六袋口实际坐标索引、同袋双色/清除、主 2D 隐藏和临时副场景排除；17 张原生渲染。 |
| iPhone SE 3 / iOS 17.0，Mac mini | 原生 2/2；五款渲染与设置页选择/重启保存部分完成。旧完整 UI 用例失败原因及未重跑范围如上。 |
| iPad 实际 UI，R3 | `testSelectPersistPreviewAndTrainingPages` 1/1：五款选择、预览、重启保存，进入自由击球及分离角与走位沿用樱花桌款。[日志](../output/local-test-runs/ce253987f9ca49999d71eb69c49dfa63/evidence/test-results.log) |
| iPad 实际 UI，R5 | `testMaterialAimAndObservationViews` 1/1：全局/沿杆/第一人称、临时俯视进入退出、2D/3D 返回，选择状态保持。[日志](../output/table-branding-app-20261116/ui-r5/test-results.log) |
| 资产复算与门禁 | 正式两份 USDZ 哈希保持；字标 JSON/PNG 从源独立复算逐字节一致；相关 diff 空白检查、文档体积门禁通过。 |

[实际沿杆视角](../output/table-branding-app-20261116/ui-r3/material-observe-along-cue.png) · [训练页樱花桌款](../output/table-branding-app-20261116/ui-r3/shotSimulation-pink.png) · [临时俯视](../output/table-branding-app-20261116/ui-r5/material-temporary-topdown.png) · [正式 2D](../output/table-branding-app-20261116/ui-r5/material-topdown.png) · [返回 3D](../output/table-branding-app-20261116/ui-r5/material-return-3d.png)。上述实际 UI 图片已查看。字标位于真实外侧面；近距离沿杆/第一人称镜头可能裁掉外侧面，不能把共享接入表述为每个视角均可读。

本轮没有修改用户真机安装，没有测真机 GPU/功耗，也没有跑完整 App 回归。Blender H 获用户批准不等于 App 新渲染已获用户视觉验收。本地构建工作目录在补测结束后通过生命周期关闭回收，日志和 xcresult 保留；远端资源已按任务关闭。

## 已批准方案 H：长边分段与半角冒号

根据[用户新批注](../output/table-branding-20261116/user-h-feedback.png)，红框长边左段改回 `CuePhys: 台球训练`，同一长边中袋右段保留 `www.cuephys.com`。另一长边按从外侧面对球桌时相同的左品牌、右域名排列；两短边仍为品牌文字。四处中英文字标统一半角冒号 `:` 加一个普通空格；字高、垂直位置、六袋口沿用前版。

[整桌](../output/table-branding-20261116/H-low.png)、[红框段近景](../output/table-branding-20261116/H-long-brand.png)、[短边标点近景](../output/table-branding-20261116/H-side.png)、[反向整桌](../output/table-branding-20261116/H-reverse.png)四张新渲染已目视检查。10,026 个表面采样通过；[独立读回](../output/table-branding-20261116/H-verification.json)确认原桌体几何、正式 USDZ 哈希保持，12 个字标区域启用，贴图打包。[可编辑 H 模型](../output/table-branding-20261116/H-candidate.blend) · [参数与采样](../output/table-branding-20261116/H-manifest.json)。以上为 H 批准前的 Blender 证据；App 接入以本文上方最新记录为准。

## 历史方案 G：域名加 www

用户明确要求加上 www，四段长边统一改为 `www.cuephys.com`，保持 F 的字高与居中位置、按原比例自然加宽至约 0.318m。短边和袋口沿用 F 参数。本次重新渲染[长边近景](../output/table-branding-20261116/G-long.png)与[整桌低机位](../output/table-branding-20261116/G-low.png)，两图已目视检查，域名完整、留边充足。

[可编辑 G 模型](../output/table-branding-20261116/G-candidate.blend)已打包；[10,640 点采样](../output/table-branding-20261116/G-manifest.json)全部通过，[独立读回](../output/table-branding-20261116/G-verification.json)确认源几何与正式 USDZ 哈希不变。仅离线看样，未接 App，未修改 DNS 或网站。F 的其余近景作为前版对照，不冒充 G 新渲染。

## 历史方案 F：域名与留白调整

按用户[四处批注](../output/table-branding-20261116/user-f-feedback.png)制作。产品域名取自 `LAUNCH-READINESS-20261109.md` 已购域名记录：`cuephys.com`；本轮仅绘制域名字标，不涉及网站部署或可访问性判断。

- 四段长边装饰条改为 `cuephys.com`；两短边保留单行“CuePhys：台球训练”。装饰条文字中心由 Z=-0.065m 下移至 -0.068m，保持高度 0.034m。
- 四角袋 CuePhys 宽度由 0.062m 增至 0.072m（约 16%），中心由 Z=-0.064m 上移至 -0.060m。
- 两中袋宽度保持 0.060m，中心同样上移至 Z=-0.060m。

角袋放大后覆盖更多原有弧面，原 0.78 法向门限会裁掉极少边缘采样；针对角袋改为 0.72，材质与最前方表面限制保持。最终 9,364 个字形采样全部命中目标材质；角袋最低法向点积约 0.760，文字完整、未碰缝线。7 张 F 渲染和四视图拼板已目视检查。独立读回确认源桌体顶点/面/变换不变、12 个区域启用、旧字标关闭、贴图全部打包；正式默认 USDZ 哈希不变。此为离线采样与看样验证，尚未接入 App。

[当前四视图](../output/table-branding-20261116/F-review.png) · [整桌低机位](../output/table-branding-20261116/F-low.png) · [F 可编辑模型](../output/table-branding-20261116/F-candidate.blend) · [参数与采样](../output/table-branding-20261116/F-manifest.json) · [读回验证](../output/table-branding-20261116/F-verification.json)。本轮沿用 E 灯光与机位，并增加长边域名近景；旧版浅色款/俯视证据不计入 F。

## 历史方案 E：按用户红线移位

用户在 D 拼板标出准确位置：[原始红线图](../output/table-branding-20261116/user-redline.png)。单行“CuePhys：台球训练”移至黑色台边下方浅金色装饰条；“CuePhys”移至六袋口缝线下方、朝外的弧形皮革。D 的下方桌身大字、袋口水平上沿小字均关闭。

模型实测装饰条材质为 `WeiBian`，其主要竖直面位于源 Z=-0.05～-0.085m。E 的中英文高 0.034m、保持字形比例，位于 Z=-0.065m；两短边和四段长边各一处。六袋口英文保持约 0.06m 宽，移至 Z=-0.064m 的外侧皮革。正面投影跟随原曲面，无新增凸起或几何变形；装饰条原花纹保留。

脚本对原完整桌体做向内射线，检查字形采样命中的最前方表面：6 条装饰条每条 872 点、6 袋口每袋 666 点，共 9,228 点全部命中各自 `WeiBian` / `Leather` 面并满足法向条件。属于离线采样，不能替代 App 材质、袋口高亮或性能验证。

制作与证据入口：[E 参数与采样](../output/table-branding-20261116/E-manifest.json)、[E 渲染日志](../output/table-branding-20261116/E-render.log)。本轮沿 D 相机、深色桌款和灯光继续；D 的浅色/俯视证据仅归属于 D，不能算作 E 的验证。

E 已完成 6 张同机位渲染及拼板目视检查；独立读回确认源桌体顶点/面/变换不变、12 个新区域启用、旧区域关闭、贴图全部打包，正式 USDZ 哈希不变。[E 四视图](../output/table-branding-20261116/E-review.png) · [E 可编辑模型](../output/table-branding-20261116/E-candidate.blend) · [读回验证](../output/table-branding-20261116/E-verification.json)。尚未接入 App。

以下 D 记录保留为上一版历史。

## 本轮决定与范围

用户先要求参考两张实拍、ShootersPool 和现有模型分析，随后授权做样。在制作中进一步提出：去掉 Q 图形，使用单行“CuePhys：台球训练”，袋口只放“CuePhys”。本轮将其落实为两个短边桌身外侧单行字标，以及六袋口皮革上沿英文小字。原 A/B/C 中的库边字、Q 图形和两行排版在 D 中均关闭。是否采用、具体大小和首发时间仍待看样反馈。

这取代 v65 W14 中仅外侧英文的早期看样建议，不更改 App 名称或现有品牌资产，不产生 14/15/16/18 项目改稿。

## 预览与可编辑文件

- [四视图预览](../output/table-branding-20261116/D-review.png)：整桌低机位、桌身、角袋、中袋。
- [高位整桌](../output/table-branding-20261116/D-overview.png)、[反方向](../output/table-branding-20261116/D-reverse.png)。
- [浅色桌身](../output/table-branding-20261116/D-ivory-side.png)、[浅色款袋口](../output/table-branding-20261116/D-ivory-pocket.png)。
- [俯视隐藏示意](../output/table-branding-20261116/D-topdown-hidden.png)：Blender 内关闭字标，仅预览原先“限 3D”的要求；不是 App 切换验证。
- 可编辑、贴图已打包：[深色 D](../output/table-branding-20261116/D-candidate.blend)、[浅色 D](../output/table-branding-20261116/D-ivory-candidate.blend)。

## 来源、制作与验证

实际加载路由是 `ModelAssetTrial.enabled=true`，默认资产为 `QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz`，SHA256 `73e43df002f07637656b767fdc105033d10f0d764f6d91aa7a5276cf1c885fb6`。上一轮分析读取的普通 `TaiQiuZhuo.usdz` 是备用资产，本轮已纠正并使用默认版本。

Blender 4.5.6 LTS；源米制坐标 X 沿桌长、Y 沿桌宽、Z 向上，实测床面 Z=-0.042m。保留桌体网格及原始变换；三颗无编号球仅作为各视图共同的摆球背景，球底与该床面一致。采用实际 TableWood_charcoal / TableWood_ivory 贴图、离线统一灯光，Cycles 32 samples、1600×1000、AgX、曝光 -0.65；此灯光和材质响应未与 SceneKit 做同态匹配。

字形由 AppKit 原生字体绘制透明遮罩，材质以几何位置投影混合底色，保留原表面法线与粗糙度。桌身投影宽 0.76m、中心 Z=-0.255m；角袋英文宽 0.062m，中袋宽 0.060m。袋口颜色分别与浅、深皮革对照。没有增加凸起文字或改碰撞几何。这是 Blender 候选节点实现，后续不能假定其自动导出后会被 SceneKit 等价支持。

实际验证：

- D 主流程与补充流程分别输出 `D_COMPLETE`、`EXTRA_COMPLETE`，9 张正式 D 渲染均已目视检查；预览拼板已检查。
- 六袋口分别对 453 个字形采样点进行向下射线检查，全部落在皮革上沿，满足 Z>-0.004m、法线 Z>0.85；这是离线采样，不是连续像素/运行时测试。
- 独立重新打开两份 D 文件，源桌体 Plane_001 / Plane_007 的顶点、面索引和世界矩阵与重新导入的默认 USDZ 一致；8 个新品牌区域启用，旧 Q/库边方案均关闭，文件图像已打包。
- 默认与备用正式 USDZ 的 SHA256 保持原值，未写入 App 源码或正式资产。
- [验证结果](../output/table-branding-20261116/verification.json)、[投影参数](../output/table-branding-20261116/D-manifest.json)、[主渲染日志](../output/table-branding-20261116/D-render.log)、[补充日志](../output/table-branding-20261116/extra.log)、[独立读回日志](../output/table-branding-20261116/verify.log)。

## 早期 D 视觉判断（历史记录）

低机位能读出桌身完整文字，近景的六袋口小字留边足够；高位整桌下，桌身字被台边遮挡，袋口字较小。这是当前桌体与视角的真实限制，不能当作所有训练画面中都能清晰辨认品牌。

下一步按用户看样反馈调整字重、尺寸和位置。正式接入需另走运行时材质覆盖、换肤、袋口高亮/清除、3D/临时俯视和真实手机可读性验证。尚未导出集成 USDZ、运行 App 或验证真机性能。
