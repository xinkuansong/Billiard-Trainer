# 库边颗星等分修正 · 2026-10-19

状态：✅ 模型修正、两次构建、7项不同专项测试及2D/3D原生截图复核完成。未真机安装、提交或发布。

## 问题与修改

用户指出库边白色颗星位置不准，确认后授权按正确等分位置修正并检查2D/3D。

当前内框为2540×1270mm；长边八等分、短边四等分，每格317.5mm。原模型长边相邻点约324.064mm，短边333.669mm，最大沿库偏差19.691mm。依据是本仓物理常量、实际SceneKit加载测量，以及[WPA设备规格 §6](https://wpapool.com/wp-content/uploads/2024/01/RECOMMENDED-EQUIPMENT-SPECIFICATIONS.pdf)。

仅刚性平移18颗星的对应White网格顶点：

- 长库点的X改为±317.5、±635、±952.5mm，保留原Z、Y。
- 短库点的Z改为−317.5、0、317.5mm，保留原X、Y。
- 默认优化资源与备用原资源同时修正，保留旧文件于`output/diamond-position-fix-20261019/backup/`。
- 颗星尺寸、形状、法线、UV及离库鼻距离保持；球、球杆、袋口、库体、台呢与解析物理均未改。
- `ModelAssetTrial`缓存身份及包内SHA测试同步更新。旧测试曾保留更早候选SHA，本轮以实际交付资源校验。

几何坐标：USD为米制Z-up；加载器按实际根变换转为SceneKit的X–Z水平面/Y向上，按原包围盒缩放并将台面抬到0.8m。测量后的缩放仍为0.9967949820895743；外包围盒保持。

旧`BTAimTableView`插图实现也存在颗星分格错误，但本轮检索只有组件内Preview调用，未作为实际训练2D球桌的根因；本次只改实际消费的USDZ资源。

## 验证

- OpenUSD逐属性比对：两份资源各1634个非points属性保持，节点、关系、拓扑、UV、法线、材质保持；41个其余包内文件逐字节相同；USDZ保持64字节对齐。
- 默认资源实际改变1344个顶点，备用资源1152个。差异来自默认资产短库中心点约0.00018mm残差归零，均属于18颗星；短库点的独立底盖随同移动。
- 独立macOS SceneKit重新读取两份候选，分别识别18点；最大沿库等分误差0.00002027mm，外包围盒与加载缩放不变。旧资产在同一0.01mm位置门禁下失败，最大误差19.691mm。
- 生产iOS测试新增：两种资产×2D/3D的18点坐标；普通/移动两种渲染路径×2D/3D截图；每日清台真实页面2D→3D全台→3D沿杆→返回2D截图。
- 同轮运行资源选择/三角形数、整球库体接触包络及袋口捕获轮廓回归。

构建与执行分开记录：Mac mini / Xcode26.2 的 r1 构建通过，但远端模拟器池已达容量，未在远端运行测试，也未清理历史设备。取回构建产物后，在本机显式借用未被固定、无租约的 iPhone16Pro / iOS26.3.1 执行。借用前保存原App与106个数据文件，结束后恢复、逐文件哈希校验并关闭、释放设备。

r1 快照`f1f7a42aead8c11a41277f54a949bcb86ed8ffcba5f62554ff38528f85aa16c2`，封存前后2643个文件哈希一致；7项测试中6项通过、1项UI失败。失败来自测试仍在主界面查找已移入“更多”菜单的2D/3D开关；按当前界面入口修正测试。渲染截图还发现移动路径切换视角会重显房间，遮挡诊断相机，故每次切换后重新隐藏诊断场景的房间节点，不改生产相机或房间逻辑。

r2 快照`63f532b44c983a3f7839e7e6bfc320f9d396cfc16c43f6d50f89241d423dac1a`只修正上述测试操作与诊断截图条件，生产资源保持；重新构建并复跑渲染与原生UI两项。r1失败及附件完整保留，不以r2覆盖。

r2两项复验构建通过，远端仍因同一模拟器池容量限制未跑测试，本机沿用显式借用设备。第一次重新借用时发现旧App安装路径登记失效，备份步骤停止、没有开始测试；保留日志`borrow-phone-r2.log`。重新使用首次备份的原始App、保留原包名“球迹.app”安装，确认安装路径及逐文件SHA后才开始复验。结束恢复也新增App文件SHA核验；数据备份一直保留。

不将后续共享工作区改动计为已测；6个修改的生产/测试文件与r2封存源码相同，包内两份模型SHA与工作区一致，见`tested-source-verification.json`。未做iPad、真机或全套回归。

## 最终结果与图像复核

- r1：6通过、1个UI定位失败；r2：渲染与原生UI两项均通过，0失败、0跳过。合并去重为7项专项测试通过；失败轮次未删除。
- r2的4张原生App图：2D与返回2D中18颗星完整，沿库坐标与台面等分网格逐点对齐；3D全台18点完整，沿杆可见点位置正常，近端短库在既有视角画面之外。模式切换后无点位漂移或丢失。
- r2的4张SceneKit独立渲染图：普通/移动渲染路径各2D/3D，18点完整、左右对称、模型连续；移动3D遮挡诊断已消除。截图由实际加载的修正USDZ生成，不是示意图。
- 原生图：[2D](../output/diamond-position-fix-20261019/app-screenshots-r2/corrected-sights-app-2d.png)、[3D全台](../output/diamond-position-fix-20261019/app-screenshots-r2/corrected-sights-app-3d-overview.png)、[3D沿杆](../output/diamond-position-fix-20261019/app-screenshots-r2/corrected-sights-app-3d-along-cue.png)、[返回2D](../output/diamond-position-fix-20261019/app-screenshots-r2/corrected-sights-app-return-2d.png)。
- 测试结果：`local-test-summary.json`、`local-test-summary-r2.json`；截图映射：`attachments-r2/manifest.json`；恢复App及106数据文件核验：`borrowed-phone-restored-r2.json`。另一次租约下重新启动设备，原App路径与文件SHA正确，启动/终止成功，再恢复数据、关闭并释放，见`restored-app-launch-verification.json`。
- 下一步：用户可根据截图复阅；真机及iPad未验，不作为本次已完成范围。

## 资源与证据

|资源|本轮SHA256|
|---|---|
|ModelTrial20261010_TaiQiuZhuo.usdz|a13d36e2787c6d3afc608cde2e06f7211e12b22b5161e75ed2a78a1507b049d0|
|TaiQiuZhuo.usdz|40b546a554257897c7df78df540b36b0ea3f1f2a3fc592c5d67306b3c632942b|

证据目录：`output/diamond-position-fix-20261019/`；修改脚本`correct_sights.py`；独立位置门禁`verify_positions.py`；结果`position-verification.json`；逐属性/包成员校验`optimized-r4/proof.json`、`original-r4/proof.json`。初次探针的组件计数及AssetPath已解析路径比较失败保留在r1–r3目录；只读源资产未受这些候选失败影响。
