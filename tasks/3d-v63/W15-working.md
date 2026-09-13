# W15 每日清台

2026-09-13，依据问题集合_v63.md W15：完整开球→续打→结束/结算及中断恢复；模式切换不重复记录/计分；母球进袋及合法目标保留现有规则。W14本地验收已归档，W07–W10完整兼容/性能仍未关闭。

实际入口是FreePlayView(entryMode:.dailyClearance)，原先is3D和toolbar排除每日清台；DailyClearanceController独立处理开球结果、规则、草稿、完成与计时。首次接入仅解除观看入口限制，完成/失败底栏保留原94pt，3D自由球提示注明2D拖放；控制器/规则/存储未改。

baseline-r1实际UI通过并查看6219A7B7截图，使用fixtureSettled替代开球结果，只作2D布局基线，不宣称真实开球验收。roundtrip-r1主动中止（session24307终态75），发现测试犯规文案应匹配真实可访问标签“1 次犯规”后改正；没有已运行结果被当作通过。roundtrip-r2/session25626正在验证进度夹具三轮模式往返及DailyClearanceControllerTests。

待验：真实自动/手动开球、续打/规则与母球入袋、完成/失败3D底栏、计分与落库唯一性、中断恢复、紧凑/iPad实际画面。完整目标不缩减为入口切换。

roundtrip-r2/session25626终态0：12项DailyClearanceControllerTests/0.051s通过，覆盖五玩法启动、恢复、重复计时与完成等控制器逻辑（mock host，不是物理开球）；实际UI三轮相机往返1项24.838s通过，保留2杆1次犯规。D3734A6B原图已核，HUD与观看控件可见；夹具球形包含靠库位置，不用此图证明真实开球的球形合法性。gate-r1/session22871终态0。下一步真实开球/续打以及完成失败/恢复矩阵，无活跃句柄。

real-r1/session60296终态0，真实9球自动开球→3D自由第一杆→终止App→不清草稿重启，1项35.756s通过；实际0杆→1杆并恢复1杆，无fixtureSettled。5BB659CF/1E1A2B20/027ACAA8三原图已核。恢复图显示母球在桌但“母球进袋”提示：源码确认VM.cuePocketed来自pred.cuePocketed（PositionPlayViewModel约1026行），是下一杆风险而非上一杆事实，故共享FreePlayView提示改为“预计母球进袋”，不更改计分/物理。该文案修改尚待构建。真实终局与完成记录唯一性、母球入袋及平台矩阵仍待验。

prediction-copy-build-r1/session96675终态0且BUILD SUCCEEDED，git diff --check通过。文案构建完成，未将其作为新截图验收。无活跃句柄。

results-r1/session43737终态0：终局重复回调/恢复后完成记录不变单测1项0.018s；完成/失败UI夹具1项25.039s。查看CE628850发现完成记录进入仍显示初始化示例且击球可用，故不接受该视觉结果。DR-266修复终态击球/编辑边界，完成记录初入清除示例球形；results-r2/session51826终态0，1项25.933s验证完成/失败3D及2D均无击球按钮，结果操作可点。219721E7/D78ADCD6两原图已核，示例球与击球工具已移除，结果底栏可读。results-gate-r1/session34817终态0。这两页来自终态夹具，不冒充最后一球真实入袋完成；真实终局、母球入袋/补回和再开局仍待验。

final-ball-r1/session96614终态0，实际末球输入夹具（仅母球x=.5/y=.23、9号x=.5/y=.08）→正常求解/播放/规则结算→再来一局真实自动开球，1项27.712s通过。数值草稿final-ball-input.json：世界X均0，Z=-.0508/-.4318，台内且间距.381m；没有注入预测或成功结果。E513679A/40B06592/A86D058F三图已核，末球合法落袋1杆0犯，新局0杆，但新局画面仍近袋裁切。

相机追踪：FreePlayView的breakRunner.seed变nil（开球交付）仍调用focus，且自动开球建立runner时也使用沿杆focus；改为仅非nil种子响应，自动开球选全桌、手动仍开球瞄准。final-ball-r2/session73683复验中。final-ball-gate-r1针对修正前版本退出0。

final-ball-r2/session73683终态0，真实末球完成→再开球1项34.632s通过；6A4BF33B新局原图已核，全桌/各球可见，0杆保持3D。DR-267记录相机修复；实际母球入袋/补回、手动开球及平台范围仍未验。

final-ball-gate-r2失败于路由表层签名：仅FreePlayView漂移；验证器取sheet后7行，捕获了新球架取景if行。将该行在签名payload替换回旧单行后SHA精确等于旧签名，证明无额外路由漂移。仅更新该文件签名和FreePlay覆盖行（真实末球/再开球全桌），未改验证器；r3复验。

DR-268修复普通scratch仅提示却无母球可拖的断点：真实规则判继续自由球后复用VM安全空位补球，补回后保存草稿；终态不补。finishStrike在规则回调前isPlaying=false，符合placeFromPalette调用条件。scratch-controller-r1/session14905终态0，14项0.062s通过，其中继续scratch保存带母球/终局犯规不补两分支通过。该test使用mock host，仍需实际物理入袋和可继续操作验证。

scratch-ui-r1/session10238终态0：仅输入scratch球形及指向中袋的自由杆向，正常播放→1次犯规→母球观察菜单可用→真实第二杆→不清草稿重启，1项33.249s通过。5388BB92/846E6B88/2ED0EC13三原图已核，初始预测母球进袋、补回后母球在安全空位且可击球、重启2杆2犯。没有注入落袋结果或规则结果。强杀后计时从上次保存点恢复（截图1:19之后→1:07），下一步核验杆末保存时机，尚不宣称完整中断用时保持。

杆末计时保存验证：timer-r1.xcresult 实际15项控制器测试全部通过（0.060s），新增 test_eachSettledShotPersistsElapsedTimeWithoutDoubleCounting 验证两杆分别保存12/20秒、重建控制器恢复20秒、再次flush保存23秒且重复flush不累加。handleShotSettled在保存杆数/球形前累计活跃用时并重设时钟锚点。仅保证已保存杆末用时，不承诺强杀前未保存间隔零丢失。手动开球实页仍待验。

计时修复门禁：timer-gate-r1退出0，verify-gate、verify-doc-size（PROGRESS 99KB/10条）、git diff --check通过。手动开球新增真实UI流程manual-r1正在运行，输入待开球fixture，无结果注入。源码发现待核缺口：FreePlayView取消仅调用vm.cancelBreakFlow恢复旧桌面，但dailyController仍是manualRacked；该阶段handleShotSettled拒绝计分。需验证取消后是否出现可击球却不计分的状态，再决定最小修复。

manual-r1/session9116终态0：SE真实手动9球开球→停稳→点击完成交付→终止并恢复草稿，1项31.802s通过，无fixtureSettled。AC816FB3/73629AAB/CCC67882三原图已核：待开球瞄准构图，停稳全桌与完成按钮，交付后0杆且击球工具可用。取消分支仍未验，W15不宣称完成；当前无活跃测试句柄。

DR-269：v52确认重开即放弃旧局，取消仅恢复VM会产生manualRacked却可击球的死局；每日开球栏隐藏取消，保留页面返回和草稿恢复。manual-r2/session45326退出0。另发现重开只增runner.seed、controller仍旧seed导致结果被拒，新增可选onRerack路由每日confirmRerack，默认其他页不变；manual-r3/session99241正在验证。

manual-r3/session99241终态0，实际1项39.402s通过：待开球重开→终止恢复→真实开球→停稳完成→再重启恢复0杆；各手动阶段无取消按钮。5E438B9F停稳原图已核，完成/重开操作可见、全桌球形可见。manual-gate-r1/session38760退出0，verify-gate/doc-size/diff通过。测试包含重开后重启，尚需直接重开不重启的交付及普通宿主取消回归；W15保持进行中。当前无活跃句柄。

DR-269复验纠正：manual-r4/session79206终态65；普通自由击球105.177s通过，每日清台51.193s失败于最终重启后HUD不存在。交付图A2C8A401显示余0/旧待开球文案，不能接受。根因进一步定位：startBreakFlow守卫breakRunner==nil，controller重开保存新seed但host未拆旧runner，启动被拒。每日host现在在替换前cancelBreakFlow，再startBreakFlow；仅每日路径变动。manual-r5/session17950验证失败原路径及控制器/规则/存储。

manual-r5/session17950终态0：控制器15/规则11/存储5共31项0.082s通过；同一不重启直接重开→实际交付→再次重启恢复UI 38.303s通过。BCAB2FEC交付原图已核，实际剩余球数及开球完成文案恢复，避免r4余0/旧文案假交付。direct-gate-r1/session97451退出0。普通自由击球取消回归沿用r4的105.177s通过，host替换改动仅每日入口。无活跃句柄。W15证据已补齐主要业务链，后续需整理批次验收并保持W16平台范围。
