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
cover.png               卡片风格封面（球放大 1.6，首杆击球前 + 预告线）→ DrillThumbnails
preview/frame_NN.png    卡片风格动画帧序列（整段抽样 12 帧）→ Previews/<id>/
initial.png / final.png 开局 / 终局布局（真实风格 1280×640，无 HUD）→ DrillTutorials
sNN_still.png           每杆击球前静帧（预告线 + 假想球 + HUD 条，1280×720）→ DrillTutorials
full.mp4 / sNN.mp4      2D 顶视整段 / 单杆视频（720×1280 竖屏@60，含 HUD 条）→ OTA
full.gif                整段分享 GIF（2D 顶视 480×240@12，无 HUD）→ 站外分发
full_3d.mp4 / sNN_3d.mp4  3D 静态斜视角整段 / 单杆视频（手机档 720×1280@60，含 HUD）→ OTA
full_3d@1440.mp4        3D 高分档整段视频（1440×2560@60，含 HUD）→ 外站备用（不进 Bundle）
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
- **分辨率双档**：手机档 720×1280（App 内竖屏播放，per-shot 一并出）；
  高分档 1440×2560（外站备用，仅整段，不出 per-shot 省渲染）。
- **物理边界**：仍是 2D 平面物理（球恒在球面高度），3D 仅换相机；**跳球/扎杆腾空** 出不来。

渲染契约（2D 顶视档）：
- **渲染风格双档**：卡片风格（球放大 1.6）仅用于 cover 和 preview；其余产物一律真实比例。
- **轨迹线 = 击球前预告**：每杆设置静帧显示白色母球瞄准线 + **随目标球球色**的进球线
  （黑 8 例外亮灰，`TrajectoryStyle` 真源）+ 假想球，出杆瞬间清除，
  运动画面无线（与编排台 App 内行为一致）。clean（全程无线）变体按需另出。
- **击球参数 HUD（ADR-P11-13）**：teaching 档画面底部 80px 暗色条显示本杆打点
  （`BTSpinMiniIcon` 球面 + 占满塞百分比读数）与力度条（档名 + m/s），每杆常驻、换杆更新；
  gif / card 档不带 HUD。场景背景为暗色（与 App 场景页一致）。
