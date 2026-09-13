# 六套球贴纸验收记录

日期：2026-09-13 · DR-194 · 当前角色：UI Reviewer

用户授权：参考六宫格设计六套，在 Blender 实现并接入 App 作为可选球贴纸。

## 实现与范围

设置 → 球贴纸提供现代赛事、极简现代、经典美式、粗描边徽章、电视竞技、复古怀旧；默认现代赛事，设备本地保存。预览为 Blender 使用原球网格和新贴图的实际渲染。母球仍用原红点，1–15 号颜色族不变。与球房、球桌、球杆偏好独立。

90 张 1024×512 sRGB 底色 PNG + 六张预览约 3.2 MB；独立 `BallStickerLibrary.blend` 约 10 MB，六个 collection、90 个球网格、全部贴图 packed。原始 `TaiQiuZhuo.usdz` SHA 不变。App 只替换编号球 diffuse/multiply，无新增球几何或渲染 pass，不重建训练场景、不改变球位、球姿态、相机、物理、灯光 shader。静态教学配图与球号语义图标不换肤。

## 已验证

| 层次 | 结果 | 证据 |
|---|---|---|
| Blender | 六套渲染 + 干净进程 packed 回读通过，90 张贴图/原UV/球号映射/源SHA检查通过 | `output/ball-stickers-20260913/verify-assets.log`、`manifest.json`、`*-all.png` |
| 单元/集成 | iOS26 与 iOS17 各 3 项通过；六款持久化/非法值默认、90张包内纹理、实例隔离、母球/几何/球位/相机/shader保持 | `unit-r2.log`、`ios17-unit.log` |
| SceneKit | 普通、增强、移动管线各六款出图；最终 iOS17 无光照近景核对 1/6/8/9/10 号码、色带与6/9区分线 | `app-renders/`（无光照近景只证明UV，不作照明证明） |
| 设置 UI | iOS26标准尺寸六款点击与重启保留通过；专用SE/iOS17最终六款+重启+浅深色通过，最终原图目视 | `ui-r2.log`、`ui-se17.log`、`ui/modern.png`、`ui/vintage.png`、`ui/light-top.png` |
| 实际训练页 | 从设置选择徽章款，进入自由击球；2D→3D、击球、回放、重打通过，原图已审 | `ui-r3.log` 中 testSelectedStickerInFreePlay 通过；`ui/freeplay-*.png` |
| 构建/门禁 | 模拟器 Debug、真机 Debug BUILD SUCCEEDED；内容门禁 FAIL0、文档长度及 diff检查通过 | `build.log`、`device-build-r2.log`、`verify-gate-final.log`、`doc-size.log`、`diff-check-final.log` |
| 真机部署 | 03:12 iPhone16Pro connected，Debug 安装成功；无测试夹具参数正常启动成功 | `device-install.json`、`device-launch.json` |

## 视觉审查

- 标准尺寸深色与SE浅/深色均检查：名称、说明、选择标记、球预览清晰；可完整滚动至第六款，未发现截断/溢出/错选。
- 色彩、字体、间距、圆角沿用当前 Design Token；整卡点击区覆盖预览与空白，辅助功能名称包含风格说明，状态声明已选择/未选择。
- 原球自带朝向保持，号码可随滚动转离镜头；未为展示贴纸强行改变训练球姿态。
- 发现并在交付前处理：最初双位数留白偏小，字号缩小；测试近景照明过曝改为明确无光照UV证明，实际照明由自由击球截图验收。
- 本次未发现待修复的 P0/P1 视觉问题。复古细衬线是可选风格；小尺寸识别优先可选极简现代或粗描边徽章。

## 失败记录与证据边界

- `unit-r1.log`：NSCache 可淘汰重载，UIImage 指针身份不是贴图正确性契约；改为比较实际 PNG 内容。非产品丢图。
- `ui-r3.log` 的另一项浅色断言失败：RootView 测试深链默认强制Dark。最终用现有显式Light参数并断言真实colorScheme，SE实图确认浅色。
- `ui-r4-interrupted.log`：同一模拟器被并行测试占用，App被终止。改用专用模拟器后通过，未修改产品来掩盖工具冲突。
- `ui-build-r1.log` / `device-build.log`：并行任务新增TableStyle/CueStyle尚未纳入生成工程，xcodegen刷新后构建成功。未删除或回退这些并行改动。
- 未做真机完整交互截图、持续帧率/能耗/发热、iPad矩阵、VoiceOver实听或Release/App Store验收；设备安装启动不代表这些项目通过。未commit/push。

交付总览：`output/ball-stickers-20260913/preview.html`；构建/资产说明：同目录 `README.md`。
