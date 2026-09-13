# 球桌风格 — 2026-09-13

## 用户裁定与范围

保留标准，新增深胡桃木、炭黑木纹、象牙白蜡木、樱花粉木纹。最终参考为 output/imagegen/table-wood-styles-20260913/recommended-four-comparison-pink.png。
球桌外观与球房风格独立。本次改变 Wood / BlackWood / MG_Gold 的木质饰面；绿色台呢、袋口皮革、球、杆、金属装饰、模型几何和物理不变。

## 实现

- Blender 4.5.6：scripts/blender/build_table_styles.py 从原木纹制作四份1024平方底色贴图；作者文件和manifest位于 output/table-styles-20260913。原USDZ SHA-256 为617bcf941e3a153965de63fff27150b1c02504a433da12a8a587c902636c851b。
- TableAppearance按场景记录灯光处理后的标准材质槽，以副本替换目标材质，切回标准恢复原实例；不修改加载器缓存。
- UserPreferences.tableStyle 使用 tableStyle.v1，本地保存、未知值回退标准；AngleSceneView make/update统一消费，提前于setup请求的偏好也保留。离线出片默认标准。
- 我的→设置→球桌风格，真实材质渲染静态预览随选择更新，避免额外持续3D渲染循环。正式/Debug均提供球桌外观入口；既有球房Debug范围不改。

## 验证结果

- unit-r1：3项通过（偏好回读/未知值；普通、增强、mobile三管线切换隔离；5款真实渲染与标准像素恢复）。
- unit-r2：模拟器启动被SBMainWorkspace Busy拒绝，未进入测试，原日志保留。
- unit-r3：四项通过，新增提前setup请求、袋口提取后切换/恢复及场景重建验证；真实预览图已导出并打包。
- ui-standard-r1：发现SwiftUI按名字加载独立PNG失败；已改为Bundle URL与UIImage显式加载。底部半露出选项的自动点击亦改为先完整揭露。
- ui-standard-r2：并行球杆任务已增加CueStyle引用但工程尚未登记，编译失败；核对新文件存在后重新xcodegen，保留该日志。
- ui-standard-r3：iPhone 17 Pro / iOS26.3 深色，完整UI流程1项通过，七张截图已人工查看设置粉色和自由击球；预览加载缺陷确认修复。
- 最终 verify-gate、verify-doc-size、git diff --check 通过；原USDZ哈希复核未变。
- ui-compact-r1：SE3 / iOS26.3 完整流程1项通过；系统light但深链强制dark，截图仅计入小屏深色。测试补入 followSystemAppearance 后补跑浅色。
- unit-ios17-r1：SE3 / iOS17.0，5项通过，包含全部打包预览/贴图解码。
- ui-compact-light-r2：并行新增CueStyleTests中的省略前导零浮点字面量导致编译失败；仅补齐0，保持测试语义，重跑r3。
- make build：BUILD SUCCEEDED，独立DerivedData；ui-compact-light-r3完整流程通过，实际浅色截图已查看。
- 真机安装/操作、持续帧率和能耗尚未验证，不代表发布验收。

## 原始证据

output/table-styles-20260913/：source-materials.json、bake-manifest.json、原模型独立source.blend、table-style-materials.blend、settings-before.png、unit-r1.xcresult与日志、render-r1。

最终状态：本地实现完成，标准尺寸深色、小屏深色/浅色UI及iOS17材质测试通过。最终门禁 gate-final3 通过（含并行球杆测试写盘面只读登记）；UI审查见 tasks/ui-reviews/UR-20260913-table-styles.md。

## 第二轮：袋口与瞄准点对比配色

用户要求深色桌用浅点、浅色桌用深点，袋口与桌框也拉开对比。

| 球桌 | 未选中皮革 | 颗星参考点 |
|---|---|---|
| 胡桃木 | 浅米灰 | 暖白 |
| 炭黑 | 浅冷灰 | 冷白 |
| 象牙白 | 石墨灰 | 深炭灰 |
| 樱花粉 | 白色 | 深梅色 |

标准仍恢复源材质。皮革沿用原纹理与表面光照，选袋/双角色材质独立于主题；切换主题不清除当前角色。White只在球桌节点内替换，不涉及母球。新增角色保持/取消后恢复检查，真实渲染及打包预览更新待验。证据：output/table-styles-20260913/contrast。

用户中途修订：樱花粉为白色皮革例外，深梅色瞄准点保持。contrast/ui-r1已通过，但属于修订前配色；白袋口另存white-pocket证据。

近景复核发现White材质同时用于台呢置球点；改为有效X-Z台面外才应用瞄准点颜色，台内保留原白。rail-only批次另行验证，旧截图保留为失败设计证据。

最终材质批次：rail-only-r1（iOS26）与rail-ios17-r1各6项通过；已查看白袋口粉色图及旧系统实际渲染。四张设置预览同步更新。gate-final通过，原USDZ哈希保持。

最终UI首试因并行新增BallStickerTests表达式类型推断超时而未启动；日志ui-final保留。已用make build成功构建当前App，再通过既有未改的TableStyleUITests测试包test-without-building核对页面（ui-final-r2）。

新增用户裁定：设置「显示颗星参考点」，默认开启，本地showsTableSights.v1独立保存。只隐藏有效台面外的White片元；台内置球点保留。设置预览提供同机位有点/无点图片，随开关同步。sights-r1编译发现误给袋口方法传开关参数，已移除；r2继续验证。

sights-r2六测通过，已查看粉色隐藏图：库边恢复连续木纹，台内置球点/白袋口正常；五款有/无参考点十张预览均已打包。最终UI开关及旧Runtime继续验证。

sights-final：6项单测+2项UI通过，设置开关/重启保存/训练隐藏/恢复开启截图已查看。sights-ios17首轮6测中的逐PNG恢复比较1次失败（246327与246332 bytes），其余通过；相同代码单独复跑渲染r2通过，不修改断言；全套r3复核中，保留首轮证据。iOS17隐藏图已目视确认正常。

相同源码/断言iOS17全套r3六测通过；首次逐PNG不一致未再现，保留记录，不将其归因为已确认的产品缺陷。最终UI两测、iOS26六测、iOS17六测通过；真机/iPad/持续性能未验。

最终make build成功（sights-build-final.log）；verify-gate、verify-doc-size、git diff --check通过。未安装真机、未提交Git。

## 第三轮：固定袋网与承球五金

用户提供近景要求袋网固定白色，下面圆环和两根承球支架固定金黄色。Blender源模型只读材料审计：White覆盖网/点，Gold为下部圆环和安装件，Black为下部支架。保留原Gold饰面，Black支架复制该材质；MG_Gold木质桌腿不动。White颗星条件增加台面高度限定，台面下方网线不随主题或颗星开关变化。

证据：output/table-styles-20260913/hardware/material-bounds.json（源Blender Z-up米制）；近景测试使用SceneKit Y-up世界坐标，水平相机中心Y0.60、半高0.19，画面顶缘0.79低于台面0.80，用整张图的开关前后像素一致性约束袋网保持。

硬件验证首轮相机受训练相机层级影响，r2使用根节点独立水平相机。逐PNG比较仍失败；解码对照定位差异仅在网线ROI(359..841,109..278)，整图8位MAE为0.000898..0.000933，最大单通道13..16，约2080..2142通道改变。属于细线边缘少量采样差异，未见网缺失。r3采用解码MAE≤0.01，并加入整网隐藏反例必须>0.1，保留前两轮失败与diff.swift量化证据，不以PNG压缩字节相等代表用户视觉要求。

硬件最终：unit-r3与ios17各7测通过；已查看炭黑款袋网/圆环/支架近景及iOS17同构图，白网存在、两根承球支架与圆环为金黄色。误删全网反例通过检测。十张设置预览已更新。

- 最终收口：`hardware/build-final.log` 为 BUILD SUCCEEDED；verify-gate 通过。iOS 26 / iOS 17 各 7 项测试通过；未安装真机，真机视觉表现仍待验收。

## DR-195 补充：球袋组件统一配色（2026-09-13）
用户批准以袋口配色统一圆环和承球支架，取代四款固定金黄色五金。胡桃木暖驼色、炭黑香槟色、象牙白深灰褐、粉色白色；白网继续固定白色。TableAppearance 捕获 Gold/Black 材质槽并按 pocketColor 设置柔和金属色，标准款恢复原金色基线。皮革仍用现有材质着色与角色高亮路径，不改变物理或台呢。实现来源：tasks/TABLE-STYLES-20260913.md；已应用至 tasks/UI-IMPLEMENTATION-SPEC.md 本补充契约。

- 统一色系验证：coordinated/unit.xcresult 与 coordinated/ios17.xcresult 各 7 项通过；gate.log FAIL 0，文档体积门禁与 git diff --check 通过。四款整桌及粉色银白五金近景已查看，10 张预览已更新。未安装真机。
- 最终预览入包构建：coordinated/build.log 为 BUILD SUCCEEDED。
