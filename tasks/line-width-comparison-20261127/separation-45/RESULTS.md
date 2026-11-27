# 分离角与走位 4.5mm补图

2026-11-27完成：通过首页进入真实页面，SE3/iOS26.3.1横屏深色，全部轨迹。A主线5.6mm、B4.5mm、C4mm，三档辅助线都保留4mm；其余既有细基准/特写屏幕线宽未调整。与上一轮C辅助2.8mm不同，不混用旧图。

- 六张1334×750完整原生页面截图及两张1334×2424竖排对比图，全部目视；拼接只加标题，原图不缩放不改线。
- 定向UI方法1/1通过，112.786秒。日志/xcresult：output/local-test-runs/2168f97b6a8543bbb3aa33021862eab5/evidence。
- 球位测试内严格比较；同组输入（排除会话UUID）及相机eye/pivot/yaw/distance/elevation/pitch/fov一致，见same-condition-check.json。页面时钟和随机球贴图转向保留原状。
- 临时DEBUG模拟器主线参数及测试块已移除，两个文件开始/结束SHA一致，见source-after.json。正式默认仍为原值，未推广到球桌其他页面，未改图解资源。
- 构建按生命周期complete回收，保留原图和日志；设备归还、原数据保留。最终状态见lifecycle-complete.json。

[2D对比](comparison-separation-2D.png) · [3D对比](comparison-separation-3D.png)

2026-11-27用户已确认“4.5好一些”，据此整理[完整方案v75.0](../../../问题集合_v75.md)：交互球桌主线4.5mm，辅助保留4mm。正式接入尚未实施；本记录不代表产品已推广或真机验证。
