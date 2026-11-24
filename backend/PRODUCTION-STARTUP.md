# CuePhys 生产启动条件

`server.js` 在连接 MongoDB 和监听端口前运行生产预检，直接 `node server.js`、`npm start`、systemd 启动均生效。未指定 NODE_ENV 时按 production 处理。开发和隔离测试须显式指定 development/test。

部署前在服务器受控环境运行 `npm run preflight:production`。报告仅包含字段检查结果，不输出密钥。必须具备当前 CuePhys Bundle ID、独立 JWT 密钥、MongoDB URI、Apple Team/Key/P-256 私钥及加密密钥、已批准微信 AppID/Secret；缺项会退出，不能依赖 `/health` 判断授权业务已经就绪。外部条件未满足时不替换正在运行的服务；没有绕过开关。

MongoDB 库名、头像目录、注销台账与加密密钥沿用实际配置，不跟随品牌重新生成。本轮没有部署生产后端。真实授权、微信审核与沙盒支付进度以 [整改执行记录](../tasks/launch-20261110/cuephys-rename/EXECUTION.md) 和人工台账为准。
