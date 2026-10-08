# B01-SHELL｜全局入口、条件路由和球桌交界

日期：2026-10-08；主控源码复核。8 条边界/系统/内部记录，不等于 8 个普通页面；完整来源见 [JSON](../../../output/app-interface-redesign/B01/SHELL/inventory.json)。本批无运行验证。

## 独立登记

| ID | 对象 | 分类 | 下一步 |
|---|---|---|---|
| P01-01 | 五Tab导航与跨Tab训练胶囊/全屏会话壳 | shell / included | B02优先五根真实导航与训练最小化恢复；B03共享导航单写。 |
| P01-02 | 组间休息锁屏与灵动岛 | system / included | B02-T按系统权限和可用设备单列采集；不能采集则列未验，不用普通App截图代替。 |
| P36 | 每日清台及局内面板边界 | external / external | 仅引用tasks/daily-adaptive/CURRENT.md；本包公共token变化时协调回归。 |
| P37 | 专用球桌/求解/拍照建球形/训练边界 | external / external | B03地图明确边界；tasks/table-page-adaptation/PAGE-INVENTORY.md负责专用页面。 |
| P38-01 | 手机号登录测试保留页 | internal / conditional | 保留为条件页；B02如复验仅使用现有隔离fixture，主流程不扩手机号登录。 |
| P38-02 | 批量出片工作室入口 | internal / conditional | 本轮只登记条件边界，不默认设计内部工作室。 |
| P38-03 | RootView测试深链和取证宿主集合 | internal / conditional | B02主路径必须正常生产入口，测试深链仅补难构造状态；核对输出目录隔离。 |
| P38-04 | 模拟器开发者Pro开关/解锁按钮 | internal / conditional | B02记录fixture授权方式；不将该控件推广到生产UI。 |

## 路由所有权核对

从 MainTabView 的四个 switch 提取 **51 个注册分支**：TrainingRoute 10、AngleRoute 28、TheoryPageID 12、HistoryRoute 1。它们是注册数，不能当成页面数。逐分支去向见 [route-ownership.json](../../../output/app-interface-redesign/B01/SHELL/route-ownership.json)。

- 五根的当前显示名为训练、动作库、练习、记录、我的；Profile自己提供NavigationStack。
- `.theoryIndex` 注册存在，没有定位到生产触发；不能按普通目录页计算生产覆盖。
- `.planList`、`.manualTraining`、History `.detail` 的 typed-route 触发未定位；对应 View 分别通过帮助直接导航、补记sheet、记录详情sheet可达。页面本身有生产入口，并不代表旧 route case 在使用。
- 2D/3D角度或瞄准点是同一View的不同模式入口；P37只有外部边界记录，实际18个专用route在下表逐项列出。
- RootView提取35个识别参数/前缀，见 [launch-arguments.json](../../../output/app-interface-redesign/B01/SHELL/launch-arguments.json)。测试路径只作B02补充，不冒充生产导航。该数是RootView当前方法的token数，不是全App测试参数总数。

| 外部 AngleRoute | 注册锚点 | 管理入口 |
|---|---|---|
| separationAngleAtlas | `QiuJi/App/MainTabView.swift:174` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| cushionEnglishAtlas | `QiuJi/App/MainTabView.swift:176` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| angleDynamic | `QiuJi/App/MainTabView.swift:178` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| geometricQuiz | `QiuJi/App/MainTabView.swift:180` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| sceneAiming2D | `QiuJi/App/MainTabView.swift:182` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| sceneAiming3D | `QiuJi/App/MainTabView.swift:185` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| aimPointTraining | `QiuJi/App/MainTabView.swift:187` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| aimPointScene2D | `QiuJi/App/MainTabView.swift:189` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| aimPointScene3D | `QiuJi/App/MainTabView.swift:191` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| bankShot | `QiuJi/App/MainTabView.swift:195` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| diamondSystem | `QiuJi/App/MainTabView.swift:197` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| shotSimulation | `QiuJi/App/MainTabView.swift:199` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| positionPlayComposer | `QiuJi/App/MainTabView.swift:201` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| freePlay | `QiuJi/App/MainTabView.swift:203` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| positionPlaySolver | `QiuJi/App/MainTabView.swift:206` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| planThree | `QiuJi/App/MainTabView.swift:208` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| snookerTactics | `QiuJi/App/MainTabView.swift:210` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |
| ballExtraction | `QiuJi/App/MainTabView.swift:212` | [球桌专项](../../table-page-adaptation/PAGE-INVENTORY.md) |

## 系统呈现与共用关系

组间休息的 LiveActivity 在 ActiveTrainingViewModel:896 启动，锁屏/灵动岛由独立扩展实现；源基线补充3个扩展Swift文件。代码有锁屏、展开、紧凑、最小布局，系统不允许活动时直接返回，请求失败只写日志。App内截图不能证明这些呈现通过。未发现widgetURL/onOpenURL指定恢复训练路由，不能写成“点击即恢复”。

训练提醒通知在 QiuJiApp:23 挂delegate、:80接pending；TrainingReminderNavigation.consume切训练Tab并清trainingPath，保留训练VM。系统通知授权和提醒设置由T盘点，全局跳转在此记录。系统键盘只作宿主状态；自定义记分键盘由T单独登记component。

开发者Pro控制同时存在于全局设置（SettingsView:299）和购买页（SubscriptionView:293），均为DEBUG+模拟器；两个入口共同归P38-04边界，不视为真实支付证据。

共享文件MainTabView、AppRouter、RootView、QiuJiApp与全局token由公共批单写。读取域也需消费受保护球桌的组件时，空间/手势变化必须联合复验。

## 版本、旧方案和未定位项

v58.4 §4.1覆盖这些域，但P0–P4记录未执行，没有可直接承接的逐页设计审批。旧tab截图是历史候选，本批没有与当前源码匹配，全部当前原生/设计验收仍待核。P36/P37及内部工具由现有专项负责，不改其状态。

| 未定位/未验项 | 负责人 | 下一动作 |
|---|---|---|
| U-S01：LiveActivity当前运行/系统版本与锁屏基线未采集 | B02-T | 专门拍锁屏/灵动岛，记录系统允许状态；无法覆盖则明确未验 |
| U-S02：TheoryIndex已注册，rg只有声明/注册/样式分支，无生产触发 | B01-L/B03-A | L独立核查；B03决定保留注册或是否需要产品入口，本批不新增 |
| U-S03：历史tab截图不能确定与当前源码对齐 | B02各域 | 按当前源码构建，真实生产导航取证 |

## 原始证据

- [源码搜索及完整输出](../../../output/app-interface-redesign/B01/SHELL/source-searches.json)、[扩展源码指纹](../../../output/app-interface-redesign/B01/SHELL/additional-source-hashes.json)。
- [生成脚本](../../../output/app-interface-redesign/B01/SHELL/build_inventory.py)与[初次语法错误记录](../../../output/app-interface-redesign/B01/SHELL/generator-initial-error.txt)保留；修正括号后已生成以上真实文件。
- 主控逐段读根/路由/条件注册、手机号保留页、LiveActivity/提醒链；独立astra审查与最终结构检查在全波收口记录。
