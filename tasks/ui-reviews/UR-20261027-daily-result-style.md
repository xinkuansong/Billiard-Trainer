# 每日清台入口与结束动作 · 2026-10-27

状态：实现、构建与2项定向UI测试通过；已查看浅深原图，待用户复阅。

## 用户反馈与范围

“这里的继续清台下面的pro相关文字不需要吧，而且这个按键的样式也不对吧，后面两个才是对的吧”。第一张为首页，第二张为结束后的再来一局，第三／四张为正确的浅深双按钮确认框。

- 删除首页周训练卡中的“每日清台每天免费1局，Pro 不限局数”。
- 每日清台2D/3D完成、失败的单动作复用 `DailyConfirmationCard`：实色 `btBGSecondary`、淡绿 `btPrimaryMuted` 主按钮、原字体/圆角及44pt命中；无标题时不保留空行，第二动作可省略。单操作148pt外框用于紧凑居中卡，原双操作252pt及辅助字号360pt保持。
- 原确认框双按钮、结束信息上方位置、游戏/额度/购买/草稿及点击回调保持。本轮不改普通自由击球、规则选择或其他页面默认。
- 根因：旧结果动作 `BTSceneDecisionActionStyle` 直接将半透明主色叠在台呢上，缺少参考确认框的实色承托；首页说明由单独非会员分支渲染。

## TP局部复核

延续每日CURRENT及Pro执行卡已有清单，本轮仅复核影响项。

|条款|判定|验证范围|
|---|---|---|
|TP08/09|继承既有确认组件的颜色、字体、触点；单动作按业务收紧|浅深原图、紧凑手机；极大字号待验|
|TP16/24|继承同一2D/3D居中覆盖层；结果单按钮按参考卡呈现|两模式完成/失败截图及真实点击|
|TP25/26|继承原replay/requestDailyRerack及数据行为|实际重开后manualRacked、杆数0；权限业务未修改|
|TP35/36|按本次局部范围验证，独立记录未验边界|标准手机正在保留用户现场，本轮不占用；不以小屏覆盖全设备|

## 证据

- 用户技术before：`output/daily-result-style-20261027/user-before-home.png` 与 `user-before-result.png`；参考为用户本轮第三／四张。用户设备截图与模拟器夹具的球形/设备不同，不作逐像素同条件比较。
- 本轮标准手机已Booted且为保留复验现场，使用受管compact-phone（SE3/iOS26.3）。
- 原生执行：沿用结果动作回归并扩展浅深外观，复用周训练首页浅深截图测试。
- 功能：`DailyAdaptivePanelUITests/testDailyResultLastActionsRemainReadableAndReachable`通过，覆盖浅/深×2D/3D×完成/失败8组；每组真实点击，失败态进入原双按钮确认后重开，验证manualRacked及0杆。`TrainingAtmosphereUITests/testWeeklyCardResponsiveBackground`通过，检查首页浅深布局及入口可达。实际 `Executed 2 tests, with 0 failures`，共145.013秒。
- 日志：`output/local-test-runs/831130fecb534da1b47dbae71e396cc2/evidence/test-results.log`；完整截图/AX/manifest：`output/daily-result-style-20261027/compact/`，首页截图：同目录`home/`。
- 视觉：已打开8组结果原图、浅深双按钮确认代表图及首页浅深图；结果卡不透台呢，文字完整、两模式居中，原确认卡保留；首页无Pro说明、周卡内容和入口完整。首页夹具为“每日清台”，与“继续清台”共用同一周卡布局；未沿用历史截图宣称新代码已验证。
- 静态：`git diff --check`、`make -f scripts/Makefile verify-doc-size`通过；未运行全仓verify-gate。
- 共享组件影响：其他现有消费者（自定义球形、编排、多球重开及换玩法）仍传入完整非空标题/双动作，源码路径与原尺寸不变；本轮仅对每日原确认实屏回归，不宣称全消费者UI验收。
- 资源收尾：xcodebuild最终 `TEST SUCCEEDED`、exit 0；受管设备已关机归还，独占构建目录自动回收约1.52GB，日志/xcresult/原图保留。测试后附加simctl诊断采集停滞超过3分钟，采样确认仅等待diagnose；停止本轮该子进程后正常完成归档。未跳过或修改任何测试断言；诊断停滞与处理记录在 `output/daily-result-style-20261027/diagnostic-stop.txt`，xcresult可正式读回。
- 真机、iPad、标准手机、最大字号、VoiceOver、真实购买、用户认可：未验；未安装用户真机、未提交或发布。
