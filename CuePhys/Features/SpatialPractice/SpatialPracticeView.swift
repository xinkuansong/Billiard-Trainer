import SwiftUI
import SceneKit

struct SpatialPracticeView: View {
    @StateObject private var vm:SpatialPracticeViewModel
    init() {
        #if DEBUG
        if let id=ProcessInfo.processInfo.environment["SPATIAL_TEST_SESSION"],UUID(uuidString:id) != nil,
           let defaults=UserDefaults(suiteName:"spatial-ui-"+id) {
            _vm=StateObject(wrappedValue:SpatialPracticeViewModel(defaults:defaults,
                ownerContext:CurrentOwnerContext(defaults:defaults),archiveRoot:FileManager.default.temporaryDirectory))
            return
        }
        #endif
        _vm=StateObject(wrappedValue:SpatialPracticeViewModel())
    }
    @ObservedObject private var preferences=TablePreferencesStore.shared
    @ObservedObject private var owner=CurrentOwnerContext.shared
    @State private var detail:String?
    @State private var confirmation:Confirmation?
    @State private var layoutEditing=false
    private enum Confirmation { case clear, reset }
    #if DEBUG
    @State private var observedPeak:Float=0
    #endif
    private var enabled:Bool { vm.canTune && !layoutEditing && detail == nil && confirmation == nil }
    private var boardEnabled:Bool { vm.canEdit && !layoutEditing && detail == nil && confirmation == nil }
    private var missingCue:Bool { vm.currentPlayerAim == nil }
    private var controls:BTTablePlanningControls {
        .init(spinX:Binding(get:{ vm.displayedInput.spinX },set:{ vm.setSpin($0,vm.input.spinY) }),
            spinY:Binding(get:{ vm.displayedInput.spinY },set:{ vm.setSpin(vm.input.spinX,$0) }),
            transparency:Binding(get:{ preferences.snapshot(for:.masseJump)[.transparency] },set:{ preferences.apply(.transparency,value:$0,to:.masseJump) }),
            hides3DAssists:$vm.hidesAssists,velocityRange:vm.velocityRange,instrumentsEnabled:enabled,
            defersStrikeAccessUntilSubmission:false,locksSceneInteraction:detail != nil || confirmation != nil,
            isAnimating:vm.busy,allowsObservationWhileAnimating:true,paletteEnabled:boardEnabled && !vm.isBreakMode,
            showsPlacementHint:vm.message == nil && vm.archiveMessage == nil,allowsPocketSelection:false,
            primaryTitle:vm.busy ? "停止" : (missingCue ? "放回母球" : (vm.isBreakMode ? "开球" : "击球")),
            primaryEnabled:vm.busy || (enabled && (missingCue || vm.canStrike)),
            onPrimary:{
                if vm.busy { vm.stopPlayback() }
                else if missingCue { vm.placeFromPalette(PositionPlayBall.cueKey) }
                else { vm.strike() }
            },
            onPaletteTap:{ key in if vm.onTableKeys.contains(key) { vm.selectTarget(key:key) } else { vm.placeFromPalette(key) } },
            menuItems:menu,refreshTrajectory:{ vm.refreshAim() },applyPreferences:{ vm.applyPreferences($0) },
            onLayoutEditingChanged:{ layoutEditing=$0 },layoutEditingBlocked:vm.busy || vm.phase == .calculating,
            onAimNudged:{ vm.nudgeAim($0) },
            resolveP01AimPan:nil,showsAimCloseupSetting:false,showsTrajectorySetting:true,showsSeparationSetting:false,
            onSpinChange:{ vm.setSpin($0,$1) },
            overlay:{ projector,_ in
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-masseJump.probe") {
                    return AnyView(SpatialPlacementProbe(vm:vm,projector:projector))
                }
                #endif
                return AnyView(EmptyView())
            },
            breakGameSelection:Binding(get:{ vm.breakGameBallCount },set:{ vm.prepareBreak(ballCount:$0) }),
            breakGameDisabled:!vm.canPrepareBreak,
            secondaryMenu:.init(id:"masseJump.lastShot",title:"上一杆",disabled:vm.busy || vm.record.lastShot == nil,items:historyMenu))
    }
    private var menu:[DailyHUDMenuItem] {
        [
            .init(id:"masseJump.clear", group: .formation, title:"清空桌面",disabled:!boardEnabled,action:{ confirmation = .clear }),
            .init(id:"masseJump.reset", group: .formation, title:"恢复默认",disabled:!enabled,action:{ confirmation = .reset })
        ]
    }
    private var historyMenu:[DailyHUDMenuItem] {
        [
            .init(id:"masseJump.route",title:"上一杆路线",selected:vm.showsLastRoute,action:{ vm.toggleLastRoute() }),
            .init(id:"masseJump.details",title:"上一杆详情",action:{ detail=shotDetails }),
            .init(id:"masseJump.speed.normal",title:"正常速度",selected:vm.playbackSpeed == 1,action:{ vm.playbackSpeed=1 }),
            .init(id:"masseJump.speed.slow",title:"1/4 慢放",selected:vm.playbackSpeed == 0.25,action:{ vm.playbackSpeed=0.25 })
        ]
    }
    private var shotDetails:String {
        guard let shot=vm.record.lastShot else { return "暂无上一杆" }
        return [
            "最高离台　"+String(format:"%.1f cm",shot.maximumHeight*100),
            "首次落台　"+(shot.landing == nil ? "未发生" : "已标记在台面"),
            "进袋球　"+labels(shot.after.filter { $0.value.disposition == "pocket" && shot.before[$0.key]?.disposition != "pocket" }.keys.sorted()),
            "飞出台面　"+labels(shot.after.filter { ["outside","escaped"].contains($0.value.disposition) }.keys.sorted())
        ].joined(separator:"\n")
    }
    private var information:[BTTeachingInformation] {
        if let message=vm.message ?? vm.archiveMessage { return [.init(text:message,kind:.notice,symbol:"info.circle",identifier:"masseJump.notice")] }
        if !vm.busy,missingCue { return [.init(text:"点“放回母球”后继续练习",kind:.notice,symbol:"info.circle",identifier:"masseJump.missingCue")] }
        if !vm.busy,!vm.cueAccessible { return [.init(text:"球杆受阻，请调整打点、方向或抬杆角度",kind:.notice,symbol:"info.circle",identifier:"masseJump.blocked")] }
        return []
    }
    var body:some View {
        BTTeachingTablePage(vm:vm,titleLabel:"扎杆与跳球",identifier:"masseJump",preferencePage:.masseJump,
            fixedView3D:true,velocity:Binding(get:{ vm.displayedInput.speed },set:{ value in vm.updateInput { $0.speed=value } }),
            planning:controls,supplementalDetail:$detail,supplementalDetailTitle:"上一杆详情",
            information:information,usesStandardTitle:true,fitsLongTitle:true,
            pairedLeftContent:{ layout in
                AnyView(VStack(spacing:layout.groupSpacing) {
                    Button { vm.prepareBreak() } label: {
                        VStack(spacing:2) {
                            BreakRackGlyph(color:HUDStyle.valueMeasured,size:layout.topDiameter-1,hollowBalls:true)
                                .btHUDActionContent().frame(width:layout.topDiameter,height:layout.topDiameter)
                                .background { BTHUDControlBackground(shape:Circle()) }
                                .overlay(Circle().stroke(HUDStyle.hairline,lineWidth:1))
                            Text(vm.isBreakMode ? "重开" : "开球").font(.btMicro).btHUDActionContent()
                        }.contentShape(Rectangle())
                    }.buttonStyle(BTHUDPressStyle()).disabled(!enabled || !vm.canPrepareBreak)
                        .accessibilityElement(children:.ignore).accessibilityLabel(vm.isBreakMode ? "重开" : "开球")
                        .accessibilityIdentifier(vm.isBreakMode ? "break.rerack" : "break.entry")
                        .freeControlItem(vm.isBreakMode ? "break.rerack" : "break.entry",name:vm.isBreakMode ? "重开" : "开球")
                    BTTeachingAimRuler(layout:layout,enabled:enabled,onNudge:{ vm.nudgeAim($0) },degreesPerPoint:0.2)
                        .accessibilityIdentifier("masseJump.aimWheel")
                    let actions=layout.horizontalActions ? AnyLayout(HStackLayout(spacing:layout.groupSpacing)) : AnyLayout(VStackLayout(spacing:layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title:"重打",symbol:"arrow.uturn.backward",size:layout.auxiliarySize) { vm.retry() }
                            .disabled(!enabled || vm.record.lastShot == nil).accessibilityIdentifier("masseJump.retry").freeControlItem("shot.undo",name:"重打")
                        BTHUDCompactAction(title:"回放",symbol:"play.rectangle",size:layout.auxiliarySize) { vm.replay() }
                            .disabled(!enabled || vm.record.lastShot == nil).accessibilityIdentifier("masseJump.replay").freeControlItem("shot.replay",name:"回放")
                    }
                    .overlay(alignment:.bottomTrailing) {
                        BTSpatialElevationWheel(value:vm.displayedInput.elevation,enabled:enabled,
                            width:max(96,min(144,layout.rulerLength)),onNudge:vm.nudgeElevation)
                            .alignmentGuide(.trailing) { _ in -layout.groupSpacing }
                    }
                }.frame(width:layout.columnWidth))
            },title:{ Text("扎杆与跳球") },leftContent:{ _ in EmptyView() },status:{ EmptyView() },
            onPalettePlace:{ vm.place($0,at:$1) })
        .onChange(of:owner.ownerKey) { _,_ in vm.ownerChanged() }
        .onChange(of:detail) { _,value in vm.showLandingMarker(value != nil) }
        .confirmationDialog(confirmation == .clear ? "清空桌面？" : "恢复本页默认输入与显示？",
            isPresented:Binding(get:{ confirmation != nil },set:{ if !$0 { confirmation=nil } }),titleVisibility:.visible) {
            if confirmation == .clear {
                Button("清空桌面",role:.destructive) { vm.clear();confirmation=nil }
            } else {
                Button("恢复默认",role:.destructive) {
                    vm.resetInputs()
                    for field in TablePreferencePage.masseJump.fields {
                        preferences.apply(field,value:field.initialValue(for:.masseJump),to:.masseJump)
                    }
                    confirmation=nil
                }
            }
            Button("取消",role:.cancel) { confirmation=nil }
        }
        .overlay(alignment:.topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-masseJump.timing") {
                TimelineView(.periodic(from:.now,by:0.25)) { _ in
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier("masseJump.timingProbe").accessibilityValue(vm.timingProbeJSON)
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier("masseJump.poseTimingProbe").accessibilityValue(vm.inputTimingJSON)
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-masseJump.probe") {
                GeometryReader { proxy in
                    Color.clear.frame(width:1,height:1).accessibilityElement()
                        .accessibilityIdentifier("masseJump.viewport")
                        .accessibilityValue(Text(verbatim: "\(proxy.size.width),\(proxy.size.height)"))
                }.allowsHitTesting(false)
                Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                    .accessibilityIdentifier("masseJump.motionTrace").accessibilityValue(vm.motionProbeJSON)
                TimelineView(.animation(minimumInterval:0.1,paused:!vm.busy)) { _ in
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier("masseJump.previewProbe").accessibilityValue(vm.previewProbeJSON)
                    Color.clear.frame(width:1,height:1).accessibilityElement()
                        .accessibilityIdentifier("masseJump.discOpacity")
                        .accessibilityValue(String(1-preferences.snapshot(for:.masseJump)[.transparency]))
                    let height=vm.scene.cueBallNode?.presentation.position.y ?? 0
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier("masseJump.probe")
                        .accessibilityValue("\(String(describing:vm.phase))|\(height)|\(observedPeak)")
                        .onChange(of:height) { _,value in if vm.busy { observedPeak=max(observedPeak,value) } }
                }
            }
            #endif
        }
    }
    private func labels(_ keys:[String])->String { keys.isEmpty ? "无" : keys.map { PositionPlayBall.isCue($0) ? "母球" : PositionPlayBall.shortLabel(for:$0)+"号" }.joined(separator:"、") }
}


#if DEBUG
private struct SpatialPlacementProbe:View {
    @ObservedObject var vm:SpatialPracticeViewModel
    let projector:TableProjector
    var body:some View {
        TimelineView(.periodic(from:.now,by:0.2)) { _ in
            Color.clear.frame(width:1,height:1).allowsHitTesting(false).accessibilityElement()
                .accessibilityIdentifier("masseJump.placementProbe").accessibilityValue(value)
        }
    }
    private var value:String {
        guard let cue=vm.scene.cueBallNode else { return "{}" }
        let target=SCNVector3(-0.7,vm.scene.surfaceY+BallPhysics.radius,0.25)
        var result:[String:Any]=["world":[cue.position.x,cue.position.z]]
        for (key,world) in [("cue",cue.position),("target",target),("clearanceTarget",SCNVector3(0.685,target.y,0)),("flyoutTarget",SCNVector3(1,target.y,0))] {
            if var point=projector.projectInWindow?(world) {
                if key != "cue",let origin=projector.projectInWindow?(cue.position) {
                    // Native temporary-table drags keep the shared finger gap.
                    // Supply the finger endpoint, not the desired ball endpoint.
                    let dx=point.x-origin.x,dy=point.y-origin.y,distance=hypot(dx,dy)
                    if distance>0 {
                        point.x += dx/distance*BTBallDragMetrics.fingerClearance
                        point.y += dy/distance*BTBallDragMetrics.fingerClearance
                    }
                }
                result[key]=[point.x,point.y]
            }
        }
        return (try? JSONSerialization.data(withJSONObject:result)).map { String(decoding:$0,as:UTF8.self) } ?? "{}"
    }
}
#endif
