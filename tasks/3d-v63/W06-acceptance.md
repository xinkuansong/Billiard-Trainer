# W06 接管、返回、跨区接触与主调度验收

日期：2026-09-13。范围以问题集合_v63.md W06为准。本批完成；完整v63未完成。

本批已经把局部求解接入EventDrivenEngine的显式混合主循环，不仅是孤立局部求解器。正式simulate仍由W07统一全部调用入口后切换，本报告不声明App进袋已修复或真机验收。

| W06完成标准 | 代码与实际证据 |
|---|---|
| 平面进入局部并返回 | Double LocalPocketOwnership、有限区域连续进入、真实支撑返回；mixed-continuation-green-r2含混合返回及双袋推进；六袋代表边界/网格对拍见W06-working DR171–174 |
| 连续重入 | mixed-reentry-regression-r1与coincident-entry-r2：中袋进入→返回→平面球碰撞→再次进入，时间/ID顺序验证 |
| 局部球与台面球接触 | mixed-main-r3、static-event-pipeline-r3：域外接收球动量传递、台面支撑与局部晋升；全桌快照覆盖域外邻球，无需全桌积分 |
| 两球近同时进入同袋 | mixed-boundaries-r1及mixed-continuation-green-r2：角/中袋两球从台面连续来球到1.4s，均下降、各一次接管，无旧吸袋 |
| 事件不提前/重复、共同时间 | mixed-continuation-green-r2精确截段、静态事件r3前缀/续算一致；coincident-entry-r2同刻独立平面碰撞与参考一致；首次碰撞元数据为绝对时间 |
| 接触组无额外能量与穿透 | 主同袋用例、真实复杂近袋连续间距证书、W05临界/返回能量；mixed-reentry-regression-r1共38测通过 |
| 高速、重复和步长误差 | mixed-high-speed-r2及coincident-entry-r2：2/8/12m/s对称三球，每档重复同一步长及半步共9次模拟；两次接触同刻，状态重复精确一致，逐对连续间距/能量通过。共同空间误差预算4e-6m，实测最大约3.1e-18m；仅为该矩阵结果 |

最后生产调整的回归：coincident-entry-r2共4项0失败/TEST SUCCEEDED。此前最近相关回归：static-event-pipeline-r3三项、mixed-reentry-regression-r1三十八项、mixed-continuation-green-r2五项；各套件有重复，不能相加当独立功能数。所有原日志/xcresult位于output/3d-v63/W06，包含失败、编译筛选错误和修复后的证据；W06-working保留完整过程。

固定步缓存绑定输入/参数版本，运行中改输入拒绝陈旧预测；本批不提供任意时刻编辑既有轨迹的产品功能。空间球球系数在显式入口由调用者提供，静态参数沿用W05原型，尚未实物标定；W07必须确定与旧入口一致的生产参数契约。几何面接触记录不是直接计分/吃库事件，持久化需要几何版本；由W07/W08继续衔接。

后续范围未缩减：W07统一捕获与规则/预测、W08实时/回放/序列/导出、W09–W15全页面、W16设备性能/可访问性、H01–H04跳球/扎杆与输入兼容全部保留。2D/3D不能改变物理结果；不能以本报告替代正式App截图、设备或真实参数验收。
