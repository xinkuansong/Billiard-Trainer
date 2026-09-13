# 台呢颜色 — 2026-09-13

## 范围与实现

用户授权保留现有绿色，生成其余五种颜色并接入设置：赛事蓝、雾灰、酒红、蓝灰、暖驼。
采用现有TaiNi的独立颜色绑定；原底色为纯色，法线/粗糙度承载布纹，不增加重复大贴图、不改USDZ。新颜色sRGB起点沿用研究建议，六色已完成模拟器实际渲染审查。
ClothAppearance在场景灯光初始化后保存原diffuse/multiply，切回绿精确恢复；保留材质实例，避免MobileContactOcclusion持有旧对象。只作用TaiNi，球桌木框、袋口、颗星、球位、相机与物理不变。
参考灯光中的球面台呢反射色改为参数，随台呢切换，默认绿色保持旧线性值。
设置独立「台呢颜色」，六项单选，clothColor.v1本地持久化，未知值回退绿色。AngleSceneView统一消费；静态教学图、已烘焙资源不重新出片。

## 验证

证据目录output/cloth-colors-20260913；专用iPhone17Pro/iOS26.3模拟器B937B725-B617-4777-8E11-832374E75EA3。
已留存设置改前截图。偏好回读、三管线隔离/恢复、实际渲染出片及标准iPhone/SE/iPad UI证据已取得；最终标准iPhone稳定截图复采一项通过，两张稳定2D原图经主控目视确认颜色与路径正常、无转场残影；build-final最终构建成功。
原TaiQiuZhuo.usdz SHA-256：617bcf941e3a153965de63fff27150b1c02504a433da12a8a587c902636c851b。
真机、持续性能、发布尚未验证；未提交Git。

## 已取得证据

- unit-r1：普通mobile预览及偏好/三管线隔离恢复，3项通过。
- unit-r2：4项断言通过，但参考光照图出现洋红球；日志明确Metal编译错误，视觉拒绝，FL-063。该批预览未作为交付。
- unit-r3：参数/函数声明分区修正，4项通过；六张原图逐张查看，shader-pixel-check.json显示旧图各257个洋红坏色像素，修复后全部0。六张实际渲染预览已打包（约1.4MB），未额外增加台呢底色纹理。
- ui-standard：iPhone17Pro/iOS26.3浅色完整流程通过，六色选择/预览、重启保存、两个训练页接入及绿色恢复。首轮2D截图取于转场中，另补稳定截图；不据转场图判断产品布局。
- se-ios17：iPhoneSE3/iOS17.0四项材质测试与完整UI通过，深色选择页原图已查看；旧系统着色器正常、颜色恢复成立。
- ui-ipad：完整UI一项通过，系统字号设为XXXL；已审查选择页、绿色恢复及两个训练页稳定2D/3D截图。继承的字体Token采用固定字号，此次捕获不证明Dynamic Type适配。
- gate-r2：通过（新增设置路由已审计登记）；doc-size-r1及diff-check-r1通过。
- 本轮未更改原模型、物理、球位或相机控制；与球贴纸/球杆等其他任务已有dirty工作并存，未提交。

## 视觉收口与待办

独立finish审查结论：在已覆盖的模拟器视觉范围内可交付，未发现P0/P1；详见[UI审查报告](ui-reviews/UR-20260913-cloth-colors.md)。暖驼色上的黄色路径对比较低但仍可辨识，记录为非阻塞观察，不扩大修改范围。
本次是沿用设置页样式的局部扩展，不改全局DESIGN或设计Token。Impeccable可执行文件因权限拒绝未能运行自动检测，以上结论来自测试输出与实际截图审查，不能表述为检测器通过。

- ui-standard-stable：完整流程一项通过，稳定2D原图已审。build-final.log记录 `BUILD SUCCEEDED`，make退出0；artifact-manifest.json确认六项预览打包、原USDZ哈希未变。
- 最终gate/doc-size与差异检查均通过。
- 未验收：真机显示与操作、持续帧率/能耗、真实VoiceOver、Dynamic Type适配、发布流程。
- 原始失败日志与截图保留在证据目录；unit-r2的断言通过不能抵消该轮视觉否决。未提交或推送Git。

最终收尾：gate-final.log（FAIL=0）、doc-size-final.log与diff-final.log均通过；最终标准手机稳定2D两页原图已目视。未提交Git或安装真机。
