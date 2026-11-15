# 台呢剩余高光研究

方案与结论：`tasks/问题集合_3D活动期性能优化_v2.md`、`tasks/render-highlight-20261114/DELIVERY.md`。当前所有候选均未推广；`ablation`有意破坏画面，仅诊断。

本机原生macOS/SceneKit/Metal夹具，依赖冻结的`output/render-lowdim-20261113/native-scene-guardcombo-package-r2/`（真实USDZ、环境、灯和原生夹具）。源身份与证据均保存在各run，不是完整App/手机基准。

```bash
python3 scripts/local_test_lifecycle.py run --task cloth-highlight-example -- \
  python3 scripts/research/cloth_highlight_20261114/run.py \
  --work '{work}' --evidence '{evidence}' --round field \
  --field-format f16 --field-resolution 32
```

`pipeline`、`direct`、`direct_marker`是材质管线诊断；`field`为几何场；`split`为固定far循环；`reduced`为短轴减半；`ablation --width 1400`为分项删除。不得把`ablation`接到生产。

只重算既有证据，不运行渲染：

```bash
python3 scripts/research/cloth_highlight_20261114/summarize.py
```

汇总先验证每run已回收且退出0、全部留存文件哈希、各轮源身份一致及当前源身份；每组两臂各24帧求均值，再取六组相对变化中位数。所有组保留，不剔除离群点。新的候选必须另立run，不覆盖既有证据。
