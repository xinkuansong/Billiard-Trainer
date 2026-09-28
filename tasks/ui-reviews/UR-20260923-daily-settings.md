# 每日清台设置入口视觉审查

- 范围：仅FreePlayView的dailyClearance分支，保留工作区既有性能修改。
- 变更：移除独立瞄准模式按钮、2D/3D轨迹chip；右上角菜单增加击球设置，HUD增加只读当前模式。
- 功能验证：最终Debug构建通过（build/daily-settings-20260923/build-final.log，BUILD SUCCEEDED）。CUA实际点击进袋→自由→进袋、轨迹全部→瞄准线→全部、2D→3D→2D，当前值/模式HUD同步，切换未改变杆数和犯规数。未运行XCTest，未验证真机。
- 视觉审查：iPhone 17 Pro/iOS26.3与iPhone SE 3/iOS17，标准字号。主界面与菜单无新增截断，模式信息单行，菜单最长“轨迹显示 · 瞄准线”单行。首版重复“轨迹”导致换行，已精简并重新构建复验。
- 画面使用progress测试球形（2球），与用户截图的15球不同，不能作为同球形渲染对照；本次只验控件布局。改前参考user-before.png为用户提供截图；before.png为启动期间截到的首页，不作有效对照。
- 证据目录：build/daily-settings-20260923/；after-2d.png、menu.png、after-3d.png、after-se.png、menu-se.png。
- 结果：本次范围功能实点与视觉通过，待用户审看；全量无障碍、iPad、真实开球及性能未在本次复验。


## DR-317：横屏大球桌与紧凑球库

- 范围：仅每日清台2D。默认自由瞄准，16球单行居中、最高24pt球径与2pt间距，贴上库边；左24pt瞄准轮、右32pt打点与力度，中央球桌按真实外边界适配。玩法/杆数/用时等不再常驻2D，顶部44pt操作行恢复开球/重打/回放/击球，有多解时显示下一解。3D继续原竖屏布局及独立击球按钮，退出回首页恢复竖屏。
- 交互：力度拖动停稳180ms求解，松手消费最新求解代次且只打一杆；横向拖出取消；新意图、离页、后台取消待击球。共享组件仅通过可选回调启用松手击球，其他页面不启用。
- 标准机iPhone17 Pro/iOS26.3：4项模型测试0失败（landscape-tests.log），1项真实力度取消/松手击球UI通过；入口→横屏→菜单→3D→2D→返回竖屏1项UI在修正关闭菜单查询后通过（landscape-entry-tests.log）。
- SE3/iOS17：力度取消/松手击球1项UI通过（landscape-se-tests.log）；入口/球库同一行/3D与返回1项UI通过（landscape-se-entry-final.log）。iOS17系统菜单不透传子菜单identifier，测试改为同时支持语义label定位，生产代码无需改动。
- 视觉：已逐张核对标准机及SE横屏、菜单、3D竖屏截图，球库单行无截断，六袋完整、控件位于桌外；不是等球形材质对照。最终证据目录build/daily-settings-20260923/landscape-standard与landscape-se。
- 截图工具修正：旋转后app.screenshot产生错误裁切，改用XCUIScreen.main.screenshot记录完整屏幕，未修改图片内容。
- 首轮模型测试中等待没有SCNView的单元宿主完成播放不成立，删除该等待，实际杆末与杆数由UI测试覆盖；失败日志保留。首轮标准机关闭菜单查询、SE子菜单identifier失败亦保留，不计为通过。
- 边界：未做真机触感/持续性能、iPad与完整无障碍矩阵；旧版依赖2D HUD的全套v52 UI用例未整体迁移/执行。本次自动化覆盖新交互及旋转路径，不代表全套回归完成。

- 用户续改：球库按CameraRig真实外框投影定位，贴上库边；两侧改24pt/32pt细条；恢复顶部常驻开球/重打/回放/击球。首版将操作行压到32pt导致返回点击不可靠，恢复44pt触控行后重新验收，保留final-standard.log失败证据。
- 真实自动开球（无fixtureSettled）到可击球已通过；开球不计入用户杆数，测试首次误写1杆，按DailyClearanceController现有语义改为0杆后通过（rail-palette-standard.log、final-standard.log）。没有修改杆数业务。

- 最终续改证据：final-entry-standard.log标准机入口/菜单/3D/返回1项0失败；final-se.log小屏入口与力度交互2项0失败；小屏“松手击球”文字修为完整显示，final-se-caption.log再1项0失败，最终截图已目视复核。final-standard.log中的实际松手击球与真实开球各1项通过；最终gate/doc-size/diff均通过。未安装真机。
