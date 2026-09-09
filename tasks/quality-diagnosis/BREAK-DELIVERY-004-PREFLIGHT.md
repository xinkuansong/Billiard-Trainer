# 正常九球开球与手动交付预飞

2026-09-08，SC21/L4。依据 BREAK-MODE-CLOSURE-004-AUDIT 与主控全文复核的 BREAK-DELIVERY-004-ORACLE-AUDIT，沿用专用设备 9DC47676-D81A-4F3D-AF31-352180B69344、普通游客入口、内存库和中文启动参数，无盘面/权益夹具。

观察001在进入工具前因脚本把左栏当上边界失败24.283秒，原件归档；002修正为含自由击球的唯一内容列后通过30.516秒。002终态完整图及AX确认“开球玩法”面板、Button break.game.9 / 9 球可见。点击后立即PNG曾捕到过渡帧，终止前PNG显示完整面板，不能把前图当面板未打开。

新方法 `BreakDeliveryDiagnosticUITests/testNormalNineBallBreakAndManualDeliveryPreservesSettledBoard`：正常进入→菜单9球→实际静止球架→开球一次→最长90秒等待完成→停稳采样→完成一次→普通击球状态→球集合/位置比较→正常返回练习。

球架必须为cueBall和_1至_9，停稳允许落袋减少，但须有停稳前已补回的母球。精确ID的firstMatch取既有真实AX同级外层语义球根，排除paletteBall及隐藏根的小mesh；仅外层小于桌宽1/10且完整位于真实tableVisual范围者纳入。主控必须以新rack/settled/delivered完整PNG和AX再次核此树结构，不因方法绿直接判全链通过。

完成前后球ID集合严格相同，屏幕中心各轴≤2pt（沿用当前同投影诊断容差），stage/table框各值≤2pt；母球朝向允许变化，不断言宽高一致。该容差不代表真实毫米误差，必须结合视觉球心核对。保存delivery-comparison.json原始框值，若投影变化或根结构失配，保留失败并分析，不降级精确集合断言。

连续录像只用于真实散开/停稳证据，不调用测试注入停稳缝，不换seed重复到绿，不写正式资产。新叶目录、每阶段先PNG后AX，失败证据保留。后续必须审完整球架/停稳/交付图及运动录像；这是当前普通宿主代表链，不能替代每日清台终态或所有玩法/宿主。
