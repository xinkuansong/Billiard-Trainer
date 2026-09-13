# W02 验收：观察相机基础

2026-09-12；状态：✅ 本批完成。完整v63仍在实施，W03–W16/H01–H04未完成。W02没有修复自然进袋或全面推广页面。

## 逐项证据

| 完成标准 | 实现与证据 |
|---|---|
| 旋转不改杆向，距离与俯仰独立 | OrbitInputV63Tests、PerspectiveStateV63Tests、ShotSimulationCameraTests；竖滑只改elevation，捏合只改distance，保留FOV。break-entry-r1最终20项通过 |
| 焦点不改击球选择 | observeBall/observePocket只改rig；业务测试保持target/pocket/freeAim；标准和SE菜单真实点击均通过 |
| 返回瞄准与模式往返稳定 | focus替换观察，PerspectiveState保存Orbit；显式返回、前后台/2D往返、击球/回放实际流程通过；保留W01竞态保护 |
| 全桌、沿杆、近袋、开球构图 | 真实viewport下拟合台面包围范围；3尺寸×4yaw的SceneKit投影测试96边界点；两手机原图已打开目视 |
| 低角度、贴库不穿桌 | 六袋+中心×四yaw最低/最近28组合，相机近裁剪面包络高于当前加载tableNode世界最高点；标准/SE最低近袋截图未见穿框 |
| 手动观察不被自动镜头夺权 | 从当前可见姿态接管并取消过渡；allowsCueScreenAnchor阻止训练页逐帧拉回母球。回到瞄准恢复；状态往返断言、3D瞄准点真实操作通过。开球只在racked阶段边界请求一次，不在settled刷新中重设 |
| 2D先开球再首次进3D | break-entry-r1新增分支断言通过，break-entry-ui-r1实际页面1项通过，first-3d-during-break-402.png已打开，六袋和散局可见 |

## 测试记录（各轮有重复覆盖，不相加为独立功能数量）

- orbit-r4：20单测/0失败。
- menu-r1、menu-se-r1：标准/SE各2UI/0失败。
- break-framing-r1：19共享单测+1UI/0失败。
- anchor-low-r1：18单测+2UI/0失败。
- anchor-low-se-r1：9单测+3UI/0失败，包含最终模型间隙扫描。
- break-entry-r1：20单测/0失败；break-entry-ui-r1：1UI/0失败。
- 所有上述成功均有TEST SUCCEEDED与独立xcresult，目录output/3d-v63/W02。初轮orbit-r1的CoreSimulator启动Busy证据保留，不作产品通过/失败断言。
- closeout-gate、closeout-doc-size退出0；最终diff检查通过。构建已包含在上述Makefile test链路。

## 视觉与边界

标准402pt与SE375pt：菜单/底栏保持单行；沿杆/全桌/近袋/开球/播放往返已实看代表图。3D瞄准点旋转后母球、目标球、特写及提交入口可见。详细视觉记录见tasks/ui-reviews/UR-20260912-v63-camera.md。

普通观察可将非焦点球移出视口，这是用户选定焦点后的正常裁剪；返回瞄准/查看全桌可恢复。这里不声称辅助线样式达标，低角度仍有球心高度悬浮线，由W03处理。当前大面积黑背景、球杆外观等渲染议题不在本批归因或验收。

真实触控、iPad完整UI、最低系统、最大字号/VoiceOver、长期帧率/能耗仍在W16；W02的iPad只证明数值构图，不当真机/UI验收。截图上的FPS标签不是性能证明。新模型改变台框范围时，加载模型间隙测试必须重跑。

## 写回

DR-142同步架构技能、SwiftUI设计系统和UI规范；执行台账与v63.3推进至W03。无本批运行中的测试句柄。后续先读W03-working.md和line-consumers.json，不重做W02已通过检查，除非相关实现或依赖改变。
