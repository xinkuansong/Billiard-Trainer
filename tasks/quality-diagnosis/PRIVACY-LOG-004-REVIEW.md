# 诊断日志与敏感信息抽查 — snapshot004

2026-09-08。SC31 的有限只读检查；不读取钥匙串、进程环境、用户真实账号或服务端日志。

## 当前实际证据

对已授权合成数据运行的四份归档 `xcode-test.log`，从 Selected tests 开始至日志末尾检查：account-failure-004（541行）、avatar-boundary-001（371行）、entitlement-boundary-001（1209行）、upload-boundary-001（23行），共2144行。前三项均使用固定离线身份，上传项使用全新无凭据内存宿主。

Bearer 非空值、JWT 形状、access/refresh token、password、authorization 赋值三类匹配均0。结果只存行号、日志/命中行 SHA，不复制可能敏感的匹配值：`archive/quality-diagnosis/observations/privacy-log004-review001.json`。

上传日志出现一条实际 `[SyncQueue]` 临时失败：包含合成训练 UUID、实体类型、create 操作和受控 networkError 文本。它是可关联记录标识及错误原文，不包含此批的训练笔记/payload。其余三份运行未出现 SyncQueue/SyncRestore 行，符合其离线身份夹具在请求前阻断的边界，不能据此证明联网错误日志安全。

## 实际代码抽查

冻结源 `QiuJi/Data/Services/`：APIClient、AuthState、AvatarStore、OwnerProfileStore 未匹配到 print/debugPrint/Logger/os_log 日志入口；这只是这些文件的窄检索，不等同于下游 SDK 无日志。

SyncQueueManager:98–104 将 entityId、operation、失败原因直接打印，classify 会保留 serverError 的前200字符响应正文，非永久错误使用错误描述。SyncRestoreService:135 会打印 userId；其 describe:392–404 对非解码错误直接插值，对 dataCorrupted 保留 debugDescription。上述路径没有按敏感字段清洗的保证，且不在 DEBUG 条件内。此为源码风险记录；本次没有向服务注入真实秘密，也没有证据表明用户秘密已泄露。

## 结论与限制

完成了本次有限合成运行日志抽查；未发现上述形状的凭据输出，**不能证明真实认证或任意后端错误下无敏感信息**。不以正则零命中作为完整隐私验收，也不将 Xcode 构建路径、合成 UUID 或测试附件误判为真实凭据泄露。

后续优先检查真实受控服务错误正文和发布版运行日志；若确认包含账号/凭据/个人资料，再按实际用户影响定级。修复阶段可考虑结构化日志与允许字段清单，此次不改业务。关于/法律正常界面尚待独立UI结果，配置为空的问题仍为 QD021。
