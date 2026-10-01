# 开球完整轨迹计算耗时（2026-10-01）

针对用户“点击开球后停住好一会”，实测当前完整轨迹计算返回耗时；物理引擎未修改。

## 测量口径

- Apple M5 Pro；iPhone 17 Pro / iOS 26.3模拟器；普通Debug（非Release、非优化真机）。
- 当前RackLayout：缝隙0.20mm、逐球随机圆盘偏移半径0.09mm；8m/s、中杆、默认母球位置、自动瞄准球堆顶球。
- 五玩法按seed1～32轮流执行，各32次，共160次；每玩法先预热1次，预热不计。
- DispatchTime单调时钟在调用BreakSimulator.breakShot前起计、返回后停止，包含引擎初始化、simulatePrediction(.appDefault)、停稳整理、轨迹和规则事实结果。排除摆球、任务排队、主线程回调、SceneKit运杆及轨迹动画。
- 测量时仅本次xcodebuild存在；其它先前构建已完成。该结果是模拟器测量，不等于手机或Release表现，也不是实际点击到动画启动的端到端测量。

## 结果

| 玩法 | 平均计算 | 中位数 | P95 | 最慢 |
|---|---:|---:|---:|---:|
| 中八（15球） | 1.506s | 1.546s | 1.825s | 1.947s |
| 9球 | 0.872s | 0.858s | 1.053s | 1.070s |
| 追分6球 | 0.590s | 0.589s | 0.727s | 0.838s |
| 追分5球 | 0.543s | 0.542s | 0.666s | 0.669s |
| 追分4球 | 0.463s | 0.473s | 0.554s | 0.574s |

五种玩法等量混合平均0.795s，只是实验等权平均，不代表用户使用占比。全部160次自然停稳。P95使用最近秩（32次中第31个升序样本）。

## 等待机制

BreakFlowRunner.breakNow先设置computing，后台串行breakQueue算完整结果；返回主线程后startPlayback才runCueStroke；触球回调才runBreakMotion。纯计算期间球与杆保持静止，没有先出杆再后台补算。
8m/s的运杆到触球时间按CueStroke.totalDuration为0.5+0.12+2×(0.05+0.035×8)/8=0.7025s。因此中八点击至球开始动按这两部分相加约2.21s（估算，未含队列/主线程/渲染准备）；约1.51s计算阶段足以解释明显静止等待。计算完成后的0.70s为可见运杆动作，与静止等待区分。

## 证据与恢复

- 1个实测XCTest真实执行并通过，内含160个完整计算样本；test.log保留各组统计。
- 临时探针已移除，RackGeneratorTests.swift字节与测试前一致；Core/Physics与Core/Rack全部源码哈希一致，并与上次安装模拟器的物理源码一致。
- 原始样本、汇总、探针备份、源码哈希及恢复检查：build/break-timing-20261001/{samples.json,summary.json,probe.swift,source-hashes.json,restoration.json,test.log}。
- 未优化、修改或重装生产App，未测真机。


## 旧实验找回与优化构建对照

用户记得有更快的参数实验。找到两份不同范围的历史证据：

- `tasks/3d-v63/W17-working.md`（2026-09-14）：默认物理路径改为planarReference；满台“母球+8障碍”predict中位6898→27ms。该场景不是15球开球，不能当作开球基准。当前appDefault仍为planarReference。
- `tasks/DAILY-CLEARANCE-PERFORMANCE-EXPANDED-20260920.md`：seed52/53/54、8m/s中八真实完整开球，Debug -Onone为485.896／463.575／492.564ms，Debug -O为96.618／76.003／80.791ms。编译设置为SWIFT_OPTIMIZATION_LEVEL=-O，未改物理参数。历史a2c42d0e源码核对：gap0.20mm、jitterRadius0.09mm、maxEvents8000、maxTime30s、maxEvolveStep0.05s与当前一致；它不是本轮0.15／0.06及向下扫描实验的计时结果。

当前源码增加临时测试探针，对旧种子未优化各重复3次，并对seed1…32加旧种子52/53/54运行优化构建。两项XCTest均真实执行通过，全部44次计算settled；两轮各1次预热另计。计时仍只包围BreakSimulator.breakShot，摆球不计。

| 输入 | 历史Debug -Onone | 当前Debug -Onone均值 | 历史Debug -O | 当前Debug -O |
|---|---:|---:|---:|---:|
| seed52 | 485.896ms | 1628.940ms | 96.618ms | 139.368ms |
| seed53 | 463.575ms | 1410.039ms | 76.003ms | 126.137ms |
| seed54 | 492.564ms | 1833.275ms | 80.791ms | 145.900ms |

当前优化构建seed1…32平均132.790ms，中位132.462ms，P95为151.446ms，最慢157.457ms。先前同32seed未优化均值1505.646ms：两轮观察到约11.3倍耗时差，不能将这个比值视为任意设备上的保证。32局录制总时长与未优化结果逐局相等；未在此探针保存全部帧和终位，所以不把总时长一致冒充完整轨迹逐帧一致性。

当前优化构建仍较历史优化记录慢；历史/当前并非同版本、同时宿主负载的严格A/B，暂未定位具体新增成本。源码可见后续圆弧求根、有限实体边界及分离/停稳校验、接触音效事实等变化，但没有逐项计时，不能归因某一项。本轮未修改任何物理代码，也未以降低精度/截断轨迹提速。

构建和采样时另一个任务使用另一DerivedData/模拟器，过程快照保存在process-snapshots.txt；这次优化数字是本机负载条件下的观测，非真机基准。测试临时片段已精确移除，RackGeneratorTests.swift与开始前字节一致，Core/Physics及Core/Rack全部源码哈希不变。仅在隔离测试模拟器运行，未更换默认模拟器或手机上的App。

证据：build/break-history-comparison-20261001/{current-debug.json,current-optimized.json,summary.json,probe.swift,debug-test.log,optimized-test.log,source-hashes.json,restoration.json,process-snapshots.txt}。优化编译命令沿用首次计时的Makefile及模拟器入口，增加TEST_BUILD_SETTINGS='SWIFT_OPTIMIZATION_LEVEL=-O -parallel-testing-enabled NO -jobs 2'。


## 优化版手机试用安装（2026-10-01 14:44）

用户先授权优化编译，随后明确要求安装手机。通过make -f scripts/Makefile build-device-profile构建Debug -O；实际QiuJi编译命令包含-O，BUILD SUCCEEDED，codesign --verify --deep --strict通过。使用现有DeviceProfile增量目录，不改项目永久Debug设置。

已安装至连接的iPhone 16 Pro，devicectl返回com.xinkuan.qiuji安装成功；随后仅带-deeplink.dailyClearance启动，打开每日清台。启动PID2941与安装返回的同一App路径一致，进程列表复核仍在运行。没有重置数据、固定球架夹具或自动击球；用户直接试开球。未在手机重新测量完整轨迹计算时间，不能将模拟器0.133秒写成手机实测结果。

物理及Rack全部生产Swift前后哈希一致，保持gap0.20mm、jitterRadius0.09mm。构建产物可执行文件SHA256为77013a59b60a19d0a055d4b2a4a0fda660cf648b452ccae82aec6e0f2dc20401。未安装模拟器、未提交或发布。

verify-doc-size通过；verify-gate其它内容/DTO/术语检查通过，但最终仍被既有测试写盘登记漂移阻断：extra=['QiuJiTests/PocketMarkerHighlightTests.swift']。该项属其他工作区改动，未修改注册表绕过，不能称全门禁通过。

证据：build/break-optimized-install-20261001/{device-build.log,build-verification.json,source-hashes-before.json,source-check-after.json,install.json,launch.json,running-check.json,processes-after.json,gate.log,doc-size.log}。


## Xcode默认运行改为优化Debug（2026-10-01）

用户要求以后直接在Xcode点运行也使用优化版。project.yml的项目settings.configs.Debug增加SWIFT_OPTIMIZATION_LEVEL=-O，现有project.pbxproj的项目级Debug同步改为-O。Run继续使用Debug，DEBUG条件与ENABLE_TESTABILITY保留；Release未改，物理及Rack源码哈希未变。未整体重生成工程，保留现有资源/文件登记。

xcodebuild -showBuildSettings的实际QiuJi Debug设置确认-O、DEBUG及testability；xcodegen dump --type parsed-json确认生成真源同样为-O。通过普通make build验证，命令没有额外传SWIFT_OPTIMIZATION_LEVEL，也没有用显式优化build-device-profile掩盖默认设置；BUILD SUCCEEDED。手机已装的-O试用版无需因纯配置变更再安装。今后需要复跑历史-Onone基准时必须显式覆盖SWIFT_OPTIMIZATION_LEVEL=-Onone。

证据：build/xcode-default-optimized-20261001/{build.log,resolved-debug-settings.json,resolved-spec.json,verification.json}。本轮未添加测试、未修改引擎或永久测试夹具，未提交发布。
