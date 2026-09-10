# v61 瞄准特写与理想方向验收

需求真源：`问题集合_v61.md`。状态：W1–W4本地实施与定向验收完成；真机未验，未提交发布。

## 结果与根因

- 特写原来固定俯视坐标，3D转动时与主场景不一致。现按实际SCNView投影统一放大，焦点、线条、标记、球体深度尺寸与避让同源，可见时随相机刷新。
- 自由模式新增独立浅灰直虚线：从首碰目标球前缘，沿碰撞法线到生产几何的首次库/袋事件，无箭头、无反弹，不运行整杆预测。主场景和特写共用；最新物理结果接替，旧预测仍受代际保护。
- 两解球器自由模式原有旧解参考路线与灰线叠加，现隐藏旧参考层；求解模式保留。瞄准点练习不新增灰线，minimal档不显示新方向层。
- 3D右轮按实际控件宽度留白；四个共用stage入口按球桌两侧仪表位置留白。SE3实测发现原0.92倍直径最小间距排除了上方空位，新增“常规间距找不到时选择更近的完全无遮挡空位”后，母球/瞄准走廊/两侧仪表均可见。

## 最终证据矩阵

统一证据根：`output/aim-preview-v61/`。设备读回见`devices.json`，源码指纹见`final-source.json`。

| 验证 | 设备/状态 | 结果 | 证据 |
|---|---|---|---|
| 定向功能/几何/布局 | iPad mini A17 Pro / iOS26.3 | 45单测通过 | ipad-final/raw.log |
| 小屏最终UI | SE3 / iOS17.0 / 系统light / large字号 | 3项通过：2D、3D含旋转、连续自由瞄准；5张按住原图已审 | compact-final/raw.log、screenshots/ |
| iPad最终UI | mini A17 Pro / iOS26.3 / dark / large字号 | 3项通过，5张按住原图已审 | ipad-final/raw.log、screenshots/ |
| 标准机最终跨页 | 17Pro / iOS26.3 / light / large字号 | 10项通过：8页、连续拖动、C042试打；17张按住原图已审 | standard-final/raw.log、screenshots/ |
| 构建 | 主工作区 | BUILD SUCCEEDED；后续最终代码测试均重新编译 | integration-direct.log及上述test日志 |
| 文档与diff | 主工作区 | 通过，源码指纹无变动；见final-checks.json | doc-size.log |

所有相关场景自身为黑底球桌，系统light/dark记录不代表改变球桌颜色。未做真机、横屏、完整VoiceOver或全部动态字号验收，不提交发布。

### 已打开原图的明确结论

- `before-hold.png`是改前真实3D页面：主瞄准线竖直、特写斜向。改后题目随机，不宣称同球形像素对拍；固定输入投影单测覆盖多个相机yaw、高度与2D。
- `compact-final/screenshots/aimpoint3d-orbit.png`和`ipad-final/screenshots/aimpoint3d-orbit.png`：生产相机经真实手势旋转后，特写白线、彩色进球线与主场景同向，不遮右轮。
- `compact-final/screenshots/freeplay-motion.png`和`ipad-final/screenshots/freeplay-motion.png`：持续6秒慢拖中第2秒抓取，灰线与特写一致，无箭头；目标、母球及两侧仪表可见。松手后截图与状态测试验证正式预测接替。
- `w2-attachments/`是六袋代表几何场景渲染，已打开检查；不是完整App页面。六袋入口、袋角先接触、180方向对称/有限性及1000次查询约29ms已验证。

## 状态与范围证据

45项最终单测覆盖首碰/身后球/擦身打空/多球选择、库袋终点、实际投影、特写门控、布局避让。集成用例覆盖输入后即时更新、预测接替、模式切换、minimal、练习排除；力度/旋转不改法线，拖球更新、撤球清理、重新摆球恢复、开球隐藏和清桌清理。

开球与播放入口走clearTrajectory/hideAllVisualization；refreshFreeAimOverlay排除isPlaying/isBreakMode/isSequenceMode；序列与回放共享清理路径按源码核对。C042实际UI验证试打/序列/暂停/摆球入口，不宣称已完成所有组合的物理或真机验收。关闭特写只影响overlay，主场景方向层独立。

## 失败与返修记录

原始失败证据保留，不能把以下批次记作全绿：

- W2首轮错误地把桌心到每个角袋孔心都当可直接进袋；按实际袋角几何修正样例为45度喉口方向，原射线保留为先碰库断言。`w2-r2-raw.log`通过，未篡改生产几何求绿。
- `final-standard/raw.log`暴露场景读取MainActor偏好的编译错误，改为ViewModel显式传档位。
- `final-r2`遇并行心得页类型检查问题；独立验证快照又因配置/测试依赖不足失败。主工作区恢复后直接构建及测试，快照不作为通过证明。
- `make build`缺xcpretty，改直接xcodebuild保留真实退出码，未修改脚本。
- `final-root`26单测、8页常规UI及C042通过，但新增慢拖因未切自由模式失败，批次退出65。补真实入口切换后`standard-r3`两项UI通过。
- `compact`6项集成+3UI通过，但截图发现仪表遮挡；`compact-r2/r3`又确认母球被软避让覆盖。采集实际375×463视口（`placement-debug.txt`）建立回归，临时采集代码已移除。`compact-final`作为小屏最终证明。


最终标准机确认：两个解球器仅保留新的单段灰线，目标、母球及仪表可见；自由/每日/编排/分离角正式轨迹接替正常；练习无新增理想线，3D旋转后局部投影同向。standard-final/raw.log以退出0及TEST SUCCEEDED收尾。最终27张按住原图审查目录为standard-final/screenshots（17）、compact-final/screenshots（5）、ipad-final/screenshots（5）。
