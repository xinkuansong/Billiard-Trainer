# 颗星几何研究包

研究结论见 [REPORT.md](REPORT.md)，全部比较指标见 [RESULTS.md](RESULTS.md)。

## 打开实验页

用浏览器打开同目录的 [index.html](index.html)。它包含全部脚本和参数，不需要联网、不需要安装依赖。

也可以在仓库根目录启动本地服务：

```sh
python3 -m http.server 8768 --bind 127.0.0.1 --directory research/diamond-aiming-20261020
```

然后访问 `http://127.0.0.1:8768/index.html`。用完Ctrl+C关闭。浏览器预览期间的服务不是后台监控或自动化任务。

## 手画直线

点「画直线」，在球桌或库边拖动绘制，可连续画多条；拖动线端可调整。点「拖球」恢复移动球，线条保留。支持撤销上一条、清空线条、Esc取消正在画的一笔。手画线为粉色，并随当前球型JSON一起导出；当前版本刷新页面会清除手画线。

## 复现统计

在本研究目录运行；需要Python 3、NumPy，重新导出生产参数还需要macOS Swift。本轮NumPy版本记录在`results/environment.json`。

```sh
python3 export_geometry.py
python3 test_model.py
python3 simulate.py
python3 supplement.py
node test_js.cjs
python3 write_results.py
python3 build_page.py
```

若当前Python没有NumPy，可以用`uv run --with numpy python simulate.py`等方式运行。画图用：

```sh
uv run --with numpy --with matplotlib python plot_results.py
```

NumPy/Matplotlib仅用于此独立研究，不是App依赖。没有更改iOS工程、SPM或产品物理参数。

导出器直接截取并执行Swift几何构造代码，以小型Float向量载体保持iOS数值语义，避免macOS的`SCNVector3`使用CGFloat导致差异。读取颗星既有测量证据前，会校验其候选SHA与当前USDZ一致；不一致则失败，要求重新测量。

## 结果结构

- `geometry.json`：实际桌面、球径、袋口入口、库鼻、颗星与源文件SHA。
- `results/metrics.csv`：主实验1,914行统计；厚度误差是0…1绝对比例。
- `results/summary.json`：总表与指定子集，实验页用。
- `results/manifest.json`：随机种子、抽样说明、过滤数、样本字节SHA、独立碰撞验证残差、45°简化式和球径实验。
- `results/supplement.json`：45°输入扰动、轨迹端点取整和真实颗星偏离库鼻的专项。
- `results/fixtures.json`：120个跨语言对拍球型。
- `results/errors.png/svg`、`results/loci.png/svg`：Matplotlib导出图。
- `results/browser-*.jpg`：实际浏览器交互与布局检查证据。
- `test-python.log`、`test-js.log`、`simulation.log`、`supplement.log`：实际运行输出。
- `QA.md`：验证记录与未验证范围。

主样本不存为大文件，可由种子与参数快照重建；manifest保存样本数组字节SHA。统计分位数用NumPy默认线性插值。环境或浮点实现不同可能影响字节SHA，几何容差测试仍应通过。

源文件：`page.html`为模板，`geometry.js`为浏览器几何，`app.js`为交互；修改后运行`build_page.py`再刷新页面。生成的`index.html`是可交付离线文件，不要只修改生成物。

**研究边界**：数学上可直切≠动态进袋；坐标噪声实验≠真人精度；看得到辅助线≠无辅助线能判断；模板准确≠任意O/P下能几秒重建模板。
