# 每日清台2D/3D稳定渲染视图（FL-122，2026-10-05）

用户授权修复此前分析出的2D→3D黑帧。基线见UR-20261005-daily-hud-white.md：原生录屏约70ms黑场，HUD保留。

坐标契约：只操作SwiftUI屏幕pt，根视图左上原点、x向右/y向下；不修改SceneKit世界坐标/物理。2D目标矩形与现有中央stage一致；3D使用ignoresSafeArea后的实际全屏矩形。不能写死刘海或设备宽高。

方案：只创建一个结构位置稳定的AngleSceneView，根据模式改变尺寸和位置；HUD覆盖在其上。保持2D中央舞台坐标与3D全屏，渲染实例及投影桥持续存在。验证包括实例身份、两种frame、球位、3D镜头恢复、真实2D球点击和连续录屏。

修前：before.log首个2D→3D实例身份断言失败（实际UUID改变），原生失败可复现。首轮修复after.log发现stage实际高度338pt、推算331pt不一致，拒绝改变测试阈值；改用现有窗口坐标stage测量，最终回归运行中。

中间验证：final2小屏1项、standard常规屏2项（同身份往返/选球规则）通过；6次切换区间中心区域blackdetect零黑场，连续图已审。但首次3D短暂使用旧viewport构图，继续修正：AngleSceneView通过layoutSubviews回调，在每日已测量可读区的情况下同步viewport并以dt=0应用相机；不等待下一CADisplayLink。未声明中间版本最终交付。

## 最终验收

- `build/daily-renderer-stable-20261005/layout-final.log` / xcresult：小屏667×375pt最终构建及1项UI通过，三次双向往返均同一rendererID，2D与实际stage框相等，3D与app全屏框相等；球位不动、3D镜头恢复、2D真实点球通过。
- `layout-standard.log` / xcresult：常规屏874×402pt同一回归及双模式规则选球共2项通过（拒绝非法组别并保留目标，合法点球可选）。
- `output/daily-renderer-stable-20261005/layout-final.mp4`为最终原生录屏；`actual-frames.png`连续解码帧与`layout-contact.png`已审。`final-blackdetect.log`对64.7–69秒的切换段中央50%区域检测（pix_th=0.10,pic_th=0.98），黑场区间0；基线约70ms黑场消失。布局回调也消除了首次3D先用旧viewport远构图再收近的问题；模式切换本身仍为直接切换，不新增渐变。
- 最终小屏`final-small-{2d,3d}.png`、常规屏`final-standard-{2d,3d}.png`，以及中间标准屏图均已审，球桌/控制区无裁切错误。
- 仅模拟器；未安装真机，实际手感/性能未验，未提交发布。早期after/final两次布局断言失败和修前身份失败均保留，未放宽断言。

实现范围：FreePlayView稳定background renderer，页面约束背景高度、stage使用全局实测坐标；AngleSceneView布局回调仅在每日可读区存在时同步viewport与相机，DEBUG已有拖球探针补renderer UUID。未改物理与相机曲面算法。
