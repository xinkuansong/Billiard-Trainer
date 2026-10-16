# 精讲图片按保存方向更新 · 2026-10-15

状态：✅ 已按 App 同源 liveReference 光影完成全部精讲图片更新；704 张已进入生产资源并通过实际 App Bundle 解码与逐字节核对。文本／序列／物理／瞄准未改；未装真机、未提交或商店发布。

用户授权：先更新图片，文本后续统一处理；图片与生产回放共用保存方向。

范围：74 个在用动作中，92 个非空序列（612 杆）生成 796 张开局／逐杆／终局 PNG；71 个动作的精讲引用集为704张。退役动作、试录草稿及空序列不进入本次导出。原 JSON、球位、力度、打点、物理和瞄准代码不修改。仅将静帧配方切到 liveReference，更新相应既有配方断言和 runner 实际配方日志。

调用链：`SequenceVideoExporter.renderStills` → `SequenceReplayResolver.solve` → 保存的 `recordedDirection` + before + 原力度／打点 → 当前物理预测。逐杆静帧不重新调用进袋辅助求瞄；初图取首杆 before，终图取存档末杆 after。既有竖版、真实球径、墨龙球杆保留；光影改与 App 同源：reflection 材质配置、曝光 -0.1、房间／接触阴影与反射。

证据根：`output/tutorial-refresh-20261015/`。

- `backup/`：旧 DrillTutorials、TutorialFigures、发布清单；APFS 克隆，2546 文件 SHA 与源逐一核对。
- `frozen-inputs.json`：719 个序列／动作内容／Bundle序列／Swift／缩略图输入哈希。
- `render-request.json`、`reference-map.json`、`all-master-map.json`：本轮输入、704引用与1411落位母版映射。
- `plain-render.log`：首轮旧光影原生导出1测通过，97.481秒；其5项Bundle测试和全量素材检查也通过，但用户随后要求切换 App 光影，不作为最终交付。首轮日志／哈希保留，任务原始备份保留；仅删除已核验属于本轮的作废图片以供重新生成。
- 切换前因磁盘空间不足，原图克隆恢复曾中断；后续按原生导出 SHA 只移除607个仍属本轮产物的母版，再移除本轮796帧及canonical副本，释放空间后全量恢复2546个原始资产并逐一核对SHA通过。无历史备份删除。
- `review.html`：704张新旧对照。

借用模拟器 E01C599F-27E5-4ECC-B482-D73744AD2AEA，通过生命周期管理器；用户编排 iPad 未操作。无提交、发布或真机安装。

## App 同源光影中间进度（下方已完成收尾）

- `live-sample.log`：3组46帧样张导出＋既有配方／真实场景几何测试，共2测0失败；已实看两库与高级蛇彩逐杆图。
- `live-batch1.log`：40组原生导出1测0失败；累计43组382帧，输入哈希核对通过。
- `live-progress.json` 保留每组进度；余49组请求为 `batch2-request.json`。磁盘约1.2GiB，已向用户请求清理609MiB旧Release模拟器构建的授权，尚未执行删除。
- 任务开始前旧图／HEIC／清单已完整恢复并核验；当前新光影图片尚未回填生产资源。临时烘焙gate与请求已移除，避免正常测试误触导出。
- 续跑：确认空间后把batch2请求复制到build/tutorial-stills-request.json，开启gate，通过make test指定test_exportTutorialStills；之后check-render.py、import-clones.py、canonical克隆、Bundle测试及最终验证。

用户已授权清理旧 Release 模拟器构建：精确删除 `build/DerivedData/Build/Products/Release-iphonesimulator`，1196文件／636134963字节；清理时无xcodebuild在运行，未触及Debug真机／模拟器产物及备份。回执 `authorized-cache-cleanup.json`。后半批已继续。

## 最终结果

- 原生渲染：样张3组＋第一批40组＋第二批49组，共92组796 PNG；`live-sample.log` 2测（含真实场景配方／几何），`live-batch1.log` 和 `live-batch2.log` 各1测，全部0失败。所有导出日志明确 lighting=liveReference。
- 全量核对：796张逐张解码、帧名／尺寸／非空台面检查通过；92组开局总览已实看，两库走位和高级蛇彩逐杆原图已实看。保留竖版1440像素宽，逐杆2720高、布局2560高。
- 回填：1411个母版／别名逐字节匹配本轮原生导出；704个引用母版全部更新，704 HEIC（q70）145.3509MiB。`import-publish.log`、`render-verification.json`、`assets.json`。
- 构建包：`bundle-tests.log` 5测0失败；全部引用经真实 `DrillTutorialImageStore` 成功读取；704 HEIC逐字节等于最终 `球迹.app` 资源，74张原缩略图也逐字节相同。`delivery.json`。
- 内容门禁：C1=92通过／0失败／3退役提示，C2=1411一致，C3=704且旧图／缺图0，C4=71且结构差异0；I5–I13全部0违规。发布检查缺失／过期／多余／打包配置问题全部0。`tutorial-gate.log`、`publish-check.log`。
- 719个冻结输入中，仅授权的 `SequenceVideoExporter.swift` 静帧配方及注释发生变化；其它718个输入哈希不变，包括序列JSON、精讲文本、缩略图及其它Swift。既有配方测试期待同步改为liveReference，runner日志改为打印实际配方；未修改物理／瞄准实现。
- `render-recipe.diff` 记录本任务渲染入口差异；最后一次源码变化仅修正旧配方注释，最终Bundle构建已包含该修改。
- 原图与清单备份保留于 `backup/`；新原生图为 `rendered/`，canonical已同步；704张对照在 `review.html`。临时gate／请求已清除，模拟器租约已释放。没有真机安装、Git提交或商店发布。
