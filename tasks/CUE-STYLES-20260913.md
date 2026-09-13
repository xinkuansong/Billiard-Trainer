# 十款球杆外观 — 2026-09-13

## 范围与修正

- 用户要求：Blender贴图、App可选；小头杆/大头杆各五款，前节和后把一起考虑。
- 硬约束：保留原球杆尺寸、顶点位置、姿态、物理参数。分类只表示外观。
- 用户要求查看真实球杆；此前错误地将其理解成否决原主题，改成纯木材、插花、握把、环饰组合。本轮按用户确认恢复原主题与实物分区的结合。先前改尺寸模型已移至 `output/cue-stickers/discarded-size-variants/`，旧贴图实验留在 `rejected-theme-wraps/`，不打包。
- 实物依据：Peradon Edwardian / Royal（白蜡木、乌木、黄铜先角）；Predator Roadline LE TS16（枫木、插花、皮握把、尾套）。品牌照片仅参考结构，没有复制商标或产品纹样。
- 原图来源：https://www.swissbillardshop.ch/de/peradon-12-verschraubte-queues/116-peradon-edwardian.html ，https://www.omegabilliards.com/Predator-Cue-Roadline-LE-TS16-Maple-p/4561.htm 。浏览器原图加载超时，搜索图片/商品资料已查；不能把未加载原图细节冒充已看清。

- 追加要求：五款小头杆剑纹加密、颜色加深；主纹频率从8.8增至15.4（约1.75倍），保留深浅细纹，待新近景复核。

## 十款

小头杆：墨龙、青花、山水、黑金几何、复古台球。
大头杆：浪潮、星轨、赛车条纹、锦鲤、赛博电路。
内部ID保留，展示名恢复原主题。原款仍为默认，可恢复。

## 资产与消费契约

- 真源：`QiuJi/Resources/TaiQiuZhuo.usdz` SHA256 `617bcf941e3a153965de63fff27150b1c02504a433da12a8a587c902636c851b`。
- 源 `QiuGan/Plane_025` 在Blender中轴向+Y指向皮头，米制；本次UV的V由后把到皮头，U绕圆周，UV不参与坐标变换。
- `scripts/blender/cue_finish_patterns.py` 在Blender内生成线性颜色的程序木纹/插花/握把，`build_cue_styles.py` 使用EMIT烘焙512×4096底色与独立粗糙度图，并用原尺寸网格渲染预览与近景。
- `CueUV.usdz`仅替换原网格UV，原顶点/面索引逐项断言相同；导出纯中性材质并保留消费端名称。运行时沿用原节点变换；样式材质独立复制，原材质及皮头保持，按实际材质识别唯一网格，避免Blender容器名称与网格名称混淆。
- `CueStick.applyStyle`仅切换材质/UV几何，回原款恢复从未修改过的原SCNGeometry及材质对象。`UserPreferences.cueStyle`本地保存，Settings独立选择页，共享AngleSceneView刷新。
- 桌面Blender预览和iOS实渲分开保留，前者不代表训练页面最终光照效果。

## 验证状态

- Blender10套烘焙完成；manifest记录每套6824顶点/6785面、位置与拓扑不变，源USDZ哈希不变。
- 初次App测试发现导出节点嵌套导致换肤失败，保留 `failed-container-binding-test.log`；修复后位置/姿态/分类保存三测通过。初版实渲光照过曝，不能因图片哈希不同判定贴图有效；已增加中心杆身颜色检查，移除与新UV不兼容的旧法线图并校准独立渲染夹具光源。
- 加密剑纹版三项定向测试本轮通过（`final-unit-test-results.log`，3/0），实际iOS渲染已查看，木纹/蓝色握把分区/碳黑前节可见；材质隔离加强后的最终三测也通过，原材质底色/法线保持不变。
- 并行球贴纸测试类型推导、球桌袋口接口两次中途编译失败已记录，相关任务随后修复，未改动其实现。
- `verify-gate` FAIL0、文档体积通过；`make build`首次缺xcpretty未成功，随后直接xcodebuild构建通过。
- 最终 `final-build-and-tests.log` 同时包含 BUILD SUCCEEDED / TEST SUCCEEDED：3项单测 + 2项UI，共5项0失败。UI覆盖十款选择、重启保存、浅深页面以及自由击球2D/3D、击球/回放/重打；最终截图已逐项查看。
- 首轮UI在最后一张部分露出的卡片点击后未选中；测试改成滚至完整卡片、等待实际已选择状态，保留 `ui-partial-card-failure.log`，复测通过。
- 预览：`output/cue-stickers/catalog.png`；App真实渲染：`app-renders/`；页面：`ui/light-top.png`、`ui/persisted-circuit.png`、`ui/freeplay-3d-inkDragon.png`。
- 本地实现与本轮模拟器验证完成；真机/iPad/旧Runtime/能耗未验，视觉最终喜好待用户反馈，未提交或发布。


## 追加：小头剑纹加宽、加深

- 用户要求仅五款小头杆的剑纹再宽、再深；数量/走向保持，phase仍为15.4。主纹宽度0.06→0.10、细层0.045→0.07，主/次暗纹权重0.79/0.36→0.92/0.48，仅small分支。
- Blender --small-only重烘焙五款底色、整杆和后把预览；原版及前节近景保存在 `output/cue-stickers/wider-darker/`。新版前节与上一版已并排目视，主纹更宽、更深。
- 哈希检查仅15张预期PNG变化；五款大头杆全部资源、粗糙度图、源USDZ及共享CueUV.usdz逐字节不变。证据 `wider-darker/verification.json`。
- 本轮为贴图外观微调，未修改Swift或物理，未重复App构建/UI测试；上一轮5项测试属于调整前版本。新图已回写App资源与预览，总览同步重渲染。

## 追加：恢复原十款主题图案

- 用户指出原图案没有实际使用；核查确认程序木纹生成器没有读取原图案。此前文档“用户否决主题”是错误解读，现已更正。
- `cue_theme_art.py` 在Blender内读取十张原始主题albedo，在线性颜色空间合成到装饰区，再EMIT烘焙进入App资源；manifest逐款记录输入文件与SHA256。
- 小头杆后把主体+四尖镶饰、大头杆前臂+尾套；圆周双面重复使主要图形两侧可见。小头杆前节加密/加宽/加深剑纹、握把粗糙度及源/共享网格保持。
- 十套Blender近景已审；修正byte-backed PNG像素为sRGB、需显式解码后混合的色彩问题，最终版深色与饱和度正确还原。
- `verification.json`确认十套原图输入哈希匹配、装饰像素发生变化、前节像素逐项相同；十张粗糙度及源/共享USDZ逐字节不变。
- 最终颜色版 `theme-integration/app-final-tests.log`：BUILD SUCCEEDED / TEST SUCCEEDED，3单测+2UI共5项零失败；十款选择、重启保存、浅深设置、自由击球/回放/重打通过，页面截图已审。静态门禁、文档体积及diff检查通过。
- 原图案已实际进入App；24MB资源含底色、粗糙度、预览与共享网格。用户视觉反馈/真机验收独立，未提交或发布。总览`catalog.png`、主题近景`theme-details.png`。
