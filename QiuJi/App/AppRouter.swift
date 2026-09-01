import SwiftUI

enum AppTab: Int, CaseIterable {
    case training = 0
    case drillLibrary
    case angle
    case history
    case profile

    var title: String {
        switch self {
        case .training:     return "训练"
        case .drillLibrary: return "动作库"
        case .angle:        return "练习"
        case .history:      return "记录"
        case .profile:      return "我的"
        }
    }

    var icon: String {
        switch self {
        case .training:     return "dumbbell.fill"
        case .drillLibrary: return "list.bullet.rectangle"
        case .angle:        return "scope"
        case .history:      return "clock.arrow.circlepath"
        case .profile:      return "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .drillLibrary: return "list.bullet.rectangle.fill"
        case .profile:      return "person.circle.fill"
        default:            return icon
        }
    }

}


@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .training
    @Published var trainingPath = NavigationPath()
    @Published var drillLibraryPath = NavigationPath()
    @Published var anglePath = NavigationPath()
    @Published var historyPath = NavigationPath()
    @Published var profilePath = NavigationPath()

    /// 「训练计划」列表上次点开的计划 id（官方 planId 或自定义 UUID 串）。
    /// 不发 published：只在 pop 时读，避免无关刷新。
    var planListRestoreID: String?

    @Published var activeTrainingMode: TrainingMode?
    @Published var minimizedTrainingVM: ActiveTrainingViewModel?
    var activeTrainingVM: ActiveTrainingViewModel?

    var isTrainingMinimized: Bool { minimizedTrainingVM != nil }

    func startTraining(mode: TrainingMode) {
        let vm = ActiveTrainingViewModel(mode: mode)
        activeTrainingVM = vm
        activeTrainingMode = mode
    }

    func resumeMinimizedTraining() {
        guard let vm = minimizedTrainingVM else { return }
        vm.expandRestOverlay()
        minimizedTrainingVM = nil
        activeTrainingVM = vm
        activeTrainingMode = vm.mode
    }

    func minimizeTraining(_ vm: ActiveTrainingViewModel) {
        minimizedTrainingVM = vm
    }

    func onTrainingDismissed() {
        activeTrainingVM = nil
    }

    func switchTab(_ tab: AppTab) {
        selectedTab = tab
    }

    func resetCurrentTabStack() {
        switch selectedTab {
        case .training:     trainingPath = NavigationPath()
        case .drillLibrary: drillLibraryPath = NavigationPath()
        case .angle:        anglePath = NavigationPath()
        case .history:      historyPath = NavigationPath()
        case .profile:      profilePath = NavigationPath()
        }
    }
}
