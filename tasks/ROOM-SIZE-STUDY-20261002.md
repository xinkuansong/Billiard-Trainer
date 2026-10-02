# 球房尺寸空间对照（2026-10-02）

用户认为目前单桌球房太空旷，授权制作多档尺寸候选，随后明确选择先试 **8×6 m**。已集成三种球房风格并安装、启动 iPhone 16 Pro 试用版；层高仍为 3.6 m。以下对照部分记录第一阶段，此后正式资源和相机边界已按末节更新。球桌尺寸及物理未改。

## 产物

- `output/room-size-study-20261002/index.html`：四档网格、三种镜头及与现状的拖动分界对比；本地预览 `http://127.0.0.1:8768/`。
- `comparison-room.jpg` / `comparison-standing.jpg` / `comparison-table.jpg`：对照拼图；12 张原生 SceneKit PNG 同目录。
- 四个尺寸子目录：独立 USDZ 与 Blender 副本；`make_candidates.py` 保存几何生成方法，`geometry-audit.json` 保存干净进程回导测量。
- `RenderQualityV62Tests.study.swift` 保存隔离出图代码；临时测试已从仓库测试文件撤回，`run-study` 闸门已移除。

## 对照约束与验证

SceneKit X–Z 为水平面、Y 向上，单位米；Blender 世界坐标为 (X,−Z,Y)。基线来自实际 Bundle 的 `Room_tournament_perimeter.usdz` / `_floor.usdz`，按独立连通片移动墙面和家具，仅墙体、踢脚线和声学墙板按新长度调整。家具、球桌和球不整体缩放。缩小地板并裁切 UV，保持原地毯物理纹理尺度及桌下既有阴影位置。

三种固定镜头均在最小候选墙内 35 cm 安全范围内。明确以世界上轴重建相机姿态，避免继承之前沿杆镜头的滚转；俯视镜头完整保留球桌。四档尺寸之间相同视角的眼位、视线目标、FOV、曝光、球位及桌体保持相同。

- Blender 4.5.6 LTS 导出与干净回导：8 个 USDZ；地板长宽匹配，外围全部几何在对应墙体外包络内，墙高 3.6 m。
- iOS 26.3 专用模拟器 `08FC41A5-57EA-4262-847B-5B297CF101EB`：`testRoomSizeSpatialCandidates20261002`，Executed 1 test / 0 failures，6.428 s；日志 `test-final.log`，最终 `TEST EXECUTE SUCCEEDED`。12 张实际渲染图已逐组审看。
- 同测试包含 4 尺寸×3 个 pivot×360 方位的 4320 个几何机位边界断言；这是空间边界探针，不能证明生产 CameraRig 全交互正确。

首轮临时测试有可选节点未解包的编译失败（`build-first.log`），修复后继续；默认模拟器卡在宿主安装，主动中断并切换专用模拟器（`install-interrupted.log`）。初轮固定相机继承滚转，旧图保存于 `rejected-inherited-camera/`，已修正出图。生成脚本初轮局部位移符号导致灯具外移，已修正并增加实际资产外包络断言，再完成最终回导与渲染；旧轮不计最终验收。

## 判断与边界

第一阶段判断：9×7 m 的变化较温和；8×6 m 明显收紧且保留较多空间；7×5.5 m 更接近紧凑单桌训练室。用户随后选择先试 8×6 m。

本轮沿用现有烘焙纹理和球房反射，不重新求解光照；部分壁灯几何与旧光斑/阴影存在错位。因此只用于尺寸与布局选择，不代表最终材质灯光验收。广角图露出无天花的黑色背景是现有场景特征。

上述灯影限制仅针对第一阶段尺寸候选。正式集成见下；本次没有提交或发布。

## 8×6 m 正式试用集成（DR-346）

- 六个正式 USDZ 和六张光照 PNG 已备份至 `integration/backup/`，替换为三风格新烘焙。生成器参数化长宽，墙板/踢脚线随壳调整，家具和球桌不整体缩放；壁灯与光斑重新生成，挂画沿新墙附着。Blender 文件、光照参数、回导证据在 `integration/assets/` 和 `asset-audit.json`。
- 旧校准脚本只识别 Swift 字面量，当前灯光 Rig 是计算值；通过实际 Swift 求值导出，绑定现行源文件 SHA-256 后重新校准。每灯 83.618076 W，四项直接漫反射探针误差均小于 0.24%；世界强度 2.2、壁灯 12 W、192 samples、2048²/1024² 沿用。`--rig-json` 支持计算值，`--use-metal` 仅本次进程启用 GPU，不保存全局偏好。运行时灯光源未改。
- `BakedTrainingRoom` 定义 8/6 m，地毯纱线及重复花纹保持物理尺寸；东方边框适配完整地面。反射探针仍从实际安装的房间生成，11 项探针检查通过（其中一项既有输出诊断跳过），未替换球体着色算法。
- 每日相机安全范围为 X±3.65、Z±2.65 m。首轮缩短眼位后，旧固定镜头裁到桌角；现在从实际眼位及完整外桌/球高包络计算全局所需 FOV，保留 35°俯角及手动接管。只在全局自动取景补偿，手动观察不被全桌拟合抢回。
- 首轮核心回归出现 1950 次断言失败：相机缩小上限/全局转向桌角，以及挂画测试把未归一化点积误当朝向判断。保留原始日志 `test-core-first.log`；相机补偿后 12 次挂画断言仍失败，见 `test-core-camera-fix.log`。挂画改为单位法线与向内墙轴的点积 >0.99；缩小距离期望改为 min(8%退距,实际墙距)。全局四角可见性原断言完整保留。

验证：

- 干净 Blender 回导 6 USDZ：地板 8×6 m、墙高 3.6 m、包络 X±4.2/Z±3.2、UV有效、无输出灯光/相机，`asset-audit.json`。
- 核心回归：46 项 / 1 既有跳过 / 0 失败，8.075 s，`integration/test-core-final.log`，`TEST SUCCEEDED`。包含新实际网格尺寸契约、墙内每帧极端手势、全局转向四角投影、观察缩放/恢复、三风格挂画及缓存。
- 原生页面：3 UI / 0 失败，146.906 s，`test-ui-final.log`。三风格组合选择/重启、自由击球观察/瞄准及2D往返、每日第一/第三人称重开回全局。20 张截图在 `ui-attachments/`；已直接审看其中9张相关正式截图，详见 [视觉审查](ui-reviews/UR-20261002-room-eight-six.md)。测试附带2条 `_UIReparentingView` 运行时警告，未造成断言失败，未据此宣称整个App无告警。
- 真机：`make -f scripts/Makefile build-device-profile`，`BUILD SUCCEEDED`；Debug `-O`。8:12 安装 `com.xinkuan.qiuji` 到 iPhone 16 Pro，8:13 每日清台启动成功，PID5882 后续仍在；`device-install.json` / `device-launch.json` / `device-process-confirmed.json`。首次命令的应用参数缺少分隔符，命令解析失败且没有启动，修正后成功，保留 `device-launch-argument-error.log`。
- 包装：源、模拟器包、真机构建包的 6 USDZ SHA-256 一致；Xcode 将6 PNG转为CgBI，反转换后的逐像素完全一致，见 `bundle-manifest.json`。这是待安装构建包与安装成功的证据，没有从手机抽取资源后宣称二次校验。

下一步仅为用户在手机上的空间感与镜头舒适度反馈。未做持续帧率/温升、新尺寸下所有页面及完整HUD遮挡验收；既有 FL-094 相机一般问题保持开放。USDZ沿用仓库忽略策略，正式文件实际已替换但不会在普通 `git diff` 中出现；未来提交需显式纳入这6项。原版完整备份可用于恢复。
