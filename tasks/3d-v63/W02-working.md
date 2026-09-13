# W02：独立相机操作

状态：🔄 已实现独立轨道输入，尚未完成W02。

## 已实现（待本批完整验收）

CameraRig在用户拖动/捏合时从当前可见SmoothPose进入独立OrbitState：distance/elevation/pitchOffset/FOV。竖滑仅改elevation，捏合仅改distance；水平方向仍改yaw。preset的enterAiming/enterObservation保留原入口，smoothToPose清除手动轨道状态。手动输入取消自动过渡；PerspectiveState同时保存轨道current/target，hasPendingDamping纳入轨道收敛。

坐标：XZ台面/Y向上/米；独立轨道distance=hypot(horizontalRadius,height)，elevation=atan2(height,radius)。三个旧预设半径/高度的转换往返Python验证误差小于1e-12m。pitchOffset保留旧机位的光轴偏移；捏合不改变FOV或光轴俯仰。

测试加入OrbitInputV63Tests四项：距离与pitch/FOV独立、俯仰与距离独立、手动接管自动镜头时位置连续、状态恢复与阻尼收敛。与W01十二项一起回归。

## 运行证据

- orbit-r1编译后在App启动前失败，CoreSimulator报Busy/Application failed preflight checks；未运行断言，不能判为产品回归。
- 尝试shutdown时专用UDID已是Shutdown；已重新boot并bootstatus。另一个渲染任务使用不同UDID `26193C38-C8FA-43D9-9DB3-A04EC5EA43DE` 与build/DerivedData，不操作其模拟器。
- 同源码复跑 orbit-r2：exec session `95269`；日志 `output/3d-v63/W02/orbit-r2.log`，xcresult同名。先轮询该句柄，不能因观察超时重复启动。

## 剩余

1. r2结果与任何真实失败根因；原有Camera/AngleTraining/Break相关回归扩大到独立输入消费者。
2. 俯仰上界须考虑pitchOffset，保证不会过顶翻转；低角度最近距离的台框避障与实际屏幕样片验证。当前数学上界pi/2还需这个组合约束。
3. 观察焦点接口、明确“查看此球/袋”、全桌/开球构图、返回瞄准的手机入口；观察选择不改业务目标。
4. 真实UI手势/低角度/近袋/全局/开球图片、紧凑屏；性能收敛守卫与W01往返一并回归。
5. W02验收和DR回写。W03–W16/H01–H04仍未完成，不能把本轮轨道输入当成完整3D交付。

r2 已结束：16项测试/0失败，TEST SUCCEEDED。与r1相同源码，证明r1启动失败不是本轮断言失败。下一步按剩余1–5推进；当前无本任务运行中的测试句柄。


## 后续检查点：观察焦点与手机菜单

- orbit-r3：19项/0失败；增加光轴防翻转、实际世界焦点居中、三种视口×四个方向的SceneKit投影检查（96个边界点）。
- orbit-r4：20项/0失败，2026-09-12 16:14 TEST SUCCEEDED。新增查看母球/目标球/袋口/全桌不改变击球选择的业务断言。
- Orbit高度现在以观察pivot为参考；全桌构图按真实视口和台面包围范围计算，不以固定手机距离代替。
- FreePlayView和ShotSimulationView共用ShotObservationMenu：全桌/母球/目标球/目标袋；沿用独立focus按钮。开球时入口位于原上沿相机区域，普通状态位于原底栏。目标缺失时禁用对应菜单项。
- 菜单功能与截图回归正在运行：menu-r1，专用标准模拟器2447DFF4，exec session37843。未读取最终结果前不标通过。
- 上文r2之后的剩余项中，俯仰上界、焦点API及数学构图已实现并有单测；实际低角度/贴库避障、手机视觉、开球自动构图、其他共享消费者回归及W02完整验收仍未完成。


menu-r1 已结束：2项UI完整流程/0失败，TEST SUCCEEDED，exec37843退出0。标准屏全桌开球、查看母球/袋口原图已打开目视，菜单与独立focus保持可读；新菜单未增加底栏高度。gate/doc-size与diff检查通过。证据副本与哈希在output/3d-v63/W02/menu-standard。此为入口与状态回归，不代表近袋细节构图/全部W02视觉验收。

紧凑屏同流程启动：menu-se-r1，UDID3FA140AB，exec session38972，结果待收取；不与标准屏UI并行运行。下轮先核对真实进程和日志，不重复启动。


## 开球自动构图增量

FreePlayView新增breakRunner.phase观察：仅previous=racked且新阶段computing/breaking时请求一次全桌构图；settled等后续变化不再次改镜头。用户后续拖动由已有手动orbit接管。此增量发生于menu-se-r1构建之后，SE该轮不覆盖此改动；必须单独复跑实际开球截图。

已目视menu-se-r1产出的375pt全桌开球和分离角全桌图：工具文字保持单行，六袋可见，原控制条高度不增；未据此宣称全W02视觉达标。


menu-se-r1完成：2项/0失败，TEST SUCCEEDED，exec38972退出0。截图与SHA-256保存在output/3d-v63/W02/menu-compact。

break-framing-r1已启动（exec session67351）：自动开球构图后的标准屏完整15/9球流程，并扩大X1_CameraAndAngleArcTests、TrainingAssistSceneTests、BreakFlowRunnerV6Tests共享消费者回归。下一轮先轮询同句柄/读取日志；完成后实看breaking-15/9与settled-15/9截图。W02仍缺低角度/贴库避障验证、自动镜头手动接管的实页证据及完整验收；W03–W16/H01–H04未完成。


break-framing-r1完成：19项单测+1项UI流程，0失败，TEST SUCCEEDED；exec67351退出0。实看breaking-15-3d-402：开球已经全桌构图，六袋可见。该轮不含随后新增的自动锚点守卫。

新增共享守卫allowsCueScreenAnchor：自动过渡中或用户Orbit观察时禁止训练页逐帧锁母球屏幕位置；回到瞄准后恢复。OrbitInputV63Tests新增状态切换、2D往返和指定焦点检查。S2试点增加真实最低俯角/最近捏合的近袋截图。

anchor-low-r1已启动，exec session51125，专用标准UDID；覆盖OrbitInputV63Tests/PerspectiveStateV63Tests、3D瞄准点实际手势与分离角完整流程。结果待收取，不能预支验收。


anchor-low-r1完成：18项单测+2项UI，0失败，TEST SUCCEEDED，exec51125退出0。已打开标准屏3D瞄准点旋转后特写与低角度近袋原图，母球/目标球与操作可见，近袋未见穿框；图片副本在anchor-low-standard。此轮不含之后新增的加载模型包围盒安全距离测试。

新增数值验证以当前加载tableNode的世界包围盒最高点为真值，扫描六袋+桌中心、四个yaw、最低俯角/最近距离，并包含近裁剪面角点半径。不是用旧固定库高作为证明。

下一轮anchor-low-se-r1已启动（exec session67570）：新增几何守卫单测+SE的3D瞄准点、分离角完整流程、自动15/9球开球；结果待收取。全v63仍未完成。


anchor-low-se-r1完成：9单测+3UI，0失败，TEST SUCCEEDED；exec67570退出0。已实看最低近袋和9球自动开球375pt原图，未见穿框，菜单可读。证据副本anchor-low-compact。DR-142已同步架构/UI技能和组件规范。

最终入口审查发现2D开球后首次3D缺全桌取景：ShotPlayCamera.setMode现区分首次运动中开球与准备瞄准；已有有效观察姿态的往返仍恢复用户视角。break-entry-r1的20项单测通过（包含新分支与再次往返不抢镜）。新增testFirstPerspectiveEntryAfterStartingBreakIn2D正在实际页面验证，日志break-entry-ui-r1；最终画面未检查前保持W02进行中。


最终break-entry-ui-r1完成：1UI/0失败，exec98823退出0，原图已实看。closeout-gate/doc-size与diff通过。W02正式关闭，详W02-acceptance.md；下一批W03进行中，无运行测试句柄。
