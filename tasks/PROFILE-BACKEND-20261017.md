# 个人资料后端发布 · 2026-10-17

用户要求核对新增个人资料并更新后端，随后要求主打球种显示名称改为“中八”“追分”。

## 字段核对与发布

现有昵称、头像、主打球种、当前水平、球龄、每周训练目标已在线上支持；本次缺口为可选性别 `gender` 与生日 `birthDate`。生日存 `YYYY-MM-DD`，年龄在客户端计算，不增加年龄字段。未传字段保持原值，显式 null 清除；游客资料仍仅保存在本机。首次资料引导复用已有字段，没有新增后端字段。

已发布至 `106.54.3.210:/opt/qiuji-backend`：仅更新 `src/models/User.js` 与 `src/services/userProfile.js`，重启 `qiuji-api`。线上 user/auth 路由与本地一致，沿用现有统一序列化函数。两份新文件 SHA256 与工作区一致。其他服务源码、server.js、package.json 和 .env 的部署前后校验一致。

旧文件备份：`/root/profile-backend-20261017/before.tar.gz`。回退时在后端目录解压该备份并重启 `qiuji-api`；本次无需数据迁移，未修改真实账号数据。没有整目录发布其他未上线功能。

## 验证

- 本地 `npm test`：19 项全部通过。
- 线上临时合成账号真实 HTTP/MongoDB 验证：无登录 GET/PUT 返回401、旧账号缺省字段返回null、全部资料保存与数据库/GET读回一致、部分修改保留其他字段、7类无效输入返回400且未改数据、null清除落库并保留其他字段。临时账号已删除并确认不存在。
- 服务内网与外部 `/health` 返回 `{"status":"ok"}`；发布后进程已运行。
- 证据：`output/profile-backend-20261017/`，含 `local-tests.log`、`remote-before.txt`、`backup.log`、`deploy.log`、`postdeploy-check.log` 和本次 `smoke.cjs`。

## 主打球种文案

`PreferredSport.displayName` 改为“中八 / 追分 / 两者”，个人资料选择项、资料摘要和首次资料引导共用。接口与本地存储仍为 `chinese8 / nineBall / both`，不迁移用户选择、不修改九球训练规则或动作库分类。既有个人资料UI用例同步更新期望文案。

提取实际枚举源码用 Swift 编译执行，输出 `chinese8=中八 / nineBall=追分 / both=两者`，日志为 `sport-label-check.log`；这只验证名称和存储映射，不代替完整App构建或UI验证。文档体积门禁初次超限，按规则将两条10-14旧进度移入归档后通过；定向 diff 检查通过。

## 验收边界

后端已部署并通过上述验证；本轮未执行真实 Apple 登录或 App 真机联调。球种名称是客户端源码修改，未安装/发布新版 App，未重新运行UI截图验证。隐私页面模板已有新增字段说明，但线上旧服务尚无该页面/路由，本次未发布法律页面或改其发布配置。未提交或推送 Git。
