# 分离角与走位 2D/3D 原生截图对比

2026-11-27完成。用户要求其他实际页面，本轮通过首页「走位→分离角与走位」进入正式 PositionPlayComposerView(.p01Replayable)，从真实菜单切换2D/3D和「轨迹·全部」，不是离屏自拟球形。

## 交付

- [2D三档对比](comparison-separation-2D.png)
- [3D三档对比](comparison-separation-3D.png)
- 六张1334×750原生整屏原图；拼图只加独立标题条，原图未缩放或修线。
- A主线5.6mm/B主线5mm/C主线4mm；半宽依次.0028/.0025/.002米。测试临时TrajectoryStyle.lineHint同时为4/4/2.8mm；不消费此常量的既有细基准、特写屏幕线宽不变，因此标题仅标主线。
- SE3/iOS26.3.1横屏/深色；默认三球、杆速2、中心打点，主线、目标球本色虚线、母球碰后白虚线均走正式绘制链路。

## 验证

定向原生UI方法1/1通过（完整日志与xcresult位于output/local-test-runs/6bfdb1cd37874656932611fd46fac2b1/evidence）。三次启动×2种模式共6张截图与6份状态JSON，全部原图及两张拼图目视核对。球位在测试内严格比较；same-condition-check.json核输入（排除会话UUID）和eye/pivot/yaw/distance/elevation/pitch/fov各档完全一致。2D投影数值仅有Float舍入末位差。时钟、初始球贴图转向等非线宽状态由真实页面保留，未修图。

PoolBallFace临时DEBUG模拟器参数与UI测试追加块已删除，source-before/after SHA完全相同，未采用候选线宽、未更改正式默认值和教学图。生成器、临时参数版备份及原图归档供复现。

TP22复用现有实虚/配色/显隐；TP12复用实际菜单与统一相机；无新页面，无布局修改，本轮不宣称其他页面或真机验证。用户待决定采用哪档。

本轮构建通过local_test_lifecycle complete回收，保留证据，设备归还并保留原数据；实际状态见lifecycle-complete.json。
