# snapshot004 Ask to Buy：pending→批准→实时权益与高级入口

2026-09-08，Test Engineer。只读核源及任务目录草稿，未注册、编译、运行或操作设备；不修改业务、snapshot、工程及共享台账。

## 独立草稿

`StoreKitPendingDiagnosticUITests.swift`，精确一个方法：
`StoreKitPendingDiagnosticUITests/testAskToBuyStaysFreeUntilApprovalThenUnlocksAtlasWithoutRestart`。

专用本地模拟器环境：`QD_STOREKIT_PENDING_AUTH=DEDICATED_LOCAL_STOREKIT_SIMULATOR` 与 `QD_SHOT_DIR`，兼容 TEST_RUNNER_ 前缀。主控负责新设备、唯一UDID、DerivedData/输出目录与全机UI串行；环境字符串不能替代真实隔离核查。沿用已审身份 fixture、内存库、resetDebugPremium，不传任何强制权益参数。

## 已核冻结源与 SDK

- `QiuJi/Data/Services/StoreKitService.swift:42–52`：真实 Product.purchase 返回 pending 后抛 StoreError.purchasePending；该错误文案为“购买正在处理中，请稍候”。不使用 session.buyProduct 替代真实 UI 购买。
- `SubscriptionManager.swift:280–299`：pending 落一般 catch，返回false并写 errorMessage，defer恢复isLoading；只成功购买才直接checkEntitlements。`listenForTransactions():329` 遍历 Transaction.updates，verified交易 finish 后 checkEntitlements。init 默认 listenForUpdates=true。
- `SubscriptionView.swift:66–70,306–310`：错误对话标题实际为“购买失败”，确认按钮“确定”；pending消息不是未知系统弹框。因此这里能用精确App alert selector，不涉及待观察的真实付款取消节点。**草稿断言该标题只是钉住当前实现用于取证，不认证标题合适；pending被称失败须在诊断中记录实际措辞。**
- `ProfileView.swift`：profile.accountHeader 标识与服务端球友 fixture；profile.membershipSummary 是组合节点，只在isPremium时呈现，使用any查询和label包含Pro会员，不要求readonly文字hittable。
- `AngleHomeView.swift:162,430–461`：学习分类的分离角图谱明确 isPremium=true，Button identifier就是“分离角图谱”；open以manager.isPremium决定弹订阅还是路由进入。`angleHomeTab_学` 为真实分类ID。
- `SeparationAngleAtlasView.swift:329–331`：真实交互按钮 `separationAngleAtlas.spinLegend.0`，value“已选/未选”、isSelected；草稿进入后隐藏再恢复此条路线，证明工具真实可操作，不只检查Pro角标或页标题。`LearningTourDiagnosticUITests`已有同一路由与按钮诊断实现；先前学习图审仅用作入口参考，本批仍须独立运行取证。
- 本机 iPhoneSimulator SDK StoreKitTest.h：askToBuyEnabled、disableDialogs可读写，approveAskToBuyTransaction(identifier:) throwing，SKTestTransaction含identifier、originalTransactionIdentifier、pendingAskToBuyConfirmation、productIdentifier、state。本草稿直接批准先读回的那个pending.identifier，不造新交易ID。

## 方法执行合同

1. UI测试bundle正式Products.storekit显式初始化本地session，reset/clear，disableDialogs=true、askToBuyEnabled=true且读回确认，交易0，loadProducts/purchase错误注入均nil。初始化失败直接失败；不回退真实商店。
2. 正常我的身份且非Pro，进入订阅管理，真实月度选中、CTA每月，只点一次购买。
3. 精确App提示出现；有界等待实际交易总数1且pending恰1，产品为月度，无purchased。保留PNG/AX/交易，关闭消息，月度仍选中且购买可操作。关闭订阅页，个人页无会员标记。
4. pending期间正常进入“练习→学→分离角图谱”，必须仍弹订阅，不能出现实际图谱交互按钮。关闭后回我的，仍免费；再次核pending ID与最初一致。
5. 在当前我的页批准相同ID，不重启、不activate、不恢复购买。最多15秒等实际membershipSummary出现且Pro会员、身份不变。核本地恰1 purchased/no pending，并保存批准ID与交易original ID供审查。
6. 同一进程再点相同高级入口，应真实打开图谱，不再弹订阅；点击路线按钮，值从已选→未选→已选，保留三状态。正常返回我的仍Pro，交易仍1，无重复购买。

每阶段先落盘PNG，再收交易摘要与App AX；terminal证据在terminate/clear/reset前。异常抛出/断言失败也保留terminal，不try?吞错。进入图谱最长45秒沿已有SceneKit页面预算，不能因此放宽15秒实时权益刷新oracle。

## 边界与审核注意

这是一次本地 Ask to Buy 待批准流程，disableDialogs=true；不证明真实付款弹框取消、真实家长账户批准、商店服务网络、账号付费归属或生产收据正确。没有force权益、强制重启刷新或后台购买seed。

按钮类型/identifier在源与现有诊断中均有依据，不依赖未知付款节点。草稿要求iPhone实际TabBar存在、非空frame、目标完整位于window/可见上下边界；超出上沿向下滚、超出下沿向上滚，有界8次，失败保留，不猜坐标。主控仍需首次执行核AX和截图，不把源码可达宣称本次已验证。

交易oracle严格为一个pending经批准后一个purchased；如果当前Runtime批准形成不同历史表示或加速续订产生更多交易，先审PNG/交易identifier/original/state及本地时间设置，不能直接放宽为“有一个purchased就算”。保留原失败区分SDK历史表示和产品重复购买，不用多次purchase重跑来凑成功。

批准后未实时刷新时本方法即失败，禁止重启补绿。可另设重启旁证区分启动恢复，但不能覆盖本项失败。pending提示标题“购买失败”是当前实现事实，是否合适应单列诊断，不与“无提前权益/实时刷新”两个状态正确性结论混同。
