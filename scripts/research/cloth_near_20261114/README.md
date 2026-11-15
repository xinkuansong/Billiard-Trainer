# 近球影区高光/遮挡实验

入口：[H6计划](../../../tasks/render-highlight-20261114/H6-PLAN.md)、[H7计划](../../../tasks/render-highlight-20261114/H7-PLAN.md)、[H9交付](../../../tasks/render-highlight-20261114/H9-DELIVERY.md)。H6/H7的11个候选未过门槛；H9常量球位+逐灯mask组合通过，已默认接入共享C1入口。

```bash
python3 scripts/local_test_lifecycle.py run --task cloth-near-example -- \
  python3 scripts/research/cloth_near_20261114/run.py \
  --work '{work}' --evidence '{evidence}' --round lamp-mask
```

- `initial`：成对中点/两端线性/严格零可见度跳过。
- `row`：固定中心/可见光加权方向，每列4样本汇总。
- `group2`：相邻2列可见光汇总。
- `lamp-mask`：保留已有逐灯逐球保守掩码。
- `relative`：接收点相对向量就地复用，单项与逐灯组合。
- `squared`：再复用距离平方，透明度读原constant uniform，单项与组合。
- `capture --width 1400`：仅捕获基线、逐灯、距离平方版的GPU程序，不计性能。原生gputrace含内部符号链接，原件写work，验证归档写evidence，避免违反生命周期证据规则。
- `constant-array`：H8诊断后的H9候选；256-byte球位改用等布局constant数组直接读取，去掉逐片元局部数组。先运行真实GPU旧/新布局哨兵探针，再做零差及配对性能初筛。
- `constant-lamp`：H9 R2，在直接常量读取上保留逐灯球mask；两尺寸通过近景收益和其他机位不退化门槛。
- `quality --width 1400`：74组颜色、法线/粗糙度、球位边界零差检查，不追加排名。
- `h9-capture --width 1400`：捕获当前生产转换器输出与C1；不作为配对性能测试。
- `integration.py --work ... --evidence ...`：执行抽取的当前共享刷新函数与真实SCNMaterial，验证Debug/非DEBUG、启动参数、16/32容量及实际shader与已测版本逐字一致。

使用冻结真实USDZ/灯/场景夹具与当前C1，三镜头每组6个球态uniform，HDR/4xMSAA。没有完整App、物理击球或实际球模型。源码、实际生成shader、设备、几何前置、AA/AB图像及每帧真实GPU时间戳/CPU编码/同步墙钟保存到证据。

汇总既有结果，不重复渲染：

```bash
python3 scripts/research/cloth_near_20261114/summarize.py
```

旧H6/H7汇总校验六轮留存证据哈希及当时生产源/冻结资产身份；生产H9已改变源文件，不应为了让旧汇总重跑而修改历史身份。H9单轮用`summarize_round.py --run RUN --output JSON`从留存证据汇总。每轮具体生成源码保留，不把当前研究脚本hash套回旧实验。
