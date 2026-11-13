# 台呢低维表示研究原型

这是独立数值 / Metal compute 实验，不会进入 App Bundle 或改变默认 R。

结论与下一步：[首轮报告](../../../tasks/render-lowdim-20261113/REPORT.md)。

## 文件分工

- `prepare_reference.py`：执行从生产提取的 Swift shader 生成器，输出可追溯 MSL 光照 core。
- `evaluate.swift`：本机 Metal 数值入口；可选方向矩消费者和冻结消费 ABBA 实验。
- `texture_samples.py`：从默认 USDZ 获取同 texel 法线 / 粗糙度；保留原绑定和坐标假设。
- `study.py`：NumPy 独立参考、方向矩候选、保护条件、数值对拍、场景矩阵。
- `run_gpu_candidate.py`：候选消费与 CPU 对拍、回退逐位一致检查、混合 / 适用点分列。
- `plot_study.py`：数学截面图和半球反例；不是 App 截图。

## 依赖和运行

需要 Xcode（Swift / SceneKit / Metal）、可用 Metal device、`usdcat`、NumPy 与 Pillow。
本次使用已有 `tools/shot_reconstruction/.venv/bin/python`，未安装新依赖。

在仓库根目录运行；替换下方输出目录名称以保留已有证据。研究脚本不应覆盖旧实验。

```bash
TASK_PY=tools/shot_reconstruction/.venv/bin/python
TASK_OUT=output/render-lowdim-20261113/new-run
python3 scripts/research/cloth_lowdim_20261113/prepare_reference.py --out "$TASK_OUT/native"
xcrun swiftc -O scripts/research/cloth_lowdim_20261113/evaluate.swift -o "$TASK_OUT/native/evaluate"
"$TASK_PY" scripts/research/cloth_lowdim_20261113/texture_samples.py --out "$TASK_OUT/textures"
"$TASK_PY" scripts/research/cloth_lowdim_20261113/study.py --native "$TASK_OUT/native" --texture-samples "$TASK_OUT/textures/paired.npy" --out "$TASK_OUT/study"
"$TASK_PY" scripts/research/cloth_lowdim_20261113/run_gpu_candidate.py --native "$TASK_OUT/native" --study "$TASK_OUT/study" --out "$TASK_OUT/gpu-mixed"
"$TASK_PY" scripts/research/cloth_lowdim_20261113/run_gpu_candidate.py --native "$TASK_OUT/native" --study "$TASK_OUT/study" --out "$TASK_OUT/gpu-eligible" --eligible-only
"$TASK_PY" scripts/research/cloth_lowdim_20261113/plot_study.py --out "$TASK_OUT/diagnostics"
```

`study.py` 输出目录必须不存在；`texture_samples.py` 拒绝覆盖已有 stats。`prepare_reference.py` 可在开发中重新生成，请正式留证时给独立目录。源码提取锚点变化时抛错，不能手动跳过该保护继续用旧参考。

## 数值协议

全部小端 Float32：

- samples：N×12，position.xyzw / worldNormal.xyzw / viewDirection.xyz+roughness。
- balls：16×4，worldX / worldZ / packed heightAboveCloth / encodedWeight；隐藏填0。
- reference：N×16，unoccludedE.xyz+nearFlag / sampledE.xyz+mask / analyticCorrectedE.xyz+0 / S.xyz+0。
- moments：N×(2+G)×4，MV.xyz+enabledFlag / M0.xyz+0 / G个Mgroup.xyz+0。G=2K，组矩已含 radiance/π，不含RGB灯色。
- candidate 输出布局相同，但 enabled 分支的 flag/mask 为1/0诊断占位，不代表实际 mask。

世界单位米，X–Z水平、Y上。CPU 公式有独立实现，必须通过生产生成 Metal 对拍；它不是另一套未经核对就自称权威的参考。

## 验证口径

- `study.py`：CPU / Metal 的 E0、sampledE、S 绝对误差上界 2e-4，仅为独立实现浮点校验；本轮实测远小于该值。
- `K=32`：CPU候选高光必须复现原样本积分至1e-10数值误差；不是性能档位。
- `run_gpu_candidate.py`：候选 GPU 与 CPU 消费对拍；disabled 回退逐位一致。
- `plot_study.py`：必须实际出现无保护方向矩错误且 guard 能拒绝的反例。
- 未设置“候选画质合格”的数值阈值；最终视觉、空间插值和运动需另外验收。
- 全样本 / 仅候选使用点 / 近档无实际遮挡 / 按粗糙度的指标分别保存。
- `receiver_count` 是点数；RGB `value_count` / `bright_count` 是通道值数量。

GPU 使用 fastMath=false，持有预计算 FP32 buffer，读回仅用于离线校验。ABBA 的 command span 不是屏幕FPS；不含空间场生成、纹理采样、同步、HDR、MSAA、完整材质或UI。`--eligible-only` 是隔离机制对照，不能用其收益冒充完整混合页面收益。
