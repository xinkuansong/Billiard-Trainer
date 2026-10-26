# 摆球优化生产接入与默认杆速10 · 2026-10-26

用户明确授权：「将我们现在的优化结果用到代码里吧，然后默认开球速度设置为10」。本轮角色为Orchestrator实施与定向验证；不是新增研究提案。当前状态：实现与定向验证完成。两轮13项/36项XCTest通过，1000副生产开球对拍全部一致。

## 生产行为

- `RackLayout.make(.chineseEightBall)`采用已验证`radial_sideM60`：先按原顺序洗球号和采样，再保留每球Float实际偏移长度，以整阵径向/切向共同方向进行两侧±30°预折叠旋转，再折叠向内。算法与研究对齐，不进行逐架试开/挑分/重抽。
- 原0.20mm名义间隙、0.09mm最大偏移、编号/8号/底角规则和世界高度保持。9球及4/5/6球摆法不外推这项15球研究。
- `BreakFlowRunner.defaultBreakVelocity = 10.0`，已有开球量程上限10保持；用户仍可调力度、打点、瞄准。
- 每日清台原来单独覆盖8，改为消费上述共用常量。其他三个实际开球宿主直接采用runner默认值。
- 本次改变新建15球摆架的同seed结果；已保存球位快照不重算。正式多球球库读取已生成的球坐标，不在此轮重生成。

## 几何与适用性

世界X–Z为台面，Y向上，单位米；球心Y=surfaceY+R，俯视+X右/+Z下。Slots/球径源于生产常量。等比例研究图册已有核验；本次不改布局/渲染。

局部复核：TP10按本次用户指令更新开球默认10；TP13继承调参与出杆分离；TP25继承开球/重开/交付语义；TP26继承快照和成绩；TP29按已验证15球算法更新摆架；TP35/36记录本轮证据与现行规格。其余布局/相机/无障碍项本轮无变更，未以此宣称新增界面或全设备验收。依托现有DEFAULT-SHOT-SPEED及每日页面合同，只复核参数/调用链，不扩展全表重测。

## 验证与资源

1. 完整App/测试构建 + 13项XCTest成功：RackGeneratorTests 9项（含两个研究冻结样本）、BreakFlowRunner默认实例10、BreakRackPhysics的三项全玩法几何/确定性/扰动回归。`output/local-test-runs/48789a8013674e8296bffe18bb21a1f2/evidence/test-results.log`，**TEST SUCCEEDED**。compact-pad已关机，临时构建回收约1.56GiB。
2. 原生对拍重新编译**当前生产RackLayout与BreakFlowRunner**，直接调用当前RackLayout，其他物理对象冻结且逐源绑定。与力度研究1000副10m/s的摆球、瞄准、停球、落袋、接触事件及早期状态逐位比较；未重复应用研究方向变换。1000副全部逐位一致且全部停稳，生产默认10核验通过。模拟器已关机，构建工作区回收；结果见`output/rack-production-integration-20261026/closure.json`及`replayed.jsonl.gz`。
3. 每日清台真实宿主默认10和既有控制器回归补验通过：完整构建及36项XCTest（每日26、摆球9、共用默认1），0失败。真实宿主验证进入时不自动击球、10可改7.5、停稳交付；其余覆盖草稿/重开/权限及规则。证据：`output/local-test-runs/0b6a38f5e7de45558a23ea149ca91578/evidence/test-results.log`，**TEST SUCCEEDED**。两台设备均已关机归还，全部本轮临时构建已回收。

研究对拍首个驱动调用缺Python import路径，在编译/启动模拟器之前失败；已修正导入路径，失败证据保留，旧工作目录通过生命周期回收。不是生产缺陷，也未跳过任何断言。首次失败run：0475330264c24c01a31d8248a5c7c620；重跑：59c6d7793a224e518d05ba83d41d1b95。

生产改动：RackLayout.swift、BreakFlowRunner.swift、DailyClearanceController.swift。保留并行任务已有授权回调和普通击球默认2.0变更。无提交、发布、真机安装；真机手感/全页面UI矩阵待用户后续体验。

原生对拍后仅将BreakFlowRunner末尾遗留注释“默认8”改为“默认10”，与运行时哈希差异按字节核对；记录见`post-replay-source-review.json`，无功能差异。当前生产最终SHA见`verification.json`。下一步为用户真机体验，尚未发布。
