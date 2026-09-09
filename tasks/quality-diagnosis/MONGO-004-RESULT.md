# 当前后端真实 Mongo 取证结果

2026-09-07 11:57，FORMAL-004-REAL-MONGO-001。**真实执行五项：2 通过、3 失败、0 跳过/取消；Node 退出 1。** 原样当前后端再次复现 QD007 归属改写和 QD008 两端点 501 条恢复截断，未修复业务。wrapper 退出0只表示完成记录/归档，不是产品测试通过。

## 当前输入与隔离

- 当前 HEAD `eaa7021b67f895766bde2df27a6b2cea26d92a97`；独立 backend004 冻结18个src文件及package/lock，共20文件。复制前后 hash/copy mismatch 均0，测试后当前源与冻结源仍无变化。没有修改 client snapshot-004。
- 副本依赖位于 `/private/tmp/qd-mongo-backend-2srnaav1/backend/node_modules`，Express4.22.1/Mongoose8.23.0/jsonwebtoken9.0.3；lock与当前冻结相同，三依赖resolve实路径全部在新副本内。未复制.env、正式server入口或已有数据。
- MongoDB8.0.29 ARM64，binary SHA256 `fb5a3c157a369839ab585df5591c36f637d64fc4e2289c6fa250aefe9c69b421`；已重核保留的归档hash/来源manifest，无新下载。
- 只启动本轮新子进程 PID13151，127.0.0.1:37294，库 `qd_isolated_run001`，全新 dbpath `/private/tmp/qd-mongo-real-UBzYq9/db`。连接后、导入模型前核对 getCmdLineOpts/serverStatus 的路径/端口/绑定/PID及空collections；所有护栏通过才进入业务测试。
- 诊断脚本副本只改 `const frozen` 路径，原始断言与模型方法不变；真实模型 init 建索引，HTTP 使用原样路由，合成A/B token不涉及真实账号。无dotenv、真实服务连接、模型替身或清库。

## 五项结果

| 项目 | 实测 | 产品断言 |
|---|---|---|
| QD007 禁止改写归属 | A对自己的记录PUT userId=B返回200，真实数据库owner=B，A GET0条/B GET1条；无token401及修改前A1/B0先通过 | 失败 |
| QD008 training500 | 首批500、after0、集合500，无缺失或额外ID | 通过 |
| QD008 training501 | 首批500、after0、集合500，缺最旧`training-501-0` | 失败 |
| QD008 angle500 | 首批500、after0、集合500，无缺失或额外ID | 通过 |
| QD008 angle501 | 首批500、after0、集合500，缺最旧`angle-501-0` | 失败 |

四个数量样本先经真实insertMany及逐条ID/date/updatedAt读回验证，才能解释后续分页结果；不是未控制时间戳的假夹具。Node报告整体约2016.686ms；这不是App性能指标。

QD007只证明A把**自己的记录**改属B，未证明接管B已有记录。QD008服务端原数据仍存在，只是当前首批+after协议未完整返回。两项继续开放；不因“成功复现”改为通过。

## 自有实例终态

after关闭HTTP、disconnect Mongoose并仅向自有mongod发SIGTERM。日志在11:57:29.934记录`mongod shutdown complete`；随后核对PID13151已不存在，db目录仍保留。没有dropDatabase、删除数据、结束其他数据库或碰模拟器。终态和日志均已归档。

## 持久证据位置

为避免将结果仅置于可清理build，本轮保留两份：

- [归档运行材料](../../archive/quality-diagnosis/runs/formal-004-real-mongo-001/)：inputs、command、process、真实exit、node-test.log、空stderr、observations、shutdown-evidence、mongod.log、脚本及唯一改动diff、runtime来源/hash材料、wrapper。归档14文件与本轮build副本逐字节一致。
- [当前后端冻结源](../../archive/quality-diagnosis/backend004/)：18src、package/lock及baseline.json，记录当前来源与每文件hash。
- 可重建运行副本：`build/quality-diagnosis/formal-004-real-mongo-001` 与 `build/quality-diagnosis/backend004`。
- 原数据库保持 `/private/tmp/qd-mongo-real-UBzYq9/db`，不纳入Git。归档日志足以查看本次关闭过程；不为复核重新启动旧库。

若日后build再次不可用，归档脚本内frozen绝对路径要在**新运行副本**按新选定基线适配，不能把归档原始记录悄悄修改。此次是新后端证据，不是重新找回旧snapshot002原始结果。

边界：未运行iOS恢复客户端、Apple登录、真实部署/跨设备链；本批只有500/501且date和updatedAt同向，未测试1000、乱序和相同时间戳边界。未改主报告、ISSUES、COVERAGE或README，由主控独立核验后收录。
