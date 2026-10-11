# DS01 组件与源码对应｜r19主控复核

范围：r18 P02的22画板＋r17 P03的30容量预览。原始审计读取65个实际主组件、48个直接使用变量；2362实例/4058 Text为嵌套库存数量，不代表组件覆盖率。r20/r21后续徽标修订另附修订回执，不能用旧审计冒称新消费者已验。

三手机选中标签10→11pt真实传播到代表实例，导出改变；恢复10pt后3张整页PNG与修改前逐字节一致。无缺字体标志不证明精确字形一致。

| 主组件ID | 名称 | 源文件/符号 | 限制 |
|---|---|---|---|
| 15:5201 | DS01/r4/Background/P02/small | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 28:97072 | DS01/r18/P02/Single | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · activePlanContent / preserveBrowsePosition | r18 derived minHeight and bottom100; entryOffset0 |
| 28:67987 | DS01/r14/WeeklySummary | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · weeklyProgressCard / weeklyDayCell | date/weekly goal/rack photo separate props; shadows precision pending |
| 28:66158 | DS01/r13/Icon/chevron.right | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:66137 | DS01/r13/Icon/BreakRackGlyph | `QiuJi/Core/Components/BTShotPageChrome.swift` · BreakRackGlyph | native source renderer@3x |
| 15:4981 | DS01/r4/WeeklyDay/Today=false | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · weeklyProgressCard / weeklyDayCell | date/weekly goal/rack photo separate props; shadows precision pending |
| 15:4984 | DS01/r4/WeeklyDay/Today=true | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · weeklyProgressCard / weeklyDayCell | date/weekly goal/rack photo separate props; shadows precision pending |
| 15:4944 | DS01/r4/Training/QuickStart | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · 未安排今日训练的分支 | empty-today only; active/complete branches out of pilot |
| 28:66164 | DS01/r13/CustomTabs | `QiuJi/Core/Components/BTSegmentedTab.swift` · BTSegmentedTab | official/custom two states |
| 28:66176 | DS01/r13/Icon/doc.text | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:66182 | DS01/r13/Icon/square.and.pencil | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:67845 | DS01/r14/TemplateCard | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateCard / BTTemplateHeaderLayout | coverSizing needs resolver; native cover bottom clip tracked APP-I003 |
| 28:97500 | P02/CoverDerivedWidth=99 | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateHeaderLayout | helper implements derived width; not automatic variable formula |
| 28:52995 | DS01/TemplateCover/Shared-r11 | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateHeaderLayout | helper implements derived width; not automatic variable formula |
| 28:67897 | DS01/r14/Icon/ellipsis.circle | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:40624 | State=None | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateStatusRow | r20 candidate supersedes macOS glyph / old badge gap |
| 28:67903 | DS01/r14/CreateTemplateButton | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · createTemplateRow | source plus.circle.fill18 regular |
| 28:67908 | DS01/r14/Icon/plus.circle.fill | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:74313 | DS01/r16/Chrome/small | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 28:67980 | DS01/r14/Icon/ellipsis | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:67972 | DS01/r14/Icon/plus | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:74253 | Symbol=training, Scale=2 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:74310 | State=Selected | `QiuJi/App/MainTabView.swift` · UIKit TabView UILabel | actual10 Medium/Semibold,12 frame; exact fallback pending |
| 28:74250 | Symbol=library, Scale=2 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:74308 | State=Normal | `QiuJi/App/MainTabView.swift` · UIKit TabView UILabel | actual10 Medium/Semibold,12 frame; exact fallback pending |
| 28:74247 | Symbol=scope, Scale=2 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:74244 | Symbol=history, Scale=2 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:74241 | Symbol=profile, Scale=2 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:97079 | DS01/r18/P02/Empty | `QiuJi/Features/Training/Views/TrainingHomeView.swift` · activePlanContent / preserveBrowsePosition | r18 derived minHeight and bottom100; entryOffset0 |
| 28:67914 | DS01/r14/EmptyTemplateShelf | `QiuJi/Core/Components/BTEmptyState.swift` · BTEmptyState | secondary action, icon32 medium; phone native overlap preserved |
| 28:67925 | DS01/r14/Icon/list.bullet.clipboard | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 15:7450 | DS01/r4/Background/P02/standard | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 28:52996 | Width=112 | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateHeaderLayout | helper implements derived width; not automatic variable formula |
| 28:74364 | DS01/r16/Chrome/standard | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 28:69794 | Symbol=training, Scale=3 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:69791 | Symbol=library, Scale=3 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:69788 | Symbol=scope, Scale=3 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:69785 | Symbol=history, Scale=3 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 28:69782 | Symbol=profile, Scale=3 | `QiuJi/App/MainTabView.swift` · native TabView image configuration | training/library/profile rendered25; scope/history actual18 Medium Large host |
| 15:9480 | DS01/r4/Background/P02/large | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 28:74419 | DS01/r16/Chrome/large | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:11521 | DS01/r4/Background/P02/pad-portrait | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 28:72485 | DS01/r15/Chrome/pad-portrait | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:13581 | DS01/r4/Background/P02/pad-landscape | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 28:73281 | DS01/r15/Chrome/pad-landscape | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:6724 | DS01/r4/Background/P03/small | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 28:79241 | DS01/r17/PageContent/P03-Capacity | `QiuJi/Features/Training/Views/PlanListView.swift` · PlanListView | capacity candidate; current entry route unconfirmed |
| 15:4972 | DS01/r4/PlanList/OfficialHeader | `QiuJi/Features/Training/Views/PlanListView.swift` · PlanListView | capacity candidate; current entry route unconfirmed |
| 15:29 | DS01/PlanCard | `QiuJi/Core/Components/BTContentGridCard.swift` · BTContentGridCard / BTPlanCover | official shelf card and activation states |
| 15:15734 | State=None | `QiuJi/Core/Components/BTPlanCover.swift` · BTPlanActivationBadge | None variant; actual source file must resolve below |
| 15:19798 | DS01/r7/PlanList/CustomHeader | `QiuJi/Features/Training/Views/PlanListView.swift` · PlanListView | capacity candidate; current entry route unconfirmed |
| 28:80783 | P03/CoverDerivedWidth=99 | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateHeaderLayout | helper implements derived width; not automatic variable formula |
| 31:20 | State=Practice | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateStatusRow | r20 candidate supersedes macOS glyph / old badge gap |
| 15:17110 | DS01/TemplateStatus/Count | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateStatusRow | r20 candidate supersedes macOS glyph / old badge gap |
| 15:17093 | DS01/Icon/chart.bar.fill | `QiuJi/Core/DesignSystem/IconToken.swift` · SF Symbol / caller font | actual iOS source r13/r14 except chart r6 replaced inr20; some effective configs pending |
| 28:79940 | P03/CoverDerivedWidth=44 | `QiuJi/Core/Components/BTDrillCard.swift` · BTTemplateHeaderLayout | helper implements derived width; not automatic variable formula |
| 15:6725 | DS01/r4/Chrome/P03/small | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:8746 | DS01/r4/Background/P03/standard | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 15:8747 | DS01/r4/Chrome/P03/standard | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:10787 | DS01/r4/Background/P03/large | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 15:10788 | DS01/r4/Chrome/P03/large | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:12862 | DS01/r4/Background/P03/pad-portrait | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 15:12863 | DS01/r4/Chrome/P03/pad-portrait | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |
| 15:15012 | DS01/r4/Background/P03/pad-landscape | `QiuJi/Core/Components/BTBlueprintBackground.swift` · BTBlueprintBackground | source-sized decoration; cross-width paths still candidate |
| 15:15013 | DS01/r4/Chrome/P03/pad-landscape | `QiuJi/App/MainTabView.swift` · MainTabView / native navigation host | system material approximation; phone and pad host structure differ |

48变量的直接使用/alias值见component-audit-summary.json；alias终值依赖闭包另待读取，源配对色仍需语义收口。1710个硬编码Solid paint记录包括图标白色alpha、系统参考及装饰等，不能直接作为绑定率分母。

本族来源文件与冻结包对应文件hash已核；源码符号有对应并不证明运行态视觉通过。跨文件库、Code Connect发布、云端恢复均未通过。
