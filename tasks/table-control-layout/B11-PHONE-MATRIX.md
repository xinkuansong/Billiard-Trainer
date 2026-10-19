# B11 手机全量组合与外围回归

状态：✅ 技术验收完成（2026-10-18），真实VoiceOver按v1.2留最终人工验收。

矩阵：18入口×标准手机/SE，逐页真实UI恢复默认→保存个人8pt偏移→恢复；默认/个人/恢复3节点，核业务快照和位移。前序各页2D/3D、实际业务动作、共享链保留索引，不代替本批全量冒烟。

## 外围消费者源核查（2026-10-18）

- 控件布局读取只存在ControlLayoutHost/Editor/Library；宿主为FreePlayView、BTTeachingTablePage、SceneAimingView、AimPointSceneTrainingView。
- DrillDetailView使用DrillSceneView(.drillDetailPreview)，DrillRecordView使用.drillRecordPreview；两页不支持布局，嵌入播放不包含Host。详情“试打”转P06后才适用。
- BTAimTableView、ContactPointTableView、GeometricAngleQuizView、AimPointTrainingView及文章图解未引用布局存储/解析/Host，图解成绩身份不合并。
- BallExtractionView与BatchAuthoringView直接AngleSceneView，未读布局；确认进入编排台之后才用composer入口；本次不执行原照片写回或内部资产导出。
- SequenceVideoExporter直接SceneKit离屏渲染，不依赖个人操作位置，不存在布局存储读取；未重跑整库导出。
- 同期自定义球形练习/编辑不在18入口中，supportsControlLayoutEditing=false由纯值回归核验。

源核查与原生UI证据分开登记；以上不等于外围全部已做运行时回归。真实VoiceOver留最终人工验收。

## 本轮追踪

- 标准手机与SE共36个入口单元已完成默认/个人/恢复冒烟（108节点）；设置隔离、旧偏好和嵌入播放均已补齐，见下方验收结论。
- r01试打：ProAccessGate把诊断元素identifier继承成pro.authorized，按实际语义值status=定位后r02通过；未改生产权限门控。
- r01三球规划两机保存等待失败，磁盘同期耗尽，末尾截图缺失、录像无法封口；保留失败，不伪造具体错误文案。清理已替代编译产物后，同产品代码r02两机通过。后续r01答题受低磁盘影响或主动中断，全部补跑；通过项录像另验完整性。
- 空间恢复只触及本任务可重建缓存和旧安装：数据tar备份、逐份校验后卸载；原截图、录像、日志、源码快照和各批最终包保留。SE首次清理因file URL与路径比较不等而安全拒绝，未删数据；规范化后26项完成，记录storage-check。
- r02 verify-gate曾报同期路由签名漂移；之后只读重算差集为空，最终门禁收口时再跑，不以修改签名放行本任务。

## 验收结论

- 18入口×标准/SE=36单元，108原生节点、实际8pt偏移与恢复、同场景/题目/参数断言全通过，全部逐图复核；完整映射见output/table-control-layout-20261017/coverage.json。
- r02设置管理：SE浅色/XXXL，复制、改名、批量应用、族默认、引用删除、原显示偏好保持，4节点通过。其他字号/主题组合沿用B03–B10各卡真实记录；未声称18页全主题×全字号穷举。
- r02原TablePreferencesUITests的testViewMemoryIsolationAndSameValueReapply和testLocalTrajectoryHiddenMemoryAndGlobalSameDetailUnhides各实际执行1条通过，3+2张图；保留同值覆盖、局部轨迹隐藏记忆及全局重开语义。
- r02嵌入详情2D→3D→播放→返回全屏，3节点通过，嵌入页无布局读取入口、全屏保存修订与8pt仍在。其他外围消费者为上方源核查，未宣称逐页运行时测试。
- 五族完整共享链分别见B04/B05击球、B07规划、B08教学、B09角度、B10瞄点；边界/换侧/面板/忙碌/计时/身份回归见上述批次，不以本轮冒烟替代。
- r02成功构建、33项纯值/存储测试、文档体积和diff检查通过；全门禁的同期签名漂移保留日志，B12最终重跑。
- 适用生产文件11项哈希与B11冻结源一致。未安装真机、未提交或发布；下一批B12依赖已就绪。
