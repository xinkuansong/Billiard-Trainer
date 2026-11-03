# 翻袋目标球切换 · 原生图复核 · 2026-11-03

角色：UI Reviewer。iPhone16Pro／iOS26.2横屏，r3冻结999d0f7f7e57f95514accb58420bdeb9eb741ad520352bcf3e43f01bf8f78724；[专项卡](../table-page-adaptation/BANK-TARGET-SELECTION-20261103.md)。

判据：球桌统一规范TP06/14/16/17/18/35及P07现行页面合同、当前Colors/Typography/Spacing；没有改布局、字号、透明HUD或按钮样式。六张xcresult原图均直接打开检查，索引与SHA在output/bank-target-selection-20261103/screenshots/reviewed-index.json。

| 原图状态 | 实际观察 | 结论 |
| --- | --- | --- |
| before-selection | 8号球库蓝圈、1号已上桌变暗；白球／黄1／黑8均在桌 | 同一新版初态，不冒称修复前二进制截图 |
| 2D-table-1 | 蓝圈移到1号，8号变暗；黑8原位保留，首碰文案变1号，瞄准与黄色路线相符 | 桌面点选后角色正确 |
| 2D-palette-1 | 由8切回1后，同样只有1号蓝圈，球位保持 | 球库切换角色正确 |
| 3D-table-1 | 透视观察视角，1号蓝圈、黑8留桌，文案与实际黄球一致 | 真实3D桌面选球状态正确 |
| 3D-palette-1 | 透视画面中球库切回1号，控件及球位保持 | 3D球库切换状态正确 |
| auto-solved-or-no-solution | 回求解仍选1号；当前摆位显示“该袋暂无翻袋解”，击球与打点禁用，旧路线已清 | 正确无解终态；此图不证明UI有解路线质量 |

六图未见本轮新增的角色错位、重复蓝圈、布局截断或遮挡操作。目标下没有新增桌面角色圈。实际命中与状态切换由XCUITest断言证明，截图只证明可见状态；触感／VoiceOver／动态字体未评定。27项测试零失败零跳过（26逻辑／实际回放＋1显式2D/3D UI）。本轮没有iPad、真机、全App或发布验收。
