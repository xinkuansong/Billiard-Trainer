# 多球上一步 · 2026-11-02

本轮仅核第三球回退状态，沿MULTI-BALL-BACK页面卡TP06/14/25/26/35；字体、布局、HUD不作调整。

Mac mini Xcode26.2，SE3/iOS26.2。r4 snapshot cd5ab3e7fc23ab01033e6de7fc3936019137c62f0c6c3b3441cd729b119c4f78；两项UI均通过、0失败/跳过。r3同生产源码31逻辑通过。r4两种视图均通过实际菜单切换/temporaryTopDown存在性核验，不以测试名称推断覆盖。

8张核心原图逐张打开：选好第三球、退回第二袋、重选袋仍未选、重新选第三球。①②和袋角色保留，③及台面第三圈在回退时消失，重新选袋不恢复；出杆提示选第三球，手动点选后恢复。2D/3D提示内容与角色一致；未见本轮造成的控件位移或截断。

最终原图目录：`output/multi-ball-back-20261102/screens-r4/`，附件名与UUID映射见manifest.json。

- 2D回退：46C646B8-6490-4010-B8CE-2F769130672F.png
- 2D重选袋：E98F3A79-546C-4979-B160-C36BDC9F1105.png
- 2D重选第三：4F429372-84C3-4252-9A6C-8AC46F2C1D44.png
- 3D回退：9EE8D45C-5520-4BCB-80CA-20732A379C1B.png
- 3D重选袋：397ABB2B-AC59-41A2-80C7-802E6D37761B.png
- 3D重选第三：D8DBCE8F-B1FF-40E1-998D-53A1E0F7B320.png

原件passed-r4/evidence/tests.xcresult保持只读语义，另用clone导出；回传清单已校验。r2为启动故障失败证据，r3第二个用例实际2D，均未冒充最终3D验收。真机、iPad、VoiceOver、完整App及用户认可未验；未安装真机或发布。
