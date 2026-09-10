# UI 审查 — 训练首页辅助功能

日期：2026-09-10。设计 Token 以 Core/DesignSystem 当前源码为准。图片为真实 XCUITest 附件，非生成稿。

## 第一轮标准手机 Light

- 更多菜单：四项文字/图标与分组正确，双人入口移除，本周卡保留现有布局。
- 心得：中文日期、补记标记、真实标题及正文显示正确；可以进入编辑并保存。P2：系统默认搜索抽屉不常显，已改 always，待复验。
- 补记：sheet 取消/保存、日期/分钟/球种与分组输入清晰；中文文本可输入且保存可点。P2：键盘态截屏显示心得输入区域偏低，需确保当前焦点可见并补无键盘全页截图。
- 提醒：自动化 tap 命中 Switch 的行框中点后仍为关闭态。测试改为观察到的控件框右侧开关，并等待星期控件出现；保留原失败录像，不把失败图当通过。
- Dark / SE / iPad：待验证。

来源：output/training-utilities-implementation/ui-light-1-shots/manifest.json；初始 simctl 两张 SpringBoard 图不作为 App 前图证据。

## 标准手机 Light 最终复验

ui-final-light.log 全流程 1/1 通过。8 张命名截图来自同一次真实操作；心得常显搜索、输入焦点文字/光标露出键盘上方、键盘收起按钮与保存可点击；无键盘补记全页已补。提醒星期完整一行、下次日期摘要和帮助层级可读。使用 btPrimary / btBG / btText 系列与系统分组样式，未向详情页扩散首页摄影背景。

## 矩阵首轮纠正

- standard-dark 虽行为通过，但导出的截图仍为浅色，TEST_RUNNER 环境未有效进入测试进程。这轮不能算 Dark 视觉证据；改为独立 Dark selector 显式传 App 启动参数，重跑。
- SE 首轮在分钟键盘仍展开时点击其下被遮住的内容字段，AX 给出了屏外字段，导致无焦点输入。按实际用户流程使用已新增的“收起键盘”按钮切换字段，保留原断言/失败，不用等待掩盖不可点击区域。随后重跑完整小屏表单。

深色根因进一步核对：RootView.uiTestMainColorScheme 只认 v49.forceLight；v54.forceDark 仅在深链分支处理，正常首页流程会忽略。因此并不能据前次推断 TEST_RUNNER 未传递。最终测试改为传入现有 UserPreferences 的 appearanceMode=dark/light，走产品真实外观解析；不修改生产 RootView。此前两个 Dark 名称运行均不计深色证据。

## 最终版本审查

最后统一心得、提醒、帮助隐藏 Tab 栏，与现有计划/设置页一致。`release-style.xcresult` 的 7 项领域测试及标准 iPhone 17 Pro/iOS 26.2 浅色、深色 UI 两项均通过；两套各 9 张真实附件位于 `release-style-shots/Light` 和 `Dark`。最终图已目视心得、帮助、深色提醒和补记：颜色、分组、导航及文字层次统一，无内容被固定底栏遮挡。

`se-release.xcresult` 小屏最终流程通过，心得与提醒截图已审，星期自动换行，输入键盘态当前光标可见。早期 `se-final` 与 `ipad-final` 也均通过；最终 `ipad-release.xcresult` 完整流程 1/1 通过，提醒与补记实际截图已审：顶部 Tab 已隐藏，sheet 在 iPad 居中显示，内容及操作可见。

数据验证覆盖 owner 隔离、非法输入、保存失败原子性、UUID 重试、心得失败回滚与历史权限、补记不产生虚假成绩及来源字段往返。`backend-test.log` 3 项通过；`final-standard.xcresult` 的既有提醒偏好两项及训练目标共享入口一项通过。

静态检查 `gate-release.log` 通过：66 张既有基线、77 条路由、134 个写入面，FAIL=0；只更新已审查的新页面路由签名，未改旧截图基线。`doc-size-release.log`、`diff-check-release.log` 通过。

[查看主要页面实际截图](/Users/song/projects/13.billiard_trainer/output/training-utilities-implementation/REVIEW.md)

边界：未执行真实系统通知授权允许/拒绝 UI 专项，调度权限分支为单元测试证据；未验证真机通知送达、真实账号端到端同步、StoreKit、VoiceOver、大字号或全量回归。未提交、未发布。初始 SpringBoard 图不作为 App 前图，故不宣称完整前后截图基线验收。

最终收尾：`build-final.log` BUILD SUCCEEDED，标准浅/深色、小屏浅色、iPad 浅色共 4 次完整 UI 流程通过；`release-style.xcresult` 7 项领域测试通过。最终源码摘要保存在 `final-source-fingerprints.json`，构建后核验一致。
