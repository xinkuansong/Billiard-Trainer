import SwiftUI

struct SpatialPracticeView: View {
    @StateObject private var vm=SpatialPracticeViewModel()
    @ObservedObject private var preferences=TablePreferencesStore.shared
    @ObservedObject private var owner=CurrentOwnerContext.shared
    @State private var showsElevation=false
    @State private var showsDetails=false
    @State private var replacement:Int?
    @State private var layoutEditing=false
    private var enabled:Bool { vm.canEdit && !layoutEditing && !showsElevation && !showsDetails }
    private var controls:BTTablePlanningControls {
        .init(spinX:Binding(get:{ vm.input.spinX },set:{ vm.setSpin($0,vm.input.spinY) }),
            spinY:Binding(get:{ vm.input.spinY },set:{ vm.setSpin(vm.input.spinX,$0) }),
            transparency:Binding(get:{ preferences.snapshot(for:.masseJump)[.transparency] },set:{ preferences.apply(.transparency,value:$0,to:.masseJump) }),
            velocityRange:0.1...8,instrumentsEnabled:enabled,
            defersStrikeAccessUntilSubmission:true,locksSceneInteraction:showsElevation || showsDetails,
            isAnimating:vm.busy,allowsObservationWhileAnimating:true,paletteEnabled:enabled,allowsPocketSelection:false,
            primaryTitle:vm.phase == .calculating ? "计算中" : (vm.busy ? "停止" : "击球"),
            primaryEnabled:vm.busy || (enabled && vm.canStrike),
            onPrimary:{ if vm.busy { vm.stopPlayback() } else { vm.strike() } },
            onPaletteTap:{ key in if vm.onTableKeys.contains(key) { vm.removeFromTable(key) } else { vm.placeFromPalette(key) } },
            menuItems:menu,refreshTrajectory:{ vm.refreshAim() },
            onLayoutEditingChanged:{ layoutEditing=$0 },layoutEditingBlocked:vm.busy || vm.phase == .calculating,
            onAimNudged:{ vm.nudgeAim($0) },showsAimCloseupSetting:false,showsTrajectorySetting:false,showsSeparationSetting:false,
            onSpinChange:{ vm.setSpin($0,$1) })
    }
    private var menu:[DailyHUDMenuItem] {
        [
            .init(id:"masseJump.side",title:"侧面观察",disabled:vm.temporaryTopDownActive,action:{
                preferences.apply(.view3D,value:1,to:.masseJump)
                vm.setCameraMode(.perspective3D)
                vm.scene.cameraRig?.observeSpatialSide(aim:vm.input.aim)
            }),
            .init(id:"masseJump.example.jump",title:"跳球示例",disabled:vm.busy,action:{ replacement=0 }),
            .init(id:"masseJump.example.left",title:"左弧扎杆示例",disabled:vm.busy,action:{ replacement=1 }),
            .init(id:"masseJump.example.right",title:"右弧扎杆示例",disabled:vm.busy,action:{ replacement=2 }),
            .init(id:"masseJump.retrieve",title:"取回桌外球（\(vm.outsideKeys.count)）",disabled:vm.busy || vm.outsideKeys.isEmpty,action:{ vm.retrieveOutside() }),
            .init(id:"masseJump.clear",title:"清空桌面",disabled:vm.busy,action:{ replacement = -1 }),
            .init(id:"masseJump.route",title:"上一杆路线",selected:vm.showsLastRoute,disabled:vm.busy || vm.record.lastShot == nil,action:{ vm.toggleLastRoute() }),
            .init(id:"masseJump.details",title:"上一杆详情",disabled:vm.record.lastShot == nil,action:{ showsDetails=true }),
            .init(id:"masseJump.speed",title:"回放速度 · \(vm.playbackSpeed == 1 ? "正常" : "1/4")",disabled:vm.busy,action:{ vm.playbackSpeed = vm.playbackSpeed == 1 ? 0.25 : 1 })
        ]
    }
    private var information:[BTTeachingInformation] {
        if vm.phase == .calculating { return [.init(text:"正在计算本杆，可调参取消重算",kind:.notice,symbol:"hourglass",identifier:"masseJump.calculating")] }
        if let message=vm.message { return [.init(text:message,kind:.notice,symbol:"info.circle",identifier:"masseJump.notice")] }
        if !vm.busy,vm.currentPlayerAim == nil { return [.init(text:"从球库放回母球后击球",kind:.notice,symbol:"info.circle",identifier:"masseJump.missingCue")] }
        if !vm.busy,!vm.cueAccessible { return [.init(text:"球杆受阻，请调整打点、方向或抬杆角度",kind:.notice,symbol:"info.circle",identifier:"masseJump.blocked")] }
        return []
    }
    var body:some View {
        BTTeachingTablePage(vm:vm,titleLabel:"扎杆与跳球",identifier:"masseJump",preferencePage:.masseJump,
            velocity:Binding(get:{ vm.input.speed },set:{ value in vm.updateInput { $0.speed=value } }),
            planning:controls,information:information,usesStandardTitle:true,fitsLongTitle:true,
            pairedLeftContent:{ layout in
                AnyView(VStack(spacing:layout.groupSpacing) {
                    Button { showsElevation=true } label: {
                        VStack(spacing:2) { Text("抬杆").foregroundStyle(HUDStyle.labelColor);Text("\(Int(vm.input.elevation.rounded()))°").foregroundStyle(.white) }
                            .font(.btCaption).monospacedDigit().frame(width:layout.columnWidth,height:layout.topDiameter+14).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!enabled).accessibilityIdentifier("masseJump.elevation")
                        .freeControlItem("shot.elevation",name:"抬杆角度")
                    BTTeachingAimRuler(layout:layout,enabled:enabled,onNudge:{ vm.nudgeAim($0) },degreesPerPoint:0.2)
                        .accessibilityIdentifier("masseJump.aimWheel")
                    let actions=layout.horizontalActions ? AnyLayout(HStackLayout(spacing:layout.groupSpacing)) : AnyLayout(VStackLayout(spacing:layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title:"重打",symbol:"arrow.uturn.backward",size:layout.auxiliarySize) { vm.retry() }
                            .disabled(!enabled || vm.record.lastShot == nil).accessibilityIdentifier("masseJump.retry").freeControlItem("shot.undo",name:"重打")
                        BTHUDCompactAction(title:"回放",symbol:"play.rectangle",size:layout.auxiliarySize) { vm.replay() }
                            .disabled(!enabled || vm.record.lastShot == nil).accessibilityIdentifier("masseJump.replay").freeControlItem("shot.replay",name:"回放")
                    }
                }.frame(width:layout.columnWidth))
            },title:{ Text("扎杆与跳球") },leftContent:{ _ in EmptyView() },status:{ EmptyView() },
            onPalettePlace:{ vm.place($0,at:$1) })
        .onChange(of:owner.ownerKey) { _,_ in vm.ownerChanged() }
        .confirmationDialog("替换当前球形？",isPresented:Binding(get:{ replacement != nil },set:{ if !$0 { replacement=nil } }),titleVisibility:.visible) {
            Button("替换",role:.destructive) { if let value=replacement { if value<0 { vm.clear() } else { vm.loadExample(value) } };replacement=nil }
            Button("取消",role:.cancel) { replacement=nil }
        }
        .sheet(isPresented:$showsElevation) {
            NavigationStack {
                VStack(spacing:Spacing.md) {
                    Text("\(Int(vm.input.elevation.rounded()))°").font(.largeTitle).monospacedDigit()
                    Slider(value:Binding(get:{ vm.input.elevation },set:{ value in vm.updateInput { $0.elevation=value } }),in:0...85,step:1)
                        .accessibilityLabel("抬杆角度").accessibilityIdentifier("masseJump.elevationSlider")
                    HStack {
                        Button("−1°") { vm.updateInput { $0.elevation=max(0,$0.elevation-1) } }
                        Spacer()
                        Button("平杆") { vm.updateInput { $0.elevation=0 } }
                        Spacer()
                        Button("+1°") { vm.updateInput { $0.elevation=min(85,$0.elevation+1) } }
                    }.buttonStyle(.bordered).frame(minHeight:44)
                    Text("角度越大，球杆越接近竖直；同时调整打点与杆速，观察弧线和腾空。").font(.btCaption).foregroundStyle(.secondary)
                }.padding(Spacing.lg).navigationTitle("抬杆角度").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button("完成") { showsElevation=false } } }
            }.presentationDetents([.height(280)])
        }
        .sheet(isPresented:$showsDetails) {
            NavigationStack {
                Form {
                    if let shot=vm.record.lastShot {
                        LabeledContent("最高离台",value:String(format:"%.1f cm",shot.maximumHeight*100))
                        LabeledContent("首次落台",value:shot.landing.map { String(format:"X %.2f m · Z %.2f m",$0.x,$0.z) } ?? "未发生")
                        LabeledContent("进袋球",value:labels(shot.after.filter { $0.value.disposition == "pocket" && shot.before[$0.key]?.disposition != "pocket" }.keys.sorted()))
                        LabeledContent("桌外球",value:labels(shot.after.filter { $0.value.disposition == "outside" }.keys.sorted()))
                        Text("回放保留本杆实际路线，可切换俯视或侧面观察。").font(.btCaption).foregroundStyle(.secondary)
                    }
                }.navigationTitle("上一杆").toolbar { ToolbarItem(placement:.confirmationAction) { Button("完成") { showsDetails=false } } }
            }
        }
        .accessibilityValue("抬杆\(Int(vm.input.elevation))度，在桌\(vm.onTableKeys.count)球")
        .overlay(alignment:.topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-masseJump.probe") {
                TimelineView(.animation(minimumInterval:0.1,paused:!vm.busy)) { _ in
                    Color.clear.frame(width:1,height:1).accessibilityElement().allowsHitTesting(false)
                        .accessibilityIdentifier("masseJump.probe")
                        .accessibilityValue("\(String(describing:vm.phase))|\(vm.scene.cueBallNode?.presentation.position.y ?? 0)")
                }
            }
            #endif
        }
    }
    private func labels(_ keys:[String])->String { keys.isEmpty ? "无" : keys.map { PositionPlayBall.isCue($0) ? "母球" : PositionPlayBall.shortLabel(for:$0)+"号" }.joined(separator:"、") }
}
