# 自定义球形生产双模拟器验收 · 2026-10-19

用户要求两台模拟器连接生产服务，验证同一账号的换机恢复、修改与删除。已完成 **7个业务阶段 + 2个本地清理阶段，9通过、0失败、0跳过**，未发现需要修改产品代码的问题。

## 执行环境与边界

- 执行主机：本机 Mac，Xcode 26.2；A为 iPhone 17 Pro，B为 iPhone SE 3，两者均为 iOS 26.3。
- A：`6873B8B5-226A-4C33-BAA6-3516CF26D1F8`；B：`FEC0D1E7-0A8E-4CDB-ADE9-D33DC2D4C898`。均通过现有生命周期管理器明确借用，每阶段串行。
- 两台运行同一次构建的 App XCTest 宿主，调用真实 `CustomFormationRepository → CustomFormationSyncService → FormationRESTBackend → APIClient`，直接连接 `http://106.54.3.210:3000`，未使用本地服务、SSH转发或HTTP模拟。
- 服务器创建一个独立临时账号，为两台提供相同账号的有效访问令牌。每阶段先请求生产 `/user/profile`，核对账号ID及本轮唯一探针名；不匹配立即停止写入。测试令牌通过0600临时文件传入内存TokenStore，不写命令行或Keychain。
- 仓库使用每台模拟器自己的 Application Support 持久文件，以本轮账号命名隔离。B恢复前断言文件不存在、列表为空、游标为0；不是预先把A文件复制到B。每阶段结束宿主进程退出，后续阶段重新加载已落盘状态。
- 本轮验证实际客户端数据链路，不覆盖 Apple/微信登录UI、设置页开关交互和后台自动调度；同步由测试显式调用。不是两台真机验收，也没有新增界面截图验收或发布App。

本机空间不足时只清理本任务旧 `build/CustomFormation-20261017/Build/Intermediates.noindex` 与 `ModuleCache.noindex`，保留旧构建产物、日志和截图，腾出约1.3GiB后继续。Mac mini仅做只读预检，当时已有队列任务，本轮没有在其上构建、启测或新增任务。

## 实际结果

| 阶段 | 验证内容 | 结果 |
| --- | --- | --- |
| A创建上传 | 25颗独立实例的重复1号球、另1母球、两条共用端点的直线 | 通过，服务端revision=1，待同步=0 |
| B换机恢复 | 从不存在的本地文件恢复，核对模板ID、名称、26个球位、球实例ID、线ID、共享端点和排列顺序 | 通过，revision=1 |
| B修改上传 | 改名、移动第一颗目标球、移动一个端点、反转第一条线的球顺序 | 通过，revision=2 |
| A接收并再次修改 | A从旧版接收并逐字段核对B修改；再改名/球位/端点，重建仓库对象后仍保留待上传操作，再同步 | 通过，revision=3 |
| B接收并删除 | B收到A的再次修改并逐字段核对，删除模板并上传删除标记 | 通过，revision=4，列表为空 |
| A接收删除 | A由仍有模板变为空；重建仓库对象并从游标0完整重放，模板不复活 | 通过，revision=4、deleted=true |
| B删除后空库恢复 | B使用另一个全新本地仓库，从0拉取所有创建/修改/删除历史 | 通过，最终仍为空，删除版本=4 |

每一阶段都在生产数据库独立核对本轮模板和变更回执。变更记录完整为 **创建1 → B修改2 → A修改3 → 删除4**，没有重复记录；客户端九次输出确认同一账号，设备UDID与命令目的设备一致。

构建日志为 `TEST BUILD SUCCEEDED`。逐次 `xcresulttool` 摘要均为1通过、0失败、0跳过；运行器强制核对实际测试计数、结果、设备身份、生产地址及待同步数，非零退出立即停止。构建前、构建后、整轮测试后的源码指纹一致。完整App/UI回归不在本轮范围，不能把上一轮56单测/3UI重复计入本轮。

## 清理与留存

两台分别执行定向清理，只删除本轮探针仓库文件；删除后重新读取为空。服务器通过实际 `/user/account` 删除临时账号，再核对该用户、模板、变更回执均为0；服务器与本机临时令牌文件已删除。生产 `/health` 正常。

两台设备租约均已释放，设备及原有保留状态未改变。管理器显示的既有 `failed` 保留状态属于此前其他测试，不能误当本轮失败，也不能据本轮通过删除旧现场。

实现入口：`QiuJiTests/CustomFormationSyncIntegrationTests.swift` 的独立生产selector；运行器 `backend/test/support/runProductionFormationSimulators.py`；账号生命周期 `backend/test/support/productionFormationSimulatorAccount.cjs`。原本的本地隔离集成selector仍独立保留。

证据：`output/custom-formation-production-sims-20261019/`，含 `build.log`、`run.log`、9份xcresult及摘要、7份服务端版本检查、`results.json`、`verification-summary.json`、源码指纹、`leases-after.json` 与 `account-cleanup.log`。令牌fixture不留存。未提交或push Git。

用户随后要求关闭本轮模拟器：已通过生命周期管理器逐台关闭A/B，并回读两台均为Shutdown；设备及数据保留，证据 `shutdown-confirmed.json`。
