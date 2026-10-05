# 每日返回与设置白色前景、2D→3D闪屏诊断（2026-10-05，DR-335 r10）

## 已实施与验证
返回标题区2D/3D均移除常驻胶囊底，保留44pt返回命中与按压反馈。透明度标题、百分比、端点说明、叉号及滑条填充为纯白；每日更多入口纯白、菜单tint白色。透明底/默认50%/保存保持。

build/daily-hud-white-20261005/verify.log及verify.xcresult：构建与1项原生完整设置流程通过（2D/3D、0/100%端点、默认50%、拖动、重启保存）；output/daily-hud-white-20261005/settings-{2d,3d}.png已实看，无标题底框、设置前景纯白。仅667×375pt/iOS26.3模拟器，未安装手机。

## 切换闪屏诊断（未修复）
用户澄清异常方向为2D→3D。本轮按请求分析，不改相机或渲染生命周期。

证据：output/daily-hud-white-20261005/switch-diagnostic.mp4原生录屏；switch-detail.png为47.8秒起0.5秒内30fps连续抽帧。切换中HUD保持，桌面/球房消失为黑色。中心50%区域blackdetect（pix_th=0.10,pic_th=0.98）测得录屏47.916667–47.986667秒约70ms黑场；该数值仅此次模拟器录制，不代表真机固定时长。

源码链：
- FreePlayView.dailyLandscapeBody分别在外层if is3D（1404行）和中央舞台if !is3D（1416行）创建sceneContainer；SwiftUI结构身份不同，切换移除旧SCNView并新建另一实例。
- ShotPlayCamera.setMode先改变模式并setCameraMode(animated:false)（PositionPlayViewModel.swift:3098–3110），同一个scene立即切到透视相机/显示球房。
- AngleSceneView.makeUIView（97行）新建SCNView并挂scene；FreePlayView.swift:544给3D黑色底。dismantleUIView（270行）停止旧渲染并清空scene。新实例首帧尚未呈现时露出黑底，与录屏中仅场景消失一致。
- 反向2D使用透明底且外层有地毯，露底的视觉冲击可能较轻；未独立测量反向帧时序，不将其称为无空帧。

建议优先保持一个稳定结构身份的SCNView，只切frame/裁剪与相机模式，并同步最终viewport后呈现。若布局暂时无法统一，再考虑保留上一帧直至新渲染首帧就绪；不靠固定延时或淡黑动画掩盖。后续修复需检查双向连续切换、球位/镜头保存与2D坐标命中，不以静态截图证明消除闪屏。
