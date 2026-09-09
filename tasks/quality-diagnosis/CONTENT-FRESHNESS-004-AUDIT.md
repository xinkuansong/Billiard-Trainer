# SC15 内容新鲜度与变更影响审计

2026-09-08，只读哈希与解析审计；未构建、测试或操作设备，未改业务或资产。

冻结基准：archive/quality-diagnosis/snapshot-004/source；原输入清单 source-before.json，时间2026-09-07T11:30:06.466127+08:00，HEAD eaa7021b67f895766bde2df27a6b2cea26d92a97。实际对比当前工作树文件字节，不以git clean或冻结没变代替当前核验。

|域|冻结文件|当前文件|新增|变更|缺失|原manifest哈希失配|原manifest未列|
|---|---:|---:|---:|---:|---:|---:|---:|
|Drills|76|76|0|0|0|0|0|
|Plans|13|13|0|0|0|0|0|
|DrillBoards|98|98|0|0|0|0|0|
|DrillTutorials|1372|1372|0|0|0|0|0|
|TutorialFigures|704|704|0|0|0|0|0|
|DrillThumbnails|74|74|0|0|0|0|0|
|Theory|4|4|0|0|0|0|0|

Drills 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `d890cdb514d9819137ddcc68f6a5cd93239a0959de3500251b577c1714b8cb7c`；现 `d890cdb514d9819137ddcc68f6a5cd93239a0959de3500251b577c1714b8cb7c`。


Plans 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `dd8059a9bb414f897cb7e596c467ea6f72c767e5ece59b9e166a4c288a6f0e41`；现 `dd8059a9bb414f897cb7e596c467ea6f72c767e5ece59b9e166a4c288a6f0e41`。


DrillBoards 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `f7a7f188c3936246178a144dbe61150ef514f96d1369cd74311dea4e08c950e0`；现 `f7a7f188c3936246178a144dbe61150ef514f96d1369cd74311dea4e08c950e0`。


DrillTutorials 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `df9cc893d79bd0800e2136cc2d03468e74a8a0064a0f94ee69d2ba4cb1f5c5b0`；现 `df9cc893d79bd0800e2136cc2d03468e74a8a0064a0f94ee69d2ba4cb1f5c5b0`。


TutorialFigures 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `3f71ec888fb22d6451ac5a6ac4b16f64b19c277a7a1546ff925ccdfe992473fa`；现 `3f71ec888fb22d6451ac5a6ac4b16f64b19c277a7a1546ff925ccdfe992473fa`。


DrillThumbnails 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `6f40d27e4ec84d00e7b3a9b35c08401a0368da708c598e42a1d0095d0aa62bc3`；现 `6f40d27e4ec84d00e7b3a9b35c08401a0368da708c598e42a1d0095d0aa62bc3`。


Theory 域清单 SHA256（路径\0文件SHA256\n，路径排序）：旧 `7cbe4d16b07295ded9156d1ef628f18d66594647694ec386b3a98f314f33b4ac`；现 `7cbe4d16b07295ded9156d1ef628f18d66594647694ec386b3a98f314f33b4ac`。


只读运行 `python3 scripts/verify_tutorial_images.py --json`，exit=0。摘要：
```json
{
  "total_refs": 704,
  "missing_refs": 0,
  "drills_with_missing": 0,
  "missing_by_drill": {}
}
```

只读运行 `python3 scripts/verify_tutorial_sync.py --gate --json`，exit=0。摘要：
```json
{
  "C1": {
    "ok": 0,
    "fail": 0,
    "warn": 95
  },
  "C2": {
    "ok": 0,
    "fail": 0,
    "collision": 0,
    "collision_idle": 0,
    "warn": 0,
    "not_backfilled": 0
  },
  "C3": {
    "ok": 704,
    "fail": 0,
    "warn": 0,
    "breach": 0,
    "dead_baseline": 0
  },
  "C4": {
    "ok": 71,
    "fail": 0,
    "warn": 3
  },
  "I5": {
    "ok": 71,
    "fail": 0,
    "exempt": 0,
    "warn": 0
  },
  "I7": {
    "ok": 0,
    "fail": 0,
    "exempt": 0,
    "warn": 11
  },
  "I8": {
    "ok": 98,
    "fail": 0,
    "warn": 0
  },
  "I9": {
    "ok": 71,
    "fail": 0,
    "exempt": 3,
    "warn": 5
  },
  "I10": {
    "ok": 88,
    "fail": 0,
    "warn": 0
  },
  "I6a": {
    "ok": 71,
    "fail": 0,
    "exempt": 0,
    "warn": 0
  },
  "I6b": {
    "ok": 92,
    "fail": 0,
    "exempt": 0,
    "warn": 0,
    "rule_exempt": 82
  },
  "I11": {
    "ok": 365,
    "fail": 0,
    "exempt": 0,
    "warn": 0
  },
  "I12": {
    "ok": 166,
    "fail": 0,
    "exempt": 0,
    "warn": 0
  },
  "I13": {
    "ok": 915,
    "fail": 0,
    "exempt": 0,
    "warn": 0
  }
}
```

## 上游及加载入口

[
  {
    "domain": "content/position_play/sequences",
    "old": 103,
    "current": 103,
    "changed": [],
    "added": [],
    "missing": []
  },
  {
    "domain": "content/drill_profiles",
    "old": 11,
    "current": 11,
    "changed": [],
    "added": [],
    "missing": []
  },
  {
    "domain": "content/retired-drills",
    "old": 55,
    "current": 55,
    "changed": [],
    "added": [],
    "missing": []
  }
]

母版清单704项实际PNG MD5与记录一致，HEIC存在且字节数吻合，失配0项。此清单没有HEIC输出哈希，不能单独证明有损编码内容对应，只能合并冻结文件SHA证据。

|输入|冻结SHA256|当前SHA256|
|---|---|---|
|project.yml|88e34e7ded638a9d74f5a2712d284b9a0eb9a4b7734d700a9a82b4d7f8f83a3a|88e34e7ded638a9d74f5a2712d284b9a0eb9a4b7734d700a9a82b4d7f8f83a3a|
|content/tutorial-figures-manifest.json|01c707927ac476614b69d9fcd08315824eda68240c73f9e486e14d6f7d493da9|01c707927ac476614b69d9fcd08315824eda68240c73f9e486e14d6f7d493da9|
|scripts/verify_tutorial_sync.py|6013df5a706b836e1ec712cfc7f8ae7d133a7174bf65e5b25de6a32173e28c70|6013df5a706b836e1ec712cfc7f8ae7d133a7174bf65e5b25de6a32173e28c70|
|scripts/verify_tutorial_images.py|82907c4609bc8f97f1b627ebe8ab190d9871ee6416ff5f14be0c87cb71e41bff|82907c4609bc8f97f1b627ebe8ab190d9871ee6416ff5f14be0c87cb71e41bff|
|scripts/content_invariant_baselines.json|5739bf0bc4c135a0adaf7f82c8d0f9674c806914565f9b64b80cbbb27b78b353|5739bf0bc4c135a0adaf7f82c8d0f9674c806914565f9b64b80cbbb27b78b353|
|QiuJi/Data/Services/DrillContentService.swift|03cce3527e2c2b9b92cde325b99877519725a17347d253658db2debbf44b3754|03cce3527e2c2b9b92cde325b99877519725a17347d253658db2debbf44b3754|
|QiuJi/Data/Services/PlanContentService.swift|cb06e7380c05294f033290ebb268d62c73ddf8ba72e52fefb9be9b74049821c6|cb06e7380c05294f033290ebb268d62c73ddf8ba72e52fefb9be9b74049821c6|
|QiuJi/Data/Services/DrillTutorialKindResolver.swift|a3298b9ec1273ded59bb836604997092ce0129a860c0acf0106a981605129ab6|a3298b9ec1273ded59bb836604997092ce0129a860c0acf0106a981605129ab6|
|QiuJi/Data/Services/TrainingDoseResolver.swift|342ce66d91023f84e8b616d90cdbe9af477025a64cbab9e58020448130839a24|342ce66d91023f84e8b616d90cdbe9af477025a64cbab9e58020448130839a24|
|QiuJi/Features/DrillLibrary/ViewModels/DrillListViewModel.swift|9636ca670addbce404b7d563ead9cabd5c845154cf283f3be9855798432636e3|9636ca670addbce404b7d563ead9cabd5c845154cf283f3be9855798432636e3|
|QiuJi/Features/DrillLibrary/Views/DrillListView.swift|45224de57b8f418e15f2f2799762660ee0f6f12f063ca800c7dd1fd877493ab8|45224de57b8f418e15f2f2799762660ee0f6f12f063ca800c7dd1fd877493ab8|
|QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift|7161cd06a4e85d5f84c1051b1b4ab36c11df16948a48b45a7cc8fb157c1933d4|7161cd06a4e85d5f84c1051b1b4ab36c11df16948a48b45a7cc8fb157c1933d4|
|QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift|cae85895741dbce43938bc8d582540da7c6ab656a88f11665cfd624b3a75ec6a|cae85895741dbce43938bc8d582540da7c6ab656a88f11665cfd624b3a75ec6a|
|QiuJi/Core/PositionPlay/DrillTryoutBoardStore.swift|26d7fcb63e78f1fd3aadc47b76fc93e659013ef3a139ea85e70aface7159e62d|26d7fcb63e78f1fd3aadc47b76fc93e659013ef3a139ea85e70aface7159e62d|

当前 Drills 索引74项/74唯一ID；Plans索引12项；上述三类JSON全量解析异常0。Swift路径新增0、缺失0；字节差异仅RootView、OnboardingView、Typography三个文件（只定位差异，不审阅无关业务）。

## 影响与历史证据适用范围

**本次结论：当前内容输入与004档案相同，未发现因工作树新增/编辑导致的内容失效；现有生成新鲜度缺口仍在。** 上表2341份资源逐字节SHA256、169份上游内容文件、14项入口/配置/脚本均直接读取当前文件核对，不是只检查冻结副本。资源全部在原5350项输入manifest中，冻结副本与原manifest无哈希失配。DrillTutorials包含未打包母版及其他文件，所以1372是文件数，不说成1372张在售精讲图。

实际加载链：DrillContentService.loadFallbackDrills 从 Drills/index 的74个ID逐个解码，失败会compactMap丢弃并记录诊断；PlanContentService.loadAllPlans从12个索引计划逐个解码；DrillTryoutBoardStore按drillId文件名前缀筛98个盘面并按token组成球形；DrillListViewModel依据搜索、球种、教程类型、level和badge筛选已加载动作。列表/详情/精讲视图、教程分类resolver、剂量resolver及打包project.yml的哈希均相同，因此本轮未发现加载或过滤逻辑变更使旧内容校验失效。project.yml仍排除DrillTutorials母版，folder-reference打包TutorialFigures/Drills/Plans/Boards，不能把母版存在直接称为实际Bundle加载成功。

并行dirty有三份Swift差异：RootView只新增-intro.preview深链暗色；Typography新增仅引导用btIntroTitle及字体注册；OnboardingView采用新的引导展示。没有Swift路径新增/缺失。这些不改变上列内容加载/过滤入口，不能据此要求全量内容重跑；但冻结引导/视觉截图不自动等价于当前引导，本审计不验收他人正在编辑的视觉工作。未修改、恢复、暂存这些文件。

B0/B3记录来自snapshot002，**不是004首次执行结果**：B0-B1.md记录原B1内容20/20；B3.md记录31/31单测及静态门禁FAIL0、12课115杆/130引用/目视20图抽样。当前归档只找到004 source-before输入清单；原B0 build目录、B1/B3原始run及snapshot002的可核哈希原件未在现存路径找到。故不得把“004与当前一致”推导成“002与004全相同”，也不得宣布当前重新取得20/20或31/31。历史终态保留为已执行历史证据，不复写成未执行；本轮当前脚本解析为新增独立当前证据。

已读代表真实测试断言：TutorialFiguresBundleTests.test_referencedTutorialImages_allResolveFromBundle 对全部引用实际调用图加载器；containsNoPNGMasters 排除PNG；countMatchesReferencedSet比去重引用数；publishedFigure_decodesAtSourceResolution仅抽首图宽1440，不证明所有图分辨率/教学正确。DrillTryoutBoardStoreTests.test_allBundledBoards_decodeAndInRange遍历真实Bundle JSON，检查初始盘非空及坐标范围，不验证全部后续运动。这些能力不能由本次Python JSON解析替代；同样不应为了“新鲜度”重复无关工具31个测试。

## 仍需保留的缺口与最小后续

1. 当前只读内容门禁exit0/FAIL0，但 C1仍为0ok/95warn，C2为全零；与CONTENT-WARNINGS记录相同，缺少中间出片比较对象，不证明序列→渲染图新鲜度。704项母版MD5与清单相符及HEIC大小相符，补强“母版没有在清单后改变”，仍不是引擎重渲染认证。不要为清空告警生产资产。
2. 当前I9五项下架上游保留、I7十一项退役profile、三个无序列豁免仍按既有意图区分。98盘面全解码不等于下架盘面不进包；不得重新上架或删除残留来消除提示。当前准则若要求实际包不含下架资源，需单独实际Bundle审计，保持既有明确问题而不反复同质复现。
3. 优先查主控现存004 Release/App归档是否已有全部引用解码、实际打包数量/排除与下架资源清单。如果原件足够，复用并链接即可；只有缺真实Bundle证据时，才建议主控最小选择 DrillContentValidationTests 的相关全索引字段方法、TutorialFiguresBundleTests的全引用/无PNG/计数以及BoardStore全解码方法，绑定当前输入指纹。此建议未运行，且不把旧31项全重跑作为前提。
4. SC17已记录教学文字/剂量矛盾仍是独立内容问题，不因哈希一致或本次门禁绿而消失；本文不扩展全库逐杆图审或教学几何认证。若未来序列/正文/HEIC或相关加载器发生实际变更，再仅围绕变更ID重查引用、剂量、正常入口与对应图，不新增无限矩阵。

审计为扫描时点观察，工作树仍可能被并行任务继续编辑。主控正式使用此结论前可复核上表域清单SHA；若有差异，保留本报告原结论并另记新增delta，不归咎或覆盖他人工作。未运行selftest_content_invariants（会制作/改写fixture）、构建、XCTest、UI或资产制作脚本。


## 原件补档（主控复审后，只读重扫）

新证据目录拒绝覆盖已存在目录；扫描脚本对每个输出使用 exclusive create，并在开始时拒绝任何同名证据。本次重扫资源与上游各域仍是新增0/变更0/缺失0，14项源文件无变化；两个检查均exit0，图片missing_refs=0、内容failures=0，原C1新鲜度告警未通过出片消除。扫描起止时间见摘要；这是新一次扫描原件，不倒填第一次扫描时间。

- [扫描脚本](../../archive/quality-diagnosis/observations/content-freshness-004/scan.py)：从仓库根目录调用；仅读取输入、写新证据。复核时应复制到新的空证据目录，原目录再次运行会拒绝覆盖。
- [扫描摘要及域摘要哈希](../../archive/quality-diagnosis/observations/content-freshness-004/scan-summary.json)：记录输入manifest自身SHA256、起止时间、计数及逐域增改删。
- [2341份资源逐路径哈希](../../archive/quality-diagnosis/observations/content-freshness-004/resource-path-hashes.json)：冻结/当前两侧完整路径和SHA256。
- [169份上游逐路径哈希](../../archive/quality-diagnosis/observations/content-freshness-004/upstream-path-hashes.json)；[14项源/配置/脚本哈希](../../archive/quality-diagnosis/observations/content-freshness-004/source-path-hashes.json)。
- [图片引用检查原始JSON](../../archive/quality-diagnosis/observations/content-freshness-004/tutorial-images.stdout.json)；[内容门禁原始JSON](../../archive/quality-diagnosis/observations/content-freshness-004/content-gate.stdout.json)：保留完整条目，不是仅数量摘要。
- [命令、退出码及stderr索引](../../archive/quality-diagnosis/observations/content-freshness-004/checks-execution.json)；[证据文件SHA256清单](../../archive/quality-diagnosis/observations/content-freshness-004/evidence-sha256.json)。两个stderr原件也同目录保留，清单不递归包含自身。

归档后逐一读回核验 evidence-sha256.json 中所有文件哈希一致。未修改业务/资产/冻结工程或共享台账，未运行构建、XCTest、UI或资产制作。
