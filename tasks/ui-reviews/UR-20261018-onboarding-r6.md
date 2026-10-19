# r6 引导原生验证 · Mac mini · 2026-10-18

## 范围
欢迎/六页介绍/四步资料；深色品牌曲面；第6页新深色截图及上移32/30pt。远端 Xcode26.2、iOS26.2，区别于主机26.3。

## 隔离与证据
使用已封存且构建验证过的队列B源码作为私有基线，覆盖本轮35个引导代码/资源文件（含相应枚举和测试），生成新工程并在私有测试仓库固定commit；没有对共享工作区声明暂停写入，也没有混入同期其他页面改动。主仓库未提交。队列快照r1=46fa085e536e71eedd92bb7bd2ae430db6a5aa01af107da2935d0003cde611f3；修复r2=732139a8ab80dd0b0edfb9952910f44bf4d82463b9673d5994b3f167316a1aeb。

## 首轮发现与修复
- iPhone17Pro：实际42项资料单测通过（文件中另有5项属于其他测试类，未纳入本轮选择器），2项资料UI通过。Tour在第3页因AX图片frame.maxX=413.76超出402pt屏幕失败。
- 查看XCTest录屏末帧，实际图像仍位于屏幕内。根因是scaledToFill裁切保留原始图像的辅助功能范围；最终修复使用iOS17起支持的 `.contentShape(.accessibility, Rectangle())` 让AX范围与外层拟合视口一致，保留横向边界断言，不改图像或放宽测试。中间r2误用UIKit式accessibilityFrame，编译检查发现后取消未执行队列，改用原生API并完成最小Swift编译验证。
- 首轮原始日志/xcresult/录像/截图保存在 `output/onboarding-implementation-20261018/mac-mini/phone-r1/`。资料四项及生日原生截图已经打开，正文、选项、开始使用可见。
- 小屏SE首轮3项UI全部通过，已目视清台/计划/四项球种/生日；r3复验中（r2未执行已取消）；未以首轮部分通过作为最终通过。历史测试快照与失败临时设备由受管队列保留，未清理其他设备。

## 最终候选快照
- r3：`81bc6218b836662033b851fb43b9bce5c99bdd76eac609c67e730d44fb555f6a`，私有测试仓库commit `04bd87c8dfc6c6d623f0c2352423bc33a09ae69c`；35个覆盖文件与当前工作区逐字节相同。
- 队列：`onboarding-r6-phone-r3`、`onboarding-r6-compact-r3`、`onboarding-r6-pad-r3`；同一快照在iPhone17Pro / SE3 / iPadAir13（M3）复验。

### 远端容量阻塞
`onboarding-r6-phone-r3` 编译通过，但生命周期分配因每机型/Runtime最多2台失败，没有运行测试。只读清单确认同类型槽位为既有池设备和本任务r1失败临时设备；队列不支持复用UDID。r1已完成诊断且仅新建测试fixture，完整xcresult/截图/失败录像已导出并校验，遂通过retire（0天）及精确UDID cleanup释放本任务设备F51D8667-28C7-4354-9C8D-EDE0FDB91B33；未处理其他设备。相同r3快照重新入队 `onboarding-r6-phone-r3-retry`。

- SE3 r3：3 UI passed / 0 failed / 0 skipped，12张原生截图逐图目视；球库、2D/3D同宽与3D袋口、第6页球形明细均完整；四项球种与大字号生日按钮可见，结束进入真实首页（首页保留现有浅色设置，深色限定引导）。

### iPad导航断言纠正
r3的六页介绍通过；资料保存后AX树已是训练首页，含trainingHome.dailyClearance与顶部五导航，原测试109行却要求TabBar，导致1通过/1失败。改为明确查找首页dailyClearance控件，返回及重启仍保留到达断言，未改生产代码。r4将三尺寸整组重跑，不混用旧绿单元。r3-retry尚在排队已取消。

### 并发边界
r4冻结后共享QiuJiApp.swift被其他页面工作加入DailyTableOrientation.restoresPreviousOwner（默认false）及前任方向恢复；引导入口未改。该同期改动不在本轮快照中，明确不宣称测试覆盖全部最新共享工作区。其余34覆盖文件与r4一致。

- 原生欢迎补充证据：从iPad r3测试录屏4.5秒处抽帧 `mac-mini/pad-r3/launch-video-4_5s.png`，实际看到Logo、品牌名、标语与背景；r4仅改测试断言，欢迎生产实现不变。此帧单列为录屏补证，不混入最终r4截图计数。

## r4最终复验
快照7607340396f5346620393ca64ad362de4130044e4008afac851239c7c57fff8e，私有commit4be3ecf747a4eee04e2d5220f0b2df5cfe8cb27e。iPhone17Pro：42资料单测+3UI全部通过，无失败/跳过；12张图逐图目视通过。加塞页原AX越界断言在同机型复验已通过。iPadAir13(M3)：2UI全部通过，11张图逐图目视，保存/返回/重启进入真实首页；SE3：3UI全部通过，12张图逐图目视，包括大字号生日页。

### 最终结论

| 设备（iOS26.2） | 单测 | UI执行 | 已目视截图 |
| --- | ---: | ---: | ---: |
| iPhone17Pro | 42 | 3 | 12 |
| iPadAir13 M3 | — | 2 | 11 |
| iPhoneSE3 | — | 3 | 12 |

同一r4快照合计50通过、0失败、0跳过。35张原生截图逐图核对：第5页两层同宽、球库和袋口露出；第6页球形明细完整；四步选填与开始使用按钮可见。首次保存、返回修改、跳过、重启恢复/进入首页均有对应UI覆盖。大字号用例在两款手机执行，未宣称全App可访问性验收。所有回传经fetch哈希校验；成功临时设备由队列回收，r3失败iPad及原始失败证据保留。

截图对照：`output/onboarding-implementation-20261018/mac-mini/review.html`；汇总`final-verification.json`。生产新增AX视口形状修复，iPad测试改查真实首页内容；没有放宽越界检查。主工作区引导文件核对仅QiuJiApp同期方向恢复变化（上节），不覆盖全仓库并行改动。用户视觉复阅、真机与线上资料同步仍未验收；未装真机/部署/主仓库提交/发布。
