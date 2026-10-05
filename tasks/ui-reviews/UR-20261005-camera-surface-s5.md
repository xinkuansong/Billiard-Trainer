# DR-348 S5 手势分轴（2026-10-05）

## 变更
用户要求横纵隔离。每日3D曲面单指拖动在系统识别时，以touch-down到began的主要位移锁定横/纵轴；本次按住期间忽略另一轴，松手/取消/新触摸后重选。正好等分的斜向取横轴，不设额外距离或方向比例门槛；保留首段与ended末段在选中轴上的位移。横向等高、纵向保持bearing，半灵敏度0.325与33ms重采样不变，俯视摆球和捏合不套用此锁轴。

改变的是手势路由，CameraSurface几何、增益、TwoViewCamera时间补间均未修改。SurfacePanAxisLock由Coordinator持有，finishCameraObservation和新touch-down清空；无效/零输入不决定轴，锁定后反向仍沿同轴。

## 验证
证据目录：`build/camera-surface-s5-20261005/`。
新增2个状态序列检查：横纵正反、主次方向互换仍不换轴、纯副轴不动、零/非有限输入、正斜角、重新开始。原生UI替换旧双轴斜拖期望，以含副轴偏移的横/竖/短反向拖动检查真实眼高和bearing；另回归S4环线/俯视编辑/摆球/击球换杆。最终16核心+5原生UI共21项全部通过。

首轮新增UI最后左滑断言误将有符号角差写成正值（实际-0.0355877rad）；按方向语义改为<-0.005，未动生产逻辑；该用例完整复跑通过（29.903s），见FL-115及axis-retest.log/xcresult。原始失败证据保留。截图已导出，抽检横向偏移、纵向偏移和短反向3张，未见HUD/球桌视觉异常。verify-gate通过。

## 交付
Debug-O设备构建与严格codesign验证通过，普通包com.xinkuan.qiuji身份及SHA256见identity.json。安装前设备曾显示connected，安装时CoreDevice报1011找不到设备；复查状态unavailable（devices-install-check.json）。因此本版尚未装到手机，设备上仍是前版；待重新连接安装，手感待用户试用，未发布。
