# 五类纯防守离线题库

用户授权每类500，共2500。最终产物从`output/defense-bank-2500-20261103/review/`读取。五类、角色与硬条件见protocol.json及`tasks/DEFENSE-BANK-2500-20261103.md`。

原样题只作搜索种子；扰动母球/我方球布局和杆法后重新执行完整3/4球模拟。类内四镜像6cm母球/我方球去重；只移动对方球/额外8号不单独计新基础题。跨类允许角色/战术差异，audit.json单列近似基础球形对数。

## 版本与复核

- `main-r1.swift`/`run-r1.py`保留首轮；r1生产代码与资源清单冻结在输出根目录，首轮数据不改写。
- `main.swift`/`run.py`专用于FL-247的11题补齐：连续角域>5%，读取`retained.json`去重，7长库＋4短库；冻结源码由`DEFENSE_FROZEN_FROM`指定，不读取工作区Swift增量。不要把此补题入口当通用500题生成器。
- `assemble.py`合并2489保留题＋11补题，拷入两轮原始来源和hash；`audit.py`独立全量核验。
- 首轮复现时应使用归档main和归档生产源；旧run-r1.py默认读取当时工作区源码，不能在漂移后的工作区直接执行并声称复现。

```sh
python3 research/defense-bank-2500-20261103/assemble.py
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-bank-2500-20261103/review" output/defense-bank-2500-20261103/audit-env/bin/python research/defense-bank-2500-20261103/audit.py
DEFENSE_PILOT_OUTPUT="$PWD/output/defense-bank-2500-20261103/review" python3 research/defense-bank-2500-20261103/deliver.py
node research/defense-bank-2500-20261103/check_gallery.mjs output/defense-bank-2500-20261103/review
```

运行物理CLI须先查模拟器租约，使用local-test-lifecycle和simulator-fleet受管入口。完成后回收临时构建。输出每题保留参考及对照完整轨迹，小/大扰动保留参数、真实事件、终态及几何证明。精确回放在同冻结二进制内比较完整参考记录。

独立审计依赖锁定NumPy，见requirements-audit.txt。图册是科学绘图，离线DOM检查不等同浏览器或App实测。题库为离线候选，不修改正式题库/动作库/App，不自动恢复延期工具。完整遮挡100是防守结果分；难度和实台成功率尚未校准。
