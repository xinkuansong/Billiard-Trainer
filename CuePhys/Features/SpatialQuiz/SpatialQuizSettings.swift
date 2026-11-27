import SwiftUI

struct SpatialQuizSettings: View {
    @ObservedObject var vm: SpatialQuizViewModel
    @State private var draft: SpatialQuizConfiguration
    @EnvironmentObject private var subscription: SubscriptionManager
    @StateObject private var notices = BTRuleNoticeCenter()
    @State private var pendingFree = false
    let onCancel: ()->Void
    init(vm: SpatialQuizViewModel,onCancel:@escaping ()->Void) {
        self.vm=vm;self.onCancel=onCancel
        let saved=vm.savedConfiguration
        _draft=State(initialValue:vm.record?.configuration ?? saved ?? .init())
    }
    var body: some View {
        Form {
            Section("训练模式") {
                BTTrainingModePicker(count:15,isPremium:subscription.isPremium,
                    freePractice:Binding(get:{draft.freePractice},set:{value in
                        if value && !subscription.isPremium { pendingFree=true;vm.needsSubscription=true }
                        else { draft.freePractice=value }
                    }))
            }
            Section("练习说明") {
                BTTrainingSettingsNote("调整方向、打点、杆速和抬杆角度，\(vm.mode == .masse ? "让母球沿弧线绕过" : "让母球跳起越过")黑八，先碰到目标球。目标球进入任意袋，或碰球后母球、目标球任一吃库即可成功。首碰目标前不能先吃库；先碰黑八失败，先碰目标球后再碰黑八不算犯规；母球落袋或飞台仍失败。只统计每题首答，重打不改成绩；成功或完成三次击打后可查看示范。")
            }
            if let manifest=vm.bank?.manifest {
                Section("母球与目标球距离") {
                    choice("综合",selected:draft.filter.distanceBin == nil) { draft.filter.distanceBin=nil }
                    ForEach(manifest.distanceBins,id:\.self) { bin in
                        choice(String(format:"%.1f–%.1f 米",Double(bin)/2,Double(bin+1)/2),selected:draft.filter.distanceBin == bin) { draft.filter.distanceBin=bin }
                    }
                }
                Section {
                    choice("综合",selected:draft.filter.s == nil) { draft.filter.s=nil }
                    ForEach(manifest.sValues,id:\.self) { value in
                        choice(String(format:"距母球约 %.0f%%",value*100),selected:draft.filter.s == value) { draft.filter.s=value }
                    }
                } header: { Text("障碍位置") } footer: { BTTrainingSettingsNote("按母球至目标球线路的长度确定黑八位置。") }
                Section {
                    choice("综合",selected:draft.filter.q == nil) { draft.filter.q=nil }
                    ForEach(manifest.qValues,id:\.self) { value in
                        choice(String(format:"遮挡档位 %.2f",value),selected:draft.filter.q == value) { draft.filter.q=value }
                    }
                } header: { Text("遮挡档位") } footer: { BTTrainingSettingsNote("数值越大，黑八越靠近直击线路；不是目标球可见面积的百分比。") }
            }
            BTTrainingSettingsResetSection {
                draft = .init();notices.show("已恢复默认设置",tone:.success,priority:.mode)
            }
        }
        .navigationTitle("训练设置").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden().toolbar(.hidden,for:.tabBar)
        .toolbar {
            ToolbarItem(placement:.principal) { Text("训练设置").font(.btHeadline).accessibilityAddTraits(.isHeader) }
            ToolbarItem(placement:.topBarLeading) { Button(vm.record == nil ? "返回" : "取消",action:onCancel).accessibilityIdentifier("training.settingsCancel") }
            ToolbarItem(placement:.topBarTrailing) {
                Button(vm.record == nil ? "开始训练" : "重新开始") { vm.start(draft) }
                    .disabled(vm.bank == nil).accessibilityIdentifier(vm.identifier+".start")
            }
        }
        .overlay { if let notice=notices.message { BTToastBanner(message:notice) } }
        .onChange(of:subscription.isPremium) { _,value in
            if value && pendingFree { draft.freePractice=true;pendingFree=false }
            else if !value { draft.freePractice=false }
        }
        .onDisappear { notices.clear() }
    }
    private func choice(_ title:String,selected:Bool,action:@escaping ()->Void)->some View {
        Button(action:action) {
            HStack { Text(title).foregroundStyle(.btText);Spacer();BTSelectionIndicator(isSelected:selected) }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(selected ? "已选" : "未选")
    }
}
