# 自定义球形同步生产部署 · 2026-10-19

用户明确授权检查生产 MongoDB 事务能力、部署后端并验证同步。已完成生产部署与真实接口验收；未发布新版 App。

## 数据库

生产 `106.54.3.210` 的 MongoDB 为 **7.0.31 standalone**，原本不支持多文档事务。先在独立端口启动鉴权副本集，验证密钥认证、初始化、事务提交及回滚；随后转换现有实例为 **单节点副本集 `qiuji-rs`**，成员 `localhost:27017`、oplog 256MB。版本、数据目录、原账号权限不变；保持 `127.0.0.1:27017` 监听及 `authorization: enabled`，新增 `/etc/mongodb-keyfile`（mongodb:mongodb，0400）。初始化由仅主机可读的集群密钥认证完成，未关闭鉴权、未扩大应用账号权限。

转换窗口为北京时间 **01:42:15–01:42:42，约27秒**，期间停止 API、正常关闭 MongoDB、制作冷备份、启动副本集及 API。应用 `.env` 仅给原 MongoDB URI 添加 `replicaSet=qiuji-rs`，0600 权限；其他环境值及账号密钥校验一致。单节点提供事务能力，不提供多节点容灾。

转换前后及清理验收数据后，users / drills / trainingsessions / angletests 的 BSON 内容哈希均一致。最后持续巡检时，原有账号在01:46:18出现后续写入，仅更新 `refreshToken/updatedAt` 并补入新版模型默认的两个同步字段；与现有鉴权保存路径一致。该账号其他字段及三个业务集合保持备份内容，未为追求哈希一致回滚正常业务写入。未认证读取返回 Unauthorized。应用账号在生产库实际完成多文档提交、主动异常回滚；测试集合已删除。

## 发布范围与备份

线上旧服务使用单文件 `server.js`，没有本地 `src/app.js`。本次将路由最小挂载到线上入口，未用本地后端整目录覆盖。

- 新增：`src/models/CustomFormation.js`、`src/services/customFormation.js`、`src/routes/customFormation.js`。
- 更新：`src/models/User.js`（两个同步字段）、`src/services/accountDeletion.js`（注销时清理同步数据）、`server.js`（导入并挂载 `/custom-formations`）。
- 六个文件与本轮 staging 逐字节一致；其余既有源码、package.json 保持原值。未发布法律页面、未修改登录/资料路由实现。
- 已创建并核对 `(userId,clientId)`、`(userId,sequence)`、`(userId,operationId)` 唯一索引。没有给历史用户批量补字段；首次同步时由原子写入建立序号。

服务器备份目录 `/root/formation-deploy-20261019/`（0700）保留：`app-before.tar.gz`、`mongodb-cold-before.tar.gz`（约202MiB）、`mongod-before.conf`、源码/数据哈希与部署脚本。备份只留服务器受限目录，未下载真实用户数据。冷备份已解压到独立目录，在鉴权 MongoDB 27028 实际启动并验证四个集合内容哈希一致；验证实例已关闭。

常规代码回退优先仅恢复备份中的旧 `server.js` 并重启 `qiuji-api`，使新增接口停止提供；**保留新增模型、账号字段、注销清理代码、集合、索引及副本集配置**，避免旧版注销遗漏模板。不要整包回退掉注销清理，也不要将切换前冷备份直接覆盖运行后的数据库。数据库恢复应先停止写入、备份当前状态、评估切换后的新增数据，再进入独立故障恢复流程。部署脚本中的自动恢复只用于尚未验收开放的切换阶段，不能作为事后恢复脚本重跑。

## 验证

| 验证层 | 结果 |
| --- | --- |
| 本地后端单元测试 | 37通过、0失败、0跳过 |
| 生产真实服务/数据库 | 19组检查全部通过，使用合成账号 |
| Mac → 生产公网接口 | 创建、空游标恢复、修改、增量下载、删除均通过 |
| 数据与安全边界 | 原四集合哈希不变、其他源码/环境配置不变、数据库鉴权和本机监听保留 |
| 服务状态 | `qiuji-api` online，内网/公网 `/health` 正常，MongoDB开机自启 |
| 清理 | 本轮5个合成账号、全部模板及变更回执、临时凭证均已删除 |

19组覆盖：健康检查；三种接口鉴权；现有令牌刷新；25颗重复目标球+1母球与连接线；第二客户端完整恢复（实例ID、共享端点、球顺序一致）；账号隔离；26颗拒绝；并发编辑一成功一冲突；冲突内容另存新ID；丢失应答的原回执重放；同操作ID不同内容409；删除增量及禁止复活；100条稳定分页及分页期间新增；非法游标400；真实同步事务中回执失败整体回滚；注销与并发写入无孤儿；资料部分修改保持旧字段；训练/角度/Drill旧接口；注销后数据清空及旧令牌写入拒绝。

测试用 JWT 由生产密钥在服务器内存签发给本轮合成账号；密钥没有输出或下载。账号与数据只按本轮创建返回的ID清理。注入失败只替换探针 Node 进程的方法，不改变 PM2 服务。探针源码：`backend/test/support/productionFormationSmoke.cjs`。

证据目录：`output/custom-formation-deploy-20261019/`，主要为 `deploy.log`、`smoke.log`、`external-smoke.log`、`restore-and-cleanup.log`、`security-scope-check.log`、`final-server-check.log`、`deployed.sha256`、`backups.sha256`、`backend-tests.log`。部署载荷和脚本同目录保存；不包含凭证或数据库备份。

## 使用与验收边界

服务端已准备好。需使用已实现本功能的新版客户端，旧手机登录账号并开启云同步、上传成功后，新手机用同一账号开启云同步即可请求恢复。旧版App不会因后端发布自动获得模板同步功能；游客模板仍须明确同意合并。

本轮是生产REST客户端验收，未用真实Apple/微信身份登录、未在两台真机执行完整换机流程。上一轮双模拟器五阶段连接的是隔离后端，不能改称本轮生产设备验收。未发布TestFlight/App Store、未提交或push Git。真机完整流程与用户体验保留为客户端发布前验收。

后续按用户追加要求，已在两台模拟器直连生产完成7个业务阶段，覆盖同一账号空库恢复、双向修改、删除与删除后空库重放；另2个本地清理阶段通过。独立记录见 [生产双模拟器验收](CUSTOM-FORMATION-PRODUCTION-SIMS-20261019.md)。真实登录UI、设置交互和真机边界仍保留。

参考：[MongoDB官方独立实例转换流程](https://www.mongodb.com/docs/manual/tutorial/convert-standalone-to-replica-set/)；[官方源码的集群密钥认证说明](https://github.com/mongodb/mongo/blob/master/src/mongo/db/auth/README.md#keyfile-intracluster-auth)。
