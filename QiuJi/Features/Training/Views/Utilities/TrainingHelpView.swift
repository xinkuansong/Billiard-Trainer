import SwiftUI

struct TrainingHelpView: View {
    let ownerKey: String
    var body: some View {
        List {
            Section("开始训练") {
                DisclosureGroup("怎样安排今天的训练？") {
                    Text("在训练首页选择官方计划，或将动作加入今日安排，再选择课程开始训练。训练中可以收起页面，稍后通过训练胶囊继续。")
                    NavigationLink("浏览训练计划") { PlanListView(ownerKey: ownerKey) }
                }
                DisclosureGroup("练完后忘记记录怎么办？") {
                    Text("补记训练日期、用时和内容。补记计入训练天数与时长，不生成组成绩，也不推进计划。")
                    NavigationLink("补记训练") { ManualTrainingView(ownerKey: ownerKey) }
                }
            }
            Section("复盘与坚持") {
                DisclosureGroup("在哪里回看训练心得？") {
                    Text("训练心得按训练日期倒排，包含整次训练和动作心得，可搜索和编辑。免费版展示最近 60 天，Pro 可查看全部历史。")
                    NavigationLink("查看训练心得") { TrainingNotesView(ownerKey: ownerKey) }
                }
                DisclosureGroup("为什么没有收到训练提醒？") {
                    Text("请检查提醒时间和重复日期，并在系统设置中允许球迹发送通知。专注模式或通知摘要可能影响提醒展示。")
                    NavigationLink("设置训练提醒") { TrainingReminderView() }
                }
            }
            Section("数据与反馈") {
                DisclosureGroup("换手机后如何恢复记录？") {
                    Text("登录原账号并允许云同步；需要重试时，可前往设置中的数据同步。游客记录保存在当前设备，请先登录并完成同步再更换设备。")
                    NavigationLink("打开设置") { SettingsView() }
                }
                NavigationLink("关于与反馈") { AboutView() }
            }
        }.font(.btBody).tint(.btPrimary).navigationTitle("使用帮助").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview("Light") { NavigationStack { TrainingHelpView(ownerKey: DeviceGuestIdentity.ownerKey()) } }
#Preview("Dark") { NavigationStack { TrainingHelpView(ownerKey: DeviceGuestIdentity.ownerKey()) }.preferredColorScheme(.dark) }
