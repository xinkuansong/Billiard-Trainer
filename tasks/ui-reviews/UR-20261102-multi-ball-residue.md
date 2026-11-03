# 多球走位 · 首袋回退残留 · 2026-11-02

已按用户要求将P05的后续选择撤销规则用于多球走位。退回第一袋立即撤销第二球、第二袋、第三球的绑定及角色显示；实体球与球位保持。退回第一球还清除第一袋。中八同袋重选仍需重新选择后续球；追分新局预览保持，回退后重新确认第一袋才恢复规则球序，第二袋必须重选。

范围沿MULTI-BALL-BACK卡TP06/14/25/26/35，未改布局、字体、HUD。多球没有P05推荐区域绘制器，本轮清除已有后续规划绑定，不增加区域能力。当前杆正常预测线保留，不视作后续规划残留。

Mac mini Xcode26.2，iPhone17Pro/iOS26.2；job `multi-ball-residue-r4-20261102`，快照 `ec4622bbe64c936446e38f442c3350b27984fd22d207af87e960b07b8791b98c`。正常构建通过，32项多球逻辑＋2项原生UI全部通过，0失败/跳过。新增逻辑核验中八和追分的真实场景节点、袋材质、球位不变、检查点保存恢复及同袋重选；原成绩冻结和重打用例保持。两项UI显式切换并断言2D/3D视图。

最终四张原图已逐张打开，路径 `output/multi-ball-residue-20261102/r4/review/`：

- `residue-first-pocket-cleared-false.png`：2D首袋回退，顶部只剩①；②③圈及第二袋颜色消失，所有目标实体球仍在。
- `residue-first-pocket-cleared-true.png`：3D同状态，首球与首袋保留，后续圈和袋已撤销。
- `residue-first-pocket-reselected-false.png`：2D重选首袋后提示选第二球，旧后续角色没有恢复。
- `residue-first-pocket-reselected-true.png`：3D重选同样正确，未见本轮引入控件位移或提示截断。

改前对照采用前轮真实“退第二球”残留图：`output/multi-ball-back-20261102/screens-r4/13C98040-A0D0-4F27-B04C-A53FCB987C53.png`。该图已打开，其controller与本轮改前副本哈希一致；不冒充本轮首袋改前截图。

r1的31/32逻辑及2项UI通过，但因追分新局固定预览回归整轮记失败；保留原失败断言并修复。r2排队取消未执行。r3构建通过，容量上限导致测试未执行；精确回收本任务r1失败临时设备后，r4同快照复验成功。所有原失败证据保留，不覆盖。

证据根目录 `output/multi-ball-residue-20261102/`：r4/evidence为原始结果，inspection.xcresult为独立导出副本；test-summary、回传校验、四个相关源码哈希匹配及task.patch均保留。完整4301文件快照归档delivery-source.tar.gz已逐文件校验。该快照不代表其他并行修改已验证。

真机、iPad、VoiceOver、全App回归及用户体验认可未验；未安装真机、提交、推送或发布。
