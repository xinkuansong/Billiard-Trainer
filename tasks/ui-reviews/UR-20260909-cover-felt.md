# 计划与练习封面台呢替换

2026-09-09。用户确认 `aiming-principle-ball-markings-v3.png` 后授权批量优化并替换App。

## 最终范围

- 正式替换38张已有绿色球桌封面（9张计划、29张练习）；草绿色、细密平整台呢，并修正明显多余的白球红点/相邻重复数字标记。
- 10张灰白静物保留原文件及其原有图案。模版、Tab氛围底图、训练场景及布局代码未改。
- 沿用资源名，计划列表/详情和练习页自动引用；不新增运行时调色或资源加载逻辑。
- 原图、候选、被拒绝版本、提示词和逐文件安装哈希保留在 `output/cover-felt-20260909/`。38组左右对比：`comparison.html`；最终清单：`delivery-manifest.json`。

## 生成与视觉检查

使用内置image_gen逐张编辑。首批灰底误变绿的输出已弃用，灰白原图全部保留。38张图以7页总览逐张检查；发现的多余第四红点及重复号码采用定向编辑修订，再次目视对应输出。仅作卡片摄影图案视觉验收，不作为隐藏球面或精确三维角度的数学证明。

## 验证

- 38张生产PNG替换、10张原图保留；48/48哈希核验一致，替换前所有原图与备份相符，无覆盖同时修改的资源。
- PNG格式/尺寸/4:3比例预检通过；最终新图合计61.6 MiB。
- `make -f scripts/Makefile build SIM_DEVICE=QiuJi-Onboarding-Pro`：exit 0，`BUILD SUCCEEDED`。证据：`output/cover-felt-20260909/build.log`。
- 已保留数据安装并启动标准iPhone / iOS26.2模拟器，实际核对训练首页卡片、点击准度计划进入详情及返回；练习全部/练分类切换正常。
- 已目视练习浅色/深色完整首屏、练分类完整卡片及计划详情：图片正常载入，草绿台呢生效，原灰白图保留，卡片裁切与编号/Pro角标/标题层次沿用原布局。
- 实际截图：`after-plan-list-light.png`、`after-plan-detail-light.png`、`after-practice-light.png`、`after-practice-dark.png`、`after-practice-tools-light.png`。外观恢复Light，字号确认large。
- `verify-doc-size`通过；本次为静态资源替换，未新增自动化测试。

## 验证边界

标准手机局部UI及全部38张源图已检查；未运行完整页面巡游、小屏/iPad/真机/完整VoiceOver验收。未提交、未发布。
