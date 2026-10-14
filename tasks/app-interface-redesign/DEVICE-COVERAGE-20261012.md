# 球迹 App：完整设备与代表测试环境清单

核对日期：2026-10-12。状态：清单已整理，代表分组待运行测量确认；本轮未运行覆盖测试。

## 数量与口径

当前工程最低系统为 iOS / iPadOS 17.0，设备族为 iPhone、iPad。按目前 Apple 已列出的型号统计，工程支持范围候选共 **68 款：36 款 iPhone、32 款 iPad**。容量、颜色、蜂窝/Wi-Fi 和销售地区不重复计数；这不是 App Store 上架兼容性或逐机验收结论。型号来源：[Apple iPhone 清单](https://support.apple.com/en-us/108044)、[Apple iPad 清单](https://support.apple.com/en-us/108043)。

| 统计层级 | iPhone | iPad | 合计 |
|---|---:|---:|---:|
| 型号 | 36 | 32 | **68** |
| 建议代表布局组 | 17 | 11 | **28** |
| 横/竖全屏布局槽位 | 34 | 22 | **56** |
| 横/竖 × 浅/深主题槽位 | 68 | 44 | **112** |

另外建议增加 **12 个设备 × 系统版本组合**，共 **40 个环境组合**；若每页都检查横/竖、浅/深，满矩阵为 **160 个检查槽位/页面状态**。这是排期上限，不是 160 台设备。页面如果仅支持竖屏，不强行展开横屏；一个环境可切换方向和主题，不需为每种状态建立新模拟器。

28 是保守的初始分组方案，不是已经证明等价的最终最小值。同宽高但刘海、安全区、显示倍率或 iPad 系统窗口行为可能不同的型号先拆组；组内复用还需读回 window bounds、safeAreaInsets、size class、displayScale 后确认。几何等价不代表性能或硬件能力等价。

## 本机环境与缺口

- Xcode 26.2（17C52）；已安装 iOS 17.0、26.3 Simulator runtime。18.x、27.x 尚未安装；升级工具链/安装 runtime 后还需核对实际可用组合。
- 28 个代表组中，26 个代表型号有本机 Simulator profile；2 个 iPhone 18 Pro 系列组预留，缺 profile 与 runtime。已有 profile 不等于 App 已启动或该组已验收。
- 68 个型号中，63 个有本机 profile；缺少 iPhone 17e、iPhone 18 Pro、iPhone 18 Pro Max、iPad Air 11-inch (M4)、iPad Air 13-inch (M4)。
- 17e / Air M4 暂按官方显示规格映射到现有组，仍需补实测；18 Pro 系列的新开孔单独预留，逻辑尺寸和安全区不猜测。
- 默认代表 runtime 为 26.3，旧 12.9 英寸 Pro 第二代用 17.0；18 Pro 系列待补 27.x。这不表示组内所有新旧型号都能运行该代表的系统版本。

## 全部型号 → 代表布局环境

尺寸为竖屏逻辑点（pt），横屏交换宽高后仍需考虑系统安全区。尺寸证据来自本机 Simulator profile，不是本轮 App 窗口实测。

### iPhone：17 组 / 36 款

| 组 | 竖屏 pt / 形态 | 代表设备 / 系统 | 映射型号 |
|---|---|---|---|
| P01 | 375 × 667；Home键 | iPhone SE (3rd generation) / 26.3 | iPhone SE (2nd generation)；iPhone SE (3rd generation) |
| P02 | 375 × 812；早期刘海 | iPhone 11 Pro / 26.3 | iPhone XS；iPhone 11 Pro |
| P03 | 375 × 812；mini 12刘海 | iPhone 12 mini / 26.3 | iPhone 12 mini |
| P04 | 375 × 812；mini 13刘海 | iPhone 13 mini / 26.3 | iPhone 13 mini |
| P05 | 414 × 896；刘海，2× | iPhone 11 / 26.3 | iPhone XR；iPhone 11 |
| P06 | 414 × 896；刘海，3× | iPhone 11 Pro Max / 26.3 | iPhone XS Max；iPhone 11 Pro Max |
| P07 | 390 × 844；12系列刘海 | iPhone 12 / 26.3 | iPhone 12；iPhone 12 Pro |
| P08 | 390 × 844；13/14/e系列刘海 | iPhone 13 / 26.3 | iPhone 13；iPhone 13 Pro；iPhone 14；iPhone 16e；iPhone 17e |
| P09 | 428 × 926；12 Pro Max刘海 | iPhone 12 Pro Max / 26.3 | iPhone 12 Pro Max |
| P10 | 428 × 926；13 Max/14 Plus刘海 | iPhone 13 Pro Max / 26.3 | iPhone 13 Pro Max；iPhone 14 Plus |
| P11 | 393 × 852；灵动岛 | iPhone 15 Pro / 26.3 | iPhone 14 Pro；iPhone 15；iPhone 15 Pro；iPhone 16 |
| P12 | 430 × 932；灵动岛 | iPhone 15 Pro Max / 26.3 | iPhone 14 Pro Max；iPhone 15 Plus；iPhone 15 Pro Max；iPhone 16 Plus |
| P13 | 402 × 874；灵动岛 | iPhone 16 Pro / 26.3 | iPhone 16 Pro；iPhone 17；iPhone 17 Pro |
| P14 | 440 × 956；灵动岛 | iPhone 17 Pro Max / 26.3 | iPhone 16 Pro Max；iPhone 17 Pro Max |
| P15 | 420 × 912；Air灵动岛 | iPhone Air / 26.3 | iPhone Air |
| P16 | 待测；新开孔，待测 | iPhone 18 Pro / 27.x | iPhone 18 Pro |
| P17 | 待测；新开孔，待测 | iPhone 18 Pro Max / 27.x | iPhone 18 Pro Max |

### iPad：11 组 / 32 款

| 组 | 竖屏 pt / 形态 | 代表设备 / 系统 | 映射型号 |
|---|---|---|---|
| T01 | 768 × 1024；Home键 | iPad mini (5th generation) / 26.3 | iPad (6th generation)；iPad mini (5th generation) |
| T02 | 810 × 1080；Home键 | iPad (9th generation) / 26.3 | iPad (7th generation)；iPad (8th generation)；iPad (9th generation) |
| T03 | 834 × 1112；Home键 | iPad Air (3rd generation) / 26.3 | iPad Air (3rd generation)；iPad Pro (10.5-inch) |
| T04 | 1024 × 1366；Home键 | iPad Pro (12.9-inch) (2nd generation) / 17.0 | iPad Pro (12.9-inch) (2nd generation) |
| T05 | 744 × 1133；全面屏mini/Touch ID | iPad mini (6th generation) / 26.3 | iPad mini (6th generation)；iPad mini (A17 Pro) |
| T06 | 820 × 1180；全面屏/Touch ID | iPad (10th generation) / 26.3 | iPad (10th generation)；iPad (A16)；iPad Air (4th generation)；iPad Air (5th generation)；iPad Air 11-inch (M2)；iPad Air 11-inch (M3)；iPad Air 11-inch (M4) |
| T07 | 834 × 1194；全面屏/Face ID | iPad Pro (11-inch) (4th generation) / 26.3 | iPad Pro (11-inch) (1st generation)；iPad Pro (11-inch) (2nd generation)；iPad Pro (11-inch) (3rd generation)；iPad Pro (11-inch) (4th generation) |
| T08 | 834 × 1210；全面屏/Face ID | iPad Pro 11-inch (M4) / 26.3 | iPad Pro 11-inch (M4)；iPad Pro 11-inch (M5) |
| T09 | 1024 × 1366；全面屏/Face ID | iPad Pro (12.9-inch) (6th generation) / 26.3 | iPad Pro (12.9-inch) (3rd generation)；iPad Pro (12.9-inch) (4th generation)；iPad Pro (12.9-inch) (5th generation)；iPad Pro (12.9-inch) (6th generation) |
| T10 | 1024 × 1366；全面屏/Air Touch ID | iPad Air 13-inch (M3) / 26.3 | iPad Air 13-inch (M2)；iPad Air 13-inch (M3)；iPad Air 13-inch (M4) |
| T11 | 1032 × 1376；全面屏/Face ID | iPad Pro 13-inch (M4) / 26.3 | iPad Pro 13-inch (M4)；iPad Pro 13-inch (M5) |

### 容易误分的情况

- iPhone 12 mini / 13 mini 的面板为 1080 × 2340，但本机 profile 的默认画布为 1125 × 2436，除以 3 后是 **375 × 812 pt**；不能直接把面板除以 3 写成 360 × 780。
- 375 × 812 的早期刘海与两代 mini、390 × 844 的不同刘海、1024 × 1366 的 Home 键 / Face ID / Air 分开保留，待实际安全区和窗口行为证据决定是否合并。
- 映射是布局测试抽样：例如 P02 在 11 Pro 上测 26.3，不能证明 XS 在 18.x 上的系统行为，因此另设 C06。

## 系统版本补充：12 个组合

在上述 28 个默认组合之外，按最低系统、旧设备最后大版本、重大系统 UI 差异抽样。不是把 68 款全部乘以每个系统。17.0 检查部署下限；执行时再补可获取的最新维护版本，不用模拟器结果代替旧硬件真机。

| 编号 | 设备 | 系统 | 目的 | 本机 runtime |
|---|---|---|---|---|
| C01 | iPhone SE (3rd generation) | 17.0 | 最低系统小屏 | 已安装，未执行 |
| C02 | iPhone 15 Pro | 17.0 | 最低系统灵动岛 | 已安装，未执行 |
| C03 | iPad (6th generation) | 17.0 | 停留17的旧Pad | 已安装，未执行 |
| C04 | iPad Pro (10.5-inch) | 17.0 | 停留17的10.5Pad | 已安装，未执行 |
| C05 | iPad Pro (11-inch) (4th generation) | 17.0 | 最低系统现代Pad | 已安装，未执行 |
| C06 | iPhone XS | 18.x | 停留18的旧手机 | 待补 |
| C07 | iPad (7th generation) | 18.x | 停留18的旧Pad | 待补 |
| C08 | iPhone 16 Pro | 18.x | 26前现代手机 | 待补 |
| C09 | iPad Pro 11-inch (M4) | 18.x | 26前现代Pad | 待补 |
| C10 | iPhone SE (3rd generation) | 27.x | 当前系统最小手机 | 待补 |
| C11 | iPhone 16 Pro | 27.x | 当前系统主力手机 | 待补 |
| C12 | iPad Pro 11-inch (M4) | 27.x | 当前系统现代Pad | 待补 |

## 全屏矩阵之外的补充场景

这些维度不能用有限的型号清单代替。先按高风险代表抽测，不把所有维度机械相乘；下列是待执行范围，不计入 160 个全屏槽位。

| 场景 | 建议代表 | 要核对的状态 |
|---|---|---|
| iPad 窗口宽度 | T08 / T11；旧系统 C05 | 在系统实际允许范围内测试最窄、居中、最大窗口，记录真实 bounds；支持分屏时检查窄侧和宽侧 |
| 连续改变窗口 | T08 / T11 | 拖动缩放跨布局分支，检查内容、导航、弹层和球桌是否丢状态 |
| 键盘与短窗口 | P01 / T05 / T08 | 文本输入、滚动到底、键盘弹出和收起，焦点内容不被遮挡 |
| 字体与辅助功能 | P01 / P13 / T08 | 默认字号与最大辅助字号；VoiceOver 关键流程、粗体文本 |
| 旋转与恢复 | P13 / T08 | 左/右横屏安全区、Pad 倒置方向、后台恢复和旋转前后状态 |
| 硬件与性能 | 可取得的旧款 / 主力真机 | SceneKit 帧率、内存、温升、触觉等单独验收；型号布局映射不覆盖这些结论 |

窗口模式与可用范围依系统、型号和工程配置实际确认，不预设某个固定分屏宽度对所有 iPad 通用。对于窗口连续范围，在端点、布局阈值及阈值两侧取样。

## 后续执行顺序

1. 先用已安装环境测量各组实际窗口与安全区，确认是否需要合并或拆分；首批从已跑通的两台并排开始，资源允许再提高并发。
2. 将同一页面和固定数据投放至代表环境，分批并排预览；优先小屏、主流灵动岛、最大手机、mini Pad、大 Pad。不要一次打开全部 28 个模拟器。
3. 完成 28 组默认布局检查，再补 12 个系统组合及上表风险场景。缺环境的组明确保留“待测”。
4. 每个页面记录状态、主题、方向、构建 SHA、设备/系统、窗口/安全区及问题；修复代码后复验受影响组。截图用于问题证据和版本留档，Figma 不是实时预览的前置步骤。

## 证据与复算

- 工程配置：`project.yml`（iOS 17.0、方向声明）、`QiuJi.xcodeproj/project.pbxproj`（设备族 1,2）。
- 最低系统型号范围：[iOS 17](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-17-iphe3fa5df43/17.0/ios/17.0)、[iPadOS 17](https://support.apple.com/guide/ipad/ipad-models-compatible-with-ipados-17-ipad213a25b2/17.0/ipados/17.0)。
- 新系统兼容范围：[iOS 27](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-27-iphe3fa5df43/ios)、[iPadOS 27](https://support.apple.com/es-mx/guide/ipad/ipad213a25b2/27/ipados/27)。
- 缺本机 profile 的显示规格：[17e](https://support.apple.com/en-us/126470)、[18 Pro](https://support.apple.com/en-us/148590)、[18 Pro Max](https://support.apple.com/en-us/148591)、[Air 11 M4](https://support.apple.com/en-us/126471)、[Air 13 M4](https://support.apple.com/en-nz/126472)。
- 机器可读清单：`output/device-coverage-20261012/inventory.json`；本机 profile：`xcode-device-profiles.json`；runtime：`runtimes.json`；校验：`validation.json`。
- 校验结果：68 个型号无重复，与已保存的 Apple 型号目录过滤结果一致；63 个本机 profile 的逻辑尺寸与分组一致；**本轮实测数量为 0**。
