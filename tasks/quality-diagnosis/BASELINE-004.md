# snapshot004：空间恢复后的新基线

2026-09-07，继续PLAN-v2诊断范围，无业务修复。HEAD eaa7021b67f895766bde2df27a6b2cea26d92a97及复制时工作区；不声称与snapshot003字节相同。旧build和旧诊断设备清单均当前不可用，见EVIDENCE-AVAILABILITY-20260907.md。

冻结5350个文件，来源目录为QiuJi、QiuJiTests、QiuJiUITests、QiuJiLiveActivity、Config、scripts、content、docs、.kiro/steering，另含project.yml。该枚举范围与旧4849计数不同，不能用数量差当代码变更数。复制采用APFS克隆并逐文件SHA256核验，源前后漂移0、副本不匹配0。未显示配置秘密内容。

工程由冻结Makefile调用XcodeGen生成，与当前工作区project.pbxproj仅两独立通知测试共8行添加，无删除。另立QiuJiDiagnosticMemoryHost，将TestAction注入-v50.inMemoryStore；只为宿主隔离存储，不推断无网络或无偏好副作用。UI用原QiuJi scheme、正常我的→训练目标入口、专用新游客设备。

证据位置：
- build/quality-diagnosis/resume004：输入、复制审计、设备/运行配置；build/quality-diagnosis/snapshot-004：执行源码。
- archive/quality-diagnosis/snapshot-004：清单、工程diff、dirty清单和独立源码副本。该目录与build分开，仍属本机副本，不是异地备份；包含构建所需私有配置，不提交发布。
- archive/quality-diagnosis/runs：终态运行由archive_run.py复制日志、选择器、截图和实际xcresult，生成SHA256清单；新目录拒绝覆盖。

原历史结果继续保留为历史记录。需要当前复核的问题按新编号重新取证，不能从文字记录伪造缺失的原始日志、截图或exit.json。当前新通知通过与否必须由新运行真实非零测试结果决定。

2026-09-08 10:59运行后基线核验：原5350个冻结输入逐文件SHA256重核，changed=[]、missing=[]。诊断新增文件不在原基线中，已单独overlay归档。报告archive/quality-diagnosis/snapshot-004/post-learning-baseline-check.json。专用Allow设备已关闭，保留沙盒。
