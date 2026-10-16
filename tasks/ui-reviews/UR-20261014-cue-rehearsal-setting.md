# 击球前试运设置 · 原生界面复核（2026-10-14）

## 范围与结论

设置→教学辅助新增默认开启的「击球前试运」开关。标准手机/iPhone SE，iOS26.3，浅深色代表图目视通过；新行完整、字号/卡片/间距沿用本页，开关与说明无重叠。新说明使用btTextSecondary，自动换行；未改既有辅助线说明颜色。

## 功能验证

- 编译通过；CueClearanceTests 42项0失败，覆盖本机偏好、完整正式轨迹一致性、选定触球杆速、实时冻结选择/取消与导出原速/两倍速。
- TrainingMusicSettingsUITests/testCueRehearsalTogglePersistsAcrossLaunches，在iPhone17Pro、iPhoneSE各1项通过；通过真实开关关闭/重启/开启/重启，无启动参数覆盖偏好。
- 默认开发设备显式借用；SE复用受管池FEC0D1E7-0A8E-4CDB-ADE9-D33DC2D4C898，均已正常释放，未删除设备。

## 图像证据

[原生前后对比](../../output/cue-stroke-20261014/r3/review.html)。原图保存在 `output/cue-stroke-20261014/r3/screenshots/`；副本与xcresult导出字节一致。已审标准机浅开/深关与小屏浅关/深开，及改前标准机浅色图。

UI经现有设置深链进入；普通Tab导航、iPad、最大辅助字号和真机未在本轮验证。没有改变全局字体策略；固定字号token不宣称已支持完整Dynamic Type。功能通过不等于用户已认可新设置页。r2运杆节奏已获用户认可并保持。


## r4 名称／默认值修订

用户最终指定「运杆」、默认关闭；保留已保存手动选择。构建与默认值单测/设置UI各1项通过。2026-10-14 12:59 iPhone17Pro浅关/深开原图已目视，新名称完整、说明不变，未见布局回归。[浅色关闭](../../output/cue-stroke-20261014/r4/settings-rehearsal-off-light.png) · [深色开启](../../output/cue-stroke-20261014/r4/settings-rehearsal-on-dark.png)。本轮未重复小屏/iPad/最大字号/真机；上方r3默认开启仅为历史状态。
