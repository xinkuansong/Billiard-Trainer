# UR-20260913 球贴纸 V2

结论：功能与双面映射通过，照片级视觉未完成。DR-200 / FL-060。

六套号码确由文生图生成，Blender 制版与纯 EMIT 烘焙 90 张 albedo，打包为可编辑库。两处号码相隔 180°，修复原模型背面折叠 UV 与 SceneKit V 原点差异；测试确认原顶点、法线、面不变。参考灯光编号球粗糙度改为 0.12 候选，母球不变。

证据目录：`output/ball-stickers-20260913-v2/`。照片目标、Blender 实渲、无光照双面验证与 App 截图分开标注。六套选择、重启持久化、明暗界面、自由击球 2D/3D/击球/回放/重置共 2 项 UI 测试通过（SE3 / iOS17）；6 项单测通过，包含 90 球双面截图及几何保真。最终日志 unit-final-r2.log / ui-final.log；设备 Debug 构建成功。

实图审查：双面数字可读、无紫红 shader 错误；编号球抛光反射改善。Blender 实景仍可辨识为 CGI，App 近景仍有轮廓分段、数字边缘与色调/环境反射差距；不能宣称照片级完成。照片参照是 imagegen 结果，不是最终 App 截图。

失败保留：初次原 UV 背面撕裂；初次 SceneKit V 上下颠倒；并发 shader panelMask 累加语法导致整球错误色，最终修复且测试新增错误色拒绝。旧日志/截图不覆盖真实失败记录。

下一步验收目标：在实际 App 同机位完成轮廓、号码边缘和环境反射与照片参照的进一步匹配；当前候选不标视觉完成。真机画质、持续帧率/温升、iPad 和 VoiceOver 未验收。未提交或推送。

最终门禁：verify-gate、verify-doc-size、git diff --check 均通过。96 张 PNG 与设备包逐文件 SHA256 一致，UV frame JSON 在包内。iPhone 16 Pro 已安装并启动本轮 Debug；画质未作真机验收。
