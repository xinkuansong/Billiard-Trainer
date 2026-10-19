# 首次填写资料 → 登录账号 · 2026-10-18

## 当前范围与决策（10-18 用户追加修订）

用户要求登录后默认带入首次填写资料，不再出现确认页；同时保留按键操作，介绍与资料步骤使用横向翻页过渡，出生日期默认2000-01-01。

- 游客引导写本机资料；登录/恢复账号后自动将真实填写值带入账号，仅补服务端空白字段。性别“不愿透露”不上传。
- 删除资料带入确认页、拒绝入口和相关路由。账号已有字段优先，后端原子 `$ifNull` 合并契约不变。
- 成功后按游客＋账号标记完成；失败保留本机资料，回到前台或重新登录自动重试，不阻挡登录。请求目标账号和返回会话代际继续校验。
- 资料自动带入与训练记录云同步保持分开；训练记录仍遵循已有用户开关。
- 生日默认2000-01-01；“开始使用”确认保存当前日期，“跳过”不填写。周岁按当前日期计算，生日页显示年龄以供核对。
- 下一步/返回由原按键触发横向翻页；资料选择后自动前进，未添加手势翻页，减少动态效果时直接切页。
- 本轮追加修改已通过11项单测、两尺寸6项UI回归；下文32单测/2UI为旧确认流程的历史记录。

## 后端部署（已完成）

现网 `/opt/qiuji-backend` 三文件：`src/routes/user.js`、`src/services/userProfile.js`、`src/models/User.js`。先逐文件比较确认差异仅本次范围，再备份到 `/root/profile-import-20261018/before.tar.gz`，语法检查后替换并重启 `qiuji-api`。未覆盖环境配置或其他路由。

- 本地完整后端测试 21/21 通过。
- 线上两个独立合成账号验证：未登录401、目标账号不匹配409、四字段导入与MongoDB/GET一致、已有性别/水平保留、追分/其他可写、重复请求保留新值、并发编辑优先、无效400且无写入。账号已全部清除。
- 公网 `/health` 返回 `{"status":"ok"}`。
- 日志/脚本：`output/profile-import-20261018/{deploy.log,backend-tests.log,online-smoke.log,smoke.cjs}`。
- 回滚：解压上述备份到原部署目录并重启 `qiuji-api`；数据不做删除迁移。回滚后新客户端导入会报错并保留本机资料。

- 静态 `verify-gate`、`verify-doc-size`、本次文件 diff 检查通过；新确认页已登记路由覆盖，RootView新增sheet已审计并更新对应签名。

## App 验证

已完成本次功能回归。使用前一轮已验证的独立引导快照作为底座，加本次明确文件；不把共享工作区所有并发修改冒称已验证。

- Mac mini / Xcode26.2 / iOS26.2 / iPhone17Pro：32项单元测试＋2项UI测试全部通过，0失败、0跳过。确认带入、回显、四球种、失败重试和明确不带入已验证；3张原生截图逐张目视。
- 单测覆盖：只有明确填写值可带入、账号已有值优先、需确认、逐账号记住拒绝、失败重试、资料保留、账号切换迟到响应隔离、请求不泄露游客标识。
- UI使用可控登录/后端夹具；实际线上API另以合成账号HTTP＋MongoDB联调。真实Apple/微信登录串到生产服务、真机仍需人工验收。
- 快照commit `d88c5b2bf002afe854e9ecbdd6dd346a5418a56d`，摘要 `e3b786eb0365b5a82bf4cec5a78ca7071cba98a2a3832ef0917e6be4e3ae8cda`；回传校验通过，成功临时设备已受管回收。
- 附加小屏测试尚未执行：远端排队任务已在运行前取消，本机已有任务占用且受管设备容量已满，未覆盖其他任务的数据。补强可点击性断言后的r2在本机Xcode26.3 `build-for-testing`通过；不将编译算作小屏UI通过。生产代码与已通过的r1一致。
- 截图：[原生验证图册](../output/profile-import-20261018/review.html)；结果 `output/profile-import-20261018/phone-r1/evidence/`。
- 未安装真机、未提交主仓库、未发布App。

## 人工试用入口（2026-10-18）

已在本机 iPhone17Pro / iOS26.3（AE86244C-EE61-4585-882F-E39B892214DB）受管借用安装独立副本“CuePhys资料试用”，bundle `com.xinkuan.qiuji.profilepreview20261018`，未覆盖原球迹App或其数据。源为本轮已编译通过的独立快照；只修改副本bundle/display name和扩展标识并重新签名。模拟器已打开到真实训练首页，保留供用户试用。

此入口使用可控登录＋资料带入夹具，不调用真实账号导入。操作：我的 → 登录 → 通过Apple登录 → 带入资料/不带入；带入后进入个人信息查看。用户可自行操作，不将手工打开等同于额外UI测试通过。证据 `output/profile-import-20261018/manual/result.json`；首页已通过窗口截图确认。

用户澄清要试前面的引导页：同一独立副本已改用新首次流程域启动，欢迎页后停在01/瞄准，接六页介绍及四步资料填写；截图已核实。未清空原App或试用副本其他数据。证据 `output/profile-import-20261018/manual/intro-result.json`、`intro-opened.png`。

## 按键翻页、生日与自动带入（追加验证）

- 已移除RootView资料确认sheet及InitialProfileImportView；登录/恢复认证后自动提交，失败在前台恢复或下次登录重试。已有字段、登录代际、目标账号校验保留；导入期间发生的手动编辑优先。
- IntroButtonPager保留按钮操作，以横向位移呈现下一页/上一页；没有滑动切页手势。六页图文及四步资料通过当前页可访问性过滤；减少动态效果时取消动画。
- 默认2000-01-01，确认按钮保存可见日期；跳过仍不保存。ProfileBirthday本来即使用Date.now计算周岁，本次补默认日期和保存逻辑，不把年龄作为持久化值。
- 私有快照构建通过；iPhone17Pro/iOS26.3：11单测＋4UI通过；iPhoneSE3/iOS26.3：介绍巡游及资料跳过/大字2UI通过。截图已检查，六页图片/按钮没有越界；默认生日、保存后回显及自动导入四球种核对通过。
- 首轮两项P8账号UI在setUp失败：测试只跳过旧onboarding标记，仍被新首次流程挡住；修正launchClean，使普通账号测试跳过新流程、专用首次流程fixture保留。原失败xcresult保留，两项原用例重跑通过。
- 证据：`paging-phone.xcresult`（11单测/2UI成功＋2项入口失败）、`auto-import-ui.xcresult`（原2项重跑成功）、`paging-small.xcresult`（2UI）；均位于`output/profile-import-20261018/`。此次未改后端，无需重新部署；真实账号登录和真机未验。
- 独立试用bundle `com.xinkuan.qiuji.onboardingreview20261018`，显示名“CuePhys引导试用”，已受管安装到本机iPhone17Pro，停在01/瞄准，原App数据未覆盖。SE借用后已恢复原关闭状态。手工动作录屏未完成（CUA窗口菜单返回无效元素），`manual/paging.mp4`仅首屏，不用作动画验收；按键前进/返回与禁止手势换页已由UI测试验证，动画观感待用户试用。
- 图册`review.html`已换为新流程；旧确认页归档`review-consent-history.html`，不再作为当前效果。

## 追加左右滑动与返回箭头（2026-10-18）

用户将此前“仅按键”改为同时支持按键与左右滑动。介绍页左滑前进、右滑返回；资料页同样支持，最后生日页左滑不会提交，仍由“开始使用”确认保存。返回统一为chevron.left＋返回，原点击区域不少于44pt。水平手势要求明显横向位移，并以simultaneousGesture与页内纵向ScrollView/生日滚轮共存。实现已完成；本节验证结果追加后方。

实测修复：同时识别水平拖动时，SwiftUI 的选项 Button 曾同时响应选中，出现一次跨两页。现于拖动期间抑制选项点击，触摸事件结束后恢复；GestureState 同时覆盖系统取消手势。标准屏最终回归通过，包含按钮／左右滑动互用、首尾边界、资料页纵向滚动、实际生日滚轮上滑及保存读取。构建和 v47 UI 基线验证通过。原失败保留于 `output/profile-import-20261018/swipe-phone.xcresult`；修复后的标准屏证据为 `swipe-phone-final.xcresult`。

最终结果：标准 iPhone 17 Pro 与 iPhone SE 3 / iOS 26.3 的完整手势回归各 1 项通过（`swipe-phone-final.xcresult`、`swipe-small-final.xcresult`）；六页介绍截图回归另于 `swipe-phone-r2.xcresult` 通过。已查看返回箭头、资料选项和生日截图。试用包 `com.xinkuan.qiuji.onboardingreview20261018` 已更新，本机 iPhone 17 Pro 停在第一页；小屏已恢复 Shutdown。导出时磁盘满，删除本轮无运行进程占用的 `local-build/DerivedData/ModuleCache.noindex` 后成功导出，测试结果保留。未改正式 bundle、未装真机。本次源码 SHA 见 `swipe-source-manifest.json`。

## 欢迎页标语间距（2026-10-18）
用户要求标语贴近品牌名称。`IntroWelcomeView` 将两行文字放入间距 `Spacing.md`（12pt）的组内，原间距24pt；Logo与文字组保持24pt。仅调整排版。build-for-testing通过，标准手机实图已核对；截图与构建日志保存在 `output/profile-import-20261018/welcome-spacing/`。

用户纠正：本次须先核对 Figma，之前直接修改 App 的顺序不符。已读取文件 `C6Qt7HUPFvP13ut8NAZGlU` 的 r6 页 `68:692`，核对正式深色欢迎页 `194:1456` 与 `262:1166`：原图层间距24px。两页品牌名称与标语现以独立Auto Layout组设12px，Logo间距24px保留；新组 `506:1698`、`506:1699`，已查看修改后Figma截图。历史候选／浅色稿未动。此前App已改12pt并更新本机试用版，用户纠正后未继续改App或安装。
