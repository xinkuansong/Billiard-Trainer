# 三球自由走位 r2 · 2026-10-27

状态：实现及本轮定向模拟器验证完成。未提交、未发布；真机/用户体验待验。

本轮按用户反馈落实全量题库、三球固定球槽、蓝当前/绿下一、两球/三球常亮袋口、同袋分半、按需缺袋提示、首杆自动推进、重试恢复并可改袋。首答统计/额度仍冻结；两球自由评分公式未修改。

证据根：`output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/`。before源在`output/three-ball-flow-r2-20261027/before/`；r1原生图保留于原报告，不当r2验收图。

## 数据与功能

- 111025个球形、23分片，completion/合并SHA/分片SHA通过；资源及实际App包全部ID与坐标逐条一致。见`full-bank-audit.json`。
- r1/r2/r3 build-for-testing通过；最终16项逻辑/共享袋口测试通过。r3仅更新旧测试断言，App与UI测试仍为r2版本。
- 首次`compact-r2`共享袋口测试有旧断言失败：原测试期望所有可见子节点总数为1，现有短亮确认层在selected时与持久皮革同时显示，因此为2。生产新增practice角色不参与该路径；修正测试为持久变体恰1，确认叠层仅selected可见，继续校验材质身份不变。原失败xcresult/log保留，复跑另名。
- 审计首次定位使用了英文App名，实际product名为“球迹.app”；改为唯一实际Bundle发现后完整审计通过，未修改资源来适配路径。

## 原生与边界

已导出并审查88张原生图：SE3 34张、iPad 32张、iPhone13 22张；关键画面另按原图检查。联系表只作索引，尊重EXIF方向，原图未修改。测试使用真实导航/点击/物理，不将探针注入业务状态。手机/Pad主题为各自已有偏好，未重设球桌风格。

真机触感、声音、性能、VoiceOver朗读、真实购买与发布均未验证；本轮结果不代表用户视觉或手感认可。完整仓库verify-gate已通过；它不等于全App人工或设备回归。

## 验证结果

|证据|结果|范围|
|---|---|---|
|compact-unit-r3.xcresult|16/16通过|三球9项＋共享袋口7项；存档、回退、评分与常亮渲染|
|compact-r2.xcresult|UI 5/5通过|SE3三球2D/3D/设置与布局，两球2D/3D常亮回归；整个bundle因旧单元断言失败，不能标为全绿|
|pad-r3.xcresult|UI 3/3通过|iPad Pro11 M4，2D/3D、横竖屏、实际小窗与恢复、大字号、设置/布局取消、动画自动换杆|
|phone-r3.xcresult|UI 2/2通过|iPhone13完整两阶段2D/3D流程|
|full-gate.log|通过|完整verify-gate；另有UI基线和文档体积检查|

上述模拟器均为iOS26.3.1。流程覆盖：首次无提示、缺袋点击才提示且不扣额、三槽不移位、同袋蓝绿分半、超过3秒仍常亮、首杆自动换角色、重试与改袋、首答保持、跨杆回放停止与后台恢复、两杆均分及下一题。3D临时俯视和镜头过渡期间仍遵守共享禁出杆规则；该临时禁用不由缺少下一袋触发。

首次共享测试失败及错误App路径审计均保留原始证据，未以删除失败或修改生产行为规避。最终16项独立复跑全绿。真机、VoiceOver、真实支付及用户视觉认可仍待后续体验。

## 原生画面

[SE3：初始三球与正常击球按钮](/Users/song/projects/13.billiard_trainer/output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/compact-images/F713D2CB-C842-4965-BAAB-F2719E966F5D.png)

[SE3：同袋蓝绿分半](/Users/song/projects/13.billiard_trainer/output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/compact-images/82A72391-CB06-484F-A571-3723711C5828.png)

[SE3：3D常亮角色](/Users/song/projects/13.billiard_trainer/output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/compact-images/AB9A498F-D9A2-49A6-82B2-0A3919BDD1FB.png)

[iPad：两杆均分与固定球槽](/Users/song/projects/13.billiard_trainer/output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/pad-images/852F30C3-DC6C-4C64-8557-63A0D58EDDE4.png)

[iPad：实际小窗](/Users/song/projects/13.billiard_trainer/output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/pad-images/00E0D145-9885-4A8E-A391-4AF77C5326D0.png)

![初始三球与击球按钮](/Users/song/projects/13.billiard_trainer/output/local-test-runs/3601455fa33c426a8e501e87d6ab8fa8/evidence/compact-images/F713D2CB-C842-4965-BAAB-F2719E966F5D.png)
