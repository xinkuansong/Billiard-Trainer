# 当前版千条磁盘读回结果

2026-09-07，snapshot-003，专用游客 CE76026D。通过环境探针、真实 SwiftData 磁盘播种、正常 App 启动与 UI 抽样验证；没有使用内存/深链数据夹具驱动 UI。Pro 参数只开放统计，不证明购买。

- probe001：1/1，0.035秒，make0；seed001：1/1，0.455秒，make0。实际1000场/1000entry/1000set、队列0。
- ui001：1方法失败，439.125秒，make2/xcode65。已读回999与滚动后的978，两条8/10且唯一note匹配；概况1天/2000分钟/1000组。分类组数显示“1,000 组”，原测试要求“1000 组”，属于定位失配。原失败保留。
- ui002：仅追加统计与返回历史补验，1/1通过，121.968秒，make0；80%、8000/10000球、1,000组同一分类行，返回历史可用。不重跑滚动样本。
- 主控逐张审查001五张、002三张自定义PNG及相应AX；概况标题与数字对应，详情note999/978正确。容器因安装重定位，最终manifest仍与原seed逐字节相同；证据resume-20260907/thousand-container-chain.json。

局限：只抽两条，不遍历千条；同日单类合成数据，不是用户真实输入或跨日混合账本。自动化约7分钟的首轮含大量AX查询，采样主要在XCTest可访问性快照、观察内存约1.8GB，不能外推普通交互耗时/真机内存/性能达标。见THOUSAND-RESUME-OBSERVATIONS.md。

原始证据：formal-resume-thousand-probe-001、formal-resume-thousand-seed-001、formal-resume-thousand-ui-001/002，各含inputs/命令/log/exit及xcresult路径；UI attachments含完整manifest。所有目录位于build/quality-diagnosis。
