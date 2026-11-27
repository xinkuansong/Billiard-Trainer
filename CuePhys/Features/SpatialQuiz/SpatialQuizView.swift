import SwiftUI

struct SpatialQuizView: View {
    @StateObject private var vm: SpatialQuizViewModel
    @ObservedObject private var owner=CurrentOwnerContext.shared
    @ObservedObject private var preferences=TablePreferencesStore.shared
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionManager
    @StateObject private var notices=BTRuleNoticeCenter()
    @State private var detail:String?
    init(mode:SpatialQuizMode) { _vm=StateObject(wrappedValue:SpatialQuizViewModel(mode:mode)) }
    var body: some View {
        Group {
            if vm.loading { ProgressView("正在读取练习…") }
            else if vm.showsSettings {
                SpatialQuizSettings(vm:vm) { if !vm.cancelSettings() { dismiss() } }.id(owner.ownerKey)
            } else {
                ProAccessGate(requiresPremium:!vm.busy && vm.record?.configuration.freePractice == true &&
                    vm.record?.currentFirst == nil && vm.record?.pending == nil) {
                    table.overlay {
                        if vm.record?.phase == .summary,let record=vm.record {
                            Button(action:vm.reviewLast) { Color.black.opacity(0.45).ignoresSafeArea() }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                            TrainingFinishContent(metrics:[("已练题数","\(record.totalCount)"),("成功率",record.successRate)],
                                onRestart:{vm.openSettings()},onComplete:{dismiss()})
                                .accessibilityIdentifier(vm.identifier+".summary")
                        }
                    }
                }
            }
        }
        .onAppear { vm.limiter.isPremium=subscription.isPremium;vm.attach(context:context) }
        .onChange(of:subscription.isPremium) { _,value in vm.limiter.isPremium=value }
        .onChange(of:owner.ownerKey) { _,_ in vm.ownerChanged() }
        .onChange(of:vm.record?.latestShot?.id) { _,_ in showResult() }
        .onChange(of:vm.session?.activity) { _,_ in if !vm.busy { showResult() } }
        .sheet(isPresented:$vm.needsSubscription) { SubscriptionView() }
        .alert("练习提示",isPresented:Binding(get:{vm.message != nil},set:{if !$0 {vm.message=nil}})) {
            Button("知道了") {vm.message=nil}
        } message: { Text(vm.message ?? "") }
        .onDisappear { notices.clear() }
    }
    private func showResult() {
        guard !vm.busy,let shot=vm.record?.latestShot else { return }
        notices.show(shot.outcome.text,tone:.info,priority:.ruling)
    }
    private var historyMenu:[DailyHUDMenuItem] {
        [
            .init(id:vm.identifier+".route",title:"上一杆路线",selected:vm.showsLastRoute,action:vm.toggleLastRoute),
            .init(id:vm.identifier+".details",title:"上一杆详情",action:{ detail=shotDetails }),
            .init(id:vm.identifier+".normal",title:"正常速度",selected:vm.playbackSpeed==1,action:{vm.playbackSpeed=1}),
            .init(id:vm.identifier+".slow",title:"1/4 慢放",selected:vm.playbackSpeed==0.25,action:{vm.playbackSpeed=0.25}),
            .init(id:vm.identifier+".playerReplay",title:"回放我的击球",disabled:!vm.canReplay,action:vm.replay)
        ]
    }
    private var shotDetails:String {
        guard let shot=vm.record?.latestShot else { return "暂无上一杆" }
        let input=shot.physical.input
        return [shot.outcome.text,
            String(format:"杆速　%.2f m/s",input.speed),
            String(format:"抬杆　%.2f°",input.elevation),
            String(format:"打点　横向 %.2f / 纵向 %.2f",input.spinX,input.spinY),
            String(format:"最高离台　%.1f cm",shot.physical.maximumHeight*100)].joined(separator:"\n")
    }
    private var controls:BTTablePlanningControls {
        var value = BTTablePlanningControls(
            spinX:Binding(get:{vm.displayedInput.spinX},set:{vm.setSpin($0,vm.input.spinY)}),
            spinY:Binding(get:{vm.displayedInput.spinY},set:{vm.setSpin(vm.input.spinX,$0)}),
            transparency:Binding(get:{preferences.snapshot(for:vm.preferencePage)[.transparency]},set:{preferences.apply(.transparency,value:$0,to:vm.preferencePage)}),
            instrumentsEnabled:vm.canAdjust,isAnimating:vm.busy,paletteEnabled:false,
            primaryTitle:vm.primaryTitle,primaryEnabled:vm.primaryEnabled,
            onPrimary:{vm.primary()},onPaletteTap:{_ in},menuItems:[],refreshTrajectory:{vm.refreshAim()})
        value.velocityRange=0.1...8
        value.showsReadOnlyDemonstration=vm.session?.activity == .demonstrating
        value.assessmentMode=true;value.allowsAssessmentAimCloseup=true;value.allowsAssessmentSpinEditing=true
        value.closeupSnapshot=vm.canAdjust ? vm.closeupSnapshot : nil
        value.defersStrikeAccessUntilSubmission=false;value.locksSceneInteraction=vm.busy
        value.allowsObservationWhileAnimating=vm.isTeachingShotRolling
        value.showsPlacementHint=false;value.allowsPocketSelection=false
        value.menuItems=[
            .init(id:vm.identifier+".settings",group:.practice,title:"训练设置",disclosure:true,disabled:vm.busy,action:{vm.openSettings()}),
            .init(id:vm.identifier+".finish",group:.practice,title:"结束练习",disabled:vm.busy,action:{vm.finish()})]
        value.onLayoutEditingChanged={vm.layoutEditingChanged($0)};value.layoutEditingBlocked=vm.busy
        value.onAimNudged={vm.nudgeAim($0)}
        value.resolveP01AimPan=nil // Scene drags observe; only the direction ruler changes aim.
        value.showsAimCloseupSetting=true;value.showsTrajectorySetting=false;value.showsSeparationSetting=false
        value.onSpinChange={vm.setSpin($0,$1)};value.paletteKeys=vm.onTableKeys;value.maximumPaletteCount=2
        value.paletteRoleDescription={ $0 == "_8" ? "黑八障碍球" : "目标球" }
        value.secondaryMenu = .init(id:vm.identifier+".lastShot",title:"上一杆",disabled:vm.busy || vm.record?.latestShot == nil,items:historyMenu)
        return value
    }
    private var information:[BTTeachingInformation] {
        if let notice=notices.message { return [.init(text:notice.text,kind:.notice,symbol:"info.circle",identifier:vm.identifier+".result")] }
        if vm.canAdjust && !vm.cueAccessible { return [.init(text:"球杆受阻，请调整打点、方向或抬杆角度",kind:.notice,symbol:"info.circle",identifier:vm.identifier+".blocked")] }
        return []
    }
    private var table:some View {
        BTTeachingTablePage(vm:vm,titleLabel:vm.mode.title,identifier:vm.identifier,preferencePage:vm.preferencePage,
            fixedView3D:true,velocity:Binding(get:{vm.displayedInput.speed},set:{value in vm.updateInput {$0.speed=value}}),
            planning:controls,supplementalDetail:$detail,supplementalDetailTitle:"上一杆详情",information:information,
            usesStandardTitle:true,fitsLongTitle:true,showsPalette:true,
            pairedLeftContent:{ layout in
                AnyView(VStack(spacing:layout.groupSpacing) {
                    VStack(spacing:0) {
                        Text("题目").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.record?.configuration.freePractice == true ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/15")
                        Text("成功率").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.busy ? "—" : vm.record?.successRate ?? "—")
                    }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
                        .frame(height:layout.topDiameter+14).accessibilityElement(children:.combine)
                        .accessibilityIdentifier(vm.identifier+".questionInfo")
                    BTTeachingAimRuler(layout:layout,enabled:vm.canAdjust,onNudge:vm.nudgeAim,degreesPerPoint:0.2)
                        .accessibilityIdentifier(vm.identifier+".aimWheel")
                    let actions=layout.horizontalActions ? AnyLayout(HStackLayout(spacing:layout.groupSpacing)) : AnyLayout(VStackLayout(spacing:layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title:"重打",symbol:"arrow.uturn.backward",size:layout.auxiliarySize,action:vm.retry)
                            .disabled(!vm.canRetry).accessibilityIdentifier(vm.identifier+".retry").freeControlItem("shot.undo",name:"重打")
                        if vm.showsDemonstration {
                            BTPracticeDemonstrationButton(enabled:vm.canDemonstrate,size:layout.auxiliarySize,
                                identifier:vm.identifier+".demonstration",action:vm.demonstrate)
                        } else {
                            BTHUDCompactAction(title:"回放",symbol:"play.rectangle",size:layout.auxiliarySize,action:vm.replay)
                                .disabled(!vm.canReplay).accessibilityIdentifier(vm.identifier+".replay").freeControlItem("shot.replay",name:"回放")
                        }
                    }.overlay(alignment:.bottomTrailing) {
                        BTSpatialElevationWheel(value:vm.displayedInput.elevation,enabled:vm.canAdjust,
                            width:max(96,min(144,layout.rulerLength)),onNudge:vm.nudgeElevation,identifier:vm.identifier+".elevation")
                            .alignmentGuide(.trailing) { _ in -layout.groupSpacing }
                    }
                }.frame(width:layout.columnWidth))
            },title:{Text(vm.mode.title)},leftContent:{_ in EmptyView()},status:{EmptyView()})
        .overlay(alignment:.topLeading) {
            #if DEBUG
            if SpatialRuntimeProbe.enabled {
                TimelineView(.periodic(from:.now,by:0.25)) { _ in
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier(vm.identifier+".timingProbe").accessibilityValue(vm.timingJSON)
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier(vm.identifier+".poseTimingProbe").accessibilityValue(vm.timingJSON)
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-spatialQuiz.probe") {
                GeometryReader { proxy in
                    Color.clear.frame(width:1,height:1).accessibilityElement()
                        .accessibilityIdentifier(vm.identifier+".viewport")
                        .accessibilityValue(Text(verbatim:"\(proxy.size.width),\(proxy.size.height)"))
                }.allowsHitTesting(false)
                Color.clear.frame(width:1,height:1).accessibilityElement()
                    .accessibilityLabel("空间练习测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier(vm.identifier+".probe").allowsHitTesting(false)
            }
            #endif
        }
    }
}

extension SpatialQuizJudgement.Outcome {
    var text:String {
        switch self {
        case .success: return "成功"
        case .failure(let reason):
            switch reason {
            case .cuePotted: return "母球落袋"
            case .cueOutside: return "母球飞台"
            case .targetOutside: return "目标球飞台"
            case .obstaclePotted: return "黑八进袋"
            case .obstacleOutside: return "黑八飞台"
            case .wrongFirstContact: return "先碰到黑八"
            case .obstacleContact: return "碰到黑八"
            case .noTargetContact: return "未碰到目标球"
            case .cushionBeforeTarget: return "碰目标球前先吃库"
            case .noJumpOverObstacle: return "未跳过障碍球"
            case .noMasseAroundObstacle: return "未形成扎杆弧线"
            case .noCompletion: return "碰球后未进袋或吃库"
            }
        case .unconfirmed: return "本次未能完成计算，请重试"
        }
    }
}
