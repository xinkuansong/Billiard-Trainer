# 精讲配图换新 · 2026-10-12

状态：✅ 墨龙球杆漏项修复完成；精讲/缩略图均明确使用墨龙＋新版球桌＋选定光影。全量生成/包内验证完成，已安装并启动用户 iPhone 16 Pro，实际效果待用户复验。未 Git 提交或发布。此前各轮记录保留，下文末尾为当前结果。

用户授权：追溯旧图片流程后要求实现新版球桌与渲染替换；中途暂停构建，用户明确恢复后继续。暂停日志保留。

## 首轮实现与范围（历史记录，灯光已由后续配方替代）

- 首轮 `Options.tutorialStills()` 接当前 App 默认炭灰球桌、绿色台呢、模型与移动端灯光；该灯光不是最终配方，后续已按用户选定样张替换。竖版取景、球位、轨迹与参数 HUD 保留。
- 常规出片 runner 的静帧改用新配方；增加按请求选定序列、输出到隔离目录的静帧 runner，逐序列核帧名及像素尺寸。
- 回填增加 `--stills-only` / `--export-root`。明确 token 永久保留；manual01 及真源库单球形保留默认别名。单球形由真源库判断，不能以选中出片目录数推断，避免单独重出 manual02 时覆盖默认图。
- C2 校验器纳入无视频的静帧目录。视频文件命名与原配方保持原行为；没有复制/重出视频、卡片预览，没有改序列和精讲正文。
- 全量 92 条有效序列生成 796 PNG，704 张引用母版及 HEIC 全部更新。发布 HEIC 合计 **122.8 MiB**；全部 704 个源哈希与旧清单不同，母版逐字节等于本次对应渲染源。

## 验证

证据根：`output/tutorial-refresh-20261012/`。

| 验证 | 结果 / 证据 |
|---|---|
| 新版样张 | c001 / c042 / c077 共 24 帧，原生 1 测通过，开局与逐杆原图目视检查；`sample-resume.log`、`sample-contact-sheet.jpg` |
| 全量原生导出 | 1 测、0 失败，92 序列 / 796 帧，135.398 秒；`full-render.log` |
| 静帧解码/尺寸/非空 | 796/796 通过；`render-verification.json`，92 开局画面总览 `overview-1.jpg` 至 `overview-4.jpg` |
| 回填回归 | 5 测通过，覆盖视频/预览保留、幂等、无视频时 C2 真能拦坏图、历史单球形别名、选定第二球形不覆盖默认别名；`import-tests.log` |
| 全部引用更新 | 704/704 母版与新渲染源字节一致、704/704 发布源哈希已变；`referenced-update-verification.json` |
| 最终 App Bundle | 4 测、0 失败；704 张均经真实图片读取器解析。另逐张验证包内 HEIC 与最终资源 SHA 一致；`bundle-final-tests.log`、`delivery.json` |
| 内容/全仓门禁 | `verify-tutorials` 与 `verify-gate` FAIL 0；C1=92、C2=1411、C3=704，发布=704；`tutorials-after.log`、`gate-after.log` |
| 文档与差异 | `verify-doc-size`、`git diff --check` 通过；对应日志 |

首次回填的逐图版本核对发现 5 个历史单球形共 30 张默认别名仍旧，已补修命名规则并补发；最终清单与 Bundle 验证在修正后重新执行。初次 Bundle 测试仅证明可读取，不作为全量已更新的证明。

C1 剩 3 条提示来自退役动作 c002/c007/c062 未重新出片，不在当前 704 张发布集内。C4 的 3 个无序列/非逐杆项沿用现有内容状态，不改内容或放宽门禁。

## 对照、备份与复现

- [704 张新旧对照](../output/tutorial-refresh-20261012/review.html)。对照左侧为旧母版，右侧为本次新渲染。
- 旧母版、旧 HEIC、旧发布清单：`backup/`。新图：`full/`；真源输入 SHA：`render-resumed-input-sha256.json`，引用映射：`reference-map.json`。
- 首轮 `build/position_play_export` 曾指向 `full/`，本轮已保存到 `canonical-first-pass/`；当前为 `tutorial-approved-full/` 的 APFS 克隆，796 帧哈希全部一致，供 C1/C2 校验，不含视频。
- 独立模拟器 Tutorial-Figures-20261012（6D4819FD-5E62-43AF-AA55-230B06ADAE4F）已关闭；临时烘焙门控与请求已移除。请求副本保留在 `sample-request.json` / `full-request.json`。
- 暂停期间其他任务改过假想球环颜色；恢复后已重编译纳入。样张和全量共用同一构建，最终比对渲染输入无漂移；本任务没有修改该场景文件。
- 未操作既有十设备评审窗口，未安装真机，未提交或发布。下一步：用户审阅新旧对照；后续需体验时将新包安装到指定设备。

用户追加（10-12）：缩略图也须换新。正在接 `DrillThumbnailRenderer` 当前 App 外观，保留横版 640×320、代表性球形与 1.8 倍球的现有缩略图配方，旧缩略图已备份。

10-12 用户反馈：确认动作库原先就读取预渲染 PNG 后，用户恢复生成；随后明确指出阴影、光照不对。74 张首轮已生成且与包内逐字节一致，但不得视为视觉交付。`lighting-diagnosis/` 将对比当前配置首帧/稳定帧、生产 reference 配置和 SCNView。精讲图与缩略图共用部分外观链，诊断确认后检查是否同样受影响。


## FL-146 缩略图返工与定位

- 首轮全量 74 PNG/640×320，最终 5 Bundle 读取测试通过；704 HEIC 与 74 PNG 均与当时构建包逐字节一致。这些属于生成/读取证明，首轮缩略图已被用户明确否决。
- 已将 74 张项目缩略图恢复本次任务前备份，核验 74/74 字节一致；候选 `thumbnails-full/` 保留。构建包仍含首轮候选，不作为新交付；`thumbnail-rollback.json` / `delivery.json` 标明失效。
- `lighting-diagnosis.log` / `lighting-diagnosis-r2.log`：离屏首帧、连续帧及补齐 reference R/曝光 -0.1 的对照；接触 uniform 的六个可见球权重均为 0.85，单纯补回调没有改变权重。首轮未挂窗口 SCNView 得到黑图，已作废；第二轮挂窗后像素依然呈现相同扁平风格。重复时刻 explicit 样张也黑，不作为有效对照。
- `recipe-comparison.log`：同 c001、同镜头/尺寸，原缩略图 plain 与 mobile reference 对照，原配方保留更明显库边明暗及小高光；新版配方 1.0/1.8 球都不同于用户旧图。缩略图 1.8 倍视觉球与光照固定真实半径还存在契约差异，但不得将它单独认定为全部问题根因。
- [同条件配方对照](../output/tutorial-refresh-20261012/recipe-review.html)。用户已提供旧版截图，存 `user-old-thumbnail-reference.png`。已展示“新版球桌 + 原缩略图光影”样张，并询问是沿用此方向，还是必须继续匹配新版 App 光影。
- 当前暂停全量回填，待上述目标明确后再选生成配方。没有为迎合单张图修改共享灯光或材质；精讲配图的外观结论仍未验收，不能沿用首轮完成表述。


## 用户选定配方及球体防重叠追加

用户已选“新版球桌 + 原缩略图光影”，并要求放大球体重叠时合理调整至相邻相切。
仅 `DrillThumbnailRenderer` 使用 `ThumbnailBallLayout`：按原球对方向建立非重叠半平面，
边界内缩视觉半径，以最小平方位移求满足全部约束的位置；不回写 JSON，不改变实时详情和训练。
生成时针对显示副本重算预告线。正在运行合成边界/密集队列/聚集与全部 74 个动作测试，随后隔离出图。


## 最终缩略图交付（用户选定配方后）

- 新版球桌 + 原缩略图光影，保持 640×320、1.8 倍视觉球。共 74 张，13 个球形产生必要移动；41 对原重叠全部消除，台内边界全部通过。
- 16 项 `DrillStaticPreviewTests` 通过：正常球位不变、最小位移到相切、贴库密集横排、斜向聚集、重合中心、不可行约束拒绝及全部 74 动作真源副本无重叠/不越界/不改源。
- 首次运行遇模拟器 Busy、未执行测试，日志 `layout-tests.log` 保留；bootstatus 后同构建 `layout-tests-retry.log` 16 测 0 失败。
- 3 张代表样张及 74 张全量原生生成均通过；`approved-samples.log` / `approved-full.log`。逐图布局及解码验证 `approved-verification.json`，全图总览 `approved-overview-1.jpg` / `approved-overview-2.jpg` 已实看。
- 最终 5 项包内读取测试通过（`approved-bundle.log`）；74 PNG 与 704 HEIC 均与项目资源逐字节一致，`delivery.json` 更新最终状态。gate FAIL 0（`gate-approved.log`）。
- [当前 74 张新旧对照](../output/tutorial-refresh-20261012/thumbnail-review.html)；第一轮失败对照保留 `thumbnail-review-rejected-r1.html`。新增防重叠算法不影响实时训练、详情和精讲生成，精讲外观仍需独立视觉验收。
- 临时诊断 runner 源码归档 `diagnostic-runner.swift.txt`，已从常规烘焙测试移除；最终烘焙门控与请求已移除。没有额外安装到用户手机或修改评审设备。


## 精讲同步选定光影（用户认可缩略图后继续）

用户确认「可以，继续吧，精讲图也接着处理吧」。精讲静帧改为 `useTutorialAppearance`：新版模型、默认炭灰球桌与绿色台呢，`enhancedRendering: false / mobileRendering: false`，与已认可缩略图的光照一致。`Options.teaching()` 的真实球径 `ballScale = 1`、原始球位、路径、相机、分辨率和 HUD 不变；缩略图专用放大与最小位移布局不用于精讲。视频与其他 `useAppAppearance` 调用继续原配方。

- 样张：`tutorial-approved-samples/`，c001/c042/c077 共 24 帧；`tutorial-approved-sample.log` 原生导出通过，目视核对开局与逐杆图。
- 本轮渲染输入：`tutorial-approved-render-input-sha256.json`；球形/内容原文：`tutorial-approved-content-sha256.json`。
- 磁盘有限，先将 1411 个与首轮导出 SHA 相同的母版改为 APFS 克隆，内容零变化，可用空间由 3.72 GB 增至 8.82 GB。原始备份完整保留，记录 `clone-identical-masters.json`。本轮回填仍调用正式 importer，仅以 `import-approved-clones.py` 将复制替换为逐文件 SHA 核验的 APFS 克隆，命名、发布与校验逻辑不变。

- 全量：`tutorial-approved-full/` 92 组 / 796 PNG，原生测试通过（`tutorial-approved-full.log`），全部解码、尺寸、帧名和非空台面检查通过（`tutorial-approved-render-verification.json`）。已目视核对 92 开局图总览 `tutorial-approved-overview-1.jpg` 至 `-4.jpg`。
- 对照页 `review.html` 更新到本轮 704 张配图，1408 个新旧图片链接均存在；首轮对照页保存为 `review-first-pass.html`。样张及总览核对不替代用户对全量精讲图的视觉验收。

- 回填：1411 个 PNG 母版/别名；704 张引用 HEIC 全部新压，97.8 MiB（q70），没有改 JSON 或视频。`tutorial-approved-import.log`。
- 包内：`TutorialFiguresBundleTests` 5 测 / 0 失败；真实图片读取器全部解析成功。704 母版逐字节等于对应渲染，704 HEIC 和 74 缩略图逐字节等于最终 `球迹.app` 内资源。`tutorial-approved-bundle.log`、`tutorial-approved-asset-verification.json`。
- 门禁：`tutorial-approved-gate.log` FAIL 0，发布集缺失/过期/多余均 0；223 个渲染输入（含 75 个 Drill JSON、103 个序列文件）哈希零变化，已认可缩略图零变化。
- 最终状态：无真机安装、无 Git 提交或发布。已移除本次门控与请求；本轮对照入口仍为 `review.html`，旧资产和首轮被替换配方完整保留。


## 墨龙球杆漏项修复（本轮）

用户反馈精讲中球杆没有换成墨龙。此前只锁定球桌、台呢和光照，`Options.cueStyle = nil`、缩略图未指定款式，导致使用模型原木外观。现在 `tutorialStills()` 显式设 `.inkDragon`，`DrillThumbnailRenderer` 同样显式应用，应用失败返回 nil 阻止生成。保留已确认光影、精讲真实球径和原球位、缩略图放大与防重叠布局，不改视频配方及用户偏好。

样张 `inkdragon-samples/` 24 帧、`inkdragon-thumbnail-samples/` 3 张，分别通过原生 runner，实际检查球杆前节纹理与先角变化。此前认可的是光影与布局，本轮增加球杆款式，最终视觉仍待用户复核。旧输出 `tutorial-approved-full/`、`thumbnails-approved-full/` 保留，旧打包图和清单备份于 `before-inkdragon-TutorialFigures/` 和 `before-inkdragon-manifest.json`。

本轮差异诊断：最初以「无球杆开局/终局应逐像素一致」作辅助检查，结果不满足（`inkdragon-delta.log` 保留失败）。追查上一轮相同源码/配方的样张与全量，24/24 重复渲染本身也存在细微像素差异，证据 `inkdragon-repeatability-diagnostic.json`；因此不声称无球杆图像素一致，不将此作为验收。改为完整保留像素差异报告并验证实际输入与布局：223 个渲染输入哈希零漂移，74 个缩略图完整布局报告与上一版相同。正式生成完整性、包内及内容门禁没有删断言或放宽条件。

本轮最终验证：92组796 PNG 完整解码/尺寸通过（`inkdragon-render-verification.json`），704 HEIC 全部新压（97.9 MiB），74 PNG 全部为640×320。704引用母版匹配渲染源，704HEIC/74PNG全部匹配最终 App Bundle（`inkdragon-asset-verification.json`）；5包内测试0失败、gate FAIL0（`inkdragon-bundle.log`、`inkdragon-gate.log`）。原始数据无变化，缩略图防重叠布局逐项一致。

当前产物：`inkdragon-full/`、`inkdragon-thumbnails-full/`；常规对照仍为 `review.html` 与 `thumbnail-review.html`，专项换杆对照 `inkdragon-review.html`。`build/position_play_export` 同步新母版，旧 canonical 保存于 `canonical-before-inkdragon/`。门控与临时请求已删除，专用模拟器收尾关闭。

## 真机安装（2026-10-12 20:29）

用户明确要求安装到手机查看效果。`devicectl` 发现唯一连接的 iPhone 16 Pro（wired），通过 `make build-device-profile` 在本任务独立输出目录构建当前工作区版本，`device-build.log` 为 BUILD SUCCEEDED。安装前逐张核对 704 HEIC + 74 PNG 与本轮资源 SHA 相同（`device-install-asset-verification.json`）。

`devicectl device install app` 安装成功，随后无额外启动参数打开 `com.xinkuan.qiuji`，PID 9769；`device-install-result.json` 和 `device-launch-result.json` 均为 success。未卸载/清数据，未提交/商店发布。安装启动成功不等于用户真机视觉验收，等待实际效果反馈。

## 2026-10-13 用户授权仅保留最终结果

已删除旧图片版本、样张、备份及本任务构建/安装产物，共15,639文件；保留墨龙版796张母版、74张缩略图和生成/验证记录。704引用母版与74缩略图匹配当前资源，4,440保留文件哈希前后不变。目录逻辑删除18.57GiB，清理窗口可用空间净增6.82GiB（其他任务并行，APFS存在共享）。上述历史备份/对照/Bundle路径已不再可用，原报告作为历史证据保留；当前review.html及thumbnail-review.html已改为最终结果预览，视觉验收状态不变。[审计](../output/tutorial-final-cleanup-20261013/verification.json)。
