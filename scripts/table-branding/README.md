# CuePhys 球桌字标

用户于 2026-11-16 认可 H 布局并要求同步 App 的五种球桌风格。

- 从桌外看，每条长边左段 `CuePhys: 台球训练`，右段 `www.cuephys.com`；两短边为品牌文字。
- 六袋口向外的皮革弧面为 `CuePhys`。中英文统一 ASCII 冒号和一个普通空格。
- `layout.json` 保存 H 的投影、尺寸及源模型校验值；`artwork/` 是批准字形的透明遮罩。
- 源模型坐标为米、Z 向上。输出顶点属于 `Plane_001` 局部坐标；运行时的缩放和轴转换由既有加载器负责。

## 生成

在仓库根目录运行（Blender 4.5.6 LTS 已验证）：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/table-branding/build_decals.py
```

可在 `--` 后加 `--output /absolute/output/path` 单独复算。脚本校验正式默认 USDZ 的 SHA256，从原三角面裁出贴合表面的字标区域，向外偏移 0.15 mm 防止共面闪烁，不修改源模型。12 个区域共 200 个三角形；运行时合并为一个装饰条节点和六个可点选袋口节点。遮罩为 1024×512 RGBA，分行留边，启用 mipmap。JSON 和 PNG 共 187,577 字节。

2026-11-16 独立从正式 USDZ 与本目录源码重建，两个输出 SHA256 均与 App 资产逐字节一致：

- `TableBrandingMask.png`: `c5cb3e7b888429f728766c59d2b04c1d96708d265804b517ed73163ec7e9d017`
- `TableBrandingMesh.json`: `8c6035a091fc4405d784f8fc3a15e7de278d57bfe80504ba52103c748b9b0338`

## App 接入与验证

`TableAppearance` 在原材质槽捕获后安装 `TableBranding`；换肤只切换字色。经典原木与象牙白蜡木的深色皮革使用浅色袋口文字，其余使用深色。装饰条文字统一深色。移动端使用球桌同源漫反射照明，去掉会冲淡细字的镜面反光。

字标袋口索引参与既有点选识别；原袋口高亮材质与物理几何保持。`AngleTrainingScene` 在普通 2D 隐藏字标，并从临时俯视副场景排除字标节点。设置页沿用真实共用场景预览。

`QiuJiTests/TableBrandingTests` 验证五桌款、六袋口坐标对应、重复换肤、高亮清除及两种俯视路径，并产生原生 SceneKit 渲染附件。实际设置页/训练页另用 `TableStyleUITests` 验证。验收结果及限制见 `tasks/TABLE-BRANDING-20261116.md`；自动渲染不等于真机性能或用户视觉验收。
