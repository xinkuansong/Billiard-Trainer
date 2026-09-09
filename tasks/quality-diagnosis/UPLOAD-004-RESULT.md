# 上传边界诊断结果 — snapshot004

2026-09-08。只诊断，不改业务。关联 PLAN-v2 / SC24、SC25。

## 多项上传中途失败及补传

`formal-004-upload-boundary-001` 实际执行唯一方法 `QiuJiTests/UploadBoundaryDiagnosticTests/testMultiItemInFlightFailureRetriesOnlyUnacknowledgedItem`：**1/1 通过，0.673 秒，make exit 0**。64 个文件已归档，包含原始 xcresult、日志、测试源码及五阶段 JSON；主控逐阶段核对事件和队列，不只依据测试绿灯。

- 全新专用 iPhone17Pro / iOS26.2：`92BF2703-3BBD-4E22-93E2-B36F949E665F`；QiuJiDiagnosticMemoryHost 初始化前开启内存模式，无身份或 Pro 夹具、无真实凭据。
- 真实 AuthState / AccountDataCoordinator / SyncQueueManager / SwiftData；注入受控上传、空恢复响应及凭据替身。通过实际登录协调入口启动，关闭本轮游客迁移询问，以保留游客对照。
- A 的 S0/S1/S2 按固定时间排序；B、guest 各一条对照。S1 在真实上传 await 内明确挂起，此时 S0 已确认、S2 尚未请求。
- 放行 S1 网络失败后：尝试 S0/S1/S2，成功 S0/S2，只有 S1 留在 A 队列；随后正常恢复阶段调用 sessions、angles 各一次。
- 下一轮只请求 S1，成功后 A 队列清空。累计尝试顺序 S0/S1/S2/S1、成功顺序 S0/S2/S1；B、guest 队列保留。独立 ModelContext 验证全部五条训练记录的归属、来源及 payload 保持不变，无意外端点调用。
- 原 snapshot004 的 5350 个输入重新校验：changed 0 / missing 0。只新增诊断类及快照测试工程注册，三份 scheme 字节恢复。

证据：`archive/quality-diagnosis/runs/formal-004-upload-boundary-001/`；`archive/quality-diagnosis/observations/source-recheck-upload001.json`。

## 边界与下一步

本项验证有限服务层行为，不证明真实 HTTP、部署服务、正常 App 网络恢复或跨设备同步；不是磁盘进程重启测试。没有新增产品缺陷，也不撤销 QD007/008。

尚未执行上传在途时关闭同步、关闭再开、账号 A→B→A 的迟到结果边界，具体判据沿用 UPLOAD-004-REMAINDER-PREFLIGHT.md。SC24/25 仍 partial。Release 普通界面验证及 B6 其余本机/外部缺口继续保留。


## 上传在途失效四行补验（18:36更新）

2026-09-08 上传在途失效001终态：单方法四独立行全部完成，1/1通过1.036秒；121文件含xcresult及24阶段JSON归档并核对。关闭后迟到成功/失败、同步关闭再开、账号A→B→A均阻止旧轮S2和恢复；新轮仅处理未确认项，B/guest保持。账户ABA实际交付B协调事件，新A轮延后到旧轮结束，不外推App通知并发调度。见UPLOAD-004-RESULT.md。

专用全新内存宿主 A9F253FE-9D44-4E07-A976-ACC67A9787FC。关闭成功行旧轮S0/S1成功并出队、S2保留；其余三行旧轮S0成功、S1失败且S1/S2保留；全部旧轮restore 0，新轮恢复各1次，最终只留B/guest两项。五条实体及来源独立读回保持，两个恢复锚点在旧轮均为空。账户ABA的syncChoiceRevision始终1，B协调事件改变代次后仍能拦住旧轮；同步ABA则为revision1→2→3。

证据：archive/quality-diagnosis/runs/formal-004-upload-invalidation-001 与 observations/upload-invalidation001-review.json。此前文中“尚未执行”的这四项现已完成有限服务层补验；真实HTTP/跨设备与通知调度并发仍未验证，SC24/25仍partial。
