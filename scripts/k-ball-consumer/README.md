# K 球参数题库

沿用两球走位的参数包方案：分片 gzip JSONL + 小索引、精确参数、按需读取、最多两个解压分片缓存。
不把研究逐帧轨迹、碰撞事件和容错探针装入 App。参考打法使用保存方向、速度和打点重算；用户改变输入后仍须运行物理引擎。

## 来源与复建

首版来源：`output/k-ball-one-per-route-20261029/selected.jsonl`，SHA-256
`9049a0aae78b593d9e28cb4fc9b334dc71193fb4382553e47c7be47936cb64f9`。
研究全量保留，只有参数包进 `QiuJi/Resources/KBallBank/`。

```sh
python3 scripts/k-ball-consumer/pack.py output/k-ball-one-per-route-20261029 output/k-ball-parameters-NEW
python3 scripts/k-ball-consumer/audit.py output/k-ball-one-per-route-20261029 output/k-ball-parameters-NEW --report output/k-ball-audit-NEW.json
```

只能写新目录。独立审计成功后才发布整个目录，禁止逐片覆盖一个正在使用的版本。
数值不取整；每条原始路线保留一题、稳定原题 ID，所有 11,458 题与 4,905 个球形保持。

## 格式

`index.json`：schema/policy、来源 SHA、几何、规则、数量/分布、分片字节数/SHA、球形行索引与 fingerprint。
每片最多 64 个球形，每行 `id + board + questions`；同球形共用母球/A/袋口及生成角。
题目保留 B、路线 ID、方向 `dir`、速度 `v`、打点 `sx/sy`、观察库 `rail`、时机 `timing`、容错档 `grade`、轨迹角、库段 ID、球心库距、实际碰 B 前库序。

- 坐标：SceneKit X/Z 米，Y 向上；序列方向原值进入引擎，不二次归一化。
- `board.angle` 是 5–50° 生成参数，不是实时碰撞切角。
- `trajectoryAngle` 相对库切线，≤45°；B **球心**到有限库段≤0.10m。
- `rail` 是观察库，入库前/出库后都归该库。`railsBeforeK` 才是实际碰 B 前库序，不替换分类。
- `grade` 1/2/3 = 敏感/常规/宽容；是原模拟扰动分级，不是实台成功率。
- 成功：母球首先碰 A，A 进指定袋，母球随后碰 B。不要求 A 先落袋再碰 B；母球落袋和 B 的碰后效果不作失败条件。

## 验证

```sh
python3 scripts/k-ball-consumer/verify.py
python3 scripts/k-ball-consumer/selftest.py
```

`audit.py` 独立逐字段比对原库，重核归档成功事件、有限库距、身份和分类；不冒称新一轮物理仿真。
`verify.py` 是不依赖本地研究目录的进包门禁，已接 `make -f scripts/Makefile verify-gate`，核资源和 project.yml / pbxproj 两端。
`reader_check.swift` 与生产 `KBallBankStore.swift` 一起编译，验证实际 Swift 解码器的全库遍历、筛选、缓存及拒绝异常数据。
原生 `KBallBankTests` 另验证包内全量读取、判题边界及1/2/3库各入库前/出库后的六类参考物理重建；2026-10-29定向3项通过，证据见 `output/k-ball-app-foundation-r1-20261029/`。
这些验证不代表全库重新物理复算、K球练习页面或真机验收完成。
