# 分组筛选布局局部修复与验收

日期：2026-09-10。范围：练习页分组筛选；动作库同类风险复查。

## U-01 练习页筛选后继承旧滚动位置（P2）
- 原实现：分组/搜索/主题直接替换 LazyVStack 中的 Section，无回顶同步；卡片使用临时 UUID，理区每次计算重建身份。
- 实证：标准手机“学”中滚动后切“理”，首卡在屏幕上方（gap=-283pt）；全部滚动三次后切练停在最后一排，首卡未进入AX树。见 `../../output/group-filter-gap-20260910/before-scroll.log` 与 `before-all-last.png`。
- 用户原图为首排下移、标题下留白；本轮未精确复现该累计路径，不能把已复现的另一方向错位等同原图全量复现。
- 修复：AngleEntry.id 改为稳定 AngleRoute；分组点击（含重复点击）及实际筛选结果变化时，ScrollViewReader 定位当前首分组标题。保留滚动视图身份、吸顶、列宽、卡片样式和业务路由，无人为额外间距、固定延迟或设备分支。

## 动作库检查
三轮分类循环（含先滚动再换组）、连续分类点击、搜索、无结果恢复及详情返回通过；有效首标题到首卡间距均20pt。未确认同类缺陷，未修改 DrillListView / DrillListViewModel。

## 验证与审图
- 标准手机：专用 iPhone 17 Pro / iOS26.2 / Light / large，5 项 UI 用例分批通过。原始 `after-isolated-r2.log` 中4项通过；主题用例修正后 `after-topic-corrected.log` TEST SUCCEEDED（exit 0）。有效首排间距约20pt。
- 小屏：专用 iPhone SE3 / iOS26.2 / Dark / large，2项UI通过（TEST SUCCEEDED、exit 0），三轮全部切练及主题/搜索/空态恢复间距均19.75pt，见 `after-se-dark.log`。
- 已目视标准手机原图：`all-single-2.png`、`group-angleHomeTab_-2-理.png`、`group-sidebar_-2-基础.png`、`practice-topic.png`。首排位置、卡片文字与双列宽度正常；底栏玻璃覆盖与原实现一致；动作库初始数据差异不算本轮样式变更。
- 已目视小屏深色原图 `se-dark-all-single-2.png`、`se-dark-practice-topic.png`：实际深色生效，首排间距无扩大，多分组内容完整；长标题仍为两行。
- 本轮构建由 Makefile test 执行，传播真实 xcodebuild 退出码。定向 diff 检查与 verify-doc-size 通过。

## 证据纠正与边界
- 首轮理区测试误选第二排“切线法则”；按 TheoryCatalog 真源改为首排“30° 法则”。
- 主题测试曾把解区防守卡与理区标题比较；防守主题实际先有理区t08/t10，再有解区防守，按真源改测“风险报酬决策矩阵”。两次原始失败日志和截图保留，均不作为产品缺陷证据，未通过放宽阈值换绿。
- 两次构建基础设施失败（共享DerivedData锁、并行任务新增提醒文件导致工程/源码瞬时不同步）保留在证据README；采用专属DerivedData/UDID后继续。
- 真机原截图精确路径、iPad、VoiceOver、最大动态字号及完整矩阵未验证。未提交、未发布。

完整证据：[README](../../output/group-filter-gap-20260910/README.md)。
