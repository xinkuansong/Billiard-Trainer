# 每日打点盘透明度设置（DR-335 r5，2026-10-05）

## 范围
每日更多菜单 → 打点盘透明度；0–100%滑条，默认50%，本地持久化。大盘自动展开实时预览，仅白色填充改变；2D/3D共用。其他宿主保持原有外观。

## 验证记录
- Before：上轮原生五档截图及build/v52-screenshots/after/landscape-menu.png；已打开检查。
- 默认值/0%/100%/73%持久化单测通过；最终原生证据见下。
- 未安装手机、提交或发布。

## 复验过程
- standard：默认/端点偏好单测通过；系统popover未呈现，UI失败，见FL-120。
- standard-overlay：同期相机测试引用新增API时构建失败；retest：共享DerivedData被另一构建锁定。均不计通过，随后改用本任务独立DerivedData与模拟器。
- compact：1偏好单测+1原生流程通过，但设置卡误居中，截图否决；compact-final：右上定位断言、滑条两端、2D/3D、重启保存通过。该版24%透明底仍让白色入口透出干扰数值；最终改为280pt宽实色深底，后续最终结果另记。

## 最终功能与视觉
- standard-final.log / standard-final.xcresult：最终构建及原生设置完整流程1项通过。覆盖默认50%、两端0/100%、真实滑动至约75%（实测78%）、2D/3D共享、重启记忆、关闭面板，滑条右上边界断言通过。
- 标准iPhone17Pro/iOS26.3截图已逐张打开：2D默认50%与3D调整78%。280pt设置面板读数清楚，大盘红点及主要盘面可见；相同fixture前后对照白盘填充透明度变化，按钮/刻度未跟随淡化。
- 原图：output/daily-spin-setting-20261005/standard-settings.png、standard-settings-3d.png、standard-clear.png、standard-opaque.png、standard-adjusted.png。
- compact-delivery.log / compact-delivery.xcresult：同一最终构建在667×375pt/iOS26.3小屏完整原生流程1项通过，实测调整77%且重启恢复一致。2D/3D原图已打开；文字完整，红点与主要盘面可见，小屏设置卡遮住盘面右上局部，关闭后恢复完整盘面。原图compact-settings.png、compact-settings-3d.png。
- 最终1项偏好单测、同一原生UI用例双尺寸2次执行通过；菜单popover与视觉返工已按FL-120关闭。门禁git diff --check及verify-doc-size通过；PROGRESS超过100KB时已将最旧10-01进袋回切条目移入既有归档，未删除历史。
