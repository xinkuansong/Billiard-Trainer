# 原生截图批处理 v4

## 可迁移恢复资料

`recovery-bundle.py --index <review-index.json> --map <figma-map.json> --base-fig <saved.fig> --output <new-directory>`保存按SHA去重的原PNG、相对路径清单、节点映射、基点.fig、导入器及独立恢复脚本。仅接受已审图片；APFS克隆后逐文件复核SHA，拒绝覆盖。恢复流程见[RECOVERY](RECOVERY.md)。同盘克隆不等于异盘灾备；打包正确、实际Figma回导、云同步、用户验收分别记录。

源码适用性表：App见`STATE-APPLICABILITY-v4.json`；每日/球桌见`TABLE-STATE-APPLICABILITY-v4.json`。候选清单保留，N/A需源码依据；分类不能增加已采覆盖，也不能把未定义状态删掉。教学球桌虽局部强制dark，训练键盘会恢复宿主主题，不能把整页Light/Dark一并合并。

运行器：`run.py`；真实页面导航：`QiuJiUITests/ScreenshotTourUITests.swift` 中 `testNativeAtlas*`；图册打包：`package.py`。当前已接入试点、五首页与训练入口六状态，不代表117项全状态导航已全部实现。

一次 `build-for-testing` 后，使用 `test-without-building`。每个 worker 的产物用 APFS clone 隔离，后续无需共享 `.xcodeproj` 或构建数据库。单个 UDID 的主题与方向始终串行，最多两个 worker。已有启动设备拒绝接管；失败记录保留，其他独立 job 继续；只有本轮成功启动的设备会关闭。

```bash
xcodebuild -project QiuJi.xcodeproj -scheme QiuJi -configuration Debug \
  -derivedDataPath build/DerivedData -destination 'platform=iOS Simulator,id=F2BE90C4-370D-46AB-B3E8-8F0060424B2D' \
  -parallel-testing-enabled NO build-for-testing

/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  scripts/native-atlas/run.py --config scripts/native-atlas/roots.json \
  --output output/app-native-audit/<new-run>/roots \
  --products build/DerivedData/Build/Products \
  --xctestrun build/DerivedData/Build/Products/QiuJi_iphonesimulator26.2-arm64.xctestrun \
  --workers 2
```

每次使用新 output，已存在则拒绝，禁止覆盖失败或旧基线。不同 SDK 先检查真实 xctestrun 名。先跑 `pilot.json --workers 1` 预热，再对小范围双路实测吞吐/失败率。其他线程的 Simulator/CUA 操作不可与 UI 测试交叉。

产出每 job 的 PNG、页面 AX、窗口/主题/fixture JSON、命令日志、xcresult、result.json，整体 summary.json。页面切换后需要三个连续相同帧；未稳定则测试失败。脚本检查预期文件、PNG解码/非空白、窗口、像素比例、主题元信息。浅深最终像素与逐图视觉仍独立检查，不把自动检查写成用户验收。根页配置50槽只覆盖首屏，长页/弹层/空有状态后续显式补齐。

Figma 导入包只接受 `status=VALIDATED` 且 SHA 对得上的人工/AI目视清单；相同slot+SHA不重复导入。新修订新增节点保留旧图，避免覆盖已有评论所指画面。导入回执记录真实节点和像素尺寸；新文件12 Page已建立，评论入口可读，真实评论跨修订仍需有评论后核验。

## 配置化导航

`flows/plan-entry.json` 用明确的 `tap / wait / back / swipeUp / type / snapshot` 步骤描述正常入口；`plan-entry.json` 把相同路线配置到五窗口、双主题。使用 `ScreenshotTourUITests/testNativeAtlasConfiguredFlow` 后，新增或修改路线只改 JSON，无需重编译 App 或测试。新增未实现的动作类型才需要重新构建。`configured-preview.json` 是标准浅色的单环境验证入口；先验证导航，再扩展矩阵。

每个 job 的 `expected` 必须与 flow 的截图名完整同序匹配，禁止静默跳过控件或以拍到的数量倒定分母。执行时复制 flow 到证据目录；`flow-current-step.json` 指明最后执行步骤。页面断言失败保留 XCTest 结果和前序截图，后续未采项维持缺口；不能拿另一页凑数。

## 已实测与经验

- N02 五首页 × 五窗口 × 双主题：50 张，双路总耗时 460.85 秒（含设备启动和收尾），10 job 全通过、零重试。50 张逐图检查后导入 Figma；原生页面长滚动仍另算。
- N03 训练菜单、帮助折叠/展开、计划列表、新建模版、动作选择器：标准浅色六张连续流程 60.77 秒，通过原生 XCTest；这不代表五窗口全矩阵完成。
- 过渡帧：不能只等待控件出现就截图；连续稳定帧检查拦截 crossfade。
- iPad 横图：Apple PNG 可能以 EXIF orientation 保存；按方向无损解码并验证像素相等，原图保留，禁止缩放来掩盖尺寸错误。
- P03“新建”正常入口本轮失败留证；P05/P06改走首页“我的模版 → 新建模版”。入口异常单独登记，不修改 App 来制造截图成功。
- Figma Section 按已有区域底部追加，已导图片不覆盖；目录数量从实际原生图节点读取。导入成功、AI检查、用户认可分别记录。

## 空间与中断恢复

运行前及每个job前检查目标卷，默认保留至少2GiB；不足则不启动后续任务，记录pending.json并关闭本轮取得的设备。运行中可在output创建`STOP`文件，在当前job结束后安全停队列；不要使用全局killall或shutdown all。未完成job保留原件，恢复使用新output和原frozen-products/frozen.xctestrun/frozen-flows，按成功result.json排除已采job，不能覆盖或靠缺图变更expected。

长页使用短距离按住拖动、停留后放手，核对相邻AX正文位移并逐张看连续内容；快速swipeUp可能跳过一整屏，reachedEnd本身不能证明无遗漏。键盘需与窗口相交且按键可点击，AX exists不等于软键盘已显示。光标稳定比较只允许显式输入框区域，保存的原图不得修改。

### 系统菜单和局内面板的实际选择器

- 不假设每个confirmationDialog都有独立“取消”按钮。r9标准手机的记录删除确认实际为popover，标题“删除这条训练记录？”与“删除”按钮可读，取消依靠外部点击。以标题+原图确认状态，不能等待不存在的取消钮后把成功显示的弹层判为App故障。
- 每日清台/分离角主菜单title=nil，没有`dailyClearance.menuClose`；带标题的瞄准/轨迹子菜单才有这个ID。主菜单关闭背景在实际AX为button label“关闭菜单”。`freeplay.moreMenu`仅设置`.more`，不是toggle。先读实际AX与面板实现，不从其他菜单类推。
- 菜单内滚动不能使用全App的`swipeUp`。r8“临时换玩法”被全局滑动误触关闭；r9直接tap已存在的目标完成正常进入。失败时先保留原图/AX，禁止把脚本定位失败记作App缺陷。
- `visualReview`统一填`AI_REVIEWED`，图像有效状态`status=VALIDATED`；不应保留相互矛盾的UNREVIEWED字段。原始capture/result.json不改，评价写派生review.json。

### 派生图册与控件定位

`build-index.py --figma-map <saved-map> --output output/app-native-audit/review`生成只读筛选图册，原图SHA逐项验证。数字包含滚动片/修订，不是页数或验收数。Figma链接只取落盘回执，不将待保存导入算完成。

r10的`tapCenter`仅显式用于实际AX activation point失败的可见按钮；r11的`kind: switch`优先选择SwiftUI标记行内的实际Switch。标记行tap未必切换开关，必须断言开关后的实际内容，再命名截图状态。任何失败局部图即使尺寸与PNG检查通过，状态不符也不得批准。

r12：iPad sheet可能同时暴露背景和前景ScrollView。仅选最大宽度会滚动背景并假报到底；订阅页已由原图和AX确认此问题。`cover`可指定`scrollId`，并用`endText`要求末尾正文真正可点击可见；默认候选也过滤不可点击ScrollView。原始reachedEnd只说明画面不再变化，必须结合正确容器、终点与连续截图复核。旧误判只保留有效首屏，不能标全页通过。

r13：正文包含Slider时，cover中段拖动可能被滑块吞掉，连续相同图不等于页尾。P18-15/16/18试点实证使用`dragX: 0.97`避开控件，并以`endText`约束真实终点；42张连续视口已逐图核至底部。cover保存dragX/requiredEndText用于回查。新路由先单环境验证，失败不能直接铺满矩阵；旧图保留FIRST_VIEWPORT_ONLY。

### 增量导入清单（不复制图片）

`prepare-import-queue.py --index <index.json> --figma-map <saved-map.json> --packages <archive-dir> --output <new-directory>`按`slotId+sha256`区分已保存回执、已打包未确认和新增待打包，仅将已审且原图哈希匹配的新增项分为每批最多80张的`review-NNN.json`。清单引用原PNG，不生成base64副本。使用新目录保留每次快照；不会修改当前Figma插件或将未保存回执视为交付。

连接恢复后，逐个清单用`package.py --review <review-NNN.json> --plugin <plugin-dir> --batch <unique-name> --archive-only`按需准备，导入/读回/保存回执继续串行。已有包和未保存回执先处理，避免重复导入。r17已用真实3,786条索引实测：664项匹配保存回执、1,108项已有包但回执未确认、2,014项新增清单/26批，总清单约6.56MiB。

### 续跑器与目标态可见性（r18）

- 等待前序任务的调度脚本也必须用上文带 Pillow 的 Python 运行。它的 `sys.executable` 会传给 run.py；系统 Python 能执行等待却会在真正接棒时因缺 PIL 退出。启动调度前用同一解释器 `-c "import PIL"` 预检。r18两条接棒在尚未启动模拟器时遇到此错误，改用已提供运行时恢复，不改变旧失败证据。
- cover 到页尾后再点页首控件，`exists/isHittable` 不足以证明点击正确。横屏账户页实际未进入个人信息，定向补采改为页首直接进入，不重拍已完成首页。
- 选中项在视口外不能以点击日志代替选中截图。小屏球龄5年以上首屏未完整露出勾选，拒收该命名目标态，滚至完整可见后补采；不因此认定App保存失败。

### Foreground List coverage (r19)

A SwiftUI List can be exposed as CollectionView while an inactive background still exposes a wider ScrollView. Unchanged screenshots then prove no movement, not list completion. Use explicit `scrollKind: "collection"` only after the captured AX tree proves one hittable collection, and require the actual last row via `endText`. Ambiguous containers must fail. Retain old screenshots as FIRST_VIEWPORT_ONLY and run one corrective attempt; never reinterpret an old reachedEnd as full coverage. r19 compilation passed; the corrective runtime pilot FAILED because no foreground collection reported isHittable. The guard remains strict. See r19/collection-blocker.json; portrait full-list capture remains blocked, while independently observed landscape scroll evidence remains valid.

### r20 端点断言与回执合并

`adjustSlider`支持显式`endpointDrag: true`，仅允许0或1端点；测得滑块中点后拖至实际端点。`expectedReadout`必须配`readoutContainer`，在对应容器中匹配完整且可见的数值文案。大屏通过不代表Pad通过；Pad实值89°时保持失败，不能改成近似90°通过。

`merge-receipts.py --map <saved-map.json> --index <index.json> --receipts <receipt.json> --output <new-or-same-map.json>`只接受IMPORTED_READBACK_OK回执，并核对slot/hash、像素和节点字段；重复身份指向不同Frame时拒绝。验证完成后原子写入，重复合并不增计；r20实测错误像素拒绝且原映射不变。回执证明桌面读回，不证明云同步或用户验收。

### r21 导入效率与可恢复归档

导入器只重排本批新增图涉及的Section，既有图片身份和内容不变；每Section缓存布局元数据和caption索引，全局仍检查Section间距。纯重复批不触发布局改写。回执记录导入/总耗时和重排Section。完整旧/新布局对照覆盖无新增、单Section新增、多Section新增；真实导入仍须逐批读回和实看。

已保存回执且核验通过的包可执行`compact-package.py --archive <package-directory> --receipt <saved-receipt.json>`：保存原导入器文本、完整包元数据、PNG引用及脚本SHA；从原图重建与原code.js逐字节一致并读回验证后，才移除重复的生成脚本字节。原PNG、package.json与回执保留。`--restore-to <new-code.js>`可恢复，拒绝覆盖已存在文件。引用归档必须与原PNG共同保存，不能单独当作脱离原图的备份；活动插件与未确认包不得压缩。
