# 解球题库固定对称变换

用户授权：原题每题固定四选一，不扩大题数；颜色按吃库顺序。原53,928题已经完成整库物理验证，本轮不重新搜索、生成目标球、添加扰动或整库物理重放。

输入固定为 `output/kick-bank-full-20261031/kick-practice-bank.json`，SHA256 `ab45e0387ca1669599d76cb0ea629d57fe2aee9d95c262dc6667271c7b360d66`；不能把变换后的App资源当作下一轮原始输入。

- `build.py`：按库数和原始格分组，用固定种子SHA排序，在四个变换间平衡分配。世界XZ米制，左右翻X、上下翻Z、中心对称翻两轴；坐标和方向同步，单轴镜像翻转spinX，spinY/杆速不变。墙及6库段映射由生产导出的端点和法线匹配，检查双射及自逆。全量验证不出界、不重叠、方向长度、原题精确还原、ID和总数、各库数各象限72格；先冻结463个分层样本，之后才重放。
- `integrate.py`：更新App资源、SHA指纹和现有测试文件里的有界样本。保留ID/格式v1/历史payload；不改判题、筛选规则或参考参数的物理含义。可重复执行，拒绝覆盖未知题库指纹。
- `validate.py`：由本地测试目录和模拟器双生命周期入口执行。明确排除旧`testAllBundledReferencesReplayUnderCurrentProductionPhysics`，选17项逻辑及2项UI；463样本走真正`KickQuestionPreparer.solve`、`KickShot`，检查实际六段顺序、完整结果和不落袋。碰后不再碰库仍允许作为题库参考，不据此删题。核包内SHA、实际方法数、源码稳定性并导出原图；退出前关闭本任务模拟器，成功后自动回收work，保留结果。
- `render.py`：从463样本中取36题（每库数9题、每种变换9题），生产原轨迹作相同对称变换用于图示。每行3题，按库数/变换筛选；只给经过的库段按先后顺序着色。生成图不是App截图，也不冒称36条新采集逐帧轨迹。

```sh
python3 research/kick-bank-symmetry-20261101/build.py
python3 research/kick-bank-symmetry-20261101/integrate.py
python3 scripts/local_test_lifecycle.py run --task kick-bank-symmetry-20261101 -- python3 scripts/simulator_fleet.py run --role notch-phone --task kick-bank-symmetry-20261101 -- python3 research/kick-bank-symmetry-20261101/validate.py '{udid}'
python3 research/kick-bank-symmetry-20261101/render.py
```

原图/样本/映射/检查回执：`output/kick-bank-symmetry-20261101/`。当前结论见 `tasks/KICK-BANK-SYMMETRY-20261101.md`。再次生成须用同一输入和种子，不能根据物理测试结果重抽样或换种子掩盖失败。
