# 自定义球形同步服务

2026-10-19 已部署生产并完成接口验收，见 [部署记录](../tasks/CUSTOM-FORMATION-DEPLOY-20261019.md)。客户端只有在当前设备、当前账号开启云同步后访问这些接口。

## 存储与部署前提

新增 `CustomFormation`（当前版本）与 `FormationChange`（不可变变更及成功操作回执）集合。唯一索引分别为 `(userId, clientId)`、`(userId, sequence)`、`(userId, operationId)`；部署时先创建并确认索引。账号 `formationSequence` 单调递增，事务同时写入账号序号、模板和回执。重复/冲突请求产生序号空洞是允许的。

**MongoDB 必须支持多文档事务：副本集或支持事务的分片集群。** 生产原为 MongoDB 7.0.31 standalone；已冷备份并转换为单节点 `qiuji-rs`，保持鉴权及本机监听。应用连接 URI 增加 `replicaSet=qiuji-rs`，事务提交、回滚及真实同步接口均验证通过。单节点不提供多机高可用。其他环境仍须独立核对拓扑、事务和唯一索引，不能因生产已配置就假设本地默认 URI 也支持事务。

失败时不确认写入，客户端保留本机模板和待上传操作。先部署兼容旧客户端的后端，再发布新客户端。回退时保留新集合、索引、删除记录和客户端 v2 文件；不能把 v1 备份覆盖到新版内容。

## 接口

均沿用现有 JWT 中的 `sub` 作为 owner，忽略客户端自报 owner。

- `GET /custom-formations?after=0[&through=N]`：每页最多100条。首批返回固定 `through`，后续沿用；响应 `{records,next,through,hasMore}`。下一轮从上一轮 `next` 开始。包含删除标记，不按手机时间分页。
- `PUT /custom-formations/:UUID`：`{operationId,baseRevision,schemaVersion:1,template}`。响应 `{conflict:false,record}`；过期版本返回200和 `{conflict:true,record}` 供客户端保留副本。同一操作ID不同内容返回409；未知内容版本/无效数据422。
- `DELETE /custom-formations/:UUID`：同样带 operationId/baseRevision/schemaVersion，写持久删除标记。已删除ID不能通过PUT重新创建。
- Record：`clientId,revision,deleted,schemaVersion,template,modifiedAt`。成功操作重试返回原回执，而非当前最新版本。

模板含 `id/name/updatedAt/ballKeys/board/drawing?`。1–25目标球，另1母球；重复号码用独立实例键。坐标遵循现有归一化球桌契约；线保留顶点ID、共享端点及球排列。技术保护上限：名称120个Unicode标量、256KB JSON、256条辅助线及512端点。没有模板数量限制。客户端先行校验，失败明确告知。

账号注销先标记 `deletionPending`，该账号行与模板写事务竞争，之后清理模板/回执再删除用户；清理失败时保留账号供重试。删除标记与回执不设TTL。

## 可重复的本地验收

`test/support/formationTestServer.js` 使用显式 `FORMATION_TEST_RUNTIME` 中的 mongodb-memory-server，启动隔离副本集和实际生产Express路由，写入 `FORMATION_TEST_FIXTURE`（0600）；测试专用运行时不加入生产依赖。示例运行时安装：`npm install --prefix output/custom-formation-sync-20261019/runtime --no-package-lock mongodb-memory-server@10`。

`FORMATION_TEST_FIXTURE=... node backend/test/support/formationIntegration.js` 验证账号隔离、并发版本、回执、删除、稳定分页、注销并发、事务回滚。脚本自行创建/清理测试账号，只连接 fixture 指定的隔离 MongoDB。不可把 fixture 指向生产。

`test/support/runFormationSimulatorPhases.py` 通过项目模拟器生命周期管理器在两台明确借用的设备上执行5阶段 Swift 实际 REST 集成；执行前调整脚本内设备UDID与本轮输出目录。凭证不写代码或命令行。默认完整单测没有隔离 fixture 时明确跳过外部集成选择器；验收必须显式运行，不把跳过计为通过。

生产接口探针另用 `test/support/productionFormationSmoke.cjs`：仅在后端主机、明确授权生产验收后以 `PRODUCTION_FORMATION_SMOKE=authorized` 执行；固定当前生产地址，创建独立合成账号，只清理本次生成的账号ID。覆盖19组检查，直接注入回执失败只影响探针进程和其测试账号，不修改在线服务进程。不要把本地隔离 fixture 绕过地址限制指向生产。

生产双模拟器验收另用 `productionFormationSimulatorAccount.cjs` 管理一次性账号与0600凭证fixture，并用 `runProductionFormationSimulators.py` 串行执行明确设备上的专用生产selector。Swift测试同时要求显式授权、允许的生产地址及匹配的临时账号身份。7业务阶段与2清理阶段均已通过，见 [报告](../tasks/CUSTOM-FORMATION-PRODUCTION-SIMS-20261019.md)。脚本绑定本轮日期、设备与输出目录；重跑须使用新的证据目录和账号，不能覆盖旧xcresult或共用未知账号。
