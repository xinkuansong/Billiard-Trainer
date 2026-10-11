# 全App方案源码锚点 v2.0

核实日期：2026-10-11。本次读取现行工作区的核心入口、相关布局/状态与调用片段；表中符号和行号另由实际文本核对。**这是规划锚点，不是全文件审计、构建或运行证明。** 执行前按符号重定位；HEAD不能代表dirty源码。逐文件hash见[原始清单](../../output/app-interface-redesign/plan-v2/source-anchors.json)。

| 文件 | 实际符号与行号 |
|---|---|
| [QiuJi/App/AppRouter.swift](/Users/song/projects/13.billiard_trainer/QiuJi/App/AppRouter.swift:42) | `final class AppRouter: ObservableObject {` L42 |
| [QiuJi/App/MainTabView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/App/MainTabView.swift:3) | `struct MainTabView: View {` L3 |
| [QiuJi/App/RootView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/App/RootView.swift:5) | `struct RootView: View {` L5 |
| [QiuJi/Core/DesignSystem/Spacing.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Spacing.swift:3) | `enum Spacing {` L3 |
| [QiuJi/Core/DesignSystem/Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift:15) | `extension Font {` L15 |
| [QiuJi/Core/DesignSystem/Colors.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Colors.swift:5) | `extension Color {` L5<br>`extension ShapeStyle where Self == Color {` L58<br>`extension Color {` L99 |
| [QiuJi/Core/Components/BTButton.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTButton.swift:5) | `enum BTButtonStyle {` L5 |
| [QiuJi/Core/Components/BTFilterChip.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTFilterChip.swift:6) | `struct BTFilterChip: View {` L6 |
| [QiuJi/Core/Components/BTSegmentedTab.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTSegmentedTab.swift:3) | `struct BTSegmentedTab<T: Hashable>: View {` L3 |
| [QiuJi/Core/Components/BTDrillCard.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTDrillCard.swift:5) | `struct BTDrillCard: View {` L5<br>`struct BTTemplateCard<Management: View>: View {` L342<br>`private struct BTTemplateHeaderLayout: Layout {` L439 |
| [QiuJi/Core/Components/BTContentGridCard.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTContentGridCard.swift:7) | `struct BTContentGridCard<Cover: View, Meta: View>: View {` L7 |
| [QiuJi/Features/Training/Views/TrainingHomeView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/TrainingHomeView.swift:4) | `struct TrainingHomeView: View {` L4 |
| [QiuJi/Features/Training/Views/PlanListView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/PlanListView.swift:18) | `struct PlanListView: View {` L18 |
| [QiuJi/Features/Training/Views/PlanDetailView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/PlanDetailView.swift:52) | `struct PlanDetailView: View {` L52 |
| [QiuJi/Features/Training/Views/CustomPlanBuilderView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/CustomPlanBuilderView.swift:19) | `struct CustomPlanBuilderView: View {` L19 |
| [QiuJi/Features/Training/Views/ActiveTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/ActiveTrainingView.swift:4) | `struct ActiveTrainingView: View {` L4 |
| [QiuJi/Features/Training/Views/DrillRecordView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/DrillRecordView.swift:3) | `struct DrillRecordView: View {` L3 |
| [QiuJi/Features/Training/Views/TrainingNoteView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/TrainingNoteView.swift:3) | `struct TrainingNoteView: View {` L3 |
| [QiuJi/Features/Training/Views/TrainingSummaryView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/TrainingSummaryView.swift:3) | `struct TrainingSummaryView: View {` L3 |
| [QiuJi/Features/Training/Views/TrainingShareView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/TrainingShareView.swift:4) | `struct TrainingShareView: View {` L4 |
| [QiuJi/Features/Training/Views/Utilities/TrainingNotesView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/Utilities/TrainingNotesView.swift:32) | `struct TrainingNotesView: View {` L32 |
| [QiuJi/Features/Training/Views/Utilities/ManualTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/Utilities/ManualTrainingView.swift:4) | `struct ManualTrainingView: View {` L4 |
| [QiuJi/Features/Training/Views/Utilities/TrainingReminderView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/Utilities/TrainingReminderView.swift:3) | `struct TrainingReminderView: View {` L3 |
| [QiuJi/Features/Training/Views/Utilities/TrainingHelpView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/Utilities/TrainingHelpView.swift:3) | `struct TrainingHelpView: View {` L3 |
| [QiuJi/Features/DrillLibrary/Views/DrillListView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/DrillLibrary/Views/DrillListView.swift:4) | `struct DrillListView: View {` L4 |
| [QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:4) | `struct DrillDetailView: View {` L4 |
| [QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift:24) | `struct DrillTutorialView: View {` L24 |
| [QiuJi/Features/AngleTraining/Views/AngleHomeView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AngleHomeView.swift:140) | `struct AngleHomeView: View {` L140 |
| [QiuJi/Features/AngleTraining/Theory/TheoryIndexView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Theory/TheoryIndexView.swift:10) | `struct TheoryIndexView: View {` L10 |
| [QiuJi/Features/AngleTraining/Theory/TheoryT01View.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Theory/TheoryT01View.swift:17) | `struct TheoryT01View: View {` L17 |
| [QiuJi/Features/History/Views/HistoryCalendarView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/History/Views/HistoryCalendarView.swift:8) | `struct HistoryCalendarView: View {` L8 |
| [QiuJi/Features/History/Views/StatisticsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/History/Views/StatisticsView.swift:5) | `struct StatisticsView: View {` L5 |
| [QiuJi/Features/History/Views/TrainingDetailView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/History/Views/TrainingDetailView.swift:30) | `struct TrainingDetailView: View {` L30 |
| [QiuJi/Features/History/Views/TrainingDataEditorView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/History/Views/TrainingDataEditorView.swift:176) | `struct TrainingDataEditorView: View {` L176 |
| [QiuJi/Features/AngleTraining/Views/AngleSessionDetailView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AngleSessionDetailView.swift:16) | `struct AngleSessionDetailView: View {` L16 |
| [QiuJi/Features/Profile/Views/ProfileView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/ProfileView.swift:4) | `struct ProfileView: View {` L4 |
| [QiuJi/Features/Profile/Views/PersonalInfoView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/PersonalInfoView.swift:4) | `struct PersonalInfoView: View {` L4 |
| [QiuJi/Features/Profile/Views/TrainingGoalView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/TrainingGoalView.swift:76) | `struct TrainingGoalView: View {` L76 |
| [QiuJi/Features/Profile/Views/FavoriteDrillsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/FavoriteDrillsView.swift:4) | `struct FavoriteDrillsView: View {` L4 |
| [QiuJi/Features/Profile/Views/LoginView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/LoginView.swift:3) | `struct LoginView: View {` L3 |
| [QiuJi/Features/Profile/Views/SubscriptionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/SubscriptionView.swift:4) | `struct SubscriptionView: View {` L4 |
| [QiuJi/Features/Profile/Views/SubscriptionStatusView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/SubscriptionStatusView.swift:3) | `struct SubscriptionStatusView: View {` L3 |
| [QiuJi/Features/Profile/Views/OnboardingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/OnboardingView.swift:5) | `struct OnboardingView: View {` L5 |
| [QiuJi/Features/Profile/Views/AboutView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/AboutView.swift:4) | `struct AboutView: View {` L4 |
| [QiuJi/Features/Profile/Views/SettingsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/SettingsView.swift:3) | `struct SettingsView: View {` L3 |
| [QiuJi/Features/Profile/Views/AppearanceCombinationPreview.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/AppearanceCombinationPreview.swift:5) | `struct AppearanceCombinationPreview: UIViewRepresentable {` L5 |
| [QiuJi/Features/Profile/Views/BallStickerSettingsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/BallStickerSettingsView.swift:3) | `struct BallStickerSettingsView: View {` L3 |
| [QiuJi/Features/Profile/Views/CueStyleSettingsView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/CueStyleSettingsView.swift:3) | `struct CueStyleSettingsView: View {` L3 |
| [QiuJi/Features/Profile/Views/RoomStyleSelectionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/RoomStyleSelectionView.swift:4) | `struct RoomStyleSelectionView: View {` L4 |
| [QiuJi/Features/Profile/Views/TableStyleSelectionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/TableStyleSelectionView.swift:4) | `struct TableStyleSelectionView: View {` L4 |
| [QiuJi/Features/Profile/Views/ClothColorSelectionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/ClothColorSelectionView.swift:4) | `struct ClothColorSelectionView: View {` L4 |
| [QiuJi/Features/PositionPlay/Views/FreePlayView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:18) | `struct FreePlayView: View {` L18 |

## 重要调用/约束锚点

- `MainTabView` L7/72/79：五Tab、最小化训练胶囊、全屏会话；L136起训练路由、L158起练习目的地、L233起理论注册。行号用于定位，当前正文是最终依据。
- `BTDrillCard.swift` L342：BTTemplateCard；L439起BTTemplateHeaderLayout：卡高由文字决定，封面单独计算。首页和货架调用同一组件。
- `ActiveTrainingView.swift` L894：DrillPickerSheet；CustomPlanBuilderView L51调用，非独立文件组件。
- `HistoryCalendarView` L26/59/76：记录与统计宿主、训练详情与认知详情sheet；TrainingDetailView L115起共享分享/编辑。
- `DrillTutorialView` L60/77：单/多球形与全屏媒体；MainTabView理论注册不证明TheoryIndex生产可达。
- `OnboardingView` L100：生产body强制dark；RootView L55测试入口主题另有逻辑。SubscriptionView L24–77为实际body，不能沿用旧摘要假定它同样强制dark。
- `FreePlayView` L103/115起entryMode：每日/普通/模拟分支共文件，专项所有权与验证不能按文件名粗分。

## 文档/代码漂移

旧UI-IMPLEMENTATION-SPEC摘要所称产品介绍强制light与当前源码不符，先登记来源冲突并在相关族核真实启动链；不在本次规划中修改App外观或假称已修规范。球桌子项详细代码保持专项锚点，本包只核路由/边界，未逐一重审渲染实现。
