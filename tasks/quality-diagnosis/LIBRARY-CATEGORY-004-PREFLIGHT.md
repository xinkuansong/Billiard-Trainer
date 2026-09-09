# SC16 分类精确集合预飞

2026-09-08；Test Engineer 按 adapter/55规则及角色执行，仅新增草稿和本文。未注册、构建、运行或操作设备。

## 独立输入真源

读取冻结004 `QiuJi/Resources/Drills/index.json` 完整74个ID，并按索引分类路径逐个读取全部74份JSON，核文件内ID与索引一致、无重复。不是全目录glob额外算未收录文件。索引SHA256：`214e783c8935b04cdd8ca1b1eb904632d0b081ca33059ad5318b4b7487bd2400`。

逐项相对路径+NUL+原字节+NUL按索引顺序合并SHA256：`932aea0c4f570745caf789b555666bd217eb03e1f25a4e426491e18353c57134`。正常 `Data/Services/DrillContentService.swift:491–494` 也是从index.allDrillIds加载fallback；没有网络内容刷新或测试写入。预期是冻结资产独立枚举，不调用App过滤函数生成oracle。

全库基线（74，仅离线内容基线；不声明此次UI遍历74项）：

`drill_c012, drill_c009, drill_c022, drill_c001, drill_c010, drill_c023, drill_c011, drill_c013, drill_c032, drill_c033, drill_c052, drill_c053, drill_c063, drill_c072, drill_c076, drill_c077, drill_c078, drill_c003, drill_c004, drill_c014, drill_c015, drill_c016, drill_c017, drill_c018, drill_c020, drill_c021, drill_c073, drill_c074, drill_c075, drill_c024, drill_c025, drill_c026, drill_c027, drill_c028, drill_c029, drill_c030, drill_c031, drill_c083, drill_c084, drill_c005, drill_c034, drill_c035, drill_c036, drill_c037, drill_c038, drill_c039, drill_c040, drill_c041, drill_c042, drill_c079, drill_c080, drill_c081, drill_c082, drill_c044, drill_c045, drill_c046, drill_c047, drill_c048, drill_c049, drill_c050, drill_c051, drill_c054, drill_c055, drill_c056, drill_c057, drill_c058, drill_c060, drill_c085, drill_c064, drill_c065, drill_c068, drill_c069, drill_c070, drill_c071`

实际 `DrillListViewModel.swift:165–172` 分类谓词为主分类等于positioning **或** secondaryCategories包含positioning，结果仍按主分类分组。完整走位集合24：

| ID | 名称 | 主分类 |
|---|---|---|
| drill_c018 | 加塞一库变线 | cueAction |
| drill_c020 | 高杆加塞走位 | cueAction |
| drill_c021 | 低杆加塞走位 | cueAction |
| drill_c030 | 分离角走位应用 | separation |
| drill_c031 | 分离角综合挑战 | separation |
| drill_c005 | 一库走位 | positioning |
| drill_c034 | 不吃库短距离走位 | positioning |
| drill_c035 | 高杆一库走位 | positioning |
| drill_c036 | 低杆一库走位 | positioning |
| drill_c037 | 走位基础 | positioning |
| drill_c038 | 两库走位 | positioning |
| drill_c039 | 直线球组合走位 | positioning |
| drill_c040 | 三库走位 | positioning |
| drill_c041 | 对角走位 | positioning |
| drill_c042 | 初级蛇彩 | positioning |
| drill_c079 | 四球走位 | positioning |
| drill_c080 | 上下半台走位 | positioning |
| drill_c081 | 四球同袋走位 | positioning |
| drill_c082 | 横向蛇彩围 8 | positioning |
| drill_c046 | 控力走位 | forceControl |
| drill_c050 | 软打控力 | forceControl |
| drill_c051 | 全力度走位综合 | forceControl |
| drill_c069 | 中级蛇彩 | combined |
| drill_c071 | 高级蛇彩 | combined |

主分类14+次分类10。若只看到走位组14项会明确失败，不能把不同主分组误视为额外结果。搜索匹配中/英文名称子串；查询“直线”独立全库预期为c012/c009/c022/c001/c072/c039六项，走位交集只有c039。这五项差值让分类重置具备真实判别力。

## 已有证据与本次新增

LIBRARY-BOUNDARY-004-RESULT记录真实1/1、187.261s：搜索“直线出杆”c009/c012→9球c009→清菜单筛选恢复两项，及收藏/取消/两次进程重启。它未检走位主副分类完整集合，本次不重跑收藏。

真实归档 `formal-004-image-viewer-observation-001/screenshots/.../2-terminal-before-termination-AX.txt` 第27/34/66行是三个ScrollView：等级横栏、分类侧栏、结果列；第36行为sidebar_全部，第51行为sidebar_走位，第70行为drillCard_drill_c001。既有实际17Pro画面分别约(0,130,402,44)、(0,182,76,692)、(76,182,326,692)。草稿不硬编码这些frame，使用**唯一含drillCard_按钮的ScrollView**定位结果列。侧栏走位真实label“走位、走位”，故按ID选，不猜label精确等于走位。

`DrillListView.swift:148–214` 为侧栏真实ID与分类回顶动作；231–280为LazyVStack/LazyVGrid及筛选后回顶。首屏可能没有NavigationBar，结果可视区取实际ScrollView/window交集并裁到真实TabBar顶边，不要求全页唯一ScrollView。

## 单方法与有限收集

`QiuJiUITests/LibraryCategoryDiagnosticUITests/testPositioningExactPrimaryAndSecondarySetThenAllResetWithSearch`

正常新磁盘游客（只中文语言参数）→我的真实游客header→动作库无搜索/菜单筛选初始态→点sidebar_走位一次→收集完整24项→正常输入“直线”且键盘关闭→交集c039→点sidebar_全部一次→查询保持，完整六项。

每轮只把**完整frame位于结果可视区**的ID纳入累计集合，不把懒加载所有已挂载节点当已看见。每次滚动为真实结果列可视高度1/3，保留重叠；先等可见ID/frame稳定≥0.7s，再PNG、AX及累计ID日志。全类最多32次、交集最多8次、复位六项最多14次前向手势；预算耗尽硬失败，不无限滚。

到底观测：连续两次实际前向手势后，可见ID及半点量化的卡上下边界均不变，且累计集合必须精确等于独立预期；缺任何ID或出现额外ID均失败。没有生产“到底”AX标识，因此这是**重复滚动无进展的观测判据**，不是读取UIScrollView.contentOffset/contentSize。主控须审末两组PNG/AX与滚动日志确认确处底部，若手势未送达/被吞则保留测试适配问题，不能仅据绿日志宣布到底。完整卡遇高度大于视口无法纳入时会有界失败，不退化成只hittable。

当前基于已观察正常17Pro/large结构；不同尺寸需重新预检，不能把32次预算外推任意AX大字。初始只采全库顶端，不谎称全库74UI遍历；分类24保持完整，复位采用用户授权的有限查询集合。

## 护栏与状态

env支持直接及TEST_RUNNER_前缀：`QD_LIBRARY_CATEGORY_AUTH=NEW_DEDICATED_DISK_GUEST`、`QD_EXPECTED_DEVICE_UDID`等于SIMULATOR_UDID、绝对`QD_SHOT_DIR`。主控新建无凭据设备，不能拿现有用户库冒充。每次新UUID证据子目录、不清库、不收藏、不训练、不数据/身份/Pro/内存fixture。App仅普通语言启动参数，无真实认证网络调用；正常Bundle加载路径已核。

失败throw，teardown先全屏PNG后完整AX再terminate，不清沙盒；每个收集步骤也先PNG后AX。未知唯一节点或首次引导不匹配会原地失败，不猜首按钮/坐标。键盘intro只处理已观察Speed up your typing与唯一Continue，等待消失后再输入。

语法解析命令 `xcrun swiftc -frontend -parse tasks/quality-diagnosis/LibraryCategoryDiagnosticUITests.swift` 退出0；不代表类型编译或实际运行通过。当前1个草稿方法，执行0。分类选择状态无专用AX selected字段，故通过实际精确结果集合验收行为，不虚构selected值。
