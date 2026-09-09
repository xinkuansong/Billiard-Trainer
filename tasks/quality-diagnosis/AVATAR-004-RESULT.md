# 头像取消与离线恢复诊断004

新隔离iPhone17Pro/iOS26.2，头像选图取消、裁切取消、同一合成图使用后离线失败、恢复默认头像、返回重入及再次选图取消完整链1/1通过80.235秒。139文件及observer归档，8张关键完整PNG已审。先行discovery001 1/1通过29.695秒、77文件归档，仅观察真实选图页，不算上传测试。

设备48F88850-F22E-4D6B-B582-D78C7ED70203，Light/large读回；合成图复用archive/quality-diagnosis/inputs/photo-004-synthetic-001/QD004-PHOTO-001.png，导入SHA见resume004/avatar-synthetic-import001.json。该设备实际选图页完整PNG/AX显示唯一合成图标签“照片, 9月08日, 17:03”，frame(0,292,132.9,133)，Cancel标识；由本轮观察取得，未凭旧设备时间戳猜选图。

正式运行formal-004-avatar-boundary-001，方法AvatarBoundaryDiagnosticUITests/testSyntheticPickerAndCropCancelThenOfflineUploadRestoresDefaultAvatar。正常游客确认后使用现有固定离线身份，已核实际Debug APIClient在requestData传输前抛notConnectedToInternet，无真实凭据或上传。首次取消没有新增头像，裁切取消也没有错误提示；再次选择同一图后点击使用才出现失败。关闭提示后恢复默认头像、昵称保持服务端球友、无删除头像入口，重新进入及再次打开/取消系统选图正常。

主控完整审图：2初始默认、4选图取消、7首次裁切、8裁切取消、11同图再次裁切、12失败提示、13默认恢复、16失败后仍可操作。观察到圆形裁切预览确为本合成图；本轮没有拖动/缩放裁切，不声称该手势已测。

新增QD031 P2：失败提示直接输出NSURLErrorDomain错误-1009，缺少易懂的网络原因与恢复建议。取消与回滚功能通过，不等于错误文案通过。

边界：初始头像为nil/默认，不能宣称非空旧头像revision回滚已在UI验证；该部分复用既有服务层证据。真实上传成功、跨设备缓存与账号接口仍需受控服务条件。SC30保持partial，不外推整套资料功能或真机相册权限。
