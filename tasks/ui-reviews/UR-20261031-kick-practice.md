# UR-20261031 · 解球练习原生界面与定向验证

状态：实施与定向验证完成；28项逻辑、140题生产重放、三尺寸10次基础UI执行及3次最终3D避让回归通过。最终原图已审；真机与用户认可未完成。

## 范围与行为

打页新增“解球练习”，位于K球后。复用BTTeachingTablePage、方向/杆速尺、打点盘、显示菜单、2D/3D宿主与设置结构；独立题库、偏好、额度、历史及账户归属。K球规则不变。

140题：一/二/三库各40，四库20。明确标记物理库边的碰撞先后，同一墙重复碰撞以“1·4”合并显示。序号锚定墙面固定位置，不是要求命中的碰库点。方向/左右塞/高低杆/力度自由，实际首碰目标前的主库序列须完全相同；母球落袋失败。首次作答冻结成绩，重打保存最新杆供回放。无少库排他扫描、无扰动评分。

## 页面审查

|维度|核对结果|范围限制|
|---|---|---|
|信息层级|标题、单颗目标球球库、题数/成功率、要求/结果、动作各归其位；库序始终可见|动态大字号未验|
|布局与留白|SE横屏、iPad横竖屏原图中桌边、双尺、球库分离；3D标签沿实际投影，未用2D位置硬套|分屏/缩窗及任意相机角度未穷举|
|字体与颜色|继承现有灰标签/白数值及原字号；杆速沿共用强调色；结果文字常驻|VoiceOver及所有主题组合未验|
|交互与触摸|方向尺、打点盘展开/关闭、菜单网格、设置取消、下一题测试通过；关闭盘未穿透改瞄准|透明度滑杆、布局模板编辑专项未验|
|状态与反馈|瞄准→击球/播放→结果→重打/回放→下一题；免费末题显式总结|真实购买未验|
|一致性|共用球桌/菜单/控件；2D/3D换视图保留题目、输入、成绩、额度|临时俯视和自定义相机手势专项未验|
|数据与物理|140参考解生产重放；首答、账号隔离、迁移失败回滚、历史载荷均有逻辑证据|无实台校准、服务器真实同步及真机听感证据|

配色来自模拟器既有球桌外观偏好（蓝台布，iPad粉色库边），本任务没有修改公共默认外观。普通手机首轮3D截图发现2号标记与击球按钮相交。最终改为把标记限定在标准两侧控件之间，并用细引线连接固定物理库边锚点；不改变题目要求或参考碰库位置。自定义控件布局及任意相机角度尚未穷举。

## 缺陷与修复

1. 首轮模拟器SpringBoard安装占位冲突，App未进入。通过本任务设备生命周期恢复并重新安装已编译App，不抹除数据；该轮不计通过。
2. 原生截图发现库序标签偏移：投影是SCNView局部坐标，叠层属于Foundation.stage。修正为投影坐标加sceneFrame原点减overlayFrame原点；新增2D库边方位/可见性断言。最终SE/iPad通过。
3. 真实成功提交测试误用了旋转符号；按生产`rotatedY`契约修正测试并检查实际方向，随后成功→失败重打仍冻结首答通过。未修改生产旋转行为来迁就测试。
4. UI测试误认为每次启动都回到2D；产品应保留偏好。测试通过正式菜单归一化初始视图后再验证切换，不清除用户偏好。最终四项SE UI通过。

5. 普通手机3D编号与击球按钮相交，新增不相交断言；首次沿库边换锚点的尝试未通过，保留`validation-phone-r2.xcresult`失败证据，最终改为标签避让加物理库边引线，普通手机/SE/iPad的不重叠断言均通过。

## 证据

统一目录：`output/kick-practice-20261031/`。

|项目|结果与证据|
|---|---|
|解球逻辑|10/10，`validation-se-r3.xcresult`；包含140题参考解逐条当前物理重放|
|K球回归|7/7，`output/local-test-runs/709720e8d9364c609880d20322aba517/evidence/tests.xcresult`|
|共享视图状态|11/11，`validation-se-r2.xcresult`内TrainingViewMergeStateTests；该包另有早期失败，不称整包通过|
|SE3，iOS26.3|基础4/4 UI，`validation-se-r4.xcresult`；最终3D避让/回放1/1，`validation-se-r5.xcresult`；`se-final-images/`与`se-r5-images/`|
|11英寸iPad，iOS26.3|基础3/3 UI，`validation-ipad.xcresult`；最终3D避让/回放1/1，`validation-ipad-r2.xcresult`；含横竖屏及3D，`ipad-final-images/`|
|iPhone13，iOS26.3|首轮3/3，`validation-phone.xcresult`；最终3D避让/回放1/1，`validation-phone-r3.xcresult`|
|构建|App及测试宿主在模拟器构建成功；最后增量含独立解球入口封面及3D标记避让|
|门禁|`verify-gate`通过（66 screenshots / 94 routes / 204 write-surfaces，FAIL=0），`gate-final.log`；文档尺寸与diff最终检查见下|

已查看原图：SE 2D瞄准/结果/总结、3D瞄准、展开打点及显示菜单；iPad竖屏2D、横屏2D、3D瞄准及展开打点。普通手机2D瞄准/设置及最终3D避让原图已审（`phone-final-images/kick-3D-aiming.png`）。其余截图保留在附件目录，自动测试通过不替代逐图人工视审。

[SE瞄准原图](../../output/kick-practice-20261031/se-final-images/kick-2D-aiming.png) · [SE结果](../../output/kick-practice-20261031/se-final-images/kick-2D-result.png) · [iPad竖屏](../../output/kick-practice-20261031/ipad-images/kick-iPad-portrait.png) · [iPad 3D](../../output/kick-practice-20261031/ipad-images/kick-3D-aiming.png)

完整TP01–TP36适用判定及未测能力见[页面卡](../table-page-adaptation/KICK-PRACTICE-20261031.md)。未执行发布、Git提交或推送。

最终核验：`git diff --check`通过；`verify-doc-size`结果见同目录`doc-size-final.log`。三台本任务模拟器与独占构建目录按生命周期入口收尾，保留结果包和原图；其它任务现场未动。
