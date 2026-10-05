# UR-20261003 — 本杆相机与透明俯视叠层 v2.1

日期：2026-10-03；范围：每日清台 DEBUG `-dailyClearance.twoViewCamera` 候选。真源：方案§0、实施§10、ADR-P18-07。未转正或提交，不把旧黑底LP当新要求验收。

## 定向结论

第三人称恢复旧1.65m起始站位及近库/两球遮叠缩距、眼高与lens适配，保沿杆方向；有效推荐后自动进入当前本杆TP，力度普通重算不触发转镜。四球形实际退远与俯角变化已查看。第一人称近库实体遮挡、部分顶部袋口旧边界仍开放。

临时俯视为普通SCNNode冻结真实资产树的一次正交快照，桌外透明，覆盖原3D；当前TP择开球线短库朝向，FP使用本杆TP基准。标准屏与SE横屏的0/5×TP/FP共8次真实长按全部通过，含短tap不进入、两相反标准朝向、main世界矩阵/FOV delta0、主camera不改正交、room可见、每次持有1张快照、不常驻第二renderer、释放actual回原值及shot intent不变。比例fit受HUD中央区限制，不拉伸或裁六袋。

## 原生证据与独立实看

| 范围 | 实际证据 | 审图结论 |
|---|---|---|
| 四球形默认/临时轨道＋真实推荐 | rail-recommendation-attachments 37原生PNG＋rail-review 13持触过程帧，另34邻帧 | 未见新增TP视觉P1；四次实际退远均非LIMITED；部分过程帧仍趋近极值，不称稳定峰值 |
| 标准屏LP最终 | overlay-review-final 4持触帧＋standard-overlay-r3新02–05透明原图4张＋overlay-r3-attachments before/releases8张；另12邻帧 | 六袋完整、HUD内大桌、房间保留；0开球线左/5右，TP/FP同杆方向一致；释放无可见跳位 |
| SE LP/图标最终 | overlay-review-se 4持触帧＋se-overlay-final透明原图4张＋overlay-se-attachments before/releases8张和icon1张；另8邻帧 | 17PNG实看，六袋与桌框完整；等比例fit上下留白正常；HUD控件可读 |

主控与独立review分别实看有效持触图。误抽触摸前候选保存在REJECTED文件及rejected-before-touch-manifest，不计held；standard-overlay-r3/raw01 sourceModified来自前包，也排除。最终持触manifest按画面实际LP高亮与overlay出现校准，原录像保留，仅旋转展示，不用于时延结论。

原始PNG未经抠图后处理，标准4张及SE4张四角alpha均0，均有alpha0与255区域，统计见build/shot-camera-overlay-20261003/alpha-standard-r3.json和alpha-se.json。透明袋口能透出下层球杆/木边属于双层显示现象，未擅改袋内遮蔽。

## 验证与限制

核心相关80唯一项分包通过（core-r4 79/0＋clone-core-r3 1/0）；真实模型复制逐元素最大世界矩阵误差0，源节点、材质、主camera保持不变。标准原生8唯一方法分包通过，6项在FL-101修后ui-r2，手选力度在ui-overlay-final，完整LP在ui-overlay-r3；最后唤醒修正后ui-recommendation-final同包手选/力度与真实杆末推荐2/0，原assertion保持。SE最终2/0，结果Runtime26.3.1。

FL-101初始化布局取消、FL-102派生节点clone崩溃、FL-103idle后新转场不唤醒均保留原失败证据并修复。gate FAIL0/WARN0；最终真机Debug/-O构建及严格签名验证通过。iPhone16Pro覆盖安装实际失败（CoreDevice1011，设备unavailable），没有新安装或启动PID，不宣称手机体验/热/能耗完成。

尚未验：iPad、竖屏、持触resize、全部球形连续域、用户手机手感；原FP边界与R/P渲染工作另列。截图不构成性能或节能结论。

## 查看

[8张有效长按图集](../../output/shot-camera-overlay-20261003/index.html)。原始xcresult、日志、alpha统计、源hash与签名/安装输出在build/shot-camera-overlay-20261003；原始PNG/录像及manifest在output/shot-camera-overlay-20261003。

2026-10-03 08:40 有线复装成功：设备实时transportType=wired、tunnelState=connected、DDI可用。最终v2.1签名包覆盖安装成功（bundle com.xinkuan.qiuji，安装实例E6C5CFDA-22B9-429D-9131-DB647220A454），带每日清台/候选参数启动，PID10990由实际进程清单复核；保留用户数据，无fixture/reset/premium参数。证据install-wired.json/log、launch-wired.json/log、processes-wired.json/log与wired-device-info.json。此前无线失败历史保留；手机手感待用户体验，不视为能耗/视觉全矩阵通过。
