# FORMAL-B4-REAL-MONGO-001 独立结果复核

2026-09-06。读取本轮inputs/command/node-test.log/exit/shutdown记录，复核实际脚本及临时backend源文件哈希、mongod二进制哈希和现存关闭日志；未重新执行脚本、未连接或启动数据库、未修改问题台账/覆盖表。

**结果：5项实际执行，2通过、3失败、0跳过，Node退出1。** wrapper自身完成/返回0只表示它成功记录结果，不能覆盖exit.json明确的node_exit=1，也不能把“复现成功”当产品断言通过。

## 被测对象与隔离可信度

- inputs记录snapshot-002/backend，18个src文件；本次独立逐文件比较临时副本与冻结源，全部一致。脚本SHA-256与inputs的39ad600f…3fa12一致。执行命令为Node --test --test-concurrency=1。
- runtime为官方macOS ARM64 MongoDB8.0.29；runtime manifest有官方来源、归档hash、版本和binary hash。本次重新计算binary hash与记录fb5a3c15…9b421一致。上游下载校验由主控完成；本次未重新下载SHA文件，不把本地hash一致说成又做了一次官方签名校验。
- 实际脚本对子进程env不再设置HOME，仅PATH/TMPDIR；这是主控唯一运行前调整，不改变路由、模型、数据库目标或业务断言。无dotenv/server入口，无model替身。
- identity日志：自有PID80502，127.0.0.1:37291，固定数据库qd_isolated_run001，全新/private/tmp/qd-mongo-real-fiIKkm/db。脚本在模型导入前通过getCmdLineOpts/serverStatus核对目录/端口/绑定/PID，确认空collections；这些guard未失败才输出identity并进入五项。不是连接默认27017或已有业务库。
- 真实模型init之后才执行；每个500/501样本真实insertMany，并从Mongo读回逐条验证clientId/date/updatedAt后才发HTTP。四项都到达结果摘要，说明时间戳fixture验证通过，不能把后续截断归咎于未控制时间戳。

## 五项实际结果

| 项目 | 实际持久化/HTTP结果 | 断言 |
|---|---|---|
| QD007归属不可由A修改为B | PUT200；findById读回owner=B；A GET200/0条，B GET200/1条 | 失败 |
| training 500 | 首批500，after批0，合并500，无缺失/额外ID | 通过 |
| training 501 | 首批500，after批0，合并500，缺training-501-0 | 失败 |
| angle 500 | 首批500，after批0，合并500，无缺失/额外ID | 通过 |
| angle 501 | 首批500，after批0，合并500，缺angle-501-0 | 失败 |

QD007前置无token401、A初始1/B初始0均先断言通过，随后才执行PUT，表明不是未鉴权通路或初始夹具串户。此次是A将**自己的记录**归属改给B导致持久串户；不外推为A能任意读取/接管B既有记录。

两端点500组锚点为2026-01-01T00:08:19.000Z，501组为00:08:20.000Z。后者按date降序先取最新500，再以该批最大updatedAt请求严格大于锚点的数据，漏掉最旧那条。真实Mongo排序/过滤/持久化重复出现原路由层问题，不是仅JS数组替身结果。这里只跑日期与updatedAt同向递增的500/501，不声称本轮验证1000、同时间戳、乱序或App恢复链全路径。

## 台账可追加文字（供主控采纳）

**QD-007证据增强**：FORMAL-B4-REAL-MONGO-001在原样冻结Express路由、真实Mongoose模型和MongoDB8.0.29独立实例复现：A授权PUT修改userId后HTTP200，真实findById归属B，A列表0/B列表1；“归属仍A”断言失败，Node退出1。仍不是Apple真实身份、线上部署或客户端UI漏洞利用证据。

**QD-008证据增强**：同轮两个真实端点各500对照通过、501各缺最旧1条；种子ID/date/updatedAt先经真实数据库读回校验，after请求返回0。缺失分别training-501-0和angle-501-0，完整恢复断言失败。支持真实数据库查询层存在分页/锚点缺口；不替代iOS SyncRestoreService端到端、外部服务版本或其他时间分布覆盖。

## 退出与保留现场

shutdown-evidence.json记录mongod shutdown complete；独立读取该实例原mongod.log亦找到同消息，包含storage engine shutdown完成。脚本after断开HTTP/Mongoose并SIGTERM仅自有子进程，无dropDatabase或删除操作；临时db/log保留。这是本次实例正常关闭证据，不是实时全机进程扫描，也不需要为复核再启动服务。

原始证据位于build/quality-diagnosis/formal-b4-real-mongo-001：inputs.json、command.json、node-test.log、exit.json、shutdown-evidence.json；运行时来源见build/quality-diagnosis/mongo-runtime-manifest.json。既有QD007/008问题无需新建重复问题，但其可信度已从替身路由层扩展至本机真实数据库持久化层。未修复，SC25/26及B4整体仍不能由本轮5项宣布完成。
