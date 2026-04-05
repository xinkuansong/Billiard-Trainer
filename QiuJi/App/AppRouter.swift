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
        case .angle:        return "角度"
        case .history:      return "记录"
        case .profile:      return "我的"
        }
    }

    var icon: String {
        switch self {
        case .training:     return "dumbbell.fill"
        case .drillLibrary: return "list.bullet.rectangle"
        case .angle:        return "angle"
        case .history:      return "clock.arrow.circlepath"
        case .profile:      return "person.circle"
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

    @Published var minimizedTrainingVM: ActiveTrainingViewModel?

    var isTrainingMinimized: Bool { minimizedTrainingVM != nil }

    func minimizeTraining(_ vm: ActiveTrainingViewModel) {
        minimizedTrainingVM = vm
    }

    func resumeTrainingVM() -> ActiveTrainingViewModel? {
        let vm = minimizedTrainingVM
        minimizedTrainingVM = nil
        return vm
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
