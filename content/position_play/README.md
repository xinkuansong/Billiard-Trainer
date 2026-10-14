# 走位序列内容库（Position-Play Content）

走位编排台「录制」产出的击打序列 JSON 的**真相源**（source of truth）。
进 git、可 review；物理引擎升级后可全量重渲教学素材。

## 目录约定

```
content/position_play/
  sequences/   ← 录制原始序列 JSON（App 在模拟器上录制结束后自动直写）
  meta/        ← （预留）教学文案 sidecar：标题/每杆讲解/需要的产物变体清单
```

## 命名约定

- 序列文件：`seq_<UUID前8位>-<序列名>-<N>杆.json`，`seq_<id8>` 为稳定资产键，
  与 `PositionPlayDrillExporter` 的 `drill_pp_<id8>` 对齐，产物（mp4/gif/png）沿用同名前缀。

## 采集链路（ADR-P11-10）

1. **模拟器**运行 App → 走位编排台 → 录制 → 结束录制；
   App 直接把 JSON 写入本目录 `sequences/`（录制入口仅模拟器构建可见，真机/发布版无此功能）。
2. 渲染出片：项目根 `cd scripts && make position-export`
   （自动把本目录 `sequences/*.json` 同步进 `build/position_play_sequences/` 收件箱后渲染）。
3. 产物落 `build/position_play_export/seq_<id8>/`；发布去向：静帧/帧序列/封面 → `QiuJi/Resources/*`
   （进 Bundle），生成视频 mp4 → 自建 REST OTA（依赖 H-14 服务器，就绪前不再往 Bundle 塞视频）。

## 默认配方产物（ADR-P11-11）

每条序列出片到 `build/position_play_export/seq_<id8>/`：

```
cover.png               卡片风格封面（球放大 1.6，首杆击球前 + 预告线，1280×640）→ DrillThumbnails
preview/frame_NN.png    卡片风格动画帧序列（整段抽样 12 帧，1280×640）→ Previews/<id>/
initial.png / final.png 开局 / 终局布局（竖版真实风格 1440×2560，长轴沿屏幕长边，无 HUD）→ DrillTutorials
sNN_still.png           每杆击球前静帧（预告线 + 假想球 + HUD 条，竖版 1440×2720）→ DrillTutorials
full.mp4                2D 顶视整段视频（1080×2040 竖屏@60，含 HUD 条）→ 本地预览 / 后续 OTA
full.gif                整段分享 GIF（竖版 2D 顶视 720×1280@12，无 HUD）→ 站外分发
full_3d.mp4             3D 静态斜视角整段视频（手机档 1080×2040@60，含 HUD）→ 本地预览 / 后续 OTA
（默认不出单杆 mp4 / 不出 4K；静帧仍含每杆 sNN_still + initial/final）
```

## 3D 斜视角渲染契约（ADR-P11-15，与 2D 并存）

- **机位**：短边后方、沿长轴看进去的**静态斜视角**（默认相机在 +X 端看向 −X，俯角 30°）。
- **看全桌面 = 不变量**：`SequenceVideoExporter.solvePerspectiveCamera` 固定俯角 + FOV，
  沿后退方向二分推距离使球桌**外框 8 角点**全部入框（含 6% 余量）。因球恒在 playfield 内，
  外框装下即「任意一杆所有在桌球可见」，与具体球形无关、整段静态机位成立。
  几何由 `SequencePerspectiveFitTests` 断言（角点投影 + 近库不遮挡 + 取景最小可行 + 端点镜像）。
- **studio 观感**：3D 档启用 `enhancedRendering`（IBL + 接地阴影 + studio 光照，与
  `Scene3DAimingView` 同源），球读作立体接地物。
- **进袋落袋**：3D 下进袋球到达袋心后沿 Y **下沉 7cm 再淡出**（仅导出层加 Y，不动物理），
  避免在台面平面凭空淡掉的穿帮。
- **轨迹线**：3D 远端线变细，半径按 `lineRadiusScale=1.3` 补粗；其余轨迹契约同 2D。
- **分辨率**：静帧 1440；2D/3D 视频手机档 1080（用户 2026-08-01 拍板）；4K 高分档
  API 保留但默认配方不调用。
- **物理边界**：仍是 2D 平面物理（球恒在球面高度），3D 仅换相机；**跳球/扎杆腾空** 出不来。

渲染契约（2D 顶视档）：
- **渲染风格双档**：卡片风格（球放大 1.6）仅用于 cover 和 preview；其余产物一律真实比例。
- **轨迹线 = 击球前预告**：每杆设置静帧显示白色母球瞄准线 + **随目标球球色**的进球线
  （黑 8 例外亮灰，`TrajectoryStyle` 真源）+ 假想球，出杆瞬间清除，
  运动画面无线（与编排台 App 内行为一致）。clean（全程无线）变体按需另出。
- **击球参数 HUD（ADR-P11-13）**：teaching 档画面底部 80px 暗色条显示本杆打点
  （`BTSpinMiniIcon` 球面 + 占满塞百分比读数）与力度条（档名 + m/s），每杆常驻、换杆更新；
  gif / card 档不带 HUD。场景背景为暗色（与 App 场景页一致）。

## 精讲静帧更新（2026-10-12）

`make -f scripts/Makefile position-export-stills` 的静帧使用
`SequenceVideoExporter.Options.tutorialStills()`：与当前 App 共用模型、默认炭灰球桌、
绿色台呢，并使用用户认可的原缩略图光影（`mobileRendering: false`）。
球杆显式使用墨龙（`.inkDragon`），不继承烘焙设备的用户偏好；款式应用失败阻止出图。
精讲保持真实球径（`ballScale = 1`）与原始球位，不使用缩略图放大或防重叠移位。
保持 1440×2560 开局/终局及 1440×2720 逐杆图。
视频、封面与卡片预览继续使用各自配方。

仅更新精讲图片时，用 `python3 scripts/import-engine-export-to-app.py --stills-only`
回填并自动发布 HEIC。`--export-root <directory>` 可指向已审查的隔离输出；静帧模式
不要求视频存在，也不复制视频/预览或改 JSON。明确的球形 token 保留，manual01 同时
写默认别名；真源库中只有一个有效球形的历史 token 也保留默认别名。发布后运行 `make -f scripts/Makefile verify-tutorials` 和 `verify-gate`。

少量样张可使用 `PositionPlaySequenceExportRunnerTests/test_exportTutorialStills`，
需要新鲜的 `build/.run-bake-runners` 门控及 `build/tutorial-stills-request.json`：
`outputDirectory` 为绝对输出目录，`sequenceFiles` 为真源目录中的文件名数组。
正常测试不启用门控；制作结束移除请求和门控文件。样张检查与用户视觉验收分别记录。


## 动作库缩略图（2026-10-12 修订）

列表仍读取 `DrillThumbnails/<id>.png`。`DrillThumbnailRenderer` 使用当前模型、默认炭灰
球桌、墨龙球杆和原缩略图光照（`mobileRendering: false`，用户已选定样张），不套用移动端面光源配方。
输出保持 640×320 与 1.8 倍球体。`ThumbnailBallLayout` 在显示副本上求最小平方位移：
以原球对方向约束至少一个放大球直径，台面边界内缩放大半径；保持球的排列顺序，
没有重叠且未越界的布局不变。Dykstra 投影未收敛或约束不可行时明确失败，不发布重叠图。
调整后的副本重新求首杆预告，真实训练布局和内容 JSON 不回写。

隔离生成可在 `build/thumbnail-bake-request.json` 指定绝对 `outputDirectory` 和可选
`drillIDs`，开启新鲜 `build/.run-bake-runners` 后运行
`DrillThumbnailBakeRunnerTests/test_bakeAllThumbnails`。无请求时 `make thumbnails`
沿用正式资源输出。生产前先检查样张的球体明暗、库边阴影及拥挤球形，结束移除临时门控/请求。
