# 目标袋口小红旗 — DR-345（已撤回）

日期：2026-10-01

最终状态：用户否决旗帜的2D/3D共用适用性，已撤回本轮生产代码、专项测试和生效设计契约；下文仅保留实验历史。

## 需求与实现

用户要求用袋口上方的小红旗替换黄色皮革选中效果。共享PocketLeatherMarker保留target语义及现有选择、清除、无障碍描述，仅将target材质改回与original一致，并附加静态红色三角旗。切换球桌主题时两套皮革材质同步；第一/第二/共同目标教学角色配色保持。旗面随镜头朝向，沿用实体深度测试；无持续动画。

SceneKit世界X/Z为桌面、Y向上，单位米；锚点来自AngleSceneCalculator.pocketMarkerPositions，Y=surfaceY+0.06。父节点逆世界变换取消USDZ旋转和缩放。旗杆124mm、旗宽70mm；颜色来自btDestructive浅色与btTextSecondary深色。

## 功能验证

- 修改前：PocketLeatherFlowUITests/testDailyAndPlanRoles，1项通过；截图已保留。
- 六袋命中/选择、角色/清除/重建、固定题目、回放与撤销、场景隔离、主题同步的核心验证：三角旗候选17项核心测试通过；日志after/triangle-core.log。
- 原生页面首稿1项通过，新增视角测试因AX值包含动态FPS而断言失败；已改为仅比较选袋描述，但用户取消方案后未继续运行，不计通过。
- 首轮混合单元/UI启动被模拟器Busy拒绝，未计通过；已改串行执行。
- 首轮核心17项中16项通过，剩余一项12次失败来自对未声明SCNMaterial键调用value(forKey:)并断言nil：SceneKit返回无关NSValue。随后“shader必须没有pocketLeatherTint”的替代断言在mobile分支6次失败，因为球桌主题本身也使用该键（TableAppearance.leatherMaterial）。最终按需求验证target与original共享同一实际材质身份，并保留旗帜世界坐标、主题同步及角色/清除断言；三角旗最终17项核心测试0失败。没有改生产实现迎合该断言。
- 数轮编译X1_CameraAndAngleArcTests前端崩溃，报告为类型检查EXC_BAD_ACCESS，未计通过；当前仓库测试源码更新后恢复正常编译，本任务没有修改该相机测试文件。

日志目录：build/red-flag-20261001；早期失败日志保留。

## 视觉审查

已目视修改前每日2D原图，黄色皮革位于左下角袋。六袋真实SceneKit渲染的红旗清晰，袋口原皮革保持；已查看首稿每日2D截图；三角旗最终原生全视角审查未继续，用户取消方案优先。

证据：output/red-flag-20261001。修改前3D截图采于相机过渡中，只作历史基线，不用于等机位对比。

## 验收边界

用户视觉否决，方案已撤回；未真机验收或发布。
