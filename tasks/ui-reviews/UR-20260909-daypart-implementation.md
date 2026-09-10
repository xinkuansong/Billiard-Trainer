# 本周训练时段摄影与头像玩法球 · 试装审查

日期：2026-09-09。范围：训练周卡背景/状态点缀、我的头像卡装饰。用户批准试装后补充“不要影响原来的尺寸和布局”。未提交或发布。

## 最终布局约束

恢复改动前周卡VStack、标题btTitle2、头部44pt入口、数据行、七日22pt圆点，以及水平16pt外边距、12pt内边距。移除首次试装增高的76pt进度环。今日安排与计划区没有本任务的布局修改。摄影放在background中，GeometryReader不参与前景测量。头像球放在原Spacer的overlay中，不增加HStack成员、不撑高原56pt头像行。

同设备同数据前后原图：`output/daypart-implementation-20260909/before/training.png`、`standard/compact-final.png`。对比页：`output/daypart-implementation-20260909/layout-comparison.html`。目视周卡四边及今日安排/计划区纵向位置相同；数据2/3、连续1天、今日6/8与335分钟保留。玻璃Tab栏的动态底色不是布局差异。

## 素材与行为

五张无UI烘焙素材：三张传统绿色台呢、红点白球及木杆照片；透明黑八/黄条九号。1280px背景及256px球图，总约3.9MB。提示词及SHA清单位于证据目录。

当地06:00–11:00晨光，11:00–18:00日间光，其余灯罩聚光。每分钟刷新摄影层，回前台按当前时段计算；减少动态效果时无淡入。没有修改系统时钟。DEBUG的QIUJI_DAYPART只用于截图，不持久化。玩法读取既有dailyClearanceGame，中八8号，其他全部9号；不改普通菜单、全局主题或玩法数据。

## 验证及返工

- `build-compact.log`：BUILD SUCCEEDED。make因环境无xcpretty走既有xcodebuild fallback。
- `unit-raw.log`：TrainingAtmosphereTests两项通过，覆盖上海/洛杉矶18个本地时间边界、5个玩法映射及素材可读性。
- 初次UI失败定位为父容器辅助标识覆盖按钮标识，已移除；第二次为测试对登录sheet结构的假设错误，实际登录页已出现，改为检查“通过 Apple 登录”。失败原图、录像帧、xcresult导出与日志保留。
- 首版SE浅色完整UI通过；其高卡截图仅作过程证据，不代表最终尺寸验收。最终紧凑版另见se-compact日志与截图。
- `gate-compact.log`、`doc-size-compact.log`及git diff --check通过。新截图测试已登记写入面，输出仅限指定隔离目录。

最终截图及补充结果见下方。未测真机、iPad、VoiceOver、大字号、真实登录账号；没有等待真实跨时段长驻切换，边界以单测及临时图片覆盖检验。摄影中球体是装饰，非物理训练画面。

## 最终结果

紧凑版SE浅色UI：`se-compact.log` / `se-compact-raw.log`，TEST SUCCEEDED；五张截图均已目视。标准手机深色夜间：`standard/dark-evening.png`，保留原数据与布局。标准手机实际每日清台点击进入清台场景，未击球或完成挑战；随后重启恢复首页。测试结束恢复系统浅色并无时段覆盖启动。标准深色属于手工截图检查，非独立全套UI自动化。

后续视觉关注：在保持所有控件原位置的约束下，球杆照片会处于右侧按钮和连续天数的背景，当前通过遮罩保证层级；若需进一步减少视觉干扰，应调整素材构图，不移动控件。
