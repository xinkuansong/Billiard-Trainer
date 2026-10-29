# 默认布局直接使用（2026-10-29，DR-410 v5）

用户反馈：点击默认进入修改模式可保留，便于另存个人模板；但默认右侧三点也要能使用，否则无法从其他模板切回默认。

## 实现与范围

- 基线HEAD：`1c296dd5b7df96f627d4261658cdda9fe2b638a7`；开工时宿主和UI测试文件无既有diff，其他并行改动保留。改前画面来自用户每日清台3D截图，归档于`output/layout-default-use-20261029/before-user.png`。
- 根因：`ControlLayoutHost`默认行右侧为无动作的禁用Button，默认名称只创建空草稿，没有直接持久恢复入口。
- 默认三点复用现有侧边子菜单，单行“使用”，按来源锚点定位；默认名称维持可编辑草稿。菜单选择用互斥目标，切到其他模板不残留旧子菜单。
- “使用”复用`FreeControlLayoutStore.restore(page:mode:expectedPageRevision:)`，原子清除当前页/模式覆盖与来源，成功退出编辑，失败显示既有错误且不退出。个人模板及其他页/模式保留；不改变球形、杆参或成绩。
- 共享宿主所有消费者接入；本轮验证目标为每日2D/3D与思路训练2D/3D，不外推全App验收。

## 本轮TP复核

沿用[既有推广记录](LOCAL-ROLLOUT-20261019.md)与[球桌规范TP28](../../docs/design/table-pages/球桌页面统一规范.md#tp28--操作布局编辑)，本轮为局部交互修订。

|影响项|判定与目标|验证|
|---|---|---|
|TP08/09|继承固定深色表面、字体和44pt命中；可用三点使用正常前景|大小屏每日2D/3D、小屏思路2D/3D原图与44pt点击通过|
|TP12/28|按最新用户决定：名称编辑、三点使用；展开不改草稿，成功持久切默认，个人模板可切回|大小屏每日2D/3D切换、取消、重入与个人模板回切通过|
|TP27/30|继承页/正式模式隔离、保存冲突保护与业务状态冻结/恢复|2项既有存储冲突/幂等回归通过；每日与思路UI业务快照不变|
|TP35|构建、交互、原图与真机认可分别记录|原生构建、定向UI及原图分批记录如下；真机/VoiceOver未验|

## 验证与交接

Swift语法解析、局部diff检查通过。iPhone16ProMax/iOS26.3.1首轮受管构建及2项UI、2项存储回归通过；目录`output/local-test-runs/3bf7f66d52b44cb9b7961100b4b7e091`。首轮截图`output/layout-default-use-20261029/screenshots/`。未提交、未发布、未安装真机。

### 10-30跨日复验 / FL-231

首轮原图发现短子菜单偏到上一行，功能通过不算视觉通过。r2新增实际中心对齐断言，global CGRect测量未修复，实测124.67pt对168pt，失败原样留在`output/layout-default-use-20261029/r2-large/`。

r3将默认/个人行的bounds以Anchor传递，在最终覆层GeometryProxy解析；宿主局部pt、x右/y下，无球桌世界系变更、无固定补偿量。r3-large重新构建与每日清台2D/3D原生回归已通过（1项UI测试、0失败），两模式原图已审，使用项与来源行对齐。SE以同一构建完成每日清台及思路训练2D/3D，共2项UI测试、0失败。旧四行菜单的功能测试不替代新单行锚点断言。最终源码副本及SHA位于`output/layout-default-use-20261029/source/`。

### 最终证据索引

|证据|结果/位置|
|---|---|
|存储回归（未改存储层）|首轮2项通过：读取失败/相同restore冲突保护、提交重试幂等与restore后不重放；见受管run的`evidence/test-results.log`|
|r3大屏最终源码|iPhone16ProMax / iOS26.3.1，1项UI（每日2D/3D）通过；`output/layout-default-use-20261029/r3-large/test.log`与`tests.xcresult`|
|r3小屏同一构建|iPhoneSE3 / iOS26.3.1，2项UI通过（思路2D/3D个人菜单、每日2D/3D默认切换），0失败；`output/layout-default-use-20261029/r3-small/`|
|静态门禁|Swift解析、`git diff --check`、`make verify-gate`通过；`output/layout-default-use-20261029/gate-final.log`|
|原图审查与验收边界|已查看最终大小屏每日2D/3D、小屏思路2D默认菜单及个人菜单原图；未验证真机、VoiceOver与iPad，不作全App/发布验收|

收尾：文档体积门禁与最终diff检查通过；受管构建work已回收（约1.54GB），证据保留。两台测试设备均已Shutdown，保留其原有评审配置与数据；见`output/layout-default-use-20261029/cleanup.log`及`final-simulator-inventory.json`。
