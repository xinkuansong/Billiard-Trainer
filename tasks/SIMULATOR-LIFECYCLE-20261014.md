# 模拟器自动回收与复用 · 2026-10-14

状态：自动管理已实现；后续授权复查20台，删除13台、保留7台。未修改App生产代码；未启动或关闭存量模拟器。

## 20台历史设备复查与清理（2026-10-14，后续授权）

已逐台核实：**删除13台，保留7台**。本轮开始时机器已有60台（首轮盘点后其他会话新增2台）；删除后47台。保留范围包含当时全部非目标设备，逐UDID回查缺失0。

删除前后可用空间：4.06 → 10.64 GiB，现场净增6.58 GiB；其他会话同时工作，不能把净变化当作严格隔离的释放测量。被删设备的simctl数据目录统计合计30.96 GiB，APFS共享块使它不等于实际释放量。

13台均为Shutdown、无租约/外部测试占用、非当前评审/默认配置、最近启动时间未晚于首轮清单。任务原图、报告、源身份与产物均在项目外部目录保留。删除前额外备份应用Documents、Application Support、Preferences及非Apple共享组，tar逐文件SHA256校验；总压缩约0.21 MiB。未备份可重建的系统/应用二进制及缓存。

| 设备 | 本轮处理 | 依据 |
|---|---|---|
| AppInterface-B02-20261008 | 已删除 | E01 r3截图采集已明确释放；源快照、原图、回执均在项目output，后续评审使用独立十设备。 |
| Daily-Standard-Audit-20261008 | 已删除 | 每日标准审计及后续C51–C56定向验证已交付，当前模板验证转用Daily-Fix设备；旧测试实例不承担当前人工评审。 |
| Motion-Diagnosis-20261010 | 已删除 | 独立球网格A/B实验已导出两份完整视频、记录并关闭专用模拟器；主观对比通过外部视频进行，不依赖旧实例。 |
| QiuJi-AngleTrial-20260926 | 保留 | 名字虽为9月，10-13仍被使用；AD01/角度相关体验未明确结束，继续保留。 |
| Tutorial-Figures-20261012 | 已删除 | 配图已完整渲染、回填并安装真机；10-13按用户要求只留最终产物，模拟器门控已移除，旧烘焙实例无后续用途。 |
| V026-Pocket-Keyframes-20261012 | 保留 | V026仍是关键帧待用户审阅，视频任务未结束。 |
| E02-phone-large-20261009 | 已删除 | E02大屏截图采集完成且明确released，截图和元数据均外置；不是现行十设备评审机。 |
| E04-Profile-large-20261009 | 保留 | 仍被scripts/native-atlas/roots.json和plan-entry.json引用；属于评审/采图设备，不动。 |
| QiuJi-FourLayer-B1-20261011 | 后续47台复核已删除（见末节） | 四层渲染实施方案的B1/B2后续未证实收口，未找到对应明确释放记录。 |
| QiuJi-Render-Cost-20261011 | 已删除 | 渲染成本诊断r8明确本轮收尾不追加测试，生产不采用候选；原模拟器仅早期成本测试，后续实测已在真机外置存档。 |
| Adaptivity se26 20261005 | 已删除 | 旧适配调查/基线及P07/P09b定向矩阵已完成，结果与原图外置；当前10-13/14人工复验使用新r34设备，旧SE不是评审设备。 |
| Daily-C51-SE-20261008 | 已删除 | C51球库/菜单及C54–C56已最终验证，后续Daily-Fix-SE提供新版本；保留外部原图无需旧临时测试实例。 |
| Daily-Fix-SE-20261009 | 保留 | 10-13仍用于试打控件/标题验证，用户观感待确认，保留近期现场。 |
| E02-phone-small-20261009 | 已删除 | E02小屏截图采集完成且明确released，截图和元数据均外置；现行01为另一个UDID。 |
| Adaptivity ipad11_26 20261005 | 已删除 | 旧每日适配基线已由B8/C56最终矩阵收口并保留外部截图；当前每日/跨页工作改用Daily-Fix-Pad等新实例。 |
| Daily-C51-Pad-20261008 | 已删除 | C51到C56原生矩阵已完成；旧Pad测试实例已被Daily-Fix-Pad和固定评审Pad替代，全部证据外置。 |
| QiuJi-FourLayer-iPad-20261011 | 后续47台复核已删除（见末节） | 四层渲染跨设备任务未证实收口，保留。 |
| Daily-Fix-Air-20261009 | 已删除 | 10-09独立FreePlay修复已交付，后续统一矩阵成功；当前剩余修复/人工验收已转为10-13/14新设备。 |
| TableAdaptation-Pad-20261009 | 已删除 | 旧P12/P15适配矩阵已工程收口，源身份和定向原图在output；当前新版验收使用另设设备。 |
| QiuJi-FourLayer-SE17-20261011 | 后续47台复核已删除（见末节） | 四层渲染最低Runtime回归未证实收口，保留。 |

完整证据：[`history-audit/plan.json`](../output/simulator-lifecycle-20261014/history-audit/plan.json)、[`execution.json`](../output/simulator-lifecycle-20261014/history-audit/execution.json)、[`应用数据备份`](../output/simulator-lifecycle-20261014/history-audit/app-data/)。每台审计文件保存任务证据路径与哈希、最近启动时间、备份文件哈希；未改写旧任务验收状态。

删除前同时修正FL-155：macOS将非末列comm截为`/Applications/Xc`，原占用解析会漏掉xcodebuild。现分别读取完整可执行文件与参数并按PID关联，真实识别其他会话的测试目标；参数不明保守拒绝。清理增加精确UDID范围，避免顺便处理其他任务的可回收设备。最新生命周期22项＋预览36项回归通过。

---

## 交付与行为

- 主机共享登记表、文件锁和独占租约：`~/Library/Application Support/QiuJi/simulator-lifecycle/`，跨 worktree 使用同一状态。
- 固定池按 Runtime＋设备类型复用，最多8台、同组合最多2台；占用时使用另一个空闲槽位或明确报错。
- 临时设备成功且本轮结果已导出才自动回收；失败保留7天。回收发生在受管命令前后或显式清理时，未安装后台任务。
- 当前评审设备、默认开发设备、正在使用、未知归属、显式保护、未释放租约、再次启动、缺少证据均不删；删除前再次读取设备和进程。
- `make test`（模拟器测试）接入租约；新增 `make sim-test` 使用受管池。日常启动、走位导出/缩略图烘焙、矩阵、原生图册、评审预览入口共用锁。普通借用保持原入口的关机策略。测试/导出关闭Xcode并行测试克隆，避免额外创建未登记设备。
- 创建新模拟器的统一入口和限制已写入 AGENTS、构建及测试规则。[使用说明](../scripts/simulator-lifecycle/README.md)。

## 首轮现有设备梳理（删除前历史）

首轮存量58台全部保留并登记原因，当时未认定旧设备可删；后续复查结果以上方章节为准。7台运行是盘点时的状态，不保证其他会话随后没有自行切换。

| 分类 | 台数 |
|---|---:|
| 历史任务待核实 | 20 |
| 正在运行 | 7 |
| 默认开发设备 | 1 |
| 近期任务或待验收 | 7 |
| 其他项目 | 11 |
| 人工评审固定设备 | 10 |
| 环境问题现场 | 2 |

13 mini诊断实例 `D00F83A0-3D2A-4063-8793-D02B5973D85A` 的旧记录称未安装球迹，但当前 `data/Containers/Bundle/Application` 内存在球迹.app。旧记录不能证明当前设备可删，故与原04 mini一并保留；APP-I028问题未关闭。

首轮20台历史待核实设备未按旧日期或Shutdown状态删除。本轮已按上方记录清理13台；剩余设备今后核实无需保留时，可用 `unprotect → retire（附证据）→ cleanup` 逐项回收。其他项目11台不纳入本项目自动处置。

## 首轮工具验证（历史，后续22项见上）

- 生命周期20项测试通过：真实子进程成败、并发租约争用、复用与数量上限、过期回收、保护/配置/运行/外部进程/新启动/身份变化/证据缺失/陈旧证据/登记损坏拒删。
- 预览控制器原有36项回归通过（子进程与租约边界均使用测试替身，不操作真实评审设备）。
- 本机真实simctl冒烟：新建一台池设备，连续借用返回相同UDID；并发第二次借用被拒；嵌套目标包装成功；新建临时设备导出证据后自动删除。池验证设备测试完显式退役并删除。两台验证设备均未启动或安装App。
- 清理后存量58个UDID全部仍存在；验证未增加最终设备数量。没有宣称释放存量159.84 GiB或实际释放了多少磁盘空间。
- Python编译检查、Makefile命令展开与文档体积检查另见证据。未运行App全量测试；本次验证对象为工具生命周期。

证据目录：[`output/simulator-lifecycle-20261014/`](../output/simulator-lifecycle-20261014/)，包含前后清单、分类、测试日志、真实复用/并发/删除回执。

## 首轮58台清单及最新处理

| 名称 | Runtime | 首轮状态 | 分类/最新处理 | UDID |
|---|---|---|---|---|
| AppInterface-B02-20261008 | iOS-26-3 | Shutdown | 本轮已删除 | 29D19F26-2EFF-4073-A232-3BD742D48EDF |
| Daily-Fix-Phone-20261009 | iOS-26-3 | Booted | 正在运行 | 9B6AEE75-2905-485A-92D2-86593F74FD66 |
| Daily-Standard-Audit-20261008 | iOS-26-3 | Shutdown | 本轮已删除 | 1D02D993-A84E-4376-9AE8-3465A6DD9967 |
| iPhone 17 Pro | iOS-26-3 | Shutdown | 默认开发设备 | AE86244C-EE61-4585-882F-E39B892214DB |
| Motion-Diagnosis-20261010 | iOS-26-3 | Shutdown | 本轮已删除 | 0DF20DC2-2B66-419E-B693-D7E802C1139F |
| Practice-Badges-Phone-20261013 | iOS-26-3 | Shutdown | 近期任务或待验收 | 152427BB-09D3-463D-AB4E-2E9A10CC71B1 |
| QiuJi-AngleTrial-20260926 | iOS-26-3 | Shutdown | 本轮核实后保留（依据见上） | 4011AD82-4380-405C-8CD9-D40E560F6B68 |
| QiuJi-Closeup-Regression-20261014 | iOS-26-3 | Booted | 正在运行 | 3CD07A23-44BA-4641-90AA-65408ADC6C11 |
| QiuJi-Remaining-Phone-20261013 | iOS-26-3 | Booted | 正在运行 | 411CCF0D-8D00-40EC-97DA-E5BE2D0B9652 |
| QiuJi-Sequence-Camera-20261014 | iOS-26-3 | Booted | 后续47台复核已删除（见末节） | 3AB10733-60A4-48E0-9F1E-CDFEA7ACAE18 |
| QiuJi-Snake2-Audit-20261014 | iOS-26-3 | Shutdown | 近期任务或待验收 | 99494237-BA75-48C5-99DD-A6418FADE041 |
| Snooker-Orbit-20261010 | iOS-26-3 | Shutdown | 其他项目 | 0AB0C8C3-EB7E-4688-9CC7-139C4004CCD6 |
| Snooker-Pocket-QA-20261010 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | 64F7C2EB-07E3-4DE8-919E-220A1884158D |
| Snooker-R2-Cloth | iOS-26-3 | Shutdown | 其他项目 | 018353F8-D36D-4120-9F16-2563597FB2E0 |
| Snooker-R3-Room-20261010 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | C1B8E24C-13DA-49A4-828B-4DF8F5EBAF10 |
| Snooker-R4-Surfaces-20261010 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | 1691EE40-534B-4692-8B11-396312FD47FF |
| Snooker-Red45-20261010 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | E391BC76-8171-49AB-B1BB-23969E0913AC |
| SnookerStudio-20261010 | iOS-26-3 | Shutdown | 其他项目 | 5F48A5C2-CC3F-43C1-91EF-906B8D577D74 |
| Tutorial-Figures-20261012 | iOS-26-3 | Shutdown | 本轮已删除 | 6D4819FD-5E62-43AF-AA55-230B06ADAE4F |
| V026-Pocket-Keyframes-20261012 | iOS-26-3 | Shutdown | 本轮核实后保留（依据见上） | C2445997-A4FB-4FD1-96C6-52A0CD4D8C38 |
| E02-phone-large-20261009 | iOS-26-3 | Shutdown | 本轮已删除 | 85812779-DC49-408E-B7C4-D3C7EBD6168C |
| E04-Profile-large-20261009 | iOS-26-3 | Shutdown | 本轮核实后保留（依据见上） | 2787E369-465A-46B1-A09E-5FA6E13AC9C5 |
| E03-Profile-Standard-20261009 | iOS-26-3 | Shutdown | 人工评审固定设备 | F2BE90C4-370D-46AB-B3E8-8F0060424B2D |
| QiuJi-EntryMemory-20261013 | iOS-26-3 | Booted | 正在运行 | A0E93E68-DEED-4019-8242-991BF02F1ACC |
| QiuJi-FourLayer-B1-20261011 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | 7BDCE02F-6DCA-487A-B0E3-A6A611961E5C |
| QiuJi-Render-Cost-20261011 | iOS-26-3 | Shutdown | 本轮已删除 | 1706F111-0858-4718-8E9B-17BAC3197055 |
| QiuJi-TableRuntime-UnitTests | iOS-26-3 | Shutdown | 近期任务或待验收 | A506A2A4-FA14-4D98-8E93-6C7267DE8A9D |
| Snooker-Color-20261010 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | 64399CAC-3D52-41B0-A0F8-017B2458ED8C |
| QiuJi-Preview-03-16ProMax | iOS-26-3 | Shutdown | 人工评审固定设备 | 16D968CB-FA14-4E00-B79F-0D675D80179E |
| Adaptivity se26 20261005 | iOS-26-3 | Shutdown | 本轮已删除 | 3A8C6D76-EA9E-4F7D-B1FD-D3380452AE96 |
| Angle-Assists-SE-20261013 | iOS-26-3 | Shutdown | 近期任务或待验收 | D43C7C3F-5539-4E15-91C0-018DD6939372 |
| Daily-C51-SE-20261008 | iOS-26-3 | Shutdown | 本轮已删除 | D9D8A663-1EE5-4045-92DB-752954EC18E6 |
| Daily-Fix-SE-20261009 | iOS-26-3 | Shutdown | 本轮核实后保留（依据见上） | D0E09B1F-D13B-4D23-BCBD-6492575CB164 |
| E02-phone-small-20261009 | iOS-26-3 | Shutdown | 本轮已删除 | 6A5682DB-E13F-4546-9216-2807EE26FB32 |
| E04-Profile-small-20261009 | iOS-26-3 | Shutdown | 人工评审固定设备 | DF09A8D3-2574-43D7-85D8-369CFDB2C36D |
| Practice-Badges-SE-20261013 | iOS-26-3 | Shutdown | 近期任务或待验收 | E13A6554-7DF6-42EB-A221-0B10F40071DF |
| SnookerStudio-SE-20261010 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | 7DA12B1C-9BBB-4F12-88A1-54570C853A3D |
| QiuJi-Preview-04-iPhone13 | iOS-26-3 | Shutdown | 人工评审固定设备 | 0D3AE337-488E-49D0-8AFF-E711249046EC |
| QiuJi-Diag-13mini-20261012 | iOS-26-3 | Shutdown | 环境问题现场 | D00F83A0-3D2A-4063-8793-D02B5973D85A |
| QiuJi-Preview-04-13mini | iOS-26-3 | Shutdown | 环境问题现场 | AB728DDE-AB44-4C76-AAF2-9DB4E1CA45D6 |
| Adaptivity ipad11_26 20261005 | iOS-26-3 | Shutdown | 本轮已删除 | 75B5C757-65BB-40A6-AEB0-4B01B2BFD954 |
| AppInterface-E02-Pad-20261009 | iOS-26-3 | Shutdown | 人工评审固定设备 | FB9B9FE0-F820-4E04-A4AD-DCF8E916C504 |
| Daily-C51-Pad-20261008 | iOS-26-3 | Shutdown | 本轮已删除 | 71A4E006-673B-466B-B424-6AFB9E2A191B |
| Daily-Fix-Pad-20261009 | iOS-26-3 | Booted | 正在运行 | 2F4C5EE7-701F-4BD3-81F8-8EC88320B10F |
| E04-Profile-pad-20261009 | iOS-26-3 | Shutdown | 人工评审固定设备 | 47AE5F33-3D60-4102-BBC7-E29D05114E6E |
| Snooker-Render-iPad | iOS-26-3 | Shutdown | 其他项目 | EF53B3CD-0064-4324-908C-A3BDAD7EB0F1 |
| QiuJi-Preview-09-Pad13-P | iOS-26-3 | Shutdown | 人工评审固定设备 | 4F00E012-1FA4-4F08-97E0-1B41160A63CC |
| QiuJi-Preview-10-Pad13-L | iOS-26-3 | Shutdown | 人工评审固定设备 | 2351AE54-8DC8-49A7-812A-BBA56596DAE1 |
| QiuJi-FourLayer-iPad-20261011 | iOS-26-3 | Shutdown | 后续47台复核已删除（见末节） | 0F01E0F6-6592-4E87-9B67-12EFF0D0715C |
| QiuJi-Info-Pad-20261014 | iOS-26-3 | Booted | 正在运行 | 70E0A435-A77C-4567-9EA6-621D8F35B275 |
| Daily-Fix-Air-20261009 | iOS-26-3 | Shutdown | 本轮已删除 | 1B0FF68A-97D8-4628-9942-4887C909B226 |
| TableAdaptation-Pad-20261009 | iOS-26-3 | Shutdown | 本轮已删除 | C1303C8F-7360-4679-B5BF-EA32350437D1 |
| QiuJi-Remaining-iPad-20261013 | iOS-26-3 | Shutdown | 近期任务或待验收 | E4B8A1EB-1547-4880-A540-A2B71D9631AB |
| QiuJi-Preview-07-PadMini-P | iOS-26-3 | Shutdown | 人工评审固定设备 | F80E0C5B-2B47-44DD-A460-5CE19CD5259A |
| QiuJi-Preview-08-PadMini-L | iOS-26-3 | Shutdown | 人工评审固定设备 | AF60E8C0-A1C9-4D5B-A27D-AEA07EF1602D |
| QiuJi-FourLayer-SE17-20261011 | iOS-17-0 | Shutdown | 后续47台复核已删除（见末节） | D16DE1BA-720D-4CAE-9D0E-40BB3B9C1048 |
| QiuJi-Remaining-SE-20261013 | iOS-17-0 | Shutdown | 近期任务或待验收 | 16365EE2-0C42-4EE1-B707-09AC55A0ABA7 |
| Snooker-Render-SE17 | iOS-17-0 | Shutdown | 其他项目 | B82659BF-746E-4B3B-B89F-68AE8072212B |

## 可复用技能

已按用户要求创建个人技能 [simulator-cleanup](/Users/song/.codex/skills/simulator-cleanup/SKILL.md)，支持“清理模拟器”“梳理剩余模拟器”或显式 `$simulator-cleanup`。覆盖任务归属核实、保护在用/评审现场、持久数据备份、精确UDID回收及收尾集合验证；运行仍使用本仓库管理器，共享登记不另建副本。技能创建不触发额外清理或后台任务。

## 限制

未接入入口的旧会话不能被共享锁强制管住。回收前的设备/进程复查提供额外保护，但与任意外部simctl不形成原子互斥；本轮所有存量已保护，后续创建与复用须遵守新入口。强杀遗留租约保守保留，由recover核实进程退出后恢复为保护态。

## 剩余47台复核 · 2026-10-14

按用户授权继续核对全部47台，读取对应会话、主项目/斯诺克项目和四层实验独立工作树的最新交付记录。**本轮删除10台、保留37台，47→37。** 每个保留UDID仍存在；没有关停在用设备，固定十设备评审配置与已有对局现场未动。

补证修正：上一轮三台FourLayer因只读到主树方案而保留；本轮找到独立工作树的实际完成报告及真机试用交付，确认临时模拟器回归已结束。Snooker-Pocket-QA最后还用于模型性能测试，已核对该后续6轮交付。不能仅按设备名字推断任务。序列相机r3已交付真机且用户明确自行真机测试；其专用模拟器回归已完成。

删除前复查关机、最后启动时间、外部xcodebuild/simctl占用、租约、保护配置及证据SHA。10台的应用Documents、Application Support、Preferences和非系统共享容器已外置备份，逐文件SHA校验；不含可重建App二进制、OS、缓存和tmp。通过生命周期管理器按精确UDID退役删除，无批量通配删除。未把工程验证解释成用户视觉/性能验收。

本轮设备dataPathSize合计18.73 GiB，不等于可释放物理空间。删除窗口磁盘可用空间观察净增约2.07 GiB；同期其他任务也在构建/清理，不能把此净值全部归因本轮。

证据：[逐台决策](../output/simulator-lifecycle-20261014/remaining-audit/plan.json)、[会话摘录](../output/simulator-lifecycle-20261014/remaining-audit/thread-evidence.json)、[执行回执](../output/simulator-lifecycle-20261014/remaining-audit/execution.json)、[备份目录](../output/simulator-lifecycle-20261014/remaining-audit/app-data/)、[最终核验](../output/simulator-lifecycle-20261014/remaining-audit/final-verification.json)。保留理由已写入共享登记；两台活跃任务创建的受管池继续按池逻辑复用，未改为永久保护。

| 设备 | 本轮结果 | 理由 |
|---|---|---|
| Daily-Fix-Phone-20261009 | 保留 | 本轮盘点时仍在运行；保留现场，未关机或清理。 |
| iPhone 17 Pro | 保留 | Makefile默认开发设备，保留。 |
| Practice-Badges-Phone-20261013 | 保留 | 卡片角标工程完成，但实际观感尚待确认，保留对应大小屏评审现场。 |
| QiuJi-AngleTrial-20260926 | 保留 | 10-13仍用于角度辅助验证/试用，最近用户反馈管道观感未处理，不按名称日期清理。 |
| QiuJi-Closeup-Regression-20261014 | 保留 | 本轮盘点时仍在运行；保留现场，未关机或清理。 |
| QiuJi-Managed-Pool-c832f804 | 保留 | 当前蛇彩修复任务创建的受管复用池；留作复用，不按历史临时设备清理。 |
| QiuJi-Managed-Pool-e1e6b772 | 保留 | 当前蛇彩修复任务创建的受管复用池；留作复用，不按历史临时设备清理。 |
| QiuJi-Remaining-Phone-20261013 | 保留 | 本轮盘点时仍在运行；保留现场，未关机或清理。 |
| QiuJi-Sequence-Camera-20261014 | 已删除 | r3的13项核心及2项UI回归完成并交付真机，用户明确自行真机体验且不录制；专用模拟器测试已结束，截图日志外置。 |
| QiuJi-Snake2-Audit-20261014 | 保留 | 蛇彩序列归因与修复任务当前仍活跃，保留专用宿主。 |
| Snooker-Orbit-20261010 | 保留 | 用户否决旧机位，六组关键帧待选；环绕视频任务未结束。 |
| Snooker-Pocket-QA-20261010 | 已删除 | 袋口QA完成后又用于模型性能6轮对照，最终报告已交付、随后转真机测试；数据和视频均外置，独立测试宿主可退役。 |
| Snooker-R2-Cloth | 保留 | 名字虽为R2，实际是R8最终Release试玩机，保留最终版本。 |
| Snooker-R3-Room-20261010 | 已删除 | 独立房间测试完成并关闭；R3临时烘焙由R5及R8最终整合替代，保留外部母版、截图和报告。 |
| Snooker-R4-Surfaces-20261010 | 已删除 | 独立材质3项测试完成且明确关闭；最终R8已整合，专用分域实例不再承担试玩。 |
| Snooker-Red45-20261010 | 已删除 | V024/V025成片、封面与校验已外置，V025用户认可并归集待发布；此渲染宿主无待录任务。 |
| SnookerStudio-20261010 | 保留 | 主模拟器已打开供用户试玩并保留原对局，不能作为普通测试机删除。 |
| V026-Pocket-Keyframes-20261012 | 保留 | V026关键帧待用户审阅，正式视频尚未完成。 |
| E04-Profile-large-20261009 | 保留 | native-atlas的roots/plan-entry仍引用，评审采图机保留。 |
| E03-Profile-Standard-20261009 | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| QiuJi-EntryMemory-20261013 | 保留 | 本轮盘点时仍在运行；保留现场，未关机或清理。 |
| QiuJi-FourLayer-B1-20261011 | 已删除 | 独立工作树补证：实验本轮模拟器验证已完成，后续四层/极简副本由用户在真机试用；源码、原图和日志外置，不再需要临时测试实例。性能目标未通过不等于此测试设备仍占用。 |
| QiuJi-TableRuntime-UnitTests | 保留 | 归属球桌缓存/生命周期优化，所属任务仍在执行新批次；关机不等于任务结束。 |
| Snooker-Color-20261010 | 已删除 | 用户已选择B球色并应用，两项目定向验证完成；最后命令已关闭测试机，原图与验证清单均外置。 |
| QiuJi-Preview-03-16ProMax | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| Angle-Assists-SE-20261013 | 保留 | 10-13仍用于角度辅助验证/试用，最近用户反馈管道观感未处理，不按名称日期清理。 |
| Daily-Fix-SE-20261009 | 保留 | 10-13试打控件/标题复验现场，尚未确认不需要保留。 |
| E04-Profile-small-20261009 | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| Practice-Badges-SE-20261013 | 保留 | 卡片角标工程完成，但实际观感尚待确认，保留对应大小屏评审现场。 |
| SnookerStudio-SE-20261010 | 已删除 | 早期SE渲染/交互测试已完成；新版相机及R2界面改由保留的Snooker-Render-SE17验证，旧SE版本已被替代。 |
| QiuJi-Preview-04-iPhone13 | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| QiuJi-Diag-13mini-20261012 | 保留 | APP-I028环境异常及对照现场尚未关闭，保留。 |
| QiuJi-Preview-04-13mini | 保留 | APP-I028环境异常及对照现场尚未关闭，保留。 |
| AppInterface-E02-Pad-20261009 | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| Daily-Fix-Pad-20261009 | 保留 | 本轮盘点时仍在运行；保留现场，未关机或清理。 |
| E04-Profile-pad-20261009 | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| Snooker-Render-iPad | 保留 | 新版R2界面与相机最终跨尺寸评审设备，保留。 |
| QiuJi-Preview-09-Pad13-P | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| QiuJi-Preview-10-Pad13-L | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| QiuJi-FourLayer-iPad-20261011 | 已删除 | 独立工作树补证：实验本轮模拟器验证已完成，后续四层/极简副本由用户在真机试用；源码、原图和日志外置，不再需要临时测试实例。性能目标未通过不等于此测试设备仍占用。 |
| QiuJi-Info-Pad-20261014 | 保留 | 本轮盘点时仍在运行；保留现场，未关机或清理。 |
| QiuJi-Remaining-iPad-20261013 | 保留 | 剩余页面修复人工复验尚在继续，保留跨尺寸设备。 |
| QiuJi-Preview-07-PadMini-P | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| QiuJi-Preview-08-PadMini-L | 保留 | 固定十设备人工评审配置，当前暂停待续，保留。 |
| QiuJi-FourLayer-SE17-20261011 | 已删除 | 独立工作树补证：实验本轮模拟器验证已完成，后续四层/极简副本由用户在真机试用；源码、原图和日志外置，不再需要临时测试实例。性能目标未通过不等于此测试设备仍占用。 |
| QiuJi-Remaining-SE-20261013 | 保留 | 剩余页面修复人工复验尚在继续，保留跨尺寸设备。 |
| Snooker-Render-SE17 | 保留 | 新版R2界面与相机最终跨尺寸评审设备，保留。 |
