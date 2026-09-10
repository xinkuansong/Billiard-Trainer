# UI 审查与交付记录 — 我的概览、菜单、默认玩法

日期：2026-09-10；DR-135。范围为用户确认的四项调整；未提交或发布。

## 结果

- 本月概览保留自然月及原训练量/最长连续口径，使用整数时长生成“2 小时 35 分”；数字20pt、单位12pt，三项独立浅绿/浅蓝/浅暖橙背景。常规三列按内容分配宽度；极窄且长时长时用标签左/数值右的紧凑行。0分钟与整小时正确显示。
- 菜单及目标页统一“收藏”“设置”；次组顺序为设置→认识球迹→关于与反馈，原导航/会员及普通灰色图标保留。已有UI回归选择器同步改名。
- 未手动选择时，默认玩法读取当前owner资料；资料成功保存、账号恢复、重启均会更新。两者保留上次推导，无历史时中八。推导值与显式选择分开保存；旧版本已有的显式选择继续优先。手动选择不被资料覆盖，已有草稿不受影响。

## 功能验证

- `output/profile-refinement-20260910/build.log`：最终 Debug **BUILD SUCCEEDED**。
- `final-light.log`：**TEST SUCCEEDED**，46项单元测试（StatisticsViewModelTests 30、DailyClearanceControllerTests 12、资料/默认玩法4）通过，另有1项真实页面导航测试通过。
- 资料测试覆盖自动跟随、手选同值/异值后保持、旧显式值、两者及重启、游客/账号切换与恢复、资料保存失败不改变默认。清台原控制器测试覆盖新局与草稿恢复。
- 页面 `testProfileRefinementNavigationAndDefaultGame` 在 iPhone17Pro/iOS26.3 浅色与深色、iPhoneSE3/iOS26.3浅色通过。检查菜单顺序、设置标题、账号默认9球、收藏目标页、认识球迹入口。深色提亮后 `confirmed-dark.log` 再次通过；窄屏长值最终组件重新渲染。
- 补充iPhoneSE3实际设置选择/重启/草稿回归：`testSettingsShowsFiveGamesPersistsAndDoesNotReplaceDraftGame`通过（`settings-draft.log`，TEST SUCCEEDED），验证五种玩法可选、手动选择重启保持、已有草稿仍保留原玩法。
- `verify-doc-size.log` 通过，`git diff --check`通过。

## 视觉审查

- 改前：独立iPhone17Pro模拟器运行原页面，`before-ui.xcresult`测试通过；原图位于 `before-attachments/`，已打开目视。
- 改后：`profile-refinement-profile-light.png`、`profile-refinement-profile-dark.png`、`profile-refinement-profile-compact.png`，以及对应menu/settings图。实际全页无截断、指标层级清晰、图标未额外着色；小屏通过滚动进入次级菜单。标准手机前后均为同一离线账号空记录状态。
- `cards/`：真实ProfileMonthlyOverviewCard的24个渲染组合，宽320/375/402pt × 浅/深色 × 0/60/155/6005分钟。代表性普通、零值、整小时、窄屏长值与深色原图已目视；8天/155分/6天是组件测试数据，不是用户实际记录。
- 首次窄屏长值回退为三块纵向卡，复核后改为更紧凑的数据行；深色绿色小字对比不足，新增局部语义色提高对比。`overview-contrast.json`计算三个指标文字与自身底色的对比为5.36–6.85（不是全App无障碍认证）。

## 未通过项与证据边界

- 第一次完整测试构建在并行 `AimCloseupPlacementTests.swift` 尚未同步实现时因缺少projected方法失败。原 `before.log`保留；临时仅UI的scheme取得改前截图，随后全scheme已能编译，临时scheme已移除并归档到证据目录。
- 首次扩大执行现有V53ProfilePreferencesTests时，4个StoreKit测试失败（商品数组为空、notEntitled，共7个失败断言/错误），见 `logic.log`；其余61个测试通过。本轮未修改订阅实现，也未将这些结果算作通过。
- 首次新UI测试因“9球”与真实标签“9 球”的空格不同失败；按既有DailyClearanceGame文案修正断言，保留原 `after-light.log`，后续通过。
- 全仓verify-gate：本次Profile路由改名/重排已经审计并更新覆盖表与对应签名；最终检查停在并行文件 `QiuJiTests/PocketRefactorDiagTests.swift` 新增写盘面尚未登记（`verify-gate-final.log`）。未代改其代码/登记，不宣称全仓门禁通过。
- 未验证真机、真实账号网络保存/跨设备、完整VoiceOver、大字/iPad矩阵；未提交发布。完整App截图使用离线fixture，非用户账号验收。

## 证据位置

全部本轮日志、xcresult、截图、配色计算与临时scheme归档：`output/profile-refinement-20260910/`。并行瞄准、球桌几何及其他原有修改保留。
