# 分离角设置“击球”开关 · 2026-10-23

> r2用户纠正：本报告下方r1的三点菜单入口被否定；现行入口为初入页面训练设置，新增重试/临时击球文字。r1证据仅保留历史。

本轮增量来自用户：设置最上面增加是否击球，默认击球；关闭按钮改“提交”，直接显示轨迹。2D/3D均覆盖。上一轮六项反馈（含移除/100）已完成，见[前轮报告](UR-20261023-separation-six-fixes.md)。

## r1实现（入口已由r2覆盖）

- 设置第一项“击球”，共用选中行、关闭入口及滚动，开关操作不关闭菜单。默认开，2D/3D本地专属偏好隔离；播放/准备/保存失败时禁用，冻结提交意图。
- 开启沿原1.5秒首帧揭示后正常击球；关闭改“提交”，物理求解/评分/保存成功后直接显示两条完整轨迹和分数，球留原位、不出杆、不启动击球声音。仍按首答计题，重打计本题均分，回放不重复计分。
- 每杆可选playsStroke标记用于恢复结果；旧记录nil默认击球。结果展示取该杆标记，而不是当前开关；保存失败可重试且不提前扣额。
- 主动“回放”仍观看物理记录，停止/结束回到原提交画面；重打允许重新调整，开关不清题或成绩。
- 共享壳仅新增默认空leadingSettingsItems，其他调用方不插入新项；没有改全局显示偏好/物理/评分/Pro。

## TP影响判定

|条款|处理|验证重点|
|---|---|---|
|TP07/09/16|继承|动作位置、2D/3D、紧凑手机和Pad设置首项可见|
|TP13/15|业务调整|点击才求解；冻结演示意图，后台取消，不能切换在途提交|
|TP20/21/27|继承并加页面专属选项|首项、默认开、保持菜单、2D/3D偏好隔离及重建|
|TP22/24/26/33|业务调整|提交直接显示完整路线与分数，沿原成绩/额度链保存|
|TP25/30|继承|重打、主动回放/停止恢复、重进结果原球位|
|TP35|局部复验|真实测试和原图，旧全页清单及真机未验边界保留|

## 证据与结果

证据目录：`output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/`。本轮在同一仍持有的构建工作目录增量验证；前轮source-final.json及ui-*-r3图为修改前基线，build-submit与后续submit-*属于本轮，不混用。

- build-submit.log：TEST BUILD SUCCEEDED。submit-unit.log：18项单元/集成全部通过（46.981秒），包括真实提交、保存失败重试、按页偏好持久化、旧载荷、原位恢复、回放停止与切回击球。
- SE：2项原生UI通过（86.794秒）；Pad：2项原生UI通过（90.295秒）。双模式均验证首项/默认开、关闭保持菜单、提交文案、两条轨迹、球位不动、无揭示/出杆启动、首答计数、后台回来、回放停止原位恢复、重打以及重新开启后真实出杆。
- 已打开两设备的设置首项与2D/3D提交结果原图：布局/文字清楚，球保持原位、橙目标与白实际路线可见。Pad竖屏3D沿原相机取景，未在本轮调整相机。未重做前轮大字/横竖缩窗全矩阵。
- source-submit.json的源码与实际App二进制哈希在测试后无漂移；git diff --check、文档体积检查通过。
- 功能验证与本轮视觉审查通过；上述自动化是局部验证，保留原全页TP检查表及其未验项。
- 真机听感/VoiceOver、真实购买、全App回归不在本轮证明范围；原先报告的音效缺失仍未确认根因/修复。未提交、未推送、未发布，未覆盖用户17Pro评审现场。


### 代表性原图

- [SE设置第一项](../../output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/submit-se-images/C0137BAE-87E1-48FB-89D4-7766B3DFC5F9.png)
- [SE 2D提交结果](../../output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/submit-se-images/3F4FE2C4-ECEE-4222-B775-97137A3D71FB.png)
- [SE 3D提交结果](../../output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/submit-se-images/19E16E5C-0A04-4520-8FC9-1D1CAC27B22F.png)
- [Pad设置第一项](../../output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/submit-pad-images/48582D8A-82C7-4E7E-AC13-7045141D694E.png)
- [Pad 2D提交结果](../../output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/submit-pad-images/6751242E-773C-414B-8696-D94097567485.png)
- [Pad 3D提交结果](../../output/local-test-runs/cfdefcdf67df45fd85f63c78bed293bc/evidence/submit-pad-images/E4976162-FE3B-476C-8535-21604D25F0A3.png)

截图中的台呢/球桌/球房沿各测试设备原有偏好，本轮未改外观资源。原始附件映射见两个submit-*-images/manifest.json。

资源收尾：两台UI与单测设备租约均已归还；受管run已reclaimed，work已删除，证据保留；本次工具实测可用空间增量2,887,901,184字节（约2.69GiB）。


## r2 · 入口纠正与辅助按钮文字（2026-10-23）

- 击球开关移动至SceneTrainingSettings表单最上方，三点菜单移除。默认开启；以表单草稿保存，开始训练生效，取消回到原题/模式。2D/3D分别持久化。
- 不击球模式：重打→重试，回放→击球。原arrow.uturn.backward/play.rectangle图标、命中、位置、个人布局ID保持。临时击球仍用保存的物理录制，停止/结束回原提交球位，不加分不切模式；主停止文案为停止击球。
- TP20/21/27按业务迁移入口，TP13/24/25/26/33复核草稿/动作语义；TP07/08/09继承图标/位置与容量，TP16/35验两模式手机/Pad。其他全页清单和未验边界沿用。
- r2证据：`output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/`；before-source归档改前源码，r1原图为错误入口before，r2构建/功能/原图验证进行中。

首轮r2测试：构建通过、提交/回放恢复集成测试1项通过（3.788秒）。SE/Pad各2项UI在关开关时失败：原生Toggle的AX框包含整行，tap()落到行中空白（SE实测x187.5/y135.25），原图开关位于右侧。测试改为在该AX框的实际右侧开关点按，保留原断言，产品源码不因测试点击修改。原失败日志/xcresult/截图保留，正在复验。

复验进度：build-r2重新构建通过，仅测试改点右侧开关；生产代码与首轮一致。SE/Pad的2D完整入口→提交→临时击球→重试→取消设置→开启正常击球流程已通过（60.091/59.675秒），3D继续验证。UI继续断言三点菜单无该选项、辅助按钮名称、球位恢复、原题保持，未删减首轮断言。


### r2最终判定

- **构建/功能通过**：build-r2.log成功；unit.log集成1项（3.788秒）；se-r2.log双模式2项（119.979秒）、pad-r2.log双模式2项（119.397秒），均0失败。首轮错误点击的失败包保留，不计通过。
- **视觉通过（本轮范围）**：已打开SE/Pad入口表单及各自2D/3D提交结果原图；开关确在初入训练设置第一行，默认开启；结果动作文字为重试/击球，箭头与播放图标、标准位置保留。Pad竖屏3D相机沿既有取景，本轮未调整。
- **恢复语义通过**：表单取消不改模式/题目；临时击球停止后仍回提交结果，重试仍为提交，正常模式恢复重打/回放。不重复计首答，现有分数算法/生成范围不变。
- **完整性**：source-r2.json源码及二进制哈希测试后无漂移；diff和文档体积门禁通过。没有安装/重启用户17Pro评审机，没有提交/发布。真机、购买、大字/全部窗口矩阵仍沿前述未验边界。

r2原图：[手机入口](../../output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/se-r2-images/88E4EACA-FBF7-4B20-BB5B-96ED3F2536A0.png) · [手机2D结果](../../output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/se-r2-images/F6C1811D-B217-4B5B-B0EA-3B132332E85C.png) · [手机3D结果](../../output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/se-r2-images/D73BEB7C-3893-40F3-ACC7-0DE2B4F41346.png) · [Pad入口](../../output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/pad-r2-images/16D2685E-D73F-4144-9EE8-56B782E67938.png) · [Pad2D结果](../../output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/pad-r2-images/C702E74C-0733-4248-8694-92DB7725A4DF.png) · [Pad3D结果](../../output/local-test-runs/47fbb45d53ab4cd18b2982e9bedd30fa/evidence/pad-r2-images/B6020459-8858-45EF-A390-59518BF752D3.png)。

资源收尾：r2受管run已reclaimed，work删除、证据保留，设备租约归还；工具实测可用空间增量1621729280字节。
