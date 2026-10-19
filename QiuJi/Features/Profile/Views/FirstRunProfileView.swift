import SwiftUI

struct FirstRunProfileView: View {
    let ownerKey: String
    let onFinish: () -> Void
    var onBackToIntroduction: (() -> Void)? = nil
    @EnvironmentObject private var authState: AuthState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = InitialProfileDraft()
    @State private var step: Step = .sport
    @State private var errorMessage: String?
    @State private var isPagingDrag = false
    // “开始使用” confirms the visible wheel date; skipping leaves birthday unset.
    @State private var birthday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1))!

    private enum Step: Int, CaseIterable {
        case sport, years, gender, birthday
        var question: String {
            switch self {
            case .sport: "你主要打哪种球？"
            case .years: "你打台球多久了？"
            case .gender: "你的性别是？"
            case .birthday: "你的生日是？"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                IntroHeader(skipID: "firstRun.skip") { advance(saveBirthday: false) }
                HStack {
                    IntroBackButton(action: back).accessibilityIdentifier("firstRun.back")
                    Spacer()
                }.padding(.horizontal, 24)
                IntroPager(selection: step.rawValue, count: Step.allCases.count,
                           onSwipeForward: { if step != .birthday { advance() } },
                           onSwipeBack: back,
                           onDragActivity: { isPagingDrag = $0 }) { index in
                    let page = Step(rawValue: index)!
                    VStack(spacing: 0) {
                        Text("认识一下你 · \(page.rawValue + 1) / 4")
                            .font(.btOnboardingChapter).foregroundStyle(.btPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 28)
                            .accessibilityIdentifier("firstRun.profileTitle")
                        GeometryReader { area in
                            ScrollView {
                                VStack(spacing: 0) {
                                    Text(page.question).font(.btOnboardingMessage).foregroundStyle(.btText)
                                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, minHeight: max(70, area.size.height * 0.22))
                                    choices(for: page)
                                    if let errorMessage {
                                        Text(errorMessage).font(.btFootnote).foregroundStyle(.btDestructive)
                                            .padding(.top, 16).accessibilityIdentifier("firstRun.error")
                                    }
                                }.padding(.horizontal, 28).frame(minHeight: area.size.height, alignment: .top)
                            }
                        }
                    }
                }
                IntroProgress(count: 4, selection: step.rawValue).padding(.vertical, 16)
                Group {
                    if step == .birthday {
                        Button("开始使用") { advance(saveBirthday: true) }
                            .buttonStyle(IntroPrimaryButtonStyle()).accessibilityIdentifier("firstRun.save")
                    } else {
                        Color.clear.frame(height: 56).accessibilityHidden(true)
                    }
                }.padding(.horizontal, 28).padding(.bottom, 16)
            }.frame(maxWidth: 600).frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(IntroBackground()).preferredColorScheme(.dark)
    }

    @ViewBuilder private func choices(for page: Step) -> some View {
        switch page {
        case .sport:
            optionList(PreferredSport.onboardingChoices, selected: draft.preferredSport, id: "sport", title: { $0.displayName }) {
                draft.preferredSport = $0; advance()
            }
        case .years:
            optionList(YearsPlaying.allCases, selected: draft.yearsPlaying, id: "years", title: { $0.displayName }) {
                draft.yearsPlaying = $0; advance()
            }
        case .gender:
            optionList([ProfileGender.male, .female, .unspecified], selected: draft.gender, id: "gender",
                       title: { $0 == .unspecified ? "不愿透露" : $0.title }) {
                draft.gender = $0; advance()
            }
        case .birthday:
            DatePicker("生日", selection: $birthday,
                       in: ProfileBirthday.date("1900-01-01")!...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN"))
                .accessibilityIdentifier("firstRun.birthday")
                .environment(\.calendar, Calendar(identifier: .gregorian))
            if let age = ProfileBirthday.age(ProfileBirthday.string(birthday)) {
                Text("\(age) 岁")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .accessibilityIdentifier("firstRun.age")
            }
        }
    }

    private func optionList<Value: RawRepresentable & Hashable>(
        _ options: [Value], selected: Value?, id: String, title: @escaping (Value) -> String,
        choose: @escaping (Value) -> Void
    ) -> some View where Value.RawValue == String {
        VStack(spacing: 14) {
            ForEach(options, id: \.self) { option in
                Button {
                    guard !isPagingDrag else { return }
                    choose(option)
                } label: {
                    HStack {
                        Text(title(option)).font(.btBodyMedium).foregroundStyle(.btText)
                        Spacer()
                        BTSelectionIndicator(isSelected: selected == option)
                    }
                        .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected == option ? Color.btPrimary : Color.btSeparator))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("firstRun.\(id).\(option.rawValue)")
                    .accessibilityValue(selected == option ? "已选" : "未选")
                    .accessibilityAddTraits(selected == option ? .isSelected : [])
            }
        }
    }

    private func advance(saveBirthday: Bool = false) {
        errorMessage = nil
        if step == .birthday {
            draft.birthDate = saveBirthday ? ProfileBirthday.string(birthday) : nil
            let profile = OwnerProfileStore(ownerKey: ownerKey)
            if profile.saveInitialProfile(draft, authState: authState) { onFinish() }
            else { errorMessage = profile.errorMessage }
        } else {
            withAnimation(reduceMotion ? nil : BTMotion.easeInOutChrome) {
                step = Step(rawValue: step.rawValue + 1)!
            }
        }
    }

    private func back() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            withAnimation(reduceMotion ? nil : BTMotion.easeInOutChrome) { step = previous }
        }
        else { onBackToIntroduction?() }
    }
}

#Preview {
    FirstRunProfileView(ownerKey: "guest:preview", onFinish: {})
        .environmentObject(AuthState())
}
