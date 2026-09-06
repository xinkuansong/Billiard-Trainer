# MongoDB运行时来源与五项真实持久化草稿

2026-09-06；仅官方网页检索、冻结源码阅读、草稿及node --check语法检查。未下载二进制、未安装、未启动/连接数据库或HTTP服务、未读取.env/Secrets。node --check退出0不证明Mongo/Mongoose运行通过。

## 官方来源与校验

官方[Community releases页面](https://www.mongodb.com/try/download/community-edition/releases)当前列有8.0.29 macOS ARM64 tgz。可选用这一固定8.0补丁作为隔离诊断运行时，而非升级App服务；下载链接为[macOS ARM64 8.0.29](https://fastdl.mongodb.org/osx/mongodb-macos-arm64-8.0.29.tgz)。官方[8.0 macOS tarball说明](https://www.mongodb.com/docs/v8.0/tutorial/install-mongodb-on-os-x-tarball/)支持Apple Silicon；执行前核对当前macOS兼容要求。网页版本列表是本次查询结果，主控获取时若已变化须固定实际版本，不能静默替换。

按官方[包校验指南](https://www.mongodb.com/docs/manual/tutorial/verify-mongodb-packages/)，同一下载URL加`.sha256`取校验文件，计算本地SHA-256并比对；PGP签名能另验证发布来源，校验和本身主要验证完整性。候选校验文件：[8.0.29 tgz SHA-256](https://fastdl.mongodb.org/osx/mongodb-macos-arm64-8.0.29.tgz.sha256)。本轮没有下载或验证其响应与hash，不编造校验结果。

主控在专用临时目录获取、校验、检查归档不含越界路径后解包；记录下载URL/时间/归档sha256、`mongod --version`、可执行文件sha256。无需加入系统PATH、brew services、Docker或安装mongosh。Node客户端已具备，不需要默认27017、既有数据库、真实账号或网络服务。

## 草稿执行接口（审阅后才可运行）

新增`mongo-route-diagnostic.cjs`使用node:test，五项顶层测试默认串行，并在命令中再指定`--test-concurrency=1`。**相对旧准备文档的一处设计调整**：新草稿自行mkdtemp创建全新dbpath并持有mongod子进程，避免外部“目录此前为空”的声明无法由脚本复核；不得先另起mongod再传端口。依赖backend副本仍按LOCAL-MONGO-PREPARATION复制src/package/lock/node_modules，不复制.env或server.js。

执行环境参数（不是当前运行记录）：

- `QD_ALLOW_REAL_MONGO=NEW_OWNED_LOOPBACK_INSTANCE`
- `QD_BACKEND_ROOT`：以`/private/tmp/qd-mongo-`开头的独立backend副本绝对真实路径。
- `QD_MONGOD`：已核准二进制绝对路径。
- `QD_MONGOD_SHA256`：该可执行文件hash，不是tgz hash。
- `QD_MONGO_PORT`：主控选择37000…37999中一个可用端口，例如37291；默认27017不可能通过检查。

命令形态：`node --test --test-concurrency=1 tasks/quality-diagnosis/mongo-route-diagnostic.cjs`，主控设置以上环境并保留原始Node退出码/标准输出。脚本读取指定参数，不打印整个环境。输入的现有MONGODB_URI不会用于连接，脚本固定覆盖为本轮loopback URI；JWT两secret也被固定诊断值覆盖，不打印token。

安全边界：先校验所有src和package/lock与冻结hash相同、三依赖resolve真实路径在副本内，再核准mongod hash。只创建新的`/private/tmp/qd-mongo-real-*`及空db子目录，以`--bind_ip 127.0.0.1 --nounixsocket`启动自有子进程。等待其独立新日志ready，连接后先用getCmdLineOpts与serverStatus核对dbpath、端口、127.0.0.1与自有PID，再确认固定`qd_isolated_run001`无collections。**身份检查之前不import模型**，避免自动建索引先写错库。主控不得选择指向既有数据的运行时wrapper冒充mongod。

之后才加载原样真实模型/init唯一索引和两路由，Express仅监听127.0.0.1随机端口。冻结src只有auth中间件，没有独立错误中间件；草稿仅另加返回500布尔标志的最小错误包装，不替换业务模型/query。无dotenv/server入口，无model方法覆写。

## 五项断言与结果

1. QD007：A真实create；无token401、A可见/B不可见；A经HTTP PUT要求改userId为B；真实findById与双方GET读取持久结果。先输出put状态/owner别名/双方计数，再断言归属仍A且A1/B0。当前源码可能失败，失败必须保留。
2–5. training/angle各500和501；四个独立owner，不清库。insertMany timestamps:false后真实find排序逐条核对ID/date/updatedAt，异常先判fixture无效。HTTP首批500+最大updatedAt后的第二批合并，与真实库ID集合比较；输出摘要与缺失ID，缺失则assert失败。

QD007失败不会中止后四项，Node整体非零不可改成“成功复现=测试通过”。setup身份/来源护栏失败会导致所有业务子项不执行；此时只能写环境失败。所有断言摘要不含token、全库、URL凭据；原始断言也只涉及合成数据。

after关闭HTTP与Mongoose，再只向自有mongod句柄发SIGTERM。保存目录/日志，不dropDatabase、不删数据、不杀端口占用者。若退出超时，保留错误与PID交由主控处理；不要扩展为查找并终止所有mongod。强制中断Node可能影响after执行，主控须保留任务句柄和identity输出用于自身子进程核对。

这五项增强真实Mongoose/Mongo持久化层证据，不替代App客户端同步、Apple登录或外部部署验收。当前仅语法检查通过，运行时API兼容、mongod就绪日志、时间戳选项以及预期失败均待实际运行验证。
