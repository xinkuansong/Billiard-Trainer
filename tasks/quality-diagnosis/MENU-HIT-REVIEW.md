# 更多菜单触摸与模版替代入口诊断草稿

2026-09-06。仅新增 `MenuHitDiagnosticUITests.swift`，最多两条方法；未构建、未操作设备、未修改原失败测试或业务。使用正常游客 Free、内存空库、跟随系统外观。截图及完整 AX 以 run UUID 写入 QD 专用输出目录，XCTAttachment keepAlways。

## 1. 更多菜单真实触摸

`testVisibleMoreMenuRespondsAtItsActualFrameCenter`：从训练根找到真实 `trainingHome.moreMenu`，要求存在、frame 非空且坐标有限、完整包含在实际首个 App window 内。先留 PNG/AX，附件和测试日志记录实际 frame/window/isHittable，再用 **该元素自身 normalized center (0.5,0.5)** 触摸，要求“新建模版”菜单动作出现且可命中，再截图。

这是元素中心定位，不是将主控观察到的 `(315,24,44,44)` 硬编码成屏幕坐标。不把 isHittable=false 当作跳过：它是要调查的观测值。如果 false 但真实中心触摸成功，支持此次 AX 命中报告假阴性；如果菜单未出现，保留失败，不能仅凭“按钮在截图中可见”判实际触摸正常。若本次 isHittable 已变 true，仅证明这次入口成功，不能据此解释上次失败。该方法只开菜单，不创建模版。

## 2. 我的模版空态完整保存

`testTemplateEmptyShelfCreateSaveAndReopen`：正常切“我的模版”，有界滚动验证“还没有模版”，点击空态“新建模版”。按 TrainingJourney 已有逻辑进入真实 customPlanNameField，从字段实际右端定位、清除原值，填写唯一“诊断模版+UUID”，立即核对字段值；正常添加“中袋直线出杆”(c012)、完成(1)，核对编辑页项目；保存→仅保存；回到货架按唯一名称和 `trainingHome.template.edit.` 标识找到本人新建卡，重开“编辑模版”，核对原字段名称和动作仍在。

本方法避开更多菜单，是**独立正常入口诊断**，不替代或抹去原更多菜单失败。仅保存不激活/开始训练，不接触现有用户样本。Free 内存空库无既有模版，未用 forcePremium 掩盖门控。

## 来源与边界

- 冻结 `QiuJi/Features/Training/Views/TrainingHomeView.swift:400–421`：更多菜单新建模版、真实 `trainingHome.moreMenu`。
- 同文件 `customPlanBrowsing`（约1548行）：空库 `BTEmptyState` 标题“还没有模版”、动作“新建模版”，正常追加 customPlanBuilder 路由。
- `TrainingJourneyDiagnosticUITests.swift`：复用已审查的实际名称字段、添加动作、仅保存和重开断言。原类与原失败方法保持不变。

实际 AX5 下空态与编辑表单可达、输入首启提示和卡片 AX label 尚需主控执行确认。稿中滚动有限次数，失败即保留断言；不引入 guard-return 假绿。中心触摸只在更多菜单观测方法采用，其他流程仍要求实际元素可命中。没有验证所有菜单项、购买、账号、磁盘重启持久化或全部字号。
