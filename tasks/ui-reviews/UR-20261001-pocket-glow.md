# UI审查 — 目标袋口黄色显示0.6秒（DR-345 r2）

日期：2026-10-01。角色：SwiftUI Developer / Test Engineer / UI Reviewer。

## 最终语义

用户明确“展示我们之前的黄色”，显示0.6秒后恢复当前主题皮革原色。保持目标选择，不留细线、淡纹或常驻色。2D/3D共用原皮革网格，教学①/②绿/青角色不变。

## 实施

PocketLeatherMarker预制黄色皮革子节点；选中时opacity=1，单次SCNAction等0.6秒后opacity=0。当前主题原材质作为基底，动画结束保留target，切换/取消立即撤销旧动作；同目标重复同步不重启。选中期间不修改原材质、纹理、几何或袋口命中区域。现有帧调度会检查节点动作；结束后无持续动作。

## 自动验证

- `build/pocket-glow-20261001/yellow-core-r2.log`：18 tests，0 failures，TEST SUCCEEDED。包含14项袋口集成、3项渲染/材质/计时、1项所有球桌主题切换测试。
- 计时检查同时覆盖plain/mobile两种材质和2D/3D：真实SCNRenderer像素差显示0.12s和0.59s为黄色，0.61s回到未选中原色；opacity=0且无残留动作，同时style保持target。再选和清除也验证动作取消。
- 首轮`yellow-core.log`有2个失败：3D默认球员镜头裁掉了被测近角袋，导致黄色/基线像素差为0。已把专项渲染测试镜头设成包含六袋的透视，保留真实3D光照/网格，重新运行全部18项通过；无为迎合测试而改生产镜头。
- 页面操作检查：`build/pocket-glow-20261001/ui-r2.log`，1 test，0 failures，TEST SUCCEEDED。试打“进袋”模式在2D→3D→2D中保持5号目标袋，等待恢复后选择仍有效。首轮Daily页面测试误将状态背景当作Button查询而失败（`ui.log`）；现专项用稳定试打路径测试真实双视图，不改Daily页面。

## 视觉证据与审查

- 修改前原页面：`output/red-flag-20261001/before-2d.png`（黄色常驻）。
- 最终原生渲染：`output/pocket-glow-20261001/{plain,mobile}-{2d,3d}-{before,peak,restored}.png`。
- 已实际打开mobile 2D黄色帧、2D恢复帧、3D黄色帧及3D恢复帧：黄色贴合完整原皮革，袋洞未覆盖，3D随模型透视；恢复后没有轮廓、旗帜或残留色，与基线像素一致。
- Token：继续用原btAccent targetTint；布局/触摸区域/文字/Dynamic Type不改；无新阴影、图标或常驻动画。无新增P0/P1视觉问题。
- 页面截图`output/pocket-leather/W4/standard/yellow-pulse-{restored-2d,restored-3d,returned-2d}.png`；已实际打开2D/3D画面，目标5号中袋皮革恢复原色，原有轨迹继续指向该袋；没有常驻选袋装饰。无新视觉问题。
- 文档体积门禁通过（97KB、当前状态9条）。19项自动检查与视觉审查完成；结论不等于用户真机视觉接受。未提交或推送。
