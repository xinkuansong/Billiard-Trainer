# B01 最小配置与可靠保存

2026-10-18；需求真源：[方案v1.1](../TABLE-CONTROL-LAYOUT-PLAN-20261017.md)。用户已授权连续执行B01–B12。

已完成类型化模板、页面绑定、设备方向域、共用/2D/3D属性覆盖及纯值解析。稳定页面枚举从显示偏好文件移至独立模型，原枚举值、字段支持和显示偏好行为不变。外围四入口不接入布局。

采用独立 `Application Support/ControlLayouts/layouts-v1.json`，JSON Codable单归档、`Data.write(.atomic)`；主actor串行访问、归档修订与原始字节双重检查。编辑草稿必须持有起点revision；成功写盘后才发布新归档。失败不发布、不清覆盖、不切绑定。另存ID由调用方持有供重试，重复ID被拒绝。坏归档/未来版本保留原字节并阻止写入；显式恢复先成功备份再替换，重读失败保留上次可用内存状态。

另存复制原模板全部配置域，只将明确选中的本页属性按原层级合入并清除；其他属性、模式、域和页面覆盖保留。同值覆盖不会自动消失。缺少能力只在解析时停用，存储不删值。默认输出为空配置，B02继续沿原Foundation绘制，不迁移任何显示偏好。

验证：

- `swift test --package-path output/table-control-layout-20261017/B01/r01/harness`：10项XCTest，0失败。通过符号链接编译实际生产模型/Store及正式测试文件，未复制或替换业务实现。包含真实文件往返、备份、写盘/备份失败注入、修订冲突、第二Store冲突、精确清理与同值覆盖、独立答题入口与域/能力隔离。
- `make -f scripts/Makefile xcodegen`：成功，新增文件进入正式target。
- `make -f scripts/Makefile test TEST_ACTION=build-for-testing TEST_DESTINATION='generic/platform=iOS Simulator' DERIVED_DATA=build/ControlLayoutImplementation TEST_LOG=output/table-control-layout-20261017/B01/r01/ios-build.log TEST_CODE_COVERAGE=NO TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES' TEST_SELECTOR='-only-testing:QiuJiTests/ControlLayoutStoreTests'`：`TEST BUILD SUCCEEDED`，含App及测试target。这是iOS编译证据，10项运行证据来自macOS纯值测试，不冒称模拟器已运行。

证据目录：`output/table-control-layout-20261017/B01/r01/`。现有共享工作区含其他改动，未回退或提交。当前无布局编辑UI；B02开始两个真实宿主的排布验证，B03才开放首个编辑闭环。

设计决定：沿既有本机偏好边界新增独立文件归档，无SwiftData实体/云同步/第三方依赖；原子文件替换可报告真实写入失败，优于使用无抛错保存结果的UserDefaults作为事务载体。2048pt为持久意图的有限偏移上限，实际可用范围由B02测量后的列容量进一步限制，不以该上限推定按钮可移动距离。
