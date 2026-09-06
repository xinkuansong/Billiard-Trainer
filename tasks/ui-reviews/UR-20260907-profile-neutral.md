# 我的普通菜单配色审查

2026-09-07；iPhone17Pro / iOS26.2，游客态，标准字号。

- 证据：output/profile-neutral/before-light.png、before-dark.png、after-light.png、after-dark.png，均已打开目视。
- 四个原品牌绿菜单转中性灰，与偏好设置一致；头像、Pro星形、订阅皇冠保留原配色。
- 浅深色文字/图标/箭头均可见，未见本次新增错位或截断；行尺寸、导航及业务逻辑未改。
- 构建：make -f scripts/Makefile build；真实 BUILD SUCCEEDED，日志 /tmp/qiuji-profile-neutral-build.log。xcpretty缺失后原脚本fallback成功。
- 本次变更视觉问题0项；未执行自动化功能测试、真机、VoiceOver或完整设备矩阵。
- 相对本轮备份，生产代码仅ProfileMenuRow默认tint一行；既有并行变更保留，未提交。
