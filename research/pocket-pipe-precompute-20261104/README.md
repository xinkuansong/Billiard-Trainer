# 目标球到袋口管道角预计算

本表仅依赖目标球位置、袋口及固定球桌几何，与母球位置无关。真实球半径管道从目标球至捕获入口不能碰主库或袋角；不包含其它球、速度、旋转、碰袋角反弹及评分。未接入App。

产物位于 `output/pocket-pipe-precompute-20261104/`：

- `pipe-grid.bin`、`pipe-grid.json`：查表数据和完整格式、几何源码SHA；压缩副本为`pipe-grid.bin.gz`。
- `audit.json`：最终验证；`abc-pipe-windows.json`：A/B/C目标球的六袋窗口。
- `six-pocket-windows.png`/`.svg`：六袋最大连续角宽热图。
- 原始格点、独立验证点、初轮未收敛记录及加密复算全部保留，便于审计。

## 数据与查询

SceneKit XZ坐标，单位米；横桌+X向右、+Z向下。台内2.54×1.27m，球半径0.028575m。球心域为内框按球半径内缩的矩形，排除已在捕获区的点；不覆盖矩形外唇沿。网格256×129，最大间距1cm，四边额外加入距贴库球心边界1/2/5mm的采样线。

六袋顺序及中心见元数据`pockets`。角区间单位为度，以`atan2(pocket.z-target.z,pocket.x-target.x)`为零方向，保存有符号左右偏移；角宽为右减左。若出现多个窗口应保留全部，展示用最大连续窗口宽，不能跨断口求总跨度。

二进制前198,144×8字节是记录：小端`uint32 intervalOffset, uint16 intervalCount, uint16 flags`。记录下标为`((ix * nz) + iz) * 6 + pocketIndex`。随后是每项8字节的小端`float32 leftDegrees, float32 rightDegrees`，offset以区间项为单位。flags：1有效位置，2双分辨率收敛，4搜索两端闭合，8存在孤立切线。零区间表示当前分辨率下没有正宽度干净窗口，不等于所有物理打法均无法进球。

参考消费者`lookup.py`校验二进制SHA。四邻点均为有效、收敛、闭合的单一正窗口，且端点跨度≤0.1°、相对宽度跨度≤10%时，双线性插值左右边界。其它情况返回`requiresExactGeometry`，调用者必须精算；脚本本身不执行Swift精算。几何或算法版本变化应重新计算。

```bash
python3 research/pocket-pipe-precompute-20261104/lookup.py output/pocket-pipe-precompute-20261104 0.2 0.1 0
```

## 验证与限制

33,024球位×6袋，二进制2,839,680字节，gzip 1,323,906字节。3,603独立位置中21,618袋口查询有11,509次允许插值，10,109次要求精算；接受样本最大边界误差0.000907075°、最大角宽误差0.000813472°，无拓扑误报。全表打包/镜像检查通过，最终未收敛和开放端点均为0。这是有限扫描和抽样验证，不能证明所有任意窄窗口均已发现，也不是连续域误差上界。

初轮全网格217.01秒、含验证240.12秒，不含编译及四点细化；合计441,456次几何调用。旧v3母球出杆角及其0.008°评分尺度不适用于本表。

## 复现

`run.py`使用已冻结的463文件编译依赖；真实几何文件逐一与当前源码SHA对照，并将当前完整AngleSceneCalculator加入快照。按项目模拟器生命周期规则运行受管CLI，不安装App。首次计算执行：

```bash
python3 scripts/local_test_lifecycle.py run --task pocket-pipe-precompute-20261104 -- python3 research/pocket-pipe-precompute-20261104/run.py
```

四个初轮未收敛记录存于`unresolved-r1.json`。使用`PIPE_MAIN`指向`refine.swift`、`PIPE_OUTPUT`指向`refinement/`、`PIPE_REFINE_INPUT`指向该文件，通过同一受管入口运行。`merge_refinement.py`仅在原始四个未收敛记录存在时运行一次；它保留原始副本，并验证两档细化结果后合并。最终依次执行`package.py`、`audit.py`、`render.py`。绘图需要numpy和matplotlib；查询、打包和审计只使用Python标准库。
