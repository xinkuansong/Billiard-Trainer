# 成果与全部中间产物台账

更新：2026-10-08。恢复入口：[CURRENT](CURRENT.md)。

## 登记规则

- 一份独立成果或一组原始文件分配一个稳定 A-ID。批量组必须有逐文件 manifest（路径、类型、大小/hash、批次/修订、生成条件、证明内容）。**未生成的文件不写成已交付。**
- 状态写“工作文档/候选/已选设计/已实现/已验证/历史/失败/被替代”；设计批准、云同步、回导、原生验证各自记录。
- 新候选保留旧 A-ID，以 `supersedes` 指向被替代项；用户粗调原稿只读保留。每个阶段都能回答“从哪一版来、现在采用哪一版、为什么”。
- 原始日志、xcresult、截图、录屏和源文件归批次目录；读者从本表或批次卡进入，避免散落在聊天消息。已有外部成果登记为引用，不计本工作包新交付。

## 当前成果

| ID | 成果/类型 | 来源与位置 | 批次/版本 | 状态与能证明什么 |
|---|---|---|---|---|
| A001 | 需求真源/总方案 | [PLAN](PLAN.md) | B00→B01 / v1.1 | 工作方案；不证明设计获准 |
| A002 | 进度与恢复入口 | [CURRENT](CURRENT.md) | B00 / 持续维护 | 唯一活动状态表 |
| A003 | 页面/状态与版本总清单 | [PAGE-INVENTORY](PAGE-INVENTORY.md) | B00→B01 / 盘点v1 | 38族拆成117覆盖条目；源码盘点，原生与设计仍待核 |
| A004 | 用户决定与反馈 | [DECISIONS](DECISIONS.md) | B00 / 持续维护 | 用户模型选择、范围建议及待定项 |
| A005 | 执行和并行协议 | [EXECUTION](EXECUTION.md) | B00 / v1.0 | 文件/工具所有权、证据与更新规则 |
| A006 | 本成果索引 | [ARTIFACTS](ARTIFACTS.md) | B00 / 持续维护 | 所有产物及来源入口 |
| A007 | B00 执行与验收记录 | [B00](batches/B00.md) | B00 | 方案编制的 DoD 与真实证据 |
| A008 | 并行源码调查与主控复核 | [源码核查](batches/B00-source-audit.md) | B00 / 2026-10-08 | 三子智能体返回、主控核对、边界与冲突；非运行验收 |
| A009 | 编制前源码与工作区基线 | [source-baseline.json](../../output/app-interface-redesign/B00/source-baseline.json)、[git-status-before.txt](../../output/app-interface-redesign/B00/git-status-before.txt) | B00 | 686 源码/配置指纹、HEAD/dirty；不代表可运行版本 |
| A010 | 独立方案审查 | [independent-review.md](../../output/app-interface-redesign/B00/independent-review.md) | B00 / gpt-6-astra | 无阻断项；跨工作包资源协调、入口状态分列两建议已采纳 |
| A011 | 文档验证、初次诊断及修正检查日志 | [verification.txt](../../output/app-interface-redesign/B00/verification.txt)；全文件见 A012 | B00 | 文档/链接/差异检查；保留 Hub 非 Git 仓库的初次检查记录；不证明 App 运行通过 |
| A012 | 全部本轮文件与共享文档修改前快照 | [manifest.json](../../output/app-interface-redesign/B00/manifest.json) | B00 / 最终生成快照 | 逐文件路径/大小/hash；包括8工作包文档、全部原始日志/快照、项目/Hub同步文件。manifest 自身不递归哈希 |
| A013 | B01 三域批次卡与统一盘点格式 | [T](batches/B01-T.md) / [L](batches/B01-L.md) / [P](batches/B01-P.md) / [格式](inventory/README.md) | B01 / r1 | 三个批次DoD5/5；独立审读与登记闭环完成 |
| A014 | 全局路由、系统呈现和外部边界调查 | [SHELL报告](inventory/B01-SHELL.md) / [页级记录](../../output/app-interface-redesign/B01/SHELL/inventory.json) | B01 / 主控 | 8条系统/边界记录，51个注册分支，源码证据；运行未验 |
| A015 | B01 前置快照与全产物清单 | [源码指纹](../../output/app-interface-redesign/B01/source-baseline.json) / [manifest](../../output/app-interface-redesign/B01/manifest.json) | B01 / 收口快照 | 全部本轮文件逐项登记；保留B00活动文档/项目与Hub修改前快照 |
| A016 | 训练域正式盘点 | [报告](inventory/B01-T.md) / [JSON](../../output/app-interface-redesign/B01/T/inventory.json) | B01 / sol；审读补正r1 | 含状态/入口/版本/旧v58/保护区；38条，运行全部unrun；修订前实际快照见A015 |
| A017 | 动作库与教学正式盘点 | [报告](inventory/B01-L.md) / [JSON](../../output/app-interface-redesign/B01/L/inventory.json) | B01 / sol；审读补正r1 | 含状态/入口/版本/旧v58/保护区；26条，运行全部unrun；修订前实际快照见A015 |
| A018 | 记录/我的/设置正式盘点 | [报告](inventory/B01-P.md) / [JSON](../../output/app-interface-redesign/B01/P/inventory.json) | B01 / sol；审读补正r1 | 含状态/入口/版本/旧v58/保护区；45条，运行全部unrun；修订前实际快照见A015 |
| A019 | 主控独立源码与计数复核 | [root-review](../../output/app-interface-redesign/B01/root-review.md) | B01 / 主控 | 亲读关键调用、共享去重与两个审查补正；非运行验收 |
| A020 | astra 独立源码盘点审查 | [审查报告](../../output/app-interface-redesign/B01/independent-review.md) | B01 / gpt-6-astra | 两项重要补正及一项锚点改善均关闭；最终8份输入hash绑定结论，无剩余阻断 |
| A021 | B01 字段/来源/文档验证 | [最终结果](../../output/app-interface-redesign/B01/verification.txt) / [盘点检查](../../output/app-interface-redesign/B01/inventory-validation.json) / [文档检查](../../output/app-interface-redesign/B01/document-validation.json) | B01 / 主控脚本 | 117条、38族、689源码指纹，文档/链接/体积/差异检查；原始日志与执行中诊断均在A015 |

B00与B01写共享进度文件前的快照分别保存在对应批次证据目录，供核对既有 dirty 工作保留情况；它们是工作区证据，不能当成活动进度入口。manifest 的 hash 是对应批次收口时快照，工作文档后续更新要按新批次重新登记，不能要求持续维护文件永远保持旧 hash。

## B02 进行中产物

| ID | 成果/类型 | 来源与位置 | 批次/版本 | 状态与能证明什么 |
|---|---|---|---|---|
| A022 | 分域采集卡与输入快照 | [T](batches/B02-T.md) / [L](batches/B02-L.md) / [P](batches/B02-P.md)，[源码指纹](../../output/app-interface-redesign/B02/source-baseline.json) | B02 / r1 | 工作中；695个Swift/配置/JSON输入指纹，不能单凭hash证明运行 |
| A023 | 训练基线构建与设备证据 | [资源记录](../../output/app-interface-redesign/B02/T/resource.json) / [构建日志](../../output/app-interface-redesign/B02/T/build.log) | B02-T / r1 | 独立模拟器Debug构建成功；首轮原生证据已复核，整个B02仍进行中 |


- A024｜B02-L/P采集准备：[L清单](../../output/app-interface-redesign/B02/L/preparation.md)、[P清单](../../output/app-interface-redesign/B02/P/preparation.md)及各域JSON；71条原ID完整，全runtime unrun。[结构检查](../../output/app-interface-redesign/B02/preparation-validation.json)；P审读前原稿见[快照manifest](../../output/app-interface-redesign/B02/P/revisions/pre-review/manifest.json)。
- A025｜B02-T原生图片与逐图来源：[截图manifest](../../output/app-interface-redesign/B02/T/screenshot-manifest.json)；每图PNG、AX和provenance逐个登记，首轮37原图（35有效、2次未命中），完整报告和原图浏览见T目录；后续继续补。工具误选或未命中状态保留，不能算成目标页通过。

- A026｜B02首轮复核与总归档：[独立审查](../../output/app-interface-redesign/B02/independent-review.md)、[主控复核](../../output/app-interface-redesign/B02/root-review.md)、[视觉观察](../ui-reviews/UR-20261008-app-interface-B02-T.md)、[完整性检查](../../output/app-interface-redesign/B02/evidence-validation.json)、[文档检查](../../output/app-interface-redesign/B02/document-validation.json)、[全量manifest](../../output/app-interface-redesign/B02/manifest.json)。逐文件hash含中间修订/失败记录；DerivedData仅目录登记，实际安装包指纹单独验证。不能据检查PASS将B02标完成。

## B02 第二轮增量（r2）

- A027｜新轮次输入与串行交接：[源码差异](../../output/app-interface-redesign/B02/r2/source-drift.json)、[T→L交接](../../output/app-interface-redesign/B02/r2/handoff-T-to-L.json)、[主控源码与原图复核](../../output/app-interface-redesign/B02/r2/root-source-review.md)；修改前共享文档保存在r2/before。旧轮次原图、manifest与审查保持原版本。
- A028｜训练补采：[报告](../../output/app-interface-redesign/B02/r2/T/report.md)、[原图浏览](../../output/app-interface-redesign/B02/r2/T/gallery.html)、[逐图来源](../../output/app-interface-redesign/B02/r2/T/screenshot-manifest.json)、[覆盖表](../../output/app-interface-redesign/B02/r2/T/coverage.json)、[全产物](../../output/app-interface-redesign/B02/r2/T/artifact-manifest.json)。sol执行；15张编号原图14有效，累计29项partial/9未采；原图与元数据修订前快照保留。成功构建和真实键盘/模版/补记增量可用，B02-T仍未完成。

- A029｜动作库/阅读首轮：[报告](../../output/app-interface-redesign/B02/r2/L/report.md)、[图册](../../output/app-interface-redesign/B02/r2/L/gallery.html)、[覆盖表](../../output/app-interface-redesign/B02/r2/L/coverage.json)、[manifest](../../output/app-interface-redesign/B02/r2/L/manifest.json)。sol执行；35图33有效，26项中8部分/18未采。155份域内产物逐项校验；[修订日志](../../output/app-interface-redesign/B02/r2/L/revision-log.md)明确旧metadata完整副本缺失，现有快照为修订后，不声称全部历史版本可恢复。
- A030｜两域独立审查：[T审查](../../output/app-interface-redesign/B02/r2/review/T-review.md) / [111项输入指纹](../../output/app-interface-redesign/B02/r2/review/input-fingerprints-T.json)、[L审查](../../output/app-interface-redesign/B02/r2/review/L-review.md) / [164项输入指纹](../../output/app-interface-redesign/B02/r2/review/input-fingerprints-L.json)。astra亲看全部50张编号原图，有限基线可用；保留未采、源码时间和恢复边界。
- A031｜第二轮汇总、资源与检查点：[跨轮次浏览](../../output/app-interface-redesign/B02/index.html)、[资源实读](../../output/app-interface-redesign/B02/r2/root-resource-check.json)、[完整性检查](../../output/app-interface-redesign/B02/r2/evidence-validation.json)、[文档检查](../../output/app-interface-redesign/B02/r2/document-validation.json)、[全量manifest](../../output/app-interface-redesign/B02/r2/manifest.json)。主控单写中央文档并同步项目/Hub；r1的267份归档产物原样保留，新manifest记录本检查点和实际中间文件，缓存单列。B02保持进行中。

## B02 第三轮增量（r3）

- A032｜P新轮次与构建身份：[预核](../../output/app-interface-redesign/B02/r3/source-preflight.json)、[完整构建前输入](../../output/app-interface-redesign/B02/r3/P/source-before.json)、[实际包指纹](../../output/app-interface-redesign/B02/r3/P/build-fingerprint.json)、[主控复核](../../output/app-interface-redesign/B02/r3/root-review.md)。r2→r3三处变化另记；新构建5108输入四时点无漂移，实际主可执行体为单体代码，不能沿用旧debug.dylib模板。
- A033｜记录/我的/设置原生首轮：[报告](../../output/app-interface-redesign/B02/r3/P/report.md)、[图册](../../output/app-interface-redesign/B02/r3/P/gallery.html)、[逐图来源](../../output/app-interface-redesign/B02/r3/P/screenshot-manifest.json)、[覆盖](../../output/app-interface-redesign/B02/r3/P/coverage.json)、[523项产物](../../output/app-interface-redesign/B02/r3/P/file-manifest.json)。sol执行；65图中63像素有效（含1AX受限）、2目标失败，完整证据图62；45项为19partial/26unrun。三来源闭环、真实两种键盘、五外观子页已采；修订前metadata与失败原图保留。
- A034｜P独立审查与设计就绪边界：[终审](../../output/app-interface-redesign/B02/r3/review/P-review.md)、[输入指纹](../../output/app-interface-redesign/B02/r3/review/input-fingerprints-P.json)、[检查](../../output/app-interface-redesign/B02/r3/review/checks-P.json)、[进入B03前的缺口判断](../../output/app-interface-redesign/B02/r3/review/baseline-readiness-next.md)。astra亲看65张源PNG，修正覆盖语义和不存在的功能分支；有限基线与整个B02完成分开。
- A035｜r3检查点与资源：[统一浏览](../../output/app-interface-redesign/B02/index.html)、[资源实读](../../output/app-interface-redesign/B02/r3/root-resource-check.json)、[defaults实读](../../output/app-interface-redesign/B02/r3/root-defaults-check.json)、[证据检查](../../output/app-interface-redesign/B02/r3/evidence-validation.json)、[文档检查](../../output/app-interface-redesign/B02/r3/document-validation.json)、[全量manifest](../../output/app-interface-redesign/B02/r3/manifest.json)。主控单写中央文档及Hub；r1/r2归档产物保留，当前文档另记新检查点。
- A036｜[B02设计前缺口收口卡](batches/B02-CLOSEOUT.md)：主控根据astra就绪判断整理，r4已完成。限定真实入口证据整合、缺失长文/覆盖层与有限跨尺寸风险组合；117是台账分母，不是全设备全状态截图配额。没有将后续真实支付/授权等功能QA机械设成粗调前置。

## B02 第四轮收口（r4，已完成设计前DoD）

- A037｜r4输入与资源：[预核](../../output/app-interface-redesign/B02/r4/source-preflight.json)、[构建前输入](../../output/app-interface-redesign/B02/r4/capture/source-before.json)、[实际构建包](../../output/app-interface-redesign/B02/r4/capture/build-fingerprint.json)、[最终资源](../../output/app-interface-redesign/B02/r4/capture/resource.json)。三台专用模拟器已释放，主控独立复算安装与进程；旧中央文档与Hub改前快照保存在r4/before。构建时序与外部源码漂移单列，不将包身份写成当前全仓一致。
- A038｜117条证据最终整合：[报告](../../output/app-interface-redesign/B02/r4/coverage/report.md)、[覆盖](../../output/app-interface-redesign/B02/r4/coverage/coverage.json)、[入口地图](../../output/app-interface-redesign/B02/r4/coverage/route-map.md)、[源码新鲜度](../../output/app-interface-redesign/B02/r4/coverage/source-freshness.json)。sol单写并于13:14:44重封；64部分/53未采，59充分/39条件未知/16外部保护/3待页面证据；运行覆盖与设计基线就绪分列，修订快照保留。
- A039｜r4原生补采与终审：[46张原图](../../output/app-interface-redesign/B02/r4/capture/gallery.html)、[逐图来源](../../output/app-interface-redesign/B02/r4/capture/screenshot-manifest.json)、[采集报告](../../output/app-interface-redesign/B02/r4/capture/report.md)、[独立终审](../../output/app-interface-redesign/B02/r4/review/review.md)、[710项审查指纹](../../output/app-interface-redesign/B02/r4/review/input-fingerprints.json)、[终审检查](../../output/app-interface-redesign/B02/r4/review/checks.json)。46正式图及4 raw逐图已审，37张计实际态覆盖、9失败意图保留；终审允许进入B03-A，完整修订前文件已冻结。

- A040｜[B03-A准备卡](batches/B03-A.md)与[117条可筛选证据地图](../../output/app-interface-redesign/B02/r4/map.html)：主控将下一阶段输入、DoD和现状入口具体化。地图由coverage JSON生成，已绑定最终117条整合；B03前置就绪但Figma尚未开始，卡片不是设计稿。

- A041｜FL-135过程纠正：[主控逐图记录](../../output/app-interface-redesign/B02/r4/root-visual-notes.md)、[实施日志](../IMPLEMENTATION-LOG.md)、[UI审查规则](../../.cursor/rules/57-ui-reviewer.mdc)。PAD-L001–L005误命中及过早进度声明已撤回，成功横屏链另拍；修改前规则/日志/规范保存在r4/before/process-correction。r4终审逐图、metadata及覆盖一致后关闭，不当作App新增缺陷。

- A042｜r4最终检查点：[主控结论](../../output/app-interface-redesign/B02/r4/root-review.md)、[证据检查](../../output/app-interface-redesign/B02/r4/evidence-validation.json)、[文档检查](../../output/app-interface-redesign/B02/r4/document-validation.json)、[安装包复算](../../output/app-interface-redesign/B02/r4/root-installation-check.json)、[资源复核](../../output/app-interface-redesign/B02/r4/root-resource-check.json)、[全量manifest](../../output/app-interface-redesign/B02/r4/manifest.json)。r1/r2/r3不可变产物267/301/566项保持原样。浏览器file://检查被拒绝，静态HTML/链接检查与原生PNG逐图审查分列；主控首次指纹脚本把path_base说明文字当目录的失败原稿保留，修正解析后复算通过。

## B03-A 全局粗调（r1，进行中）

- A043｜三域设计输入：[训练](../../output/app-interface-redesign/B03-A/r1/briefs/T/brief.md)、[记录/我的/设置](../../output/app-interface-redesign/B03-A/r1/briefs/P/brief.md)、[动作库/练习与导航壳](../../output/app-interface-redesign/B03-A/r1/briefs/L/brief.md)。sol各自核T/P源和原图，主控核L；每份inputs.json记录真实来源观察。仅候选输入，非图稿批准。
- A044｜B03-A独立Figma工作区：[新文件](https://www.figma.com/design/zrpmapqJPyllc6uEmweb3B)、[资源锁](../../output/app-interface-redesign/B03-A/r1/resource.json)。astra单写新文件，旧每日双文件保护；六板轮廓稿已导入，原生Text/组件与云端未完成。六张实际PNG和最终.fig已保存；[包外UI原件与副本校验](../../output/app-interface-redesign/B03-A/r1/external-export-copies.json)另记，未独立回导。实际node、导出/保存与失败见[交付记录](../../output/app-interface-redesign/B03-A/r1/design/README.md)。改前中央文档位于r1/before，完整中间成果由本批manifest登记。

- A045｜B03-A r1六板候选与完整设计源：[评审入口](../../output/app-interface-redesign/B03-A/r1/index.html)、[本地预览来源表](../../output/app-interface-redesign/B03-A/r1/design/local-previews/report.json)、[设计说明](../../output/app-interface-redesign/B03-A/r1/design/README.md)。含当前层规格/插件、真实图源、PNG/SVG、转轮廓导入稿及失败/审前修订；由astra制作，主控建议训练A＋我的B，尚未由用户选择。本地预览与Figma导出分开记，未生成的原生文字不算成果。
- A046｜B03-A两轮独审与主控检查点：[首轮](../../output/app-interface-redesign/B03-A/r1/review/local-round1-review.md)、[第二轮](../../output/app-interface-redesign/B03-A/r1/review/local-round2-review.md)、[实际Figma交付独审](../../output/app-interface-redesign/B03-A/r1/review/figma-delivery-review.md)、[主控复核](../../output/app-interface-redesign/B03-A/r1/root-review.md)、[检查](../../output/app-interface-redesign/B03-A/r1/checks.json)、[全量manifest](../../output/app-interface-redesign/B03-A/r1/manifest.json)。原稿/逐图观察输入与修改前中央文档均保留；本地粗稿达到供选择门槛，Figma与用户DoD未全部闭合。

## E00 统一现状完整图层图册（当前；未迁入）

- A047｜最新优先与保存点：[PLAN v1.2](PLAN.md)、[D011/D012](DECISIONS.md)、[E00](batches/E00.md)、[E01具体样板](batches/E01.md)。改前中央文档和Hub位于 `output/app-interface-redesign/E00/r1/before/`；B03旧候选原样保留，新需求先完成现状整理。
- A048｜117原ID矩阵与分层准备：[汇总](../../output/app-interface-redesign/E00/r1/summary.json)、[T](../../output/app-interface-redesign/E00/r1/T/matrix.json)、[LP](../../output/app-interface-redesign/E00/r1/LP/matrix.json)、[SHELL](../../output/app-interface-redesign/E00/r1/SHELL/matrix.json)。sol页面/主控边界；包含原图引用、源码hash、完整内容范围、条件和候选批次，审前修订存各域目录。矩阵准备不是Figma图层包完成；实际迁入0。
- A049｜[统一现状Figma](https://www.figma.com/design/Ea42AbmIyS7ct4Oeg3kcAH)、[交付](../../output/app-interface-redesign/E00/r1/figma/README.md)、[分层协议](../../output/app-interface-redesign/E00/r1/figma/layer-contract.md)、[实际本地.fig](../../output/app-interface-redesign/E00/r1/figma/E00-capability-blocked.fig)。astra单写，只含能力失败小样；真实PNG/AX/错误/独立插件与旧协议备份见其manifest。原生Text和批量导入失败，Frame最终值可核；编辑过程为执行者报告，云端/回导未验。
- A050｜[独立复核](../../output/app-interface-redesign/E00/r1/review/review.md)、[主控结论](../../output/app-interface-redesign/E00/r1/root-review.md)、[检查](../../output/app-interface-redesign/E00/r1/checks.json)、[资源](../../output/app-interface-redesign/E00/r1/resource.json)、[完整manifest](../../output/app-interface-redesign/E00/r1/manifest.json)。E00 DoD-1/2/5完成、3未过、4部分完成；独立准备审查与整批未完成分开。没有App修改、新构建/模拟器或发布成果。

## E00-r2 环境修复与分层试点

- A051｜[修复记录](../../output/app-interface-redesign/E00/r2/network-report.md)、[持久配置与系统读回](../../output/app-interface-redesign/E00/r2/network-final-settings.json)、[批次卡](batches/E00-r2.md)。主控仅新增static.figma.com系统代理排除，原8项保留；无效试验规则已撤回。原失败探测、改前列表、官方设置源码与回滚范围均归档；不声称应用重启测试。
- A052｜[原生中文和设置外观组件](../../output/app-interface-redesign/E00/r2/figma/README.md)、[节点/交付](../../output/app-interface-redesign/E00/r2/figma/delivery.json)、[本地.fig](../../output/app-interface-redesign/E00/r2/figma/evidence/E00-r2-native.fig)。astra：page3:2，能力frame4:2、外观frame4:8；7非空Text/4 Rectangle/6 Frame。三阶段树与PNG真实修改后精确复原；外观为源绑定组件，非完整页面或几何精确复刻，完整迁入0。
- A053｜[Settings完整分层素材](../../output/app-interface-redesign/E01/preparation/README.md)、[140层数据](../../output/app-interface-redesign/E01/preparation/layer-package.json)、[来源](../../output/app-interface-redesign/E01/preparation/source.json)、[检查](../../output/app-interface-redesign/E01/preparation/validation.json)。sol：9区/61文字层、17源锚点；B02历史Light图引用与当前运行分列，实测位置全null；不是新采图或已迁入。
- A054｜[r2独立终审](../../output/app-interface-redesign/E00/r2/review/final/review.md)、[主控复核](../../output/app-interface-redesign/E00/r2/root-review.md)、[最终检查](../../output/app-interface-redesign/E00/r2/checks.json)、[完整manifest](../../output/app-interface-redesign/E00/r2/manifest.json)。初审/终审及修改前交付保留；环境功能阻塞解除，配置已保存且当前生效，真实重启/辅助诊断结果/独立云端和回导未验证。完整页迁入仍0。

## 当前未产生的成果

本工作包已有B03-A六板候选与独立Figma轮廓导入；精调图、获准实现版本、改后截图、App改造与发布成果均**未产生**。B02改前基线已收口；构建/截图与检查的实际状态以各批次证据为准。每日清台已有设计和 App 成果继续从其 [CURRENT](../daily-adaptive/CURRENT.md) 引用，不纳入本工作包的“新设计完成数”。

## 后续登记字段

新行至少含：A-ID、标题/类型、P-ID/批次/需求或 DoD、制作者/模型、生成时间、路径或 Figma file/node、修订/源码基线、当前状态、获准依据、验证范围、被替代关系、manifest/备份位置。

Figma 另记：本地编辑源已保存、云端独立读回、备份导出、独立回导，各自使用“已验/未验/失败”。原生证据另记：Runtime/设备、窗口/安全区、外观/字号/数据状态、build 与配置 hash。
