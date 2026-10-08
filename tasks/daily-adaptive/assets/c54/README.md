# C54 持杆图标真源

用户选定造型的矢量整理版：standing=站立持竖杆，aiming=俯身持横杆。
`glyphs.json` 100单位路径生成这两枚SVG和 `BTShotInstrumentColumn.swift` 的 `BTPlayerViewGlyph` Canvas。28pt槽，5.5/100描边，圆端圆连接；不带截图的棋盘底或选择框。

Figma C54与原生共用轮廓。更新时修改JSON，运行 `python3 tasks/daily-adaptive/assets/c54/generate.py`，再用生成的Swift片段替换现有Canvas并复核；行为/状态以[C54](../../C54.md)为准。

C55（2026-10-08）：路径与28pt画布保持原样；图标视图在44pt按钮内 standing +2pt / aiming −2pt 光学平移。Figma 对应 glyph.x=10/6，不能同时平移 SVG 路径，否则会重复补偿。生成器的 Swift 片段已同步平移；SVG 保留源坐标。
