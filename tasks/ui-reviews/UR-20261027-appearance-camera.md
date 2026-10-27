# 球桌及台呢预览相机 · 2026-10-27

U-01（P2）：旧机位按10×8m环境校验，当前8×6m房间内正交图像平面越墙，左下显示黑带和墙背。修正仅作用于AppearanceCombinationPreview全桌分支：推进机位、正交尺度1.35→1.10。

已打开并核对实际原图：
- [同场景旧机位](../../output/appearance-camera-20261027/before.png)与[修后机位](../../output/appearance-camera-20261027/after.png)：缺口消失，主体约放大23%，六袋、桌框、桌腿完整。
- [16ProMax整页](../../output/appearance-camera-20261027/phone-after.png)与[SE17整页](../../output/appearance-camera-20261027/compact-final/7E052AAB-7D68-4B3C-8317-9894BFAFE002.png)：预览框、选择列表及原生导航保持；小屏列表正常滚动。
- 三房修后原生图（compact-attachments中after-tournament/walnut/eastern附件）均无近侧墙缺口；两手机蓝台呢实际页及标准手机球房全景已核。

本轮目标视觉通过。功能为1项真实SCNView投影、16ProMax及SE17各1项跨页/切换/重启UI通过；失败测试宿主和旧swipe定位问题已修，保留原始结果。具体命令、日志与TP01–36适用性见[页面卡](../SETTINGS-APPEARANCE-20260913.md)本轮节。

仅浅色整页；真机、Dark整页、大字号、VoiceOver、iPad页面旋转未验，不外推全App验收。未提交/发布，待用户体验。
