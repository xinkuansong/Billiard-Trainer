# 本机隔离 MongoDB 集成准备

2026-09-06；仅只读发现与装配设计，未连接任何数据库、未读取.env、未安装软件、未启动服务或容器。当前平台arm64。基线为snapshot-002，本文不改变QD007/008已成立的路由层证据，也未取得真实Mongo持久化复验结果。

## 本机已核实条件

| 检查 | 结果 |
|---|---|
| `command -v mongod` / `command -v docker` | 两者均无输出，即当前PATH不可用 |
| `/Applications/Docker.app` | 不存在；没有执行docker daemon探测 |
| `/opt/homebrew/Cellar`下名称含mongo/docker/podman/colima的条目 | 无；`/usr/local/Cellar`不存在 |
| Node/npm | `/opt/homebrew/bin/node`、`/opt/homebrew/bin/npm`可定位；未安装依赖 |
| backend package/lock | 当前两文件SHA256均与冻结副本一致；声明mongoose `^8.9.5`，锁定且已安装mongoose **8.23.0**、MongoDB Node driver **6.20.0** |
| mongodb-memory-server / core | backend/node_modules均无对应package.json，冻结backend无node_modules |
| 常见二进制缓存 | `~/.cache/mongodb-binaries`、`~/Library/Caches/mongodb-binaries`、`backend/node_modules/.cache/mongodb-memory-server`均不存在；两个用户cache根无mongo命名直接子目录 |
| npm本地索引 | 只解析`~/.npm/_cacache/index-v5/*/*/*`，匹配mongodb-memory-server的记录数0；未打印缓存URL/认证内容 |

结论：**现有客户端依赖可复用，但本轮未找到可立即启动的MongoDB服务器运行时。** 这不是“必须用户提供外部数据库”。主控可另行安排本机临时运行时获取/安装与权限；该动作未在本只读子任务执行。缓存检查有界，不声称全磁盘不存在任何私藏二进制，也不检查现有数据库内容。

## 推荐最小装配：独立真实mongod，不复用已有库

若主控取得并核准一个arm64可执行mongod，先记录其绝对路径、版本、哈希与来源。不要把Node driver当服务器，不要假定安装memory-server包便自带离线二进制。无需安装/使用Docker作为额外前提；也不应尝试连接默认27017看看是否有现成库。

以下是**运行时具备后**的准确启动形态，不是本轮已执行命令。`QD_MONGOD`由主控填已核准路径；端口37291仅为该轮候选，若占用则换一个并记录，禁止终止占用者。

```sh
QD_RUN=$(mktemp -d /private/tmp/qd-mongo-real-XXXXXX)
mkdir "$QD_RUN/db"
"$QD_MONGOD" --dbpath "$QD_RUN/db" --bind_ip 127.0.0.1 --port 37291 --nounixsocket --logpath "$QD_RUN/mongod.log"
```

主控在独立受管进程启动并保留句柄，不用`--fork`交给不明守护进程、不用任何已有mongod配置文件。测试固定连接 `mongodb://127.0.0.1:37291/qd_isolated_run001?directConnection=true`，serverSelectionTimeoutMS=3000。启动前确认db目录新建为空；连接前必须核对该新子进程已就绪且没有因端口冲突退出。进一步用本连接`adminCommand({getCmdLineOpts:1})`检查parsed.storage.dbPath与本轮绝对dbpath、parsed.net.bindIp/port对应，任何不符立即断开并拒绝写入。端口空闲查询本身不能代替这个身份检查。

只终止自己启动的子进程；测试结束先mongoose.disconnect、关闭本轮HTTP server，再对已持有句柄的mongod正常SIGTERM。保留dbpath和日志供取证，不调用dropDatabase，不清理其他安装，也不把合成数据搬入已有库。

## 冻结代码与依赖装配

在新`$QD_RUN/backend`复制snapshot-002/backend的`src`、package.json、package-lock.json，并复制当前已核对锁一致的node_modules；不复制server.js、public、.env或任何秘密配置。按正式B4-ROUTES做复制后哈希/解析路径校验：所有src文件与冻结一致，express/mongoose/jsonwebtoken的require.resolve实路径必须落本轮node_modules。不要直接require正常server.js，因为它会加载环境并连接其配置数据库。

独立新`mongo-route-diagnostic.cjs`应使用`createRequire`定位本临时backend；只设置本进程固定诊断JWT_SECRET/JWT_REFRESH_SECRET，使用冻结`src/utils/jwt`签合成ownerA/B token，不打印token。Express仅挂冻结`src/routes/trainingSession`、`src/routes/angleTest`及错误处理中间件，在127.0.0.1端口0监听。

**不能直接运行现有formal-route-diagnostic.cjs获得真实数据库证据**：该文件显式禁用mongoose.connect/createConnection，并覆写model.find/findOneAndUpdate。新装配必须保留真实mongoose模型方法，不使用这些替身；引入冻结模型后分别`await Model.init()`，让唯一索引实际建立。连接固定上述URI，不接受MONGODB_URI/.env或任意外部连接字符串。命令形态为：

```sh
QD_BACKEND_ROOT="$QD_RUN/backend" QD_EXPECTED_DBPATH="$QD_RUN/db" QD_MONGO_PORT=37291 node --test --test-concurrency=1 "$QD_RUN/mongo-route-diagnostic.cjs"
```

新脚本尚未写出/编译运行，主控需按下面断言装配后审阅其diff与网络/写入边界，不能把本命令当现成可执行文件。所有写入仅限已经验明身份的新实例和固定qd数据库。来源文件应保持原样，诊断只包装路由与模型，不修路由。

## 最小真实持久化复验：QD007 + QD008

### QD007：一次越权归属修改与持久读回

1. 真实TrainingSession.create创建合成A的一条记录，字段至少clientId、userId(A ObjectId)、date；A/B用固定不同合法24位ObjectId字符串，无需真实User、Apple或密码。
2. A的token经真实HTTP GET可见，B的GET不可见；无token401作为对照。
3. A正常授权HTTP PUT `/<mongo_id>`，body只传`{userId:B}`。预期拒绝该改动或归属仍A，不把200单独当失败，检查实际内容。
4. 用真实`TrainingSession.findById(...).lean()`和A/B再次GET验证持久归属；如果当前实现把归属改B，则记录响应状态、脱敏A/B可见性、数据库归属，报告预期断言失败。不要把“成功复现漏洞”记成产品断言通过。

冻结依据：trainingSession.js的PUT将req.body直接传findOneAndUpdate，过滤仅旧owner；真实schema userId为可写ObjectId。新测试需要真实_id，不能沿用假模型`/0`。

### QD008：两个端点各500对照与501失败样本

最小四组：training-sessions与angle-tests各500、501 aligned。每组用新的合成owner，避免清库；clientId按0…n−1唯一，date/updatedAt随i严格递增。TrainingSession需要clientId/userId/date；AngleTest另有必填actualAngle/userAngle/pocketType（可用45/40/`corner`）并带quizType=`table2D`。

必须控制**真实存下的**updatedAt：用合法schema文档的insertMany并显式`timestamps:false`保留指定createdAt/updatedAt，插入后立刻读回核对数量、所有clientId以及日期序列。若Mongoose当前版本仍改写时间，则该fixture无效，先解决诊断写入方式；不能在未核对时间的样本上解释分页结论。禁止使用假的model.find或只在JS数组中排序。

每组真实GET首批，检查状态200和ID集合；取返回最大updatedAt作为after再GET，合并ID并与真实数据库的预期集合比较。500组预期全覆盖；501 aligned当前源码按date降序limit500，因此最大updatedAt锚点之后应无剩余，可能缺最旧1条。缺失断言必须失败，并输出仅count/first/after/missingClientIds摘要，不打印全库/token。

这四组足以把已知边界落到Mongo真实索引/查询/持久存储，优先于重复穷举。若时间允许再添501同updatedAt和1000组，用相同时间读回约束；不需要一开始重跑全部17个假模型用例。各子测试独立，QD007预期失败不应中止QD008取证，最终Node退出码仍保留非零。

## 结果能说明什么

成功执行后可增强为“冻结真实路由＋真实Mongoose/MongoDB查询持久化”的证据；仍不是App SyncRestoreService实际调用、Apple登录、真实部署版本或跨设备端到端。合成owner认证只检验JWT路由边界，不冒充真实身份授权。当前运行时缺口可由本机后续补足，先保留为**本机准备受运行时前提阻碍**，不推给用户提供生产DB，也不宣布B4全部完成。
