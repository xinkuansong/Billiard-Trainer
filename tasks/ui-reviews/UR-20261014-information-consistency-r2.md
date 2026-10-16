# 练习球桌信息一致性 · 第二轮

日期：2026-10-14。设计已获用户授权；本轮代码、构建、单测、三设备UI验证及最大字号补修复验完成。用户体验认可待看本轮原生图反馈。

## 实施与逐项对应

| 用户要求 | 最终行为 / 消费入口 |
|---|---|
| 角度与瞄准去掉拖动中 | AngleDynamicView在拖动期间返回空状态；初次操作指导、角度与厚度读数保留。 |
| 自由走位、自由击球去掉进袋i | 删除aimSelectionLabel的常驻展示及普通自由练习的模式播报；目标控件、实际结果、母球落袋、比赛规则裁定保留。 |
| 思路训练不要方案详情与长按 | 三规划页移除PlanningPanel.details和详情入口；通用操作说明仍由更多菜单打开。 |
| 求解不要f(x) | 五页共用路径图标TeachingSolverSymbols.solve。 |
| 解统一 | 三规划页、翻袋、颗星共用箭头+解k/N；多解点击循环，单解可读但禁切换，不弹长按列表或详情。未求解/零可用解仅显示禁用“解”，实际无解原因在台面显示，避免把未求解误报为失败。 |
| 普通提示i后消失 | 规划页普通步骤和反馈以i开头，按事件+步骤约3秒退出；重绘不重播，再次选择同一项可重新提示。失败/未满足约束等不计时隐藏；VoiceOver阅读例外保留。 |
| 已选打绿勾 | PlanThree角色行由isFilled控制绿勾；未选空圈，当前编辑用背景高亮，与完成状态分开。 |
| 菜单简称与球图标 | 1球/2球/3球 + 中点 + 实际球号花色图标；第一杆/第二杆 + 中点 + 按当前方向命名的袋口或未选择。选球选袋提示及异常引导去掉“计划”冗词。 |
| 推荐区域颜色 | 默认区域亮琥珀色虚线+轻填充；自绘区域青色实线。沿用原世界坐标几何，2D/3D/临时2D共享样式。 |
| 翻袋、颗星不要解i | 通过独立tableStatusText过滤普通解摘要、求解/拖动/运动播报；模拟失败、无解原因以及自由模式必要首碰读数保留。 |

求解排序、物理输入、训练记录和比赛规则未因本轮更改；共享工作区中其他任务的改动保留。

## 自动化验证

- `build-final.log`：build-for-testing成功；随后针对零解文案和最大字号菜单补修，构建见`build-final-refinement.log`。
- `final-phone.log/.xcresult`：28项单元测试通过（PlanningInformationState、PlanThreeSectorSolver、PositionPlayUndoSnapshot、W1BTeachingEditing），3项UI流程通过。
- `final-compact.log/.xcresult`、`final-pad.log/.xcresult`：各2项UI流程通过。主矩阵共7项UI执行，覆盖五页2D/3D、单解/多解计数、点击下一解和末解循环、无长按入口、三普通练习入口、角色选择、短提示消失与重触发、临时2D、自绘区域。
- iPhone额外验证：无解原因超过普通提示时限仍存在、操作说明可查看当前问题、调打点后解按钮保留“微调”。
- 最大字号补修定向复验：`refined-phone`两项、`refined-compact`和`refined-pad`各一项全部通过，补采正常角色菜单、最大字号顶部/底部、普通提示与临时俯视；零可用解不误报无解。最终构建SHA与源码清单见`refined-build-identity.json`。
- `gates-complete.log`：verify-gate、verify-doc-size通过；`diff-check-complete.log`为空。路由审计仅更新本轮两个实际变更文件签名，并移除三规划页详情路由描述。

| 设备 | Runtime / 系统外观 | UDID |
|---|---|---|
| iPhone 16 Pro | iOS26.3 / Light | 64A63CC8-6415-4C74-AF49-DB3B2D253746 |
| iPhone SE 3 | iOS26.3 / Dark | FEC0D1E7-0A8E-4CDB-ADE9-D33DC2D4C898 |
| iPad Air 13 M3 | iOS26.3 / Dark；最大字号转竖屏 | FC1D1E55-98B0-4129-BE34-9890D9CA12EE |

所有设备通过simulator_lifecycle独占借用，本轮租约已归还。SE/iPad通过同一入口关机；iPhone在收尾时被其他任务占用，管理器拒绝关机，因此保留、不干扰对方。数据与原图保留；详细返回码和设备状态见每次的`*-result.json`、`*-device.json`。不等同真机测试或用户视觉认可。

## 原生视觉审查

已查看手机五页常态、2D/3D代表状态、计划菜单、普通提示出现/消失、自由走位/自由击球、无解和微调画面，以及小屏与iPad代表状态。图中球桌实际存在，不能仅以AX层级有table.scene判通过。代表配色能区分琥珀虚线推荐区与青色实线自绘区。

- U01（P2，已修复，三设备复验通过）：最大辅助字号时勾选图标跟随正文扩大而溢出固定列，袋项两个Text竞争宽度产生竖排。改为图标独立尺寸，袋项一个自然换行Text；大字号popover扩宽并可滚动，球图标随字号适度放大。旧图保留在`before-large-type-fix/`。
- 截图采集曾提前于popover出现完成：等待角色可用、先取AX层级、等待呈现事务后再截图。旧截图保留在`after-attempt1/`，不作菜单验收图。
- 初次大字号测试用了未被App识别的启动参数：修正为系统UICTContentSizeCategoryAccessibilityXXXL，补采上/下滚动位置。旧图不作为最大字号证据。

角度与瞄准“拖动中”删除由生产分支核对；本轮图册中的该页为初始状态，不冒充拖动中帧。全套颜色主题、全部系统字号、所有物理求解场景和真实VoiceOver朗读不在本轮验证范围。

## 改前与改后证据

[原生对比页](../../output/information-simplification-20261014/r2/review.html)。改前14张，改后手机28张、SE25张、iPad25张，共92张原图。全部原图、AX、构建、测试及设备回执位于`output/information-simplification-20261014/r2/`。

改前用实施前冻结的`baseline-app/球迹.app`，SHA保存在`baseline-app-identity.json`，在新测试runner修正按钮定位后重新采集，完整`before-phone-retry`流程通过；不是用改后源码伪装改前。初次采集因测试脚本错误使用solver.strike而失败，日志与部分原图保留在`before-attempt1/`。本轮初次构建还遇到计划菜单表达式编译超时，提取行视图后解决；另一并行任务的CueClearanceTests编译超时在对方修正后重建通过。

正常显示与行为批准、自动验证、原生目视核对、用户认可分别记录。未做提交、真机安装或发布。
