# QD007/008 当前后端真实 Mongo 新取证准备

2026-09-07。仅只读核对来源/代码/依赖及 `mongod --version`、`node --check`，没有启动或连接数据库、下载、读取 .env 内容、访问真实服务或修改业务/旧诊断脚本。

**结论：运行时和依赖已具备，无需下载；当前脚本不能原样直接执行。** 它硬编码的 snapshot-002 已不存在，而且 snapshot-004 不包含 backend。主控只需独立冻结当前后端、复制诊断脚本并更新这一条冻结路径，保留全部身份护栏与五项断言，再按下述步骤执行。没有发现需业务改动或真实账号前提。

## 实际存在的运行时与来源

- mongod：`/private/tmp/qd-mongo-runtime-4upbmyti/extracted/mongodb-macos-aarch64--8.0.29/bin/mongod`
- 本次重新计算 binary SHA256：`fb5a3c157a369839ab585df5591c36f637d64fc4e2289c6fa250aefe9c69b421`
- 实际 `--version` 返回 v8.0.29，arm64，gitVersion `559d67c651f7393e62757234a0b25cb7a8622148`。
- 归档仍在 `/private/tmp/qd-mongo-runtime-4upbmyti/runtime.tgz`，本次 SHA256：`d2ed296a7a0a653dd5d2d7867a2589a7ad3f64b95fa3f05722f5414afaa28b4c`。
- 同目录 `runtime.sha256` 内容匹配该归档 hash；`runtime-manifest.json` 的 binary/archive hash、版本和固定来源 URL 也与本次核对一致。记录来源为官方 `https://fastdl.mongodb.org/osx/mongodb-macos-arm64-8.0.29.tgz`，取得时间2026-09-06。本次只重核已有材料的一致性，没有重新联网验证官方发布签名。

## 当前源码与历史保留副本

旧临时副本 `/private/tmp/qd-mongo-backend-1trq4mzy/backend` 仍在。当前仓库 backend/src 的 **18 个 JS 文件逐字节全部相同**，package.json 与 package-lock.json 也相同。这个副本是历史结果中记录的执行材料线索；原 build 输入 manifest 已缺失，故不能将今日比对说成重新验证了历史 snapshot-002 的完整指纹链。下一次以新冻结当前源为准。

直接阅读确认：训练 PUT 仍用 owner 限定查询后将 req.body 原样传给 findOneAndUpdate；TrainingSession.userId 仍可写；两 GET 仍 date 倒序/limit(500)/updatedAt 严格大于 after。未看到 QD007/008 根因修复。这里只判定源码与可复验性，不预报新运行结果。

旧副本 node_modules 可用于全量复制；本次 require.resolve 实路径在副本 node_modules 内：express 4.22.1、mongoose 8.23.0、jsonwebtoken 9.0.3。三者只做解析和 package 版本读取，没有加载业务或连接服务。复制后仍需再次解析/比对，不能以当前这次检查替代运行前护栏。

## 唯一必要诊断适配

`tasks/quality-diagnosis/mongo-route-diagnostic.cjs` 当前 `node --check` 返回0；顶部 `const frozen` 指向已不存在的 snapshot-002/backend。

主控应复制为新运行目录内的 `mongo-route-diagnostic.cjs`，**仅将 const frozen 更新为新独立后端冻结绝对路径**。不要修改当前业务 src、模型方法、断言或复制旧库。保留原脚本与适配后 diff/hash；不把新后端偷偷补进已完成指纹的 snapshot-004。建议独立后端基线目录名：`build/quality-diagnosis/backend-baseline-004`，并记录与 App snapshot-004 的关联。

原脚本已经自行创建新 `/private/tmp/qd-mongo-real-*` 和空 db，持有 mongod 子进程。**不能先手动启动数据库**，也不要把旧 `qd-mongo-real-fiIKkm/db` 传给它。固定 qd_isolated_run001 库名在全新实例中安全；不是连接默认27017。脚本覆盖本进程诊断JWT及Mongo URI，导入 config 前已赋值；当前 config 仅读取环境，没有 dotenv 加载。

## 主控可直接采用的下一批步骤

1. 新建专属结果目录（如 `formal-resume-real-mongo-004-001`，须不存在）和独立后端基线。只复制当前 `backend/src`、package.json、package-lock.json；不复制 .env、server.js、public、数据目录。复制前后逐文件 hash 加文件集合校验，记录当前 HEAD/时间/来源；变化则重新冻结而不带病继续。
2. 用 mkdtemp 创建 `/private/tmp/qd-mongo-backend-XXXXXX`，其下 backend 同样只复制冻结 src/package/lock，再复制已核对的 node_modules。依赖实路径须落新 backend/node_modules 内，确保 .env 不存在。旧依赖目录不直接用作新业务源。
3. 复制诊断脚本到结果目录，唯一修改 frozen 字符串为第1步冻结路径，保留 diff、源/脚本/二进制/依赖包版本和hash。做 `node --check`，0仅表示语法可用。
4. 用结构化 subprocess 参数/env 启动下述命令，保存句柄、原始 stdout/stderr 与真正 Node 退出码。子进程环境仅保留必要 PATH/TMPDIR 和这些诊断键；不要把整个系统环境/秘密输出到 inputs。

```text
executable: /opt/homebrew/bin/node
arguments: --test --test-concurrency=1 <新结果目录>/mongo-route-diagnostic.cjs
QD_ALLOW_REAL_MONGO=NEW_OWNED_LOOPBACK_INSTANCE
QD_BACKEND_ROOT=<新建/private/tmp/qd-mongo-backend-XXXXXX/backend绝对路径>
QD_MONGOD=/private/tmp/qd-mongo-runtime-4upbmyti/extracted/mongodb-macos-aarch64--8.0.29/bin/mongod
QD_MONGOD_SHA256=fb5a3c157a369839ab585df5591c36f637d64fc4e2289c6fa250aefe9c69b421
QD_MONGO_PORT=37294
```

端口37294只是本次建议候选，**本次没有绑定/探测其空闲**。脚本启动前自身试绑定；若占用，保留拒绝结果，换37000…37999的新候选及新run，不杀占用者。脚本还会在真正连接后核对自有PID、dbpath、绑定地址、端口和空collections；这些护栏不可删。被沙盒阻止 loopback/子进程时，主控按明确的本机临时实例动作申请所需执行权限，不切换到真实服务。

5. 预期执行五项：QD007一次真实owner修改与持久可见性；training/angle各500完整对照、501完整恢复断言。确认每条先通过真实插入后时间戳/ID回读护栏再解释结果。预计当前根因仍会导致3失败，但**以实际运行记录为准**；Node非零不能被wrapper返回0掩盖。
6. 结束核对自有 mongod 正常退出和新日志 shutdown complete；保留新db/log，不dropDatabase、不删旧库、不用killall。若进程超时，凭本次句柄/PID/identity核对仅处理自有进程。运行后记录源指纹未变化与可重新打开的原始证据位置。

本批与正在执行的 iOS UI 无共享设备焦点，只是本机独立临时 HTTP/Mongo 端口；主控仍统一资源调度。本报告未擅自启动并行运行。

## 结果边界

本次新运行可重新取得当前原样后端路由＋真实Mongoose/Mongo持久化证据，补回原 build 丢失后的关键可核验材料。它仍不证明 App SyncRestoreService 实际调用、真实Apple登录、部署服务版本或跨设备恢复。500/501同向时间样本不等同1000/乱序/相同updatedAt全覆盖；不为尽快交付扩写成所有恢复测试通过。
